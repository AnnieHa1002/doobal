import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/ui/guestbook/guestbook_write_screen.dart';
import 'package:doobal/ui/note/note_screen.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

Future<void> _open(WidgetTester tester, UiEnv e) => openOnTop(tester, e, const NoteScreen(),
    height: 1200, ready: () => find.text('내 방명록').evaluate().isNotEmpty);

final _empty = find.text('아직 남긴 방명록이 없어요');
final _pending = find.text('연결되면 올라가요');

/// 내 방명록 탭을 열고(처음에는 열려 있다) 글 목록이나 빈 상태가 뜰 때까지 기다린다
Future<void> _settleGuestbook(WidgetTester tester) async {
  await settle(tester, () => _empty.evaluate().isNotEmpty || _pending.evaluate().isNotEmpty);
  await tester.pump();
}

/// 내가 쓴 글 한 줄을 DB에 직접 넣는다 (쓰기 화면을 거치지 않는 목록 확인용)
Future<void> _post(
  AppDb db,
  String ticketId,
  String scope,
  String body,
  DateTime at, {
  PostStatus status = PostStatus.pending,
}) =>
    db.into(db.guestbookPosts).insert(GuestbookPostsCompanion.insert(
          ticketId: ticketId,
          scope: scope,
          body: body,
          createdUtc: at.millisecondsSinceEpoch,
          status: status,
        ));

Future<void> _openWalksTab(WidgetTester tester, {String? waitFor}) async {
  await tester.tap(find.byKey(const ValueKey('tab-walks')));
  await settle(tester, () => waitFor == null || find.text(waitFor).evaluate().isNotEmpty);
  await tester.pump();
}

/// 걷기 한 줄을 DB에 직접 넣는다 (걷기 기록 화면을 열지 않는 목록 확인용)
Future<void> _session(AppDb db, DateTime start, int minutes, int steps, double distanceM) =>
    db.into(db.walkSessions).insert(WalkSessionsCompanion.insert(
          startUtc: Value<int>(start.millisecondsSinceEpoch),
          endUtc: start.add(Duration(minutes: minutes)).millisecondsSinceEpoch,
          steps: steps,
          distanceM: distanceM,
          runRatio: 0,
          qualified: true,
          counted: true,
        ));

