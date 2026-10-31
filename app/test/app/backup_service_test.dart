import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:doobal/app/backup_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:doobal/domain/rules.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

/// 마지막 동기화 KST 2026-11-18 14:30
final _synced = DateTime.utc(2026, 11, 18, 5, 30);
final _now = DateTime.utc(2026, 11, 18, 6);

int _ms(DateTime t) => t.millisecondsSinceEpoch;

Map<String, dynamic> _json(String text) =>
    jsonDecode(utf8.decode(gzip.decode(base64.decode(text)))) as Map<String, dynamic>;

String _pack(Map<String, dynamic> json) =>
    base64.encode(gzip.encode(utf8.encode(jsonEncode(json))));

/// 표 하나의 열과 행
Map<String, Object?> _table(List<String> cols, List<List<Object?>> rows) =>
    {'cols': cols, 'rows': rows};

/// 머리만 있는 백업 JSON (표는 [tables])
Map<String, dynamic> _backupJson({
  int format = 1,
  int schema = 9,
  int? synced,
  Map<String, Object?>? walked,
  Map<String, Object?> tables = const {},
}) =>
    {
      'format': format,
      'schema': schema,
      'createdUtc': _ms(_now),
      'syncedUtc': synced,
      'journeyWalked': walked,
      'tables': tables,
    };

/// 이 기기에만 두는 프로필 열의 값 (백업 문자열에 있으면 안 된다)
const _ageAt = 1700000000111;
const _onboardedAt = 1700000000222;
const _linkAt = 1700000000333;
const _guestbookAt = 1700000000444;

