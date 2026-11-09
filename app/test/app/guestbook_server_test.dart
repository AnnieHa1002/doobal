import 'package:doobal/app/account_service.dart';
import 'package:doobal/app/backup_service.dart';
import 'package:doobal/app/guestbook_server.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/server.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'fake_server.dart';

// KST 2026-11-18 12:00
final _t = DateTime.utc(2026, 11, 18, 3);

class _Env {
  _Env({bool server = true}) : db = AppDb(NativeDatabase.memory()) {
    svc = SyncService(
      db: db,
      source: FakeStepSource(),
      rules: rules,
      allowedSources: const [],
      landmarks: {for (final l in landmarks) l.id: l},
      props: props,
      milestones: milestones,
      eventCatalog: eventCatalog,
      badgeCatalog: badgeCatalog,
    );
    final account = server
        ? AccountService(
            server: fake.backend,
            db: db,
            backupService: () async => BackupService(db, rules),
            clock: () => _t,
          )
        : null;
    gb = GuestbookServer(
      server: server ? fake.backend : null,
      account: account,
      db: db,
      sync: () async => svc,
      rules: rules,
      clock: () => _t,
    );
  }

  final AppDb db;
  final fake = FakeServer();
  late final SyncService svc;
  late final GuestbookServer gb;

  /// 만 14세 확인·닉네임과 열린 도착 기회 a:j1(경복궁)
  Future<void> seed({String ticket = 'a:j1', String scope = 'kr001'}) async {
    await db.into(db.profile).insert(ProfileCompanion.insert(
          id: const Value(1),
          ageConfirmedAt: Value(_t.millisecondsSinceEpoch),
          nickname: const Value('두발'),
        ));
    await addTicket(ticket, scope);
  }

