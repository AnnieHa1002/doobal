import 'dart:convert';
import 'dart:io' show gzip;

import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../domain/bucket.dart';
import '../domain/gait.dart';
import '../domain/rules.dart';
import '../domain/time_kst.dart';

/// 백업 문자열의 형식 번호. 문자열의 짜임(머리·표 배치)을 바꿀 때 올린다.
/// 표나 열이 늘어나는 건 DB 스키마 번호가 맡는다
const backupFormat = 1;

/// 백업 문자열의 크기. 실기기에서 서버 문서 한도(1MiB)와 견주어 볼 때 쓴다
class BackupSize {
  const BackupSize({required this.chars, required this.gzipBytes, required this.jsonBytes});

  /// base64 글자 수 (서버에 올라가는 크기, config backup.maxChars와 견준다)
  final int chars;

  /// 압축한 바이트와 압축 전 JSON의 바이트
  final int gzipBytes;
  final int jsonBytes;
}

/// 로컬 DB ↔ 백업 문자열 (M5 명세). 문자열은 JSON을 gzip한 뒤 base64로 바꾼 것이고,
/// 서버에 올리고 받는 건 BackupStore가 한다 (여기는 DB와 문자열 사이만).
///
/// JSON 짜임: { format, schema, createdUtc, syncedUtc, journeyWalked, tables: { 표: { cols, rows } } }.
/// 표 이름·열 이름은 SQL 이름이고, 행은 cols 순서의 값 배열이다 (이름을 행마다 되풀이하지 않아 작다).
/// 옛 백업에 없는 열은 DB 기본값으로 채우고, 지금 DB에 없는 열·표는 건너뛴다.
/// 시각은 DB처럼 UTC epoch ms
class BackupService {
  BackupService(this.db, this.rules);

  final AppDb db;
  final Rules rules;

  /// 백업에 넣는 표 → 그 표에서 뺄 열.
  /// 뺀 열은 이 기기에만 두고 서버·백업에 넣지 않는다 (M5 명세): 만 14세 확인 시각, 계정 연결·방명록
  /// 동의 시각. 권한 단계를 마친 시각(onboardedAt)도 뺀다 (새 기기에서는 권한을 다시 물어야 한다).
  /// 표 하나를 새로 만들면 여기나 [skippedTables]에 넣어야 하고, 테스트가 빠진 표가 없는지 본다
  late final Map<TableInfo<Table, dynamic>, Set<String>> _included = {
    db.daySummaries: {},
    db.walkSessions: {},
    db.journeys: {},
    db.travelFund: {},
    db.paintingsOwned: {},
    db.propsOwned: {},
    db.wallSlots: {},
    db.guestbookTickets: {},
    db.guestbookPosts: {},
    db.notificationSettings: {},
    db.profile: {
      db.profile.ageConfirmedAt.$name,
      db.profile.onboardedAt.$name,
      db.profile.linkConsentAt.$name,
      db.profile.guestbookConsentAt.$name,
    },
  };

  /// 백업에 넣지 않는 표 (기기 상태). 복원할 때 걸음 분과 동기화 상태는 다시 만들고,
  /// 알림 기록은 지금 기기 것을 그대로 둔다. 동기화 상태의 restoreFloorDay(복원한 마지막 날)도
  /// 이 기기에서 복원할 때 정하는 값이라 표째 넣지 않는다
  List<TableInfo<Table, dynamic>> get skippedTables =>
      [db.stepMinutes, db.syncState, db.notificationLog];

  /// 백업에 넣는 표 (SQL 이름)
  List<String> get includedTableNames => [for (final t in _included.keys) t.actualTableName];

  /// 지금 DB를 백업 문자열로 만든다. [now]는 만든 시각(createdUtc).
  /// base64 길이가 config backup.maxChars를 넘으면 StateError (넘는 일은 없어야 한다)
  Future<String> exportBackup(DateTime now) async {
    final json = await db.transaction(() async {
      final tables = <String, Object?>{
        for (final e in _included.entries) e.key.actualTableName: await _dump(e.key, e.value),
      };
      final synced = (await _syncStateRow())?.lastFetchedUtc;
      return <String, Object?>{
        'format': backupFormat,
        'schema': db.schemaVersion,
        'createdUtc': now.toUtc().millisecondsSinceEpoch,
        'syncedUtc': synced,
        'journeyWalked': await _walkedSnapshot(synced),
        'tables': tables,
      };
    });
    final text = base64.encode(gzip.encode(utf8.encode(jsonEncode(json))));
    if (text.length > rules.backupMaxChars) {
      throw StateError('백업이 너무 커요: ${text.length}자 (한도 ${rules.backupMaxChars}자)');
    }
    return text;
  }

