import 'package:doobal/app/providers.dart';
import 'package:doobal/data/backup_store.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/server.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'fake_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  ProviderContainer container(AppDb db, [FakeServer? s]) {
    final c = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      rulesProvider.overrideWith((ref) => rules),
      if (s != null) serverBackendProvider.overrideWithValue(s.backend),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('서버가 없으면 (시험·서버를 끈 빌드)', () {
    test('백업은 메모리 자리표시, 백업 uid는 늘 null, 로그인도 없다', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final c = container(db);
      expect(c.read(backupStoreProvider), isA<PlaceholderBackupStore>());
      // Riverpod 3은 듣는 곳이 없는 스트림을 멈춰서 듣고 읽는다
      c.listen(authUserProvider, (_, _) {});
      expect(await c.read(authUserProvider.future), isNull);
      expect(c.read(accountServiceProvider), isNull);
      expect(c.read(backupUidProvider), isNull);
    });
  });

  group('서버가 있으면', () {
    test('백업 uid는 계정을 연결한 사용자만 준다', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.profile).insert(ProfileCompanion.insert(
            id: const Value(1),
            ageConfirmedAt: const Value(1),
          ));
      final s = FakeServer();
      final c = container(db, s);
      c.listen(backupUidProvider, (_, _) {});
      expect(c.read(backupStoreProvider), same(s.backup));

      await c.read(accountServiceProvider)!.ensureSignedIn();
      c.invalidate(accountStateProvider);
      await c.read(accountStateProvider.future);
      expect(c.read(backupUidProvider), isNull, reason: '익명');

      await c.read(accountServiceProvider)!.link(LinkProvider.google);
      c.invalidate(accountStateProvider);
      await c.read(accountStateProvider.future);
      expect(c.read(backupUidProvider), 'anon1');
    });

    test('금칙어는 서버 문서를 쓰고, 없으면 앱에 든 것', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final s = FakeServer();
      final c = container(db, s);
      final bundled = await c.read(moderationProvider.future);
      expect(bundled.message, moderation.message);

      s.store.moderation = {
        'message': '서버 문구',
        'allow': {'words': <String>[], 'autoWords': <String>['경복궁']},
        'normalize': {'lookalike': <String, String>{}},
        'rules': [
          {'id': 'X1', 'cat': 'test', 'on': 'raw', 're': '바나나'},
        ],
      };
      c.invalidate(moderationProvider);
      final remote = await c.read(moderationProvider.future);
      expect(remote.message, '서버 문구');
      expect(remote.isBlocked('바나나 우유'), isTrue);

      // 읽을 수 없는 문서면 앱에 든 것
      s.store.moderation = {'message': 1};
      c.invalidate(moderationProvider);
      expect((await c.read(moderationProvider.future)).message, moderation.message);
    });
  });
}