  Future<void> addTicket(String id, String scope) =>
      db.into(db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
            id: id,
            kind: id.startsWith('m:') ? TicketKind.milestone : TicketKind.arrival,
            scope: scope,
            openedUtc: _t.millisecondsSinceEpoch,
          ));

  Future<List<GuestbookPostRow>> posts() => db.select(db.guestbookPosts).get();

  Future<GuestbookTicketRow> ticket(String id) =>
      (db.select(db.guestbookTickets)..where((t) => t.id.equals(id))).getSingle();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('남기기', () {
    test('서버가 없는 빌드는 이 기기에만 남긴다 (pending)', () async {
      final e = _Env(server: false);
      await e.seed();
      expect(await e.gb.send('a:j1', ' 좋았어요 '), isA<SendQueued>());
      final p = (await e.posts()).single;
      expect((p.body, p.status), ('좋았어요', PostStatus.pending));
    });

    test('연결돼 있으면 로그인·users 문서 뒤 서버에 올리고 sent로 남긴다', () async {
      final e = _Env();
      await e.seed();
      e.fake.api.needProfile = true;
      expect(await e.gb.send('a:j1', '좋았어요'), isA<SendDone>());
      expect(e.fake.store.profiles['anon1']?.$1, '두발');
      final server = e.fake.api.posts['anon1_a:j1']!;
      expect((server.scope, server.text), ('kr001', '좋았어요'));
      expect((await e.posts()).single.status, PostStatus.sent);
      expect((await e.ticket('a:j1')).usedUtc, isNotNull);
    });

    test('users 문서가 아직 없다(no-profile)면 올리고 한 번 더 보낸다', () async {
      final e = _Env();
      await e.seed();
      e.fake.store.failTimes = 1;
      e.fake.api.needProfile = true;
      // 첫 users 올리기는 실패해도 글 보내기는 해 본다 → no-profile → 다시 올리고 다시 보낸다
      expect(await e.gb.send('a:j1', '안녕'), isA<SendDone>());
      expect(e.fake.api.calls.where((c) => c == 'postGuestbook'), hasLength(2));
    });

    test('이미 올라간 기회(already-exists)는 보낸 것으로 본다', () async {
      final e = _Env();
      await e.seed();
      e.fake.api.failNext.add(const ServerError('already-exists', reason: 'duplicate'));
      expect(await e.gb.send('a:j1', '다시'), isA<SendDone>());
      expect((await e.posts()).single.status, PostStatus.sent);
    });

    test('서버가 금칙어로 막으면 이 기기에도 남기지 않고 기회를 열어 둔다', () async {
      final e = _Env();
      await e.seed();
      e.fake.api.failNext.add(const ServerError('invalid-argument',
          reason: 'moderation', message: '이 표현은 방명록에 남길 수 없어요'));
      final r = await e.gb.send('a:j1', '나쁜 말');
      expect((r as SendBlocked).message, '이 표현은 방명록에 남길 수 없어요');
      expect(await e.posts(), isEmpty);
      expect((await e.ticket('a:j1')).usedUtc, isNull);
    });

    test('작성 제한 중이면 그 시각을 돌려주고 남기지 않는다', () async {
      final e = _Env();
      await e.seed();
      final until = _t.add(const Duration(days: 7));
      e.fake.api.failNext.add(ServerError('permission-denied',
          reason: 'banned', details: {'banUntil': until.millisecondsSinceEpoch}));
      final r = await e.gb.send('a:j1', '글');
      expect((r as SendBanned).until, until);
      expect(await e.posts(), isEmpty);
    });

    test('연결이 안 되면 이 기기에만 남긴다 (pending)', () async {
      final e = _Env();
      await e.seed();
      e.fake.api.failAlways = const ServerError.offline();
      expect(await e.gb.send('a:j1', '산에서'), isA<SendQueued>());
      expect((await e.posts()).single.status, PostStatus.pending);
    });

    test('로그인하지 못하면(오프라인) 서버를 부르지 않고 이 기기에만 남긴다', () async {
      final e = _Env();
      await e.seed();
      e.fake.auth.failSignIn = Exception('network');
      expect(await e.gb.send('a:j1', '산에서'), isA<SendQueued>());
      expect(e.fake.api.calls, isEmpty);
    });

    test('기회가 지났으면 서버를 부르지 않고 그 사유를 돌려준다', () async {
      final e = _Env();
      await e.seed();
      final r = await e.gb.send('a:j9', '없는 기회');
      expect(r, isA<SendClosed>());
      expect(e.fake.api.calls, isEmpty);
    });
  });

  group('못 올린 글 다시 올리기', () {
    test('pending 글을 오래된 순서로 올리고 sent로 바꾼다. 막힌 글은 rejected', () async {
      final e = _Env();
      await e.seed();
      await e.addTicket('m:100', 'steps:100');
      e.fake.api.failAlways = const ServerError.offline();
      await e.gb.send('a:j1', '첫 글');
      await e.gb.send('m:100', '둘째 글');
      e.fake.api.failAlways = null;
      e.fake.api.calls.clear();

      e.fake.api.failNext.add(const ServerError('invalid-argument', reason: 'moderation'));
      expect(await e.gb.uploadPending(), 1);
      final byId = {for (final p in await e.posts()) p.ticketId: p.status};
      expect(byId, {'a:j1': PostStatus.rejected, 'm:100': PostStatus.sent});
      expect(e.fake.api.posts.keys, ['anon1_m:100']);
    });

    test('연결이 안 되면 멈추고 그대로 둔다. 작성 제한 중인 글도 그대로', () async {
      final e = _Env();
      await e.seed();
      e.fake.api.failAlways = const ServerError.offline();
      await e.gb.send('a:j1', '첫 글');
      expect(await e.gb.uploadPending(), 0);
      e.fake.api.failAlways = null;
      e.fake.api.failNext.add(const ServerError('permission-denied', reason: 'banned'));
      expect(await e.gb.uploadPending(), 0);
      expect((await e.posts()).single.status, PostStatus.pending);
      expect(await e.gb.uploadPending(), 1);
      expect((await e.posts()).single.status, PostStatus.sent);
    });

    test('서버가 없으면 아무것도 하지 않는다', () async {
      final e = _Env(server: false);
      await e.seed();
      await e.gb.send('a:j1', '글');
      expect(await e.gb.uploadPending(), 0);
      expect((await e.posts()).single.status, PostStatus.pending);
    });
  });

  group('읽기·반응·받은 하트', () {
    test('읽기는 로그인한 뒤 그 범위로 부른다. 서버가 없으면 offline', () async {
      final e = _Env();
      await e.seed();
      final page = GuestbookPage(3, [
        OtherPost(
          postId: 'x_a:j',
          nickname: '나그네',
          text: '안녕',
          hearts: 2,
          createdAt: _t,
          myReaction: null,
        ),
      ]);
      e.fake.api.page = page;
      expect(await e.gb.read('kr001'), same(page));
      expect(e.fake.api.calls, ['readGuestbook:kr001']);

      final off = _Env(server: false);
      expect(() => off.gb.read('kr001'), throwsA(isA<ServerError>()));
    });

    test('받은 하트는 로그인했을 때만 읽는다', () async {
      final e = _Env();
      await e.seed();
      e.fake.store.hearts = {'a:j1': 4};
      expect(await e.gb.myHearts(), isEmpty);
      await e.gb.send('a:j1', '글');
      expect(await e.gb.myHearts(), {'a:j1': 4});
    });
  });
}
