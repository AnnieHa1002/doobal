import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/backup_runner.dart';
import 'package:doobal/app/backup_service.dart';
import 'package:doobal/data/backup_store.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/backup_policy.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

/// 올라간 백업을 모으는 가짜 저장소. [gate]가 있으면 열릴 때까지 저장이 끝나지 않고,
/// [failWith]가 있으면 저장이 그 오류로 실패한다
class _Store implements BackupStore {
  final saved = <(String, String)>[];
  Completer<void>? gate;
  Object? failWith;

  @override
  Future<void> save(String uid, String text) async {
    await gate?.future;
    final error = failWith;
    if (error != null) throw error;
    saved.add((uid, text));
  }

  @override
  Future<String?> load(String uid) async {
    for (final s in saved.reversed) {
      if (s.$1 == uid) return s.$2;
    }
    return null;
  }
}

int _createdUtc(String text) =>
    (jsonDecode(utf8.decode(gzip.decode(base64.decode(text)))) as Map<String, dynamic>)['createdUtc']
        as int;

// KST 2026-11-18 12:00
final _t = DateTime.utc(2026, 11, 18, 3);

Duration _min(int m, [int s = 0]) => Duration(minutes: m, seconds: s);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDb db;
  late _Store store;
  late BackupRunner runner;
  String? uid;

  setUp(() {
    db = AppDb(NativeDatabase.memory());
    store = _Store();
    uid = 'u1';
    runner = BackupRunner(
      service: BackupService(db, rules),
      store: store,
      rules: rules,
      uid: () => uid,
    );
  });
  tearDown(() => db.close());

  group('run', () {
    test('계정을 연결하지 않았으면(uid 없음) 백업하지 않는다', () async {
      uid = null;
      for (final reason in BackupReason.values) {
        expect(await runner.run(reason, _t), isFalse);
      }
      expect(store.saved, isEmpty);
      expect(runner.lastBackupUtc, isNull);
    });

    test('연결했으면 그 uid로 올리고, 올린 시각을 기억한다', () async {
      expect(await runner.run(BackupReason.background, _t), isTrue);
      expect(store.saved, hasLength(1));
      expect(store.saved.single.$1, 'u1');
      expect(_createdUtc(store.saved.single.$2), _t.millisecondsSinceEpoch);
      expect(runner.lastBackupUtc, _t);
    });

    test('올린 문자열은 그대로 복원된다', () async {
      await runner.run(BackupReason.arrived, _t);
      final other = AppDb(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other, rules).restoreBackup((await store.load('u1'))!);
    });

    test('10분 이내는 건너뛰고(9분 59초) 10분이 되면 올린다', () async {
      await runner.run(BackupReason.background, _t);
      expect(await runner.run(BackupReason.background, _t.add(_min(9, 59))), isFalse);
      expect(store.saved, hasLength(1));
      expect(await runner.run(BackupReason.background, _t.add(_min(10))), isTrue);
      expect(store.saved, hasLength(2));
      expect(runner.lastBackupUtc, _t.add(_min(10)));
      // 건너뛴 부름은 마지막 백업 시각을 늦추지 않는다
      expect(await runner.run(BackupReason.arrived, _t.add(_min(19, 59))), isFalse);
      expect(await runner.run(BackupReason.arrived, _t.add(_min(20))), isTrue);
    });

    test('연결이 나중에 되면 그때부터 한다 (uid를 부를 때마다 읽는다)', () async {
      uid = null;
      expect(await runner.run(BackupReason.background, _t), isFalse);
      uid = 'u2';
      expect(await runner.run(BackupReason.background, _t.add(_min(1))), isTrue);
      expect(store.saved.single.$1, 'u2');
    });

    test('저장이 실패하면 던지고, 마지막 백업 시각은 그대로라 바로 다시 시도할 수 있다', () async {
      store.failWith = StateError('네트워크 없음');
      await expectLater(runner.run(BackupReason.background, _t), throwsStateError);
      expect(runner.lastBackupUtc, isNull);
      expect(store.saved, isEmpty);

      store.failWith = null;
      expect(await runner.run(BackupReason.background, _t.add(_min(1))), isTrue);
      expect(store.saved, hasLength(1));
    });

    test('올리는 중에 또 부르면 건너뛴다 (숨김·일시정지가 연달아 와도 한 번)', () async {
      store.gate = Completer<void>();
      final first = runner.run(BackupReason.background, _t);
      await Future<void>.delayed(Duration.zero);
      expect(await runner.run(BackupReason.background, _t.add(_min(30))), isFalse);
      store.gate!.complete();
      expect(await first, isTrue);
      expect(store.saved, hasLength(1));
      // 끝난 뒤에는 다시 올릴 수 있다
      expect(await runner.run(BackupReason.background, _t.add(_min(30))), isTrue);
    });
  });

  group('afterSync (날짜가 바뀐 뒤 첫 동기화)', () {
    test('백업한 적이 없으면 첫 동기화에 한 번 올린다', () async {
      expect(await runner.afterSync(_t), isTrue);
      expect(store.saved, hasLength(1));
    });

    test('같은 한국 날짜의 다음 동기화들은 올리지 않는다', () async {
      await runner.afterSync(_t);
      expect(await runner.afterSync(_t.add(const Duration(hours: 1))), isFalse);
      expect(await runner.afterSync(_t.add(const Duration(hours: 11))), isFalse); // KST 23:00
      expect(store.saved, hasLength(1));
    });

    test('한국 날짜가 바뀐 뒤 첫 동기화에는 올리고, 그날의 다음 동기화는 안 올린다', () async {
      await runner.afterSync(_t);
      final nextDay = DateTime.utc(2026, 11, 18, 15, 10); // KST 11/19 00:10
      expect(await runner.afterSync(nextDay), isTrue);
      expect(await runner.afterSync(nextDay.add(const Duration(hours: 2))), isFalse);
      expect(store.saved, hasLength(2));
    });

    test('날짜가 바뀌었어도 마지막 백업 10분 이내면 올리지 않는다 (자정 직전에 올렸을 때)', () async {
      final beforeMidnight = DateTime.utc(2026, 11, 18, 14, 58); // KST 23:58
      await runner.afterSync(beforeMidnight);
      expect(await runner.afterSync(DateTime.utc(2026, 11, 18, 15, 1)), isFalse);
      expect(store.saved, hasLength(1));
    });

    test('연결하지 않았으면 올리지 않는다', () async {
      uid = null;
      expect(await runner.afterSync(_t), isFalse);
      expect(store.saved, isEmpty);
    });
  });

  group('PlaceholderBackupStore', () {
    test('uid마다 마지막으로 저장한 문자열을 메모리에 둔다', () async {
      final s = PlaceholderBackupStore();
      expect(await s.load('u1'), isNull);
      await s.save('u1', 'a');
      await s.save('u2', 'b');
      await s.save('u1', 'c');
      expect(await s.load('u1'), 'c');
      expect(await s.load('u2'), 'b');
    });
  });
}