double _y(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('내 방명록 탭', () {
    testWidgets('제목과 두 탭, 처음에는 내 방명록이 빈 상태로 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _settleGuestbook(tester);

      expect(find.text('노트'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(find.text('내 방명록'), findsOneWidget);
      expect(find.text('걷기 기록'), findsOneWidget);
      expect(_empty, findsOneWidget);
      expect(find.text('아직 감지된 걷기가 없어요'), findsNothing);

      // 걷기 기록 탭을 보고 돌아와도 빈 상태
      await _openWalksTab(tester);
      expect(_empty, findsNothing);
      await tester.tap(find.byKey(const ValueKey('tab-guestbook')));
      await _settleGuestbook(tester);
      expect(_empty, findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('열기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('쓴 글이 최신순으로: 태그(명소 도착·내 동네 스케치 도착·걸음 숫자)·본문·날짜', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 일부러 섞어 넣는다. 한국 11월 18일 10:00 = t1
        await _post(e.db, 'a:j1', 'kr001', '경복궁 좋았어요', t1);
        await _post(e.db, 'm:12345', 'steps:12345', '만 이천 걸음!', t1.add(const Duration(days: 1)));
        await _post(e.db, 'a:j0', 'sketch', '첫 그림', t1.subtract(const Duration(days: 2)));
        // 같은 한국 날짜 안(11월 18일 00:30)이면 전날 UTC여도 18일
        await _post(e.db, 'a:j2', 'kr001', '또 왔어요', DateTime.utc(2026, 11, 17, 15, 30));
      });
      await _open(tester, e);
      await _settleGuestbook(tester);

      expect(_empty, findsNothing);
      // 태그 3종: 명소 도착 / 내 동네 스케치 도착 / 걸음 숫자 (천 단위 쉼표)
      expect(find.text('경복궁 도착'), findsNWidgets(2));
      expect(find.text('내 동네 스케치 도착'), findsOneWidget);
      expect(find.text('12,345보'), findsOneWidget);
      // 날짜: 한국 날짜로
      expect(find.text('11월 19일'), findsOneWidget);
      expect(find.text('11월 18일'), findsNWidgets(2));
      expect(find.text('11월 16일'), findsOneWidget);
      expect(find.text('만 이천 걸음!'), findsOneWidget);
      // 받은 하트는 아직 보이지 않는다
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      // 위에서 아래로: 11월 19일 → 11월 18일 10:00 → 11월 18일 00:30 → 11월 16일
      final order = [
        _y(tester, find.text('만 이천 걸음!')),
        _y(tester, find.text('경복궁 좋았어요')),
        _y(tester, find.text('또 왔어요')),
        _y(tester, find.text('첫 그림')),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]), reason: '$i번째 카드');
      }
      await end(tester, e);
    });

    testWidgets('서버에 못 올린 글(pending)만 "연결되면 올라가요"가 붙는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _post(e.db, 'a:j1', 'kr001', '아직', t1);
        await _post(e.db, 'a:j2', 'kr002', '이미', t1.add(const Duration(minutes: 1)),
            status: PostStatus.sent);
      });
      await _open(tester, e);
      await _settleGuestbook(tester);

      expect(find.text('아직'), findsOneWidget);
      expect(find.text('이미'), findsOneWidget);
      expect(_pending, findsOneWidget);
      // 안내는 pending 글의 카드 안에 있다
      expect(
        find.descendant(of: find.byKey(const ValueKey('post-a:j1')), matching: _pending),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('post-a:j2')), matching: _pending),
        findsNothing,
      );
      await end(tester, e);
    });

    testWidgets('쓰기 화면에서 글을 남기고 돌아오면 노트에 새 글이 맨 위에 보인다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _post(e.db, 'a:j0', 'sketch', '예전 글', t1.subtract(const Duration(days: 1)));
        await e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
              id: 'a:j1',
              kind: TicketKind.arrival,
              scope: 'kr001',
              openedUtc: t1.millisecondsSinceEpoch,
            ));
      });
      await _open(tester, e);
      await _settleGuestbook(tester);
      expect(find.text('예전 글'), findsOneWidget);
      expect(find.text('새로 남긴 글'), findsNothing);

      // 노트 위에 쓰기 화면을 올려 쓴다 (노트는 아래에 열려 있다)
      final nav = Navigator.of(tester.element(find.byType(NoteScreen)));
      nav.push(MaterialPageRoute<void>(
        builder: (_) => const GuestbookWriteScreen(ticketId: 'a:j1'),
      ));
      await transition(tester);
      final input = find.byKey(const ValueKey('guestbook-input'));
      await settle(tester, () => input.evaluate().isNotEmpty);
      await tester.enterText(input, '새로 남긴 글');
      await tester.pump();
      await tester.tap(find.text('남기기'));
      await settle(tester, () => find.text('방명록을 남겼어요').evaluate().isNotEmpty, tries: 12);
      await transition(tester);
      await settle(tester, () => find.text('새로 남긴 글').evaluate().isNotEmpty);

      expect(find.byType(GuestbookWriteScreen), findsNothing);
      expect(find.text('새로 남긴 글'), findsOneWidget);
      expect(find.text('예전 글'), findsOneWidget);
      expect(_y(tester, find.text('새로 남긴 글')), lessThan(_y(tester, find.text('예전 글'))));
      // 방금 쓴 글은 아직 서버로 보내지 않았다
      expect(
        find.descendant(of: find.byKey(const ValueKey('post-a:j1')), matching: _pending),
        findsOneWidget,
      );
      await end(tester, e);
    });
  });

  group('걷기 기록 탭', () {
    testWidgets('걷기가 없으면 빈 상태', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _openWalksTab(tester, waitFor: '아직 감지된 걷기가 없어요');

      expect(find.text('아직 감지된 걷기가 없어요'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('최신순으로, 날짜별 묶음에 시각·걸음·거리가 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 한국 11월 17일 20:00, 11월 18일 10:00, 11월 18일 12:00 (일부러 섞어 넣는다)
        await _session(e.db, DateTime.utc(2026, 11, 18, 1), 15, 1500, 1050);
        await _session(e.db, DateTime.utc(2026, 11, 17, 11), 30, 3000, 2100);
        await _session(e.db, DateTime.utc(2026, 11, 18, 3), 20, 2400, 1680);
      });
      await _open(tester, e);
      await _openWalksTab(tester, waitFor: '12:00');

      expect(find.text('2,400보'), findsOneWidget);
      expect(find.text('1.68 km'), findsOneWidget);
      expect(find.text('1,500보'), findsOneWidget);
      expect(find.text('1.05 km'), findsOneWidget);
      expect(find.text('3,000보'), findsOneWidget);
      expect(find.text('2.10 km'), findsOneWidget);

      // 위에서 아래로: 11월 18일 → 12:00 → 10:00 → 11월 17일 → 20:00
      final order = [
        _y(tester, find.text('11월 18일')),
        _y(tester, find.text('12:00')),
        _y(tester, find.text('10:00')),
        _y(tester, find.text('11월 17일')),
        _y(tester, find.text('20:00')),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]), reason: '$i번째 줄');
      }
      await end(tester, e);
    });

    testWidgets('한 줄을 누르면 그 걷기의 걷기 기록이 다시 보기로 열린다 (동기화 없이, 쉼터로 대신 뒤로)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 걷기 15분 × 100보 = 1,500보, 1.05km. 목적지 여정이 있어도 다시 볼 때는 진행 막대가 없다
        await e.svc.startJourney('kr003', t1);
        e.source.records.add(walkRecord(t1, 15, 100));
        e.now = t1.add(const Duration(minutes: 30));
        await e.svc.sync(e.now);
      });
      final syncedAt = (await tester.runAsync(() => e.svc.snapshot(e.now)))!.lastFetched;
      // 열 때 시계가 훌쩍 지나 있어도 동기화하지 않는다 (마지막 동기화 시각이 그대로)
      e.now = t1.add(const Duration(minutes: 90));
      await _open(tester, e);
      await _openWalksTab(tester, waitFor: '10:00');

      await tester.tap(find.byKey(ValueKey('walk-${t1.millisecondsSinceEpoch}')));
      await transition(tester);
      await settle(tester, () => find.text('기록을 정리하는 중').evaluate().isEmpty);
      await tester.pump();

      final screen = tester.widget<WalkRecordScreen>(find.byType(WalkRecordScreen));
      expect(screen.review, isTrue);
      expect(screen.start, t1);
      expect(screen.end, t1.add(const Duration(minutes: 15)));

      expect(find.text('걷기 기록'), findsOneWidget);
      expect(find.text('11월 18일 10:00 ~ 10:15'), findsOneWidget);
      expect(find.text('1,500'), findsOneWidget);
      expect(find.text('1.05 km'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('걷기 100% · 달리기 0%'), findsOneWidget);
      expect(find.text('오늘 1/3번째 함께 걷기'), findsOneWidget);
      expect(find.text('다음 방명록 지점까지 3,500보'), findsOneWidget);
      // 진행 막대 연출과 쉼터로 버튼은 없고 뒤로 가기만 있다
      expect(find.textContaining('왔어요'), findsNothing);
      expect(find.text('쉼터로'), findsNothing);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(
        (await tester.runAsync(() => e.svc.snapshot(e.now)))!.lastFetched,
        syncedAt,
      );

      // 뒤로 오면 노트의 걷기 기록 탭 그대로
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(WalkRecordScreen), findsNothing);
      expect(find.text('노트'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('지난 날의 걷기는 오늘 대신 그 날짜와 그날의 몇 번째인지로 부른다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 같은 날 15분 걷기 4번 (30분 간격): 앞 셋은 인정, 넷째는 하루 최대를 채워 인정 안 됨
        for (var i = 0; i < 4; i++) {
          e.source.records.add(walkRecord(t1.add(Duration(minutes: 30 * i)), 15, 100));
        }
        e.now = t1.add(const Duration(hours: 3));
        await e.svc.sync(e.now);
      });
      // 이틀 뒤에 노트를 연다
      e.now = t1.add(const Duration(days: 2));
      await _open(tester, e);
      await _openWalksTab(tester, waitFor: '10:00');

      Future<void> view(String clock, String line) async {
        await tester.tap(find.text(clock));
        await transition(tester);
        await settle(tester, () => find.text(line).evaluate().isNotEmpty);
        await tester.pump();
        expect(find.text(line), findsOneWidget, reason: clock);
        expect(find.textContaining('오늘'), findsNothing, reason: clock);
        await tester.tap(find.byTooltip('뒤로'));
        await transition(tester);
      }

      // 앞 셋은 그날의 1·2·3번째 인정, 넷째는 하루 최대를 채운 뒤라 인정 못 받는다
      await view('10:00', '11월 18일 1/3번째 함께 걷기');
      await view('10:30', '11월 18일 2/3번째 함께 걷기');
      await view('11:00', '11월 18일 3/3번째 함께 걷기');
      await view('11:30', '11월 18일은 3/3번을 다 채웠어요');
      await end(tester, e);
    });
  });
}