/// 백업에 들어가는 표마다 행을 넣고, 안 들어가는 표(걸음 분·동기화 상태·알림 기록)에도 넣는다.
/// 진행 중인 여정은 넣지 않는다 (그건 따로 시험한다)
Future<void> _fill(AppDb db) async {
  await db.batch((b) {
    b.insertAll(db.daySummaries, [
      DaySummariesCompanion.insert(
          day: '2026-11-17', steps: 4000, distanceM: 2800.5, countedSessions: 1),
      DaySummariesCompanion.insert(
          day: '2026-11-18', steps: 8123, distanceM: 5686.1, countedSessions: 2),
    ]);
    b.insertAll(db.walkSessions, [
      WalkSessionsCompanion.insert(
        startUtc: Value(_ms(_synced) - 3600000),
        endUtc: _ms(_synced) - 1800000,
        steps: 3000,
        distanceM: 2100.0,
        runRatio: 0.25,
        qualified: true,
        counted: true,
      ),
      WalkSessionsCompanion.insert(
        startUtc: Value(_ms(_synced) - 7200000),
        endUtc: _ms(_synced) - 6000000,
        steps: 800,
        distanceM: 560.0,
        runRatio: 0.0,
        qualified: false,
        counted: false,
      ),
    ]);
    b.insertAll(db.journeys, [
      // 내 동네 스케치에 도착한 첫 여정
      JourneysCompanion.insert(
        id: 'j1',
        originLat: 37.5665,
        originLng: 126.978,
        destId: 'sketch',
        startUtc: 1000,
        fundKm: 0,
        totalEffectiveKm: 2.4,
        status: JourneyStatus.arrived,
        arrivedUtc: const Value(2000),
        endLat: const Value(37.58),
        endLng: const Value(126.99),
        endedUtc: const Value(2000),
        visitNo: const Value(1),
        newFrame: const Value(Frame.wood),
        arrivalShown: const Value(true),
        destLat: const Value(37.58),
        destLng: const Value(126.99),
      ),
      // 명소에 도착 (아직 도착 화면을 안 봤다)
      JourneysCompanion.insert(
        id: 'j2',
        originLat: 37.58,
        originLng: 126.99,
        destId: 'kr001',
        startUtc: 3000,
        fundKm: 1.5,
        totalEffectiveKm: 25.25,
        status: JourneyStatus.arrived,
        arrivedUtc: const Value(4000),
        endLat: const Value(37.5796),
        endLng: const Value(126.977),
        visitNo: const Value(2),
        prevFrame: const Value(Frame.wood),
        newFrame: const Value(Frame.silver),
      ),
      JourneysCompanion.insert(
        id: 'j3',
        originLat: 37.5796,
        originLng: 126.977,
        destId: 'kr008',
        startUtc: 5000,
        fundKm: 0,
        totalEffectiveKm: 300.5,
        status: JourneyStatus.stopped,
        endLat: const Value(37.2),
        endLng: const Value(127.0),
        endedUtc: const Value(6000),
      ),
    ]);
    b.insert(
        db.travelFund, TravelFundCompanion.insert(id: const Value(1), km: 3.5, fundedUntilUtc: 7000));
    b.insertAll(db.paintingsOwned, [
      // 첫 그림(첫 여행 짐 꾸러미): 소유 기록 1줄만 있다
      PaintingsOwnedCompanion.insert(
        landmarkId: 'sketch',
        visits: 1,
        frame: Frame.wood,
        bestKm: 2.4,
        firstArrivedUtc: 2000,
        lastArrivedUtc: 2000,
        seen: const Value(false),
      ),
      PaintingsOwnedCompanion.insert(
        landmarkId: 'kr001',
        visits: 2,
        frame: Frame.silver,
        bestKm: 25.25,
        firstArrivedUtc: 3000,
        lastArrivedUtc: 4000,
      ),
    ]);
    b.insertAll(db.propsOwned, [
      PropsOwnedCompanion.insert(propId: 'hat_01', unlockedUtc: 10, seen: const Value(true)),
      PropsOwnedCompanion.insert(propId: 'bag_02', unlockedUtc: 20),
    ]);
    b.insertAll(db.wallSlots, [
      WallSlotsCompanion.insert(slot: const Value(0), landmarkId: 'kr001'),
      WallSlotsCompanion.insert(slot: const Value(2), landmarkId: 'sketch'),
    ]);
    b.insertAll(db.guestbookTickets, [
      GuestbookTicketsCompanion.insert(
        id: 'a:j1',
        kind: TicketKind.arrival,
        scope: 'sketch',
        openedUtc: 2000,
        usedUtc: const Value(2100),
      ),
      GuestbookTicketsCompanion.insert(
        id: 'm:1000',
        kind: TicketKind.milestone,
        scope: 'steps:1000',
        openedUtc: 8000,
        closedUtc: const Value(9000),
      ),
      GuestbookTicketsCompanion.insert(
          id: 'a:j2', kind: TicketKind.arrival, scope: 'kr001', openedUtc: 4000),
    ]);
    b.insertAll(db.guestbookPosts, [
      GuestbookPostsCompanion.insert(
          ticketId: 'a:j1',
          scope: 'sketch',
          body: '첫 그림이에요 🎨',
          createdUtc: 2100,
          status: PostStatus.pending),
      GuestbookPostsCompanion.insert(
          ticketId: 'm:1000',
          scope: 'steps:1000',
          body: '천 걸음',
          createdUtc: 8500,
          status: PostStatus.sent),
      GuestbookPostsCompanion.insert(
          ticketId: 'x:1', scope: 'kr001', body: '막힌 글', createdUtc: 9500, status: PostStatus.rejected),
    ]);
    b.insert(
      db.notificationSettings,
      NotificationSettingsCompanion.insert(
          id: const Value(1), allOn: const Value(true), n3On: const Value(false)),
    );
    b.insert(
      db.profile,
      ProfileCompanion.insert(
        id: const Value(1),
        homeName: const Value('중구'),
        homeLat: const Value(37.5665),
        homeLng: const Value(126.978),
        homeId: const Value('seoul-jung'),
        ageConfirmedAt: const Value(_ageAt),
        installId: Value('ab' * 16),
        nickname: const Value('나그네'),
        look: const Value('{"hair":3}'),
        onboardedAt: const Value(_onboardedAt),
        linkConsentAt: const Value(_linkAt),
        guestbookConsentAt: const Value(_guestbookAt),
      ),
    );
    // 안 들어가는 표
    b.insertAll(db.stepMinutes, [
      StepMinutesCompanion.insert(minuteUtc: Value(_ms(_synced) ~/ 60000 - 2), steps: 100),
      StepMinutesCompanion.insert(minuteUtc: Value(_ms(_synced) ~/ 60000 - 1), steps: 110),
    ]);
    b.insert(
      db.syncState,
      SyncStateCompanion.insert(
        id: const Value(1),
        lastFetchedUtc: Value(_ms(_synced)),
        firstRecordDay: '2026-11-17',
        installUtc: _ms(_synced) - 86400000 * 5,
      ),
    );
    b.insert(
      db.notificationLog,
      NotificationLogCompanion.insert(
          kind: NoticeKind.n2, refKey: 'j2', atUtc: 4000, status: NoticeStatus.sent),
    );
  });
}

/// 백업에 들어가는 표의 내용. 프로필은 이 기기에만 두는 네 열을 뺀 값으로 비교한다
Future<Map<String, Object?>> _userState(AppDb db) async => {
      'days': await db.select(db.daySummaries).get(),
      'sessions': await db.select(db.walkSessions).get(),
      'journeys': await db.select(db.journeys).get(),
      'fund': await db.select(db.travelFund).get(),
      'paintings': await db.select(db.paintingsOwned).get(),
      'props': await db.select(db.propsOwned).get(),
      'wall': await db.select(db.wallSlots).get(),
      'tickets': await db.select(db.guestbookTickets).get(),
      'posts': await db.select(db.guestbookPosts).get(),
      'noticeSettings': await db.select(db.notificationSettings).get(),
      'profile': [
        for (final r in await db.select(db.profile).get())
          r.copyWith(
            ageConfirmedAt: const Value(null),
            onboardedAt: const Value(null),
            linkConsentAt: const Value(null),
            guestbookConsentAt: const Value(null),
          ),
      ],
    };

