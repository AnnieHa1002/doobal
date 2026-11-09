import 'package:doobal/app/account_service.dart';
import 'package:doobal/app/backup_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/server.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'fake_server.dart';

// KST 2026-11-18 12:00
final _t = DateTime.utc(2026, 11, 18, 3);

class _Env {
  _Env({bool ageConfirmed = true, String? nickname = '두발'}) : db = AppDb(NativeDatabase.memory()) {
    account = AccountService(
      server: server.backend,
      db: db,
      backupService: () async => BackupService(db, rules),
      clock: () => _t,
    );
    _seed = db.into(db.profile).insert(ProfileCompanion.insert(
          id: const Value(1),
          ageConfirmedAt: Value(ageConfirmed ? _t.millisecondsSinceEpoch : null),
          nickname: Value(nickname),
        ));
  }

  final AppDb db;
  final server = FakeServer();
  late final AccountService account;
  late final Future<void> _seed;

  Future<void> ready() => _seed;

  Future<int?> consentAt() async =>
      (await (db.select(db.profile)..where((t) => t.id.equals(1))).getSingle()).linkConsentAt;

  Future<void> addDay(String day, int steps) => db.into(db.daySummaries).insert(
        DaySummariesCompanion.insert(
          day: day,
          steps: steps,
          distanceM: steps * 0.7,
          countedSessions: 0,
        ),
      );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('익명 로그인', () {
    test('만 14세 확인 전에는 Auth를 부르지 않는다', () async {
      final e = _Env(ageConfirmed: false);
      await e.ready();
      expect(await e.account.ensureSignedIn(), isNull);
      expect(e.server.auth.calls, isEmpty);
    });

    test('확인 뒤 한 번 익명으로 들어가고, 이미 들어갔으면 다시 부르지 않는다', () async {
      final e = _Env();
      await e.ready();
      final results = await Future.wait([e.account.ensureSignedIn(), e.account.ensureSignedIn()]);
      expect(results.map((u) => u?.uid), ['anon1', 'anon1']);
      await e.account.ensureSignedIn();
      expect(e.server.auth.calls, ['anon']);
    });

    test('실패하면(오프라인) null이고 앱을 막지 않으며 다음에 다시 한다', () async {
      final e = _Env();
      await e.ready();
      e.server.auth.failSignIn = Exception('network');
      expect(await e.account.ensureSignedIn(), isNull);
      e.server.auth.failSignIn = null;
      expect((await e.account.ensureSignedIn())?.uid, 'anon1');
    });
  });

  group('users 문서', () {
    test('닉네임과 누적 걸음을 올리고, 같은 값이면 다시 올리지 않는다', () async {
      final e = _Env();
      await e.ready();
      await e.addDay('2026-11-17', 1200);
      await e.addDay('2026-11-18', 300);
      await e.account.ensureSignedIn();
      await e.account.pushProfile();
      await e.account.pushProfile();
      expect(e.server.store.profiles['anon1'], ('두발', 1500));
      expect(e.server.store.pushes, 1);

      await e.addDay('2026-11-19', 10);
      await e.account.pushProfile();
      expect(e.server.store.profiles['anon1'], ('두발', 1510));
      expect(e.server.store.pushes, 2);
    });

    test('동시에 불러도 차례로 한 번만 올린다 (둘이 함께 만들면 두 번째가 규칙에 막힌다)', () async {
      final e = _Env();
      await e.ready();
      await e.account.ensureSignedIn();
      await Future.wait([e.account.pushProfile(), e.account.pushProfile(), e.account.pushProfile()]);
      expect(e.server.store.pushes, 1);
    });

    test('실패해도 다음 올리기는 막히지 않는다', () async {
      final e = _Env();
      await e.ready();
      await e.account.ensureSignedIn();
      e.server.store.failTimes = 1;
      await expectLater(e.account.pushProfile(), throwsA(isA<ServerError>()));
      await e.account.pushProfile();
      expect(e.server.store.pushes, 1);
    });

    test('로그인 전이거나 닉네임이 없으면 올리지 않는다', () async {
      final e = _Env(nickname: null);
      await e.ready();
      await e.account.pushProfile();
      await e.account.ensureSignedIn();
      await e.account.pushProfile();
      expect(e.server.store.pushes, 0);
    });
  });

  group('연결한 계정', () {
    test('구글·애플은 Auth, 카카오는 커스텀 토큰 세션 + 연결 동의 시각', () {
      const anon = AuthUser(uid: 'u');
      const custom = AuthUser(uid: 'u', customToken: true);
      expect(linkedOf(null, 1), isNull);
      expect(linkedOf(anon, null), isNull);
      expect(linkedOf(anon, 1), isNull);
      expect(linkedOf(const AuthUser(uid: 'u', idpLinks: {LinkProvider.google}), null),
          LinkProvider.google);
      expect(linkedOf(const AuthUser(uid: 'u', idpLinks: {LinkProvider.apple}), 1),
          LinkProvider.apple);
      expect(linkedOf(custom, 1), LinkProvider.kakao);
      // 카카오를 해제하면 동의 시각을 지워서 커스텀 세션이 남아도 연결 안 함이다
      expect(linkedOf(custom, null), isNull);
    });
  });