  /// 백업 문자열로 지금 DB를 되돌린다. 한 트랜잭션이라 중간에 실패하면 아무것도 바뀌지 않는다.
  /// 모르는 format이거나 깨진 문자열이면 FormatException, 이 앱보다 새 스키마면 StateError.
  ///
  /// - 넣는 표는 비우고 백업 행으로 채운다. 이 기기에만 두는 프로필 열(확인·동의·권한 단계 시각)과
  ///   알림 기록은 지금 기기 값 그대로다.
  /// - 걸음 분(StepMinutes)은 비운다. 동기화 상태는 마지막 동기화 시각을 비우고, 설치 시각을 거기서
  ///   48시간 전으로 둬서 다음 동기화가 건강 앱에서 그 뒤를 다시 가져온다: 백업에 적힌 마지막 동기화
  ///   (syncedUtc)의 refetchHours 전 한국 날짜 시작부터 (그 날의 하루 요약이 잘리지 않게 날짜 시작으로,
  ///   첫 기록일보다는 앞서지 않게). 복원한 하루 요약의 마지막 날은 restoreFloorDay에 적는다:
  ///   새 기기의 건강 앱에 그 기록이 없어도 그 날까지의 하루 요약·걷기 구간이 0으로 덮이지 않는다
  ///   (SyncService가 다시 계산한 값이 복원값보다 작으면 복원값을 지킨다)
  /// - 진행 중인 여정은 걸음 분이 없어서 진행 거리를 다시 셀 수 없다. 백업에 적힌 걸은 거리
  ///   (journeyWalked.km)를 여정의 경비(fundKm)에 더하고 시작 시각을 syncedUtc의 분으로 옮긴다.
  ///   그러면 진행 거리 = 경비 + 시작 이후 걸은 거리라는 엔진 계산은 그대로이고, 복원 뒤 동기화가
  ///   가져오는 그 분 이후의 걸음만 새로 더해진다 (엔진은 바꾸지 않는다)
  Future<void> restoreBackup(String text) async {
    final backup = _decode(text);
    await db.transaction(() async {
      final device = await (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();
      for (final e in _included.entries) {
        await db.delete(e.key).go();
        final dump = backup.tables[e.key.actualTableName];
        if (dump != null) await _load(e.key, e.value, dump);
      }
      if (device != null) {
        await db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
          id: const Value(1),
          ageConfirmedAt: Value(device.ageConfirmedAt),
          onboardedAt: Value(device.onboardedAt),
          linkConsentAt: Value(device.linkConsentAt),
          guestbookConsentAt: Value(device.guestbookConsentAt),
        ));
      }
      await _carryWalkedKm(backup);
      await db.delete(db.stepMinutes).go();
      await _resetSyncState(backup);
    });
  }

  /// [text]의 크기 (base64 글자 수, 압축 바이트, 압축 전 JSON 바이트). 읽을 수 없으면 FormatException
  static BackupSize measure(String text) {
    try {
      final zipped = base64.decode(text.trim());
      return BackupSize(
        chars: text.trim().length,
        gzipBytes: zipped.length,
        jsonBytes: gzip.decode(zipped).length,
      );
    } catch (_) {
      throw const FormatException(_unreadable);
    }
  }

  Future<Map<String, Object?>> _dump(TableInfo<Table, dynamic> t, Set<String> skip) async {
    final cols = [
      for (final c in t.$columns)
        if (!skip.contains(c.$name)) c.$name,
    ];
    final rows = await db
        .customSelect(
          'SELECT ${cols.map((c) => '"$c"').join(', ')} FROM "${t.actualTableName}" ORDER BY rowid',
        )
        .get();
    return {
      'cols': cols,
      'rows': [
        for (final r in rows) [for (final c in cols) r.data[c]],
      ],
    };
  }

  /// 진행 중인 여정이 시작한 뒤 마지막 동기화 직전 분까지 저장된 걸음으로 잰 걸은 거리(km).
  /// 마지막 동기화 분은 아직 덜 찬 분이라 빼고, 복원 뒤 동기화가 그 분부터 다시 가져와서 센다.
  /// 진행 중인 여정이 없거나 동기화한 적이 없으면 null (이때는 이을 값이 없다).
  /// 디버그 거리 배수는 곱하지 않은 값이다
  Future<Map<String, Object?>?> _walkedSnapshot(int? syncedUtc) async {
    if (syncedUtc == null) return null;
    final active = await (db.select(db.journeys)
          ..where((t) => t.status.equalsValue(JourneyStatus.active)))
        .getSingleOrNull();
    if (active == null) return null;
    final rows = await (db.select(db.stepMinutes)
          ..where((t) =>
              t.minuteUtc.isBiggerOrEqualValue(_minuteOf(active.startUtc)) &
              t.minuteUtc.isSmallerThanValue(_minuteOf(syncedUtc)))
          ..orderBy([(t) => OrderingTerm(expression: t.minuteUtc)]))
        .get();
    final minutes = [for (final r in rows) StepMinute(r.minuteUtc, r.steps)];
    return {'id': active.id, 'km': distanceM(classifyGait(minutes, rules), rules) / 1000};
  }

  Future<SyncStateRow?> _syncStateRow() =>
      (db.select(db.syncState)..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<void> _load(TableInfo<Table, dynamic> t, Set<String> skip, _Dump dump) async {
    final known = {for (final c in t.$columns) c.$name};
    // 지금 DB에 없는 열(옛 백업의 지워진 열)과 뺄 열은 건너뛰고, 빠진 열은 DB 기본값이 채운다
    final use = [
      for (var i = 0; i < dump.cols.length; i++)
        if (known.contains(dump.cols[i]) && !skip.contains(dump.cols[i])) i,
    ];
    if (use.isEmpty) return;
    // 표마다 행 타입이 달라서 SQL로 넣는다 (열 이름은 위에서 이 DB의 열로 걸렀다)
    final sql = 'INSERT INTO "${t.actualTableName}" (${use.map((i) => '"${dump.cols[i]}"').join(', ')}) '
        'VALUES (${use.map((_) => '?').join(', ')})';
    await db.batch((b) {
      for (final row in dump.rows) {
        b.customStatement(sql, [for (final i in use) _arg(row[i])]);
      }
    });
  }

  Object? _arg(Object? v) => switch (v) {
        null || int() || double() || String() => v,
        bool() => v ? 1 : 0,
        _ => throw FormatException('백업의 값을 읽을 수 없어요: $v'),
      };

  /// 진행 중인 여정에 백업의 걸은 거리를 이어 붙인다 (restoreBackup 설명). 여정이 마지막 동기화 분
  /// 이후에 시작했으면 걸음 분이 모자라지 않아서 그대로 둔다
  Future<void> _carryWalkedKm(_Backup b) async {
    final id = b.walkedJourneyId;
    final synced = b.syncedUtc;
    if (id == null || synced == null) return;
    final row = await (db.select(db.journeys)
          ..where((t) => t.id.equals(id) & t.status.equalsValue(JourneyStatus.active)))
        .getSingleOrNull();
    final cut = _minuteOf(synced) * Duration.millisecondsPerMinute;
    if (row == null || row.startUtc >= cut) return;
    await (db.update(db.journeys)..where((t) => t.id.equals(id))).write(JourneysCompanion(
      fundKm: Value(row.fundKm + b.walkedKm),
      startUtc: Value(cut),
    ));
  }

  /// 동기화 상태를 다시 만든다: 마지막 동기화 시각은 비우고, 설치 시각을 다음 동기화가 가져올 시작으로 둔다
  /// (마지막 동기화의 refetchHours 전 한국 날짜 시작). 첫 기록일은 복원한 하루 요약의 가장 이른 날이라
  /// (옛 기기의 첫 동기화 날이 곧 가장 이른 하루 요약이다) 도착 예정일 평균이 이어지고,
  /// 가져올 시작이 그 날보다 앞이면 그 날 시작으로 미룬다 (첫 기록일 전의 하루 요약을 새로 만들지 않는다).
  /// 하루 요약이 없으면 가져올 시작의 날짜가 첫 기록일이다.
  /// 복원한 하루 요약의 가장 늦은 날은 restoreFloorDay (없으면 null)
  Future<void> _resetSyncState(_Backup b) async {
    final ref = DateTime.fromMillisecondsSinceEpoch(b.syncedUtc ?? b.createdUtc, isUtc: true);
    var from = kstDayStartUtc(kstDayKey(ref.subtract(Duration(hours: rules.refetchHours))));
    final earliest = db.daySummaries.day.min();
    final latest = db.daySummaries.day.max();
    final range =
        await (db.selectOnly(db.daySummaries)..addColumns([earliest, latest])).getSingle();
    final first = range.read(earliest);
    if (first != null && kstDayStartUtc(first).isAfter(from)) from = kstDayStartUtc(first);
    await db.delete(db.syncState).go();
    await db.into(db.syncState).insert(SyncStateCompanion.insert(
          id: const Value(1),
          firstRecordDay: first ?? kstDayKey(from),
          installUtc: from.millisecondsSinceEpoch,
          restoreFloorDay: Value(range.read(latest)),
        ));
  }

  /// 문자열을 풀어 머리·표 짜임을 확인한다. DB는 건드리지 않는다
  _Backup _decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(gzip.decode(base64.decode(text.trim()))));
    } catch (_) {
      throw const FormatException(_unreadable);
    }
    if (json is! Map<String, dynamic>) throw const FormatException(_unreadable);
    final format = json['format'];
    if (format != backupFormat) throw FormatException('모르는 백업 형식이에요: $format');
    final schema = json['schema'];
    final created = json['createdUtc'];
    final synced = json['syncedUtc'];
    final tables = json['tables'];
    if (schema is! int ||
        created is! int ||
        (synced != null && synced is! int) ||
        tables is! Map<String, dynamic>) {
      throw const FormatException(_unreadable);
    }
    if (schema > db.schemaVersion) {
      throw StateError('더 새로운 앱에서 만든 백업이에요 (백업 $schema, 이 앱 ${db.schemaVersion})');
    }

    final dumps = <String, _Dump>{};
    for (final t in _included.keys) {
      final raw = tables[t.actualTableName];
      if (raw == null) continue;
      if (raw is! Map<String, dynamic>) throw const FormatException(_unreadable);
      final cols = raw['cols'];
      final rows = raw['rows'];
      if (cols is! List || cols.any((c) => c is! String) || rows is! List) {
        throw const FormatException(_unreadable);
      }
      for (final r in rows) {
        if (r is! List || r.length != cols.length) throw const FormatException(_unreadable);
      }
      dumps[t.actualTableName] = (
        cols: cols.cast<String>(),
        rows: [for (final r in rows) (r as List).cast<Object?>()],
      );
    }

    final walked = json['journeyWalked'];
    String? walkedId;
    var walkedKm = 0.0;
    if (walked != null) {
      if (walked is! Map<String, dynamic> || walked['id'] is! String || walked['km'] is! num) {
        throw const FormatException(_unreadable);
      }
      walkedId = walked['id'] as String;
      walkedKm = (walked['km'] as num).toDouble();
    }
    return _Backup(created, synced as int?, walkedId, walkedKm, dumps);
  }
}

const _unreadable = '백업 문자열을 읽을 수 없어요';

int _minuteOf(int ms) => ms ~/ Duration.millisecondsPerMinute;

typedef _Dump = ({List<String> cols, List<List<Object?>> rows});

class _Backup {
  const _Backup(this.createdUtc, this.syncedUtc, this.walkedJourneyId, this.walkedKm, this.tables);

  final int createdUtc;

  /// 백업한 기기가 마지막으로 동기화한 시각. 동기화한 적이 없으면 null
  final int? syncedUtc;

  /// 진행 중이던 여정과 그 여정이 그때까지 걸은 거리(km). 없으면 null
  final String? walkedJourneyId;
  final double walkedKm;
  final Map<String, _Dump> tables;
}
