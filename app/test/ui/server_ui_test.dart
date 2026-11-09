import 'package:doobal/app/server_providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/server.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/guestbook/guestbook_read_screen.dart';
import 'package:doobal/ui/guestbook/guestbook_tag.dart';
import 'package:doobal/ui/guestbook/guestbook_write_screen.dart';
import 'package:doobal/ui/note/note_screen.dart';
import 'package:doobal/ui/settings/settings_account.dart';
import 'package:doobal/ui/settings/settings_screen.dart';
import 'package:doobal/ui/start/welcome_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_server.dart';
import 'ui_env.dart';

/// 가짜 서버를 붙인 화면 시험 (T1b). 서버 없는 화면은 각 화면 시험이 본다

OtherPost _other(String id, {int hearts = 0, String? mine, int daysAgo = 3}) => OtherPost(
      postId: id,
      nickname: '나그네$id',
      text: '글 $id',
      hearts: hearts,
      createdAt: t1.subtract(Duration(days: daysAgo)),
      myReaction: mine,
    );

Future<void> _myPost(UiEnv e, {PostStatus status = PostStatus.sent}) =>
    e.db.into(e.db.guestbookPosts).insert(GuestbookPostsCompanion.insert(
          ticketId: 'a:j1',
          scope: 'kr001',
          body: '내 글',
          createdUtc: t1.millisecondsSinceEpoch,
          status: status,
        ));

Future<void> _openRead(WidgetTester tester, UiEnv e, FakeServer s) => openOnTop(
      tester,
      e,
      const GuestbookReadScreen(ticketId: 'a:j1'),
      height: 1400,
      extra: [serverBackendProvider.overrideWithValue(s.backend)],
      ready: () =>
          find.byKey(const ValueKey('guestbook-read-title')).evaluate().isNotEmpty &&
          (find.byType(GameButton).evaluate().isNotEmpty ||
              find.byKey(const ValueKey('guestbook-read-empty')).evaluate().isNotEmpty ||
              find.byKey(const ValueKey('guestbook-read-offline')).evaluate().isNotEmpty ||
              find.textContaining('나그네').evaluate().isNotEmpty),
    );

Future<void> _openSettings(WidgetTester tester, UiEnv e, FakeServer s) => openOnTop(
      tester,
      e,
      const SettingsScreen(),
      height: 1700,
      extra: [serverBackendProvider.overrideWithValue(s.backend)],
      ready: () => find.byKey(const ValueKey('account-state')).evaluate().isNotEmpty,
    );