Future<int> _count(AppDb db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM "$table"').getSingle()).read<int>('n');

Rules _rulesWithMaxChars(int maxChars) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  (j['backup'] as Map<String, dynamic>)['maxChars'] = maxChars;
  return Rules.fromJson(j);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDb a;
  late AppDb b;
  late BackupService svcA;
  late BackupService svcB;

  setUp(() {
    a = AppDb(NativeDatabase.memory());
    b = AppDb(NativeDatabase.memory());
    svcA = BackupService(a, rules);
    svcB = BackupService(b, rules);
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('모든 표는 백업에 넣는 표 아니면 안 넣는 표 중 하나다 (새 표는 어느 쪽인지 정해야 한다)', () {
    final skipped = {for (final t in svcA.skippedTables) t.actualTableName};
    final included = svcA.includedTableNames.toSet();
    expect(included.intersection(skipped), isEmpty);
    expect({...included, ...skipped}, {for (final t in a.allTables) t.actualTableName});
    expect(skipped, {'step_minutes', 'sync_state', 'notification_log'});
  });

  group('왕복 (export → 빈 DB에 restore)', () {
    test('넣는 표의 내용이 모두 같다 (첫 그림 소유 1줄·방명록 글·화집 벽·알림 설정 포함)', () async {
      await _fill(a);
      for (final name in svcA.includedTableNames) {
        expect(await _count(a, name), greaterThan(0), reason: '$name에 시험 행이 있어야 한다');
      }
      final text = await svcA.exportBackup(_now);
      await svcB.restoreBackup(text);

      expect(await _userState(b), await _userState(a));
      // 첫 그림은 소유 기록 1줄 그대로
      final sketch = await (b.select(b.paintingsOwned)..where((t) => t.landmarkId.equals('sketch')))
          .getSingle();
      expect((sketch.visits, sketch.frame, sketch.seen, sketch.bestKm), (1, Frame.wood, false, 2.4));
      // 한글·이모지 글, 새 그림 표시 같은 값이 그대로
      expect((await b.select(b.guestbookPosts).get()).map((r) => r.body), contains('첫 그림이에요 🎨'));
    });

    test('백업 머리: format 1, 지금 스키마, 만든 시각, 마지막 동기화 시각', () async {
      await _fill(a);
      final json = _json(await svcA.exportBackup(_now));
      expect(json['format'], 1);
      expect(json['schema'], a.schemaVersion);
      expect(json['schema'], 9);
      expect(json['createdUtc'], _ms(_now));
      expect(json['syncedUtc'], _ms(_synced));
      expect((json['tables'] as Map<String, dynamic>).keys, svcA.includedTableNames);
    });

    test('같은 DB는 같은 시각이면 같은 문자열이다', () async {
      await _fill(a);
      expect(await svcA.exportBackup(_now), await svcA.exportBackup(_now));
    });

    test('로컬 시각으로 불러도 만든 시각은 UTC로 적는다', () async {
      expect(_json(await svcA.exportBackup(_now.toLocal()))['createdUtc'], _ms(_now));
    });

    test('빈 DB도 왕복한다', () async {
      final text = await svcA.exportBackup(_now);
      await svcB.restoreBackup(text);
      expect(await _userState(b), await _userState(a));
      expect(_json(text)['syncedUtc'], isNull);
    });
  });

  group('이 기기에만 두는 값', () {
    test('확인·동의·권한 단계 시각 네 열은 백업 문자열에 없다 (열도 값도)', () async {
      await _fill(a);
      final text = await svcA.exportBackup(_now);
      final json = _json(text);
      final profile = (json['tables'] as Map<String, dynamic>)['profile'] as Map<String, dynamic>;
      expect(profile['cols'], isNot(contains('age_confirmed_at')));
      expect(profile['cols'], isNot(contains('onboarded_at')));
      expect(profile['cols'], isNot(contains('link_consent_at')));
      expect(profile['cols'], isNot(contains('guestbook_consent_at')));
      // 프로필의 나머지(닉네임·설치 번호·모습·출발 동네)는 들어 있다
      expect(profile['cols'],
          containsAll(['home_name', 'home_lat', 'home_lng', 'home_id', 'install_id', 'nickname', 'look']));
      final raw = jsonEncode(json);
      for (final v in [_ageAt, _onboardedAt, _linkAt, _guestbookAt]) {
        expect(raw, isNot(contains('$v')));
      }
    });

    test('빈 기기에 복원하면 네 시각은 비어 있다 (시작 흐름이 확인부터 다시 돈다)', () async {
      await _fill(a);
      await svcB.restoreBackup(await svcA.exportBackup(_now));
      final r = await (b.select(b.profile)..where((t) => t.id.equals(1))).getSingle();
      expect([r.ageConfirmedAt, r.onboardedAt, r.linkConsentAt, r.guestbookConsentAt],
          everyElement(isNull));
      expect((r.nickname, r.installId, r.homeName), ('나그네', 'ab' * 16, '중구'));
    });

    test('쓰던 기기에 복원하면 그 기기의 네 시각과 알림 기록이 그대로다', () async {
      await _fill(a);
      final text = await svcA.exportBackup(_now);
      // 기기 B: 다른 사용자 상태 + 자기 시각들 + 알림 기록
      await b.into(b.profile).insert(ProfileCompanion.insert(
            id: const Value(1),
            nickname: const Value('다른 사람'),
            installId: Value('cd' * 16),
            ageConfirmedAt: const Value(11),
            onboardedAt: const Value(22),
            linkConsentAt: const Value(33),
            guestbookConsentAt: const Value(44),
          ));
      await b.into(b.daySummaries).insert(DaySummariesCompanion.insert(
          day: '2026-01-01', steps: 1, distanceM: 1, countedSessions: 0));
      await b.into(b.notificationLog).insert(NotificationLogCompanion.insert(
          kind: NoticeKind.n5, refKey: '', atUtc: 5, status: NoticeStatus.scheduled));

      await svcB.restoreBackup(text);

      final r = await (b.select(b.profile)..where((t) => t.id.equals(1))).getSingle();
      expect([r.ageConfirmedAt, r.onboardedAt, r.linkConsentAt, r.guestbookConsentAt],
          [11, 22, 33, 44]);
      // 나머지는 백업으로 바뀐다
      expect((r.nickname, r.installId), ('나그네', 'ab' * 16));
      expect(await _userState(b), await _userState(a));
      final log = await b.select(b.notificationLog).get();
      expect([for (final l in log) (l.kind, l.refKey, l.status)],
          [(NoticeKind.n5, '', NoticeStatus.scheduled)]);
    });
  });

  group('걸음 분과 동기화 상태', () {
    test('걸음 분은 백업에 없고, 복원하면 비운다 (쓰던 기기의 분도 지운다)', () async {
      await _fill(a);
      final text = await svcA.exportBackup(_now);
      expect((_json(text)['tables'] as Map<String, dynamic>).keys, isNot(contains('step_minutes')));
      expect((_json(text)['tables'] as Map<String, dynamic>).keys, isNot(contains('sync_state')));

      await b.into(b.stepMinutes).insert(StepMinutesCompanion.insert(minuteUtc: const Value(5), steps: 9));
      await svcB.restoreBackup(text);
      expect(await b.select(b.stepMinutes).get(), isEmpty);
    });

    test('마지막 동기화 시각은 null, 설치 시각은 마지막 동기화의 48시간 전 한국 날짜 시작이다', () async {
      await _fill(a);
      // 첫 기록일을 한참 앞으로 (하루 요약 하나 더)
      await a.into(a.daySummaries).insert(DaySummariesCompanion.insert(
          day: '2026-10-01', steps: 10, distanceM: 7, countedSessions: 0));
      await svcB.restoreBackup(await svcA.exportBackup(_now));
      final s = await (b.select(b.syncState)..where((t) => t.id.equals(1))).getSingle();
      expect(s.lastFetchedUtc, isNull);
      // 마지막 동기화 KST 11/18 14:30 → 48시간 전 11/16 14:30 → 그날(한국) 시작 = UTC 11/15 15:00
      expect(s.installUtc, _ms(DateTime.utc(2026, 11, 15, 15)));
      expect(rules.refetchHours, 48);
      // 첫 기록일은 복원한 하루 요약의 가장 이른 날
      expect(s.firstRecordDay, '2026-10-01');
    });

    test('가져올 시작이 첫 기록일보다 앞이면 첫 기록일의 한국 날짜 시작으로 미룬다', () async {
      await _fill(a); // 가장 이른 하루 요약 2026-11-17
      await svcB.restoreBackup(await svcA.exportBackup(_now));
      final s = await (b.select(b.syncState)..where((t) => t.id.equals(1))).getSingle();
      // 11/17(한국) 시작 = UTC 11/16 15:00 (48시간 전 날짜 시작 11/16보다 늦다)
      expect(s.installUtc, _ms(DateTime.utc(2026, 11, 16, 15)));
      expect(s.firstRecordDay, '2026-11-17');
    });

    test('하루 요약이 없고 동기화한 적도 없으면 백업한 시각 기준이고, 첫 기록일은 가져올 날짜다', () async {
      await svcB.restoreBackup(await svcA.exportBackup(_now));
      final s = await (b.select(b.syncState)..where((t) => t.id.equals(1))).getSingle();
      // _now = KST 11/18 15:00 → 48시간 전 11/16 15:00 → 한국 11/16 시작 = UTC 11/15 15:00
      expect(s.installUtc, _ms(DateTime.utc(2026, 11, 15, 15)));
      expect(s.firstRecordDay, '2026-11-16');
      expect(s.lastFetchedUtc, isNull);
    });

    test('쓰던 기기의 동기화 상태는 새로 만든 값으로 바뀐다 (한 줄만)', () async {
      await _fill(a);
      await _fill(b);
      await b.update(b.syncState).write(SyncStateCompanion(lastFetchedUtc: Value(_ms(_now))));
      await svcB.restoreBackup(await svcA.exportBackup(_now));
      final rows = await b.select(b.syncState).get();
      expect(rows, hasLength(1));
      expect(rows.single.lastFetchedUtc, isNull);
    });
  });

  group('진행 중인 여정의 걸은 거리', () {
    // 여정이 시작한 분부터 10분 동안 분당 100보. 마지막 동기화는 그 열 번째 분의 한가운데
    final startMinute = _ms(DateTime.utc(2026, 11, 18, 4, 0)) ~/ 60000;

    Future<void> activeJourney({double fundKm = 2.0}) async {
      await a.into(a.journeys).insert(JourneysCompanion.insert(
            id: 'jA',
            originLat: 37.5,
            originLng: 127.0,
            destId: 'kr008',
            startUtc: startMinute * 60000,
            fundKm: fundKm,
            totalEffectiveKm: 300,
            status: JourneyStatus.active,
          ));
      await a.batch((bt) => bt.insertAll(a.stepMinutes, [
            for (var i = 0; i < 10; i++)
              StepMinutesCompanion.insert(minuteUtc: Value(startMinute + i), steps: 100),
          ]));
      await a.into(a.syncState).insert(SyncStateCompanion.insert(
            id: const Value(1),
            lastFetchedUtc: Value(startMinute * 60000 + 9 * 60000 + 30000),
            firstRecordDay: '2026-11-18',
            installUtc: 0,
          ));
    }

    test('백업에 걸은 거리(km)가 들어간다 (덜 찬 마지막 동기화 분은 뺀다)', () async {
      await activeJourney();
      final json = _json(await svcA.exportBackup(_now));
      final walked = json['journeyWalked'] as Map<String, dynamic>;
      expect(walked['id'], 'jA');
      // 9분 × 100보 × 0.7m = 630m
      expect(walked['km'], closeTo(0.63, 1e-9));
      expect(json['syncedUtc'], startMinute * 60000 + 9 * 60000 + 30000);
    });

    test('진행 중인 여정이 없거나 동기화한 적이 없으면 null', () async {
      expect(_json(await svcA.exportBackup(_now))['journeyWalked'], isNull);
      await _fill(a); // 여정은 모두 끝난 것, 동기화는 했다
      expect(_json(await svcA.exportBackup(_now))['journeyWalked'], isNull);

      await a.delete(a.syncState).go();
      await a.into(a.journeys).insert(JourneysCompanion.insert(
            id: 'jB',
            originLat: 37.5,
            originLng: 127.0,
            destId: 'kr008',
            startUtc: 5,
            fundKm: 0,
            totalEffectiveKm: 300,
            status: JourneyStatus.active,
          ));
      expect(_json(await svcA.exportBackup(_now))['journeyWalked'], isNull);
    });

    test('복원하면 걸은 거리를 경비에 더하고 시작을 마지막 동기화 분으로 옮긴다', () async {
      await activeJourney(fundKm: 2.0);
      await svcB.restoreBackup(await svcA.exportBackup(_now));
      final j = await (b.select(b.journeys)..where((t) => t.id.equals('jA'))).getSingle();
      expect(j.fundKm, closeTo(2.63, 1e-9));
      // 마지막 동기화가 속한 분의 시작
      expect(j.startUtc, (startMinute + 9) * 60000);
      expect(j.status, JourneyStatus.active);
    });

    test('여정이 마지막 동기화 분 뒤에 시작했으면 그대로 둔다', () async {
      await activeJourney();
      final later = (startMinute + 20) * 60000;
      await a.update(a.journeys).write(JourneysCompanion(startUtc: Value(later)));
      await svcB.restoreBackup(await svcA.exportBackup(_now));
      final j = await (b.select(b.journeys)..where((t) => t.id.equals('jA'))).getSingle();
      expect((j.fundKm, j.startUtc), (2.0, later));
    });
  });

  group('잘못된 문자열', () {
    test('모르는 format이면 FormatException (DB는 그대로)', () async {
      await _fill(b);
      final before = await _userState(b);
      await expectLater(svcB.restoreBackup(_pack(_backupJson(format: 2))), throwsFormatException);
      await expectLater(svcB.restoreBackup(_pack(_backupJson(format: 0))), throwsFormatException);
      final noFormat = _backupJson()..remove('format');
      await expectLater(svcB.restoreBackup(_pack(noFormat)), throwsFormatException);
      expect(await _userState(b), before);
    });

    test('깨진 문자열이면 에러 (DB는 그대로)', () async {
      await _fill(b);
      final before = await _userState(b);
      final good = await svcA.exportBackup(_now);
      final broken = [
        '',
        'not base64 at all!!',
        base64.encode(utf8.encode('gzip이 아닌 글')),
        base64.encode(gzip.encode(utf8.encode('json이 아닌 글'))),
        base64.encode(gzip.encode(utf8.encode('[1, 2, 3]'))),
        good.substring(0, good.length ~/ 2),
        _pack({'format': 1}),
        _pack({..._backupJson(), 'tables': 5}),
        _pack({..._backupJson(), 'schema': 'x'}),
        _pack(_backupJson(tables: {'day_summaries': 5})),
        _pack(_backupJson(tables: {
          'day_summaries': _table(['day', 'steps'], [
            ['2026-11-18']
          ]),
        })),
        _pack(_backupJson(walked: {'id': 5, 'km': 1})),
      ];
      for (final text in broken) {
        await expectLater(svcB.restoreBackup(text), throwsFormatException,
            reason: text.length > 40 ? '${text.substring(0, 40)}...' : text);
      }
      expect(await _userState(b), before);
    });

    test('이 앱보다 새 스키마면 StateError (DB는 그대로)', () async {
      await _fill(b);
      final before = await _userState(b);
      await expectLater(svcB.restoreBackup(_pack(_backupJson(schema: 10))), throwsStateError);
      expect(await _userState(b), before);
    });

    test('넣는 도중 실패하면(같은 키가 두 번) 트랜잭션이 되돌아가 DB는 그대로다', () async {
      await _fill(b);
      final before = await _userState(b);
      final text = _pack(_backupJson(tables: {
        'day_summaries': _table(['day', 'steps', 'distance_m', 'counted_sessions'], [
          ['2026-11-01', 1, 1.0, 0],
          ['2026-11-01', 2, 2.0, 0],
        ]),
      }));
      await expectLater(svcB.restoreBackup(text), throwsA(anything));
      expect(await _userState(b), before);
      expect(await b.select(b.stepMinutes).get(), hasLength(2));
      expect((await b.select(b.syncState).getSingle()).lastFetchedUtc, _ms(_synced));
    });
  });

  group('옛 백업', () {
    test('빠진 열은 기본값으로 채우고, 지금 없는 열·표는 건너뛴다', () async {
      final text = _pack(_backupJson(schema: 5, tables: {
        // seen 열이 없다 → 기본값 true (스키마 5에서 더한 열)
        'paintings_owned': _table(
          ['landmark_id', 'visits', 'frame', 'best_km', 'first_arrived_utc', 'last_arrived_utc'],
          [
            ['kr001', 1, 'wood', 3.0, 1000, 1000],
          ],
        ),
        // seen 열이 없다 → 기본값 false
        'props_owned': _table(['prop_id', 'unlocked_utc'], [
          ['hat_01', 5],
        ]),
        // 도착 화면을 봤는지·가상 목적지 열이 없다
        'journeys': _table(
          [
            'id',
            'origin_lat',
            'origin_lng',
            'dest_id',
            'start_utc',
            'fund_km',
            'total_effective_km',
            'status'
          ],
          [
            ['j1', 37.5, 127.0, 'kr001', 1, 0.0, 10.0, 'stopped'],
          ],
        ),
        // 지금은 없는 열이 있다
        'day_summaries': _table(['day', 'steps', 'distance_m', 'counted_sessions', 'removed'], [
          ['2026-11-18', 100, 70.0, 0, 'x'],
        ]),
        // 지금은 없는 표
        'obsolete': _table(['a'], [
          [1]
        ]),
      }));
      await _fill(b);
      await svcB.restoreBackup(text);

      final painting = await b.select(b.paintingsOwned).getSingle();
      expect((painting.landmarkId, painting.seen), ('kr001', true));
      expect((await b.select(b.propsOwned).getSingle()).seen, isFalse);
      final j = await b.select(b.journeys).getSingle();
      expect((j.arrivalShown, j.destLat, j.visitNo), (false, null, null));
      expect((await b.select(b.daySummaries).getSingle()).steps, 100);
      // 백업에 없는 표(스키마 5에는 없던 표)는 비운다
      expect(await b.select(b.notificationSettings).get(), isEmpty);
      expect(await b.select(b.guestbookPosts).get(), isEmpty);
      // 프로필은 백업에 없어서 비워지고, 이 기기의 네 시각만 남는다
      final profile = await b.select(b.profile).getSingle();
      expect((profile.nickname, profile.installId, profile.homeName), (null, null, null));
      expect([profile.ageConfirmedAt, profile.onboardedAt, profile.linkConsentAt,
          profile.guestbookConsentAt], [_ageAt, _onboardedAt, _linkAt, _guestbookAt]);
    });
  });

  group('크기', () {
    test('한도(config backup.maxChars)를 넘으면 StateError', () async {
      await _fill(a);
      final small = BackupService(a, _rulesWithMaxChars(200));
      await expectLater(small.exportBackup(_now), throwsStateError);
      // 한도 안이면 된다
      final text = await BackupService(a, _rulesWithMaxChars(1000000)).exportBackup(_now);
      expect(text.length, lessThan(200000));
    });

    test('measure: base64 글자 수, 압축 바이트, 압축 전 JSON 바이트', () async {
      await _fill(a);
      final text = await svcA.exportBackup(_now);
      final size = BackupService.measure(text);
      expect(size.chars, text.length);
      expect(size.gzipBytes, base64.decode(text).length);
      expect(size.jsonBytes, gzip.decode(base64.decode(text)).length);
      expect(size.gzipBytes, lessThan(size.jsonBytes));
      expect(() => BackupService.measure('깨진'), throwsFormatException);
    });

    test('1년치 하루 요약 365줄 + 걷기 1,000개 + 여정 50개는 한도보다 훨씬 작다', () async {
      final r = Random(2027);
      final base = _ms(DateTime.utc(2025, 1, 1));
      await a.batch((bt) {
        bt.insertAll(a.daySummaries, [
          for (var i = 0; i < 365; i++)
            DaySummariesCompanion.insert(
              day: addDays('2025-01-01', i),
              steps: 2000 + r.nextInt(14000),
              // 걸음 × 보폭으로 계산한 값처럼 부동소수 꼬리가 길다 (압축이 가장 안 되는 쪽)
              distanceM: (2000 + r.nextInt(14000)) * 0.7 + r.nextDouble() * 300,
              countedSessions: r.nextInt(4),
            ),
        ]);
        bt.insertAll(a.walkSessions, [
          for (var i = 0; i < 1000; i++)
            () {
              final steps = 1000 + r.nextInt(8000);
              final start = base + i * 8 * 3600000 + r.nextInt(3600000);
              return WalkSessionsCompanion.insert(
                startUtc: Value(start),
                endUtc: start + (10 + r.nextInt(80)) * 60000,
                steps: steps,
                distanceM: steps * 0.7 + r.nextDouble() * 100,
                runRatio: r.nextDouble(),
                qualified: r.nextBool(),
                counted: r.nextBool(),
              );
            }(),
        ]);
        bt.insertAll(a.journeys, [
          for (var i = 0; i < 50; i++)
            JourneysCompanion.insert(
              id: 'j${base + i * 7 * 86400000}',
              originLat: 34 + r.nextDouble() * 4,
              originLng: 126 + r.nextDouble() * 3,
              destId: 'kr${(1 + r.nextInt(101)).toString().padLeft(3, '0')}',
              startUtc: base + i * 7 * 86400000,
              fundKm: r.nextDouble() * 15,
              totalEffectiveKm: 5 + r.nextDouble() * 300,
              status: JourneyStatus.arrived,
              arrivedUtc: Value(base + i * 7 * 86400000 + 5 * 86400000),
              endLat: Value(34 + r.nextDouble() * 4),
              endLng: Value(126 + r.nextDouble() * 3),
              endedUtc: Value(base + i * 7 * 86400000 + 5 * 86400000),
              visitNo: Value(1 + r.nextInt(3)),
              prevFrame: const Value(Frame.wood),
              newFrame: const Value(Frame.silver),
              arrivalShown: const Value(true),
            ),
        ]);
      });
      await _fill(a); // 소품·방명록·프로필 같은 나머지도 함께

      final text = await svcA.exportBackup(_now);
      final size = BackupService.measure(text);
      // ignore: avoid_print
      print('백업 크기: 문자열 ${size.chars}자 · 압축 ${size.gzipBytes}바이트 · '
          '압축 전 ${size.jsonBytes}바이트 (한도 ${rules.backupMaxChars}자)');
      expect(size.chars, lessThan(rules.backupMaxChars ~/ 4));
      expect(size.jsonBytes, lessThan(300000));

      // 큰 백업도 그대로 돌아온다
      await svcB.restoreBackup(text);
      expect(await _count(b, 'day_summaries'), 367);
      expect(await _count(b, 'walk_sessions'), 1002);
      expect(await _count(b, 'journeys'), 53);
      expect(await _userState(b), await _userState(a));
    });
  });

  group('복원 뒤 동기화가 이어진다 (엔진 왕복)', () {
    // 설치 KST 2026-11-18 09:00
    final t0 = DateTime.utc(2026, 11, 18);
    final byId = {for (final l in landmarks) l.id: l};

    SyncService svcOf(AppDb db, StepSource source) => SyncService(
          db: db,
          source: source,
          rules: rules,
          allowedSources: const [],
          landmarks: byId,
          props: props,
          milestones: milestones,
        );

    StepRecord walk(DateTime start, int minutes, int spm) => StepRecord(
          start: start,
          end: start.add(Duration(minutes: minutes)),
          steps: minutes * spm,
          sourceId: 'iphone',
          method: RecordingMethod.automatic,
        );

    Future<List<DaySummaryRow>> sortedDays(AppDb db) async =>
        (await db.select(db.daySummaries).get())..sort((x, y) => x.day.compareTo(y.day));

    Future<List<WalkSessionRow>> sortedSessions(AppDb db) async =>
        (await db.select(db.walkSessions).get())
          ..sort((x, y) => x.startUtc.compareTo(y.startUtc));

    test('새 기기가 같은 건강 기록으로 동기화하면 진행 거리·하루 요약·걷기 구간이 이어진다', () async {
      // 나흘 동안 걸은 건강 앱 기록: 걷기 4.2km, 걷기 5.04km, 뛰기 4.5km, 걷기 3.15km
      final health = FakeStepSource([
        walk(t0.add(const Duration(hours: 2)), 60, 100),
        walk(t0.add(const Duration(hours: 26)), 60, 120),
        walk(t0.add(const Duration(hours: 50)), 30, 150),
        walk(t0.add(const Duration(hours: 74)), 45, 100),
      ]);
      final sa = svcOf(a, health);
      await sa.sync(t0);
      await placeAt(a, testHome, t0);
      final startAt = t0.add(const Duration(hours: 1));
      await sa.startJourney('kr008', startAt, useFund: false);
      for (final h in [3, 27, 51, 75]) {
        await sa.sync(t0.add(Duration(hours: h)));
      }
      // 백업: 마지막 동기화(t0 + 75시간) 5분 뒤
      final backupAt = t0.add(const Duration(hours: 75, minutes: 5));
      final text = await svcA.exportBackup(backupAt);
      final progressAtBackup = (await sa.snapshot(backupAt)).journey!.progress.progressKm;
      expect(progressAtBackup, closeTo(16.89, 1e-9));
      final walked = _json(text)['journeyWalked'] as Map<String, dynamic>;
      expect(walked['id'], 'j${startAt.millisecondsSinceEpoch}');
      expect(walked['km'], closeTo(16.89, 1e-9));

      // 백업한 뒤에도 20분 더 걸었다 (건강 앱에는 남아 있다)
      health.records.add(walk(t0.add(const Duration(hours: 76)), 20, 100));
      final syncAt = t0.add(const Duration(hours: 80));
      await sa.sync(syncAt);
      final original = await sa.snapshot(syncAt);
      expect(original.journey!.progress.progressKm, closeTo(18.29, 1e-9));

      // 새 기기: 복원 직후에는 걸음 분이 없어도 백업 때의 진행 거리가 보인다
      await svcB.restoreBackup(text);
      final sb = svcOf(b, health);
      final justRestored = await sb.snapshot(backupAt);
      expect(justRestored.journey!.progress.progressKm, closeTo(progressAtBackup, 1e-9));
      expect(justRestored.lastFetched, isNull);

      // 첫 동기화가 48시간 전 날짜 시작부터 다시 가져와서 같은 진행 거리가 된다
      await sb.sync(syncAt);
      final restored = await sb.snapshot(syncAt);
      expect(restored.journey!.progress.progressKm, closeTo(18.29, 1e-9));
      expect(restored.lastFetched, syncAt);
      expect(await sortedDays(b), await sortedDays(a));
      expect(await sortedSessions(b), await sortedSessions(a));
      expect(restored.fundKm, original.fundKm);
      expect(restored.totalSteps, original.totalSteps);
      // 한 번 더 동기화해도 그대로
      await sb.sync(syncAt.add(const Duration(minutes: 1)));
      expect((await sb.snapshot(syncAt)).journey!.progress.progressKm, closeTo(18.29, 1e-9));
    });

    test('여정이 없으면 경비도 이어진다', () async {
      final health = FakeStepSource([walk(t0.add(const Duration(hours: 2)), 60, 100)]);
      final sa = svcOf(a, health);
      await sa.sync(t0);
      await sa.sync(t0.add(const Duration(hours: 4)));
      final backupAt = t0.add(const Duration(hours: 5));
      final text = await svcA.exportBackup(backupAt);
      expect(_json(text)['journeyWalked'], isNull);
      health.records.add(walk(t0.add(const Duration(hours: 6)), 30, 100));
      final syncAt = t0.add(const Duration(hours: 8));
      await sa.sync(syncAt);
      final original = await sa.snapshot(syncAt);
      expect(original.fundKm, closeTo(4.2 + 2.1, 1e-9));

      await svcB.restoreBackup(text);
      final sb = svcOf(b, health);
      await sb.sync(syncAt);
      expect((await sb.snapshot(syncAt)).fundKm, closeTo(original.fundKm, 1e-9));
      expect(await sortedDays(b), await sortedDays(a));
    });
  });
}