  group('구글·애플 연결', () {
    test('지금 계정에 연결하고 연결 동의 시각을 적는다 (uid 그대로)', () async {
      final e = _Env();
      await e.ready();
      expect(await e.account.link(LinkProvider.google), isA<LinkDone>());
      expect(e.server.auth.calls, ['anon', 'link:google']);
      expect(e.server.auth.user!.uid, 'anon1');
      expect(await e.consentAt(), _t.millisecondsSinceEpoch);
      expect((await e.account.state()).linked, LinkProvider.google);
    });

    test('창을 닫으면 아무것도 바뀌지 않는다', () async {
      final e = _Env();
      await e.ready();
      e.server.auth.cancel = true;
      expect(await e.account.link(LinkProvider.apple), isA<LinkDismissed>());
      expect(await e.consentAt(), isNull);
    });

    test('로그인하지 못하면(오프라인) 연결하지 않고 알린다', () async {
      final e = _Env();
      await e.ready();
      e.server.auth.failSignIn = Exception('network');
      final r = await e.account.link(LinkProvider.google);
      expect((r as LinkFailed).message, '인터넷에 연결한 뒤 다시 해 주세요');
    });

    test('다른 계정에 연결된 구글이면 묻고, 바꾸면 그 계정의 백업으로 이 기기 기록을 바꾼다', () async {
      // 다른 기기(그 계정)의 기록: 하루 요약 하나를 백업해 둔다
      final other = _Env();
      await other.ready();
      await other.addDay('2026-11-10', 4321);
      other.server.backup.texts['g-owner'] =
          await BackupService(other.db, rules).exportBackup(_t);

      final e = _Env();
      await e.ready();
      await e.addDay('2026-11-18', 7);
      e.server.backup.texts.addAll(other.server.backup.texts);
      e.server.auth.conflicts[LinkProvider.google] = 'g-owner';

      final r = await e.account.link(LinkProvider.google);
      expect(r, isA<LinkNeedsConfirm>());
      expect((r as LinkNeedsConfirm).hasBackup, isNull);
      // 묻는 동안에는 아무것도 바뀌지 않는다
      expect(e.server.auth.user!.uid, 'anon1');

      expect(await e.account.confirmSwitch(r), SwitchResult.restored);
      expect(e.server.auth.user!.uid, 'g-owner');
      expect((await e.account.state()).linked, LinkProvider.google);
      final days = await e.db.select(e.db.daySummaries).get();
      expect(days.map((d) => (d.day, d.steps)), [('2026-11-10', 4321)]);
      // 기기에만 두는 만 14세 확인 시각은 그대로다
      expect(
        (await (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle())
            .ageConfirmedAt,
        _t.millisecondsSinceEpoch,
      );
    });

    test('그 계정에 백업이 없으면 이 기기 기록을 그대로 둔다', () async {
      final e = _Env();
      await e.ready();
      await e.addDay('2026-11-18', 7);
      e.server.auth.conflicts[LinkProvider.apple] = 'a-owner';
      final r = await e.account.link(LinkProvider.apple) as LinkNeedsConfirm;
      expect(await e.account.confirmSwitch(r), SwitchResult.kept);
      expect(e.server.auth.user!.uid, 'a-owner');
      expect((await e.db.select(e.db.daySummaries).get()).single.steps, 7);
    });
  });

  group('카카오 연결 (kakaoSignIn)', () {
    test('SDK가 없으면 준비 중', () async {
      final e = _Env();
      await e.ready();
      e.server.kakao.available = false;
      final r = await e.account.link(LinkProvider.kakao);
      expect((r as LinkFailed).message, '아직 준비 중이에요');
      expect(e.server.api.calls, isEmpty);
    });

    test('창을 닫으면(토큰 없음) 서버를 부르지 않는다', () async {
      final e = _Env();
      await e.ready();
      e.server.kakao.token = null;
      expect(await e.account.link(LinkProvider.kakao), isA<LinkDismissed>());
      expect(e.server.api.calls, isEmpty);
    });

    test('linked: 처음 보는 카카오면 지금 uid로 토큰을 받아 들어가고 카카오로 연결됨', () async {
      final e = _Env();
      await e.ready();
      expect(await e.account.link(LinkProvider.kakao), isA<LinkDone>());
      expect(e.server.api.calls, ['kakaoSignIn']);
      expect(e.server.auth.calls, ['anon', 'custom:ct-anon1']);
      final s = await e.account.state();
      expect((s.user!.uid, s.linked), ('anon1', LinkProvider.kakao));
    });

    test('needsConfirm → 확인하면 switched로 그 계정에 들어가고 백업이 있으면 복원한다', () async {
      final owner = _Env();
      await owner.ready();
      await owner.addDay('2026-11-11', 999);
      final text = await BackupService(owner.db, rules).exportBackup(_t);

      final e = _Env();
      await e.ready();
      e.server.api.kakaoLinks['kakao-1'] = 'k-owner';
      e.server.backup.texts['k-owner'] = text;

      final r = await e.account.link(LinkProvider.kakao);
      expect(r, isA<LinkNeedsConfirm>());
      final c = r as LinkNeedsConfirm;
      expect((c.provider, c.hasBackup), (LinkProvider.kakao, true));
      expect(e.server.auth.user!.uid, 'anon1');

      expect(await e.account.confirmSwitch(c), SwitchResult.restored);
      expect(e.server.api.calls, ['kakaoSignIn', 'kakaoSignIn:confirm']);
      expect(e.server.auth.user!.uid, 'k-owner');
      expect((await e.account.state()).linked, LinkProvider.kakao);
      expect((await e.db.select(e.db.daySummaries).get()).single.steps, 999);
    });

    test('그 계정에 백업이 없으면 hasBackup false로 묻고, 바꿔도 기록을 그대로 둔다', () async {
      final e = _Env();
      await e.ready();
      await e.addDay('2026-11-18', 5);
      e.server.api.kakaoLinks['kakao-1'] = 'k-owner';
      final c = await e.account.link(LinkProvider.kakao) as LinkNeedsConfirm;
      expect(c.hasBackup, isFalse);
      expect(await e.account.confirmSwitch(c), SwitchResult.kept);
      expect((await e.db.select(e.db.daySummaries).get()).single.steps, 5);
    });

    test('카카오 토큰이 끝났거나 연결이 안 되면 알린다', () async {
      final e = _Env();
      await e.ready();
      e.server.api.failNext.add(const ServerError('unauthenticated', reason: 'kakao-token'));
      expect((await e.account.link(LinkProvider.kakao) as LinkFailed).message,
          '카카오 로그인이 끝났어요. 다시 해 주세요');
      e.server.api.failNext.add(const ServerError.offline());
      expect((await e.account.link(LinkProvider.kakao) as LinkFailed).message,
          '인터넷에 연결한 뒤 다시 해 주세요');
      expect(await e.consentAt(), isNull);
    });
  });

  group('연결 해제', () {
    test('카카오는 서버 연결을 지우고 동의 시각을 지워 연결 안 함으로 보인다', () async {
      final e = _Env();
      await e.ready();
      await e.account.link(LinkProvider.kakao);
      expect(await e.account.unlink(LinkProvider.kakao), isNull);
      expect(e.server.api.kakaoLinks, isEmpty);
      expect(await e.consentAt(), isNull);
      // 이 기기의 로그인(uid)은 그대로다
      expect(e.server.auth.user!.uid, 'anon1');
      expect((await e.account.state()).linked, isNull);
    });

    test('구글은 Auth 연결을 끊는다', () async {
      final e = _Env();
      await e.ready();
      await e.account.link(LinkProvider.google);
      expect(await e.account.unlink(LinkProvider.google), isNull);
      expect(e.server.auth.calls.last, 'unlink:google');
      expect((await e.account.state()).linked, isNull);
    });

    test('연결이 안 되면 그대로 두고 알린다', () async {
      final e = _Env();
      await e.ready();
      await e.account.link(LinkProvider.kakao);
      e.server.api.failNext.add(const ServerError.offline());
      expect(await e.account.unlink(LinkProvider.kakao), '인터넷에 연결한 뒤 다시 해 주세요');
      expect((await e.account.state()).linked, LinkProvider.kakao);
    });
  });

  group('서버 계정 삭제', () {
    test('로그인한 적이 없으면 서버에 지울 것이 없다', () async {
      final e = _Env();
      await e.ready();
      expect(await e.account.deleteServerAccount(), isNull);
      expect(e.server.api.calls, isEmpty);
    });

    test('지우고 로그아웃한다', () async {
      final e = _Env();
      await e.ready();
      await e.account.ensureSignedIn();
      await e.account.pushProfile();
      expect(await e.account.deleteServerAccount(), isNull);
      expect(e.server.api.calls, ['deleteAccount']);
      expect(e.server.store.profiles, isEmpty);
      expect(e.server.auth.calls.last, 'signOut');
      expect(e.server.auth.user, isNull);
    });

    test('오프라인이면 로그인을 그대로 두고 알린다 (기기 기록은 부른 쪽이 지우지 않는다)', () async {
      final e = _Env();
      await e.ready();
      await e.account.ensureSignedIn();
      e.server.api.failAlways = const ServerError.offline();
      expect(await e.account.deleteServerAccount(), '인터넷에 연결한 뒤 다시 해 주세요');
      expect(e.server.auth.user?.uid, 'anon1');
    });
  });
}