String _accountText(WidgetTester tester) => tester
    .widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('account-state')), matching: find.byType(Text)))
    .data!;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('방명록 읽기', () {
    testWidgets('다른 여행자 글과 n명 중 5명, 다른 5개 보기는 다시 읽는다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.api.page = GuestbookPage(7, [_other('1', hearts: 2), _other('2', daysAgo: 0)]);
      await e.seed(tester, () => _myPost(e));
      await _openRead(tester, e, s);

      expect(find.text('내 글'), findsOneWidget);
      expect(find.text('7명 중 2명'), findsOneWidget);
      expect(find.text('나그네1'), findsOneWidget);
      expect(find.text('3일 전'), findsOneWidget);
      expect(find.text('글 2'), findsOneWidget);
      expect(s.api.calls, ['readGuestbook:kr001']);

      await tester.tap(find.text('다른 5개 보기'));
      await settle(tester, () => s.api.calls.length == 2);
      await tester.pump();
      expect(s.api.calls.last, 'readGuestbook:kr001');
      await end(tester, e);
    });

    testWidgets('하트를 누르면 채워지고 숫자가 바뀌고, 신고는 신고함과 토스트', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.api.page = GuestbookPage(3, [_other('1', hearts: 2)]);
      s.api.hearts['1'] = 2;
      await e.seed(tester, () => _myPost(e));
      await _openRead(tester, e, s);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('heart-1')));
      await settle(tester, () => find.byIcon(Icons.favorite).evaluate().isNotEmpty);
      expect(s.api.calls.last, 'react:1:heart');
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('report-1')));
      await settle(tester, () => find.text('신고함').evaluate().isNotEmpty);
      expect(s.api.calls.last, 'react:1:report');
      expect(find.text('신고했어요'), findsOneWidget);
      // 서버는 글 하나에 내 반응 하나: 신고하면 하트가 빠진다
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // 신고함을 다시 누르면 취소
      await tester.tap(find.byKey(const ValueKey('report-1')));
      await settle(tester, () => find.text('신고').evaluate().isNotEmpty);
      expect(s.api.calls.last, 'react:1:null');
      await end(tester, e);
    });

    testWidgets('지워진 글에 누르면 카드가 빠진다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.api.page = GuestbookPage(3, [_other('1'), _other('2')]);
      await e.seed(tester, () => _myPost(e));
      await _openRead(tester, e, s);
      s.api.failNext.add(const ServerError('not-found', reason: 'no-post'));
      await tester.tap(find.byKey(const ValueKey('heart-1')));
      await settle(tester, () => find.text('지워진 글이에요').evaluate().isNotEmpty);
      expect(find.text('나그네1'), findsNothing);
      expect(find.text('나그네2'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('아직 아무도 없으면 빈 안내, 다른 5개 보기는 없다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.api.page = const GuestbookPage(1, []);
      await e.seed(tester, () => _myPost(e));
      await _openRead(tester, e, s);
      expect(find.text('처음 지나는 여행자예요'), findsOneWidget);
      expect(find.text('아직 아무도 남기지 않았어요'), findsOneWidget);
      expect(find.text('다른 5개 보기'), findsNothing);
      expect(find.textContaining('명 중'), findsNothing);
      await end(tester, e);
    });

    testWidgets('연결이 안 되면 내 글만 보이고 한 줄로 알린다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.api.failAlways = const ServerError.offline();
      await e.seed(tester, () => _myPost(e, status: PostStatus.pending));
      await _openRead(tester, e, s);
      expect(find.text('내 글'), findsOneWidget);
      expect(find.text('연결되면 다른 여행자의 글을 볼 수 있어요'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('방명록 쓰기', () {
    testWidgets('서버가 금칙어로 막으면 초안을 두고 칸 아래에 알리며, 고치면 다시 남길 수 있다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      await e.seed(tester, () async {
        await e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
              id: 'a:j1',
              kind: TicketKind.arrival,
              scope: 'kr001',
              openedUtc: t1.millisecondsSinceEpoch,
            ));
      });
      final input = find.byKey(const ValueKey('guestbook-input'));
      await openOnTop(tester, e, const GuestbookWriteScreen(ticketId: 'a:j1'),
          extra: [serverBackendProvider.overrideWithValue(s.backend)],
          ready: () => input.evaluate().isNotEmpty);
      s.api.failNext.add(const ServerError('invalid-argument',
          reason: 'moderation', message: '이 표현은 방명록에 남길 수 없어요'));
      await tester.enterText(input, '서버만 아는 말');
      await tester.pump();
      await tester.tap(find.text('남기기'));
      await settle(tester, () => find.text('이 표현은 방명록에 남길 수 없어요').evaluate().isNotEmpty);

      expect(find.byType(GuestbookWriteScreen), findsOneWidget);
      expect(find.text('서버만 아는 말'), findsOneWidget);
      expect(
          tester.widget<GameButton>(find.widgetWithText(GameButton, '남기기')).onPressed, isNull);
      expect(await tester.runAsync(() => e.db.select(e.db.guestbookPosts).get()), isEmpty);

      await tester.enterText(input, '고친 말');
      await tester.pump();
      expect(find.text('이 표현은 방명록에 남길 수 없어요'), findsNothing);
      await tester.tap(find.text('남기기'));
      await settle(tester, () => find.byType(GuestbookReadScreen).evaluate().isNotEmpty, tries: 60);
      await transition(tester);
      final post = (await tester.runAsync(() => e.db.select(e.db.guestbookPosts).get()))!.single;
      expect((post.body, post.status), ('고친 말', PostStatus.sent));
      expect(s.api.posts.values.single.text, '고친 말');
      await end(tester, e);
    });
  });

  group('노트', () {
    testWidgets('서버에 올린 글에 받은 하트가 붙는다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.store.hearts = {'a:j1': 7};
      await e.seed(tester, () => _myPost(e));
      await openOnTop(tester, e, const NoteScreen(),
          height: 1200,
          extra: [serverBackendProvider.overrideWithValue(s.backend)],
          ready: () => find.text('내 글').evaluate().isNotEmpty);
      // 노트는 로그인을 기다리지 않는다. 로그인하면 하트를 다시 읽는다
      await tester.runAsync(() => s.auth.signInAnonymously());
      final hearts = find.byKey(const ValueKey('hearts-a:j1'));
      await settle(tester, () => hearts.evaluate().isNotEmpty);
      expect(find.descendant(of: find.byKey(const ValueKey('post-a:j1')), matching: hearts),
          findsOneWidget);
      expect(find.descendant(of: hearts, matching: find.text('7')), findsOneWidget);
      expect(find.descendant(of: hearts, matching: find.byIcon(Icons.favorite)), findsOneWidget);
      await end(tester, e);
    });
  });

  group('설정 계정 연결', () {
    testWidgets('연결 전에는 익명과 세 계정, 동의 한 줄. 구글로 연결하면 연결됨과 연결 해제', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      await e.seed(tester);
      await _openSettings(tester, e, s);

      expect(_accountText(tester), '연결 안 함 (익명)');
      expect(find.text(linkConsentText), findsOneWidget);
      for (final t in ['구글', '애플', '카카오']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('준비 중'), findsOneWidget); // 광고 동의만

      await tester.tap(find.text('구글'));
      await settle(tester, () => _accountText(tester) == '구글로 연결됨');
      expect(find.text('구글로 연결했어요'), findsOneWidget);
      expect(find.text(linkConsentText), findsNothing);
      expect(find.text('카카오'), findsNothing);
      expect(s.auth.calls, ['anon', 'link:google']);

      await tester.tap(find.text('연결 해제'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(unlinkWarning), findsOneWidget);
      await tester.tap(find.text('해제'));
      await settle(tester, () => _accountText(tester) == '연결 안 함 (익명)');
      expect(s.auth.calls.last, 'unlink:google');
      await end(tester, e);
    });

    testWidgets('카카오 SDK가 없으면 카카오만 준비 중', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.kakao.available = false;
      await e.seed(tester);
      await _openSettings(tester, e, s);
      expect(find.text('준비 중'), findsNWidgets(2));
      await end(tester, e);
    });

    testWidgets('다른 계정에 연결된 구글이면 묻고, 바꾸면 그 계정으로 들어간다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.auth.conflicts[LinkProvider.google] = 'g-owner';
      await e.seed(tester);
      await _openSettings(tester, e, s);

      await tester.tap(find.text('구글'));
      await settle(tester, () => find.text('그 계정의 기록으로 바꿀까요? 이 기기의 기록은 사라져요')
          .evaluate()
          .isNotEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('바꾸기'));
      await settle(tester, () => _accountText(tester) == '구글로 연결됨');
      // 그 계정에 백업이 없어서 이 기기 기록을 그대로 둔다
      expect(find.text('그 계정으로 바꿨어요'), findsOneWidget);
      expect(s.auth.user!.uid, 'g-owner');
      await end(tester, e);
    });

    testWidgets('바꾸지 않으면 그대로다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.auth.conflicts[LinkProvider.apple] = 'a-owner';
      await e.seed(tester);
      await _openSettings(tester, e, s);
      await tester.tap(find.text('애플'));
      await settle(tester, () => find.text('그대로 두기').evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('그대로 두기'));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, () => false, tries: 4);
      expect(_accountText(tester), '연결 안 함 (익명)');
      expect(s.auth.user!.uid, 'anon1');
      await end(tester, e);
    });
  });

  group('계정 삭제', () {
    Future<void> deleteAll(WidgetTester tester, UiEnv e, FakeServer s) async {
      await e.seed(tester);
      phone(tester, height: 1700);
      await tester.pumpWidget(ProviderScope(
        overrides: [...e.overrides, serverBackendProvider.overrideWithValue(s.backend)],
        child: const DoobalApp(),
      ));
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await settle(tester, () => s.auth.user != null);
      await tester.tap(find.byIcon(Icons.settings));
      await transition(tester);
      await tester.tap(find.text('계정 삭제'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('이 기기와 서버의 기록(방명록 포함)이 모두 지워져요'), findsOneWidget);
      await tester.tap(find.text('계속'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('삭제'));
    }

    testWidgets('서버 계정을 지우고 로그아웃한 뒤 기기 기록을 지워 환영 화면', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      await deleteAll(tester, e, s);
      await settle(tester, () => find.byType(WelcomeScreen).evaluate().isNotEmpty);
      await transition(tester);
      expect(s.api.calls, contains('deleteAccount'));
      expect(s.auth.calls.last, 'signOut');
      expect(await tester.runAsync(() => e.db.select(e.db.profile).get()), isEmpty);
      await end(tester, e);
    });

    testWidgets('오프라인이면 기기 기록도 지우지 않고 알린다', (tester) async {
      final e = UiEnv();
      final s = FakeServer();
      s.api.failAlways = const ServerError.offline();
      await deleteAll(tester, e, s);
      await settle(tester, () => find.text('인터넷에 연결한 뒤 다시 해 주세요').evaluate().isNotEmpty);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(await tester.runAsync(() => e.db.select(e.db.profile).get()), isNotEmpty);
      expect(s.auth.user, isNotNull);
      await end(tester, e);
    });
  });

  group('시간 줄', () {
    test('방금 · n분 전 · n시간 전 · n일 전 · 그보다 오래면 날짜', () {
      final now = DateTime.utc(2026, 11, 18, 3);
      expect(formatAgo(now.subtract(const Duration(seconds: 30)), now), '방금');
      expect(formatAgo(now.add(const Duration(minutes: 5)), now), '방금');
      expect(formatAgo(now.subtract(const Duration(minutes: 59)), now), '59분 전');
      expect(formatAgo(now.subtract(const Duration(hours: 23)), now), '23시간 전');
      expect(formatAgo(now.subtract(const Duration(days: 3)), now), '3일 전');
      expect(formatAgo(now.subtract(const Duration(days: 30)), now), '30일 전');
      expect(formatAgo(DateTime.utc(2026, 10, 1, 16), now), '10월 2일');
    });
  });
}
