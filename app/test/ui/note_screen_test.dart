import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/ui/guestbook/guestbook_read_screen.dart';
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

/// [start]부터 [minutes]분 동안 분당 [spm]보를 걷고 그 시간을 닫힌 물감 길 한 줄로 넣는다 (동기화까지)
Future<void> _trail(UiEnv e, DateTime start, int minutes, int spm) async {
  e.source.records.add(walkRecord(start, minutes, spm));
  final end = start.add(Duration(minutes: minutes));
  await e.db.into(e.db.paintTrails).insert(PaintTrailsCompanion.insert(
        startUtc: start.millisecondsSinceEpoch,
        endUtc: Value(end.millisecondsSinceEpoch),
        endReason: const Value(PaintTrailEnd.idle),
      ));
  if (end.isAfter(e.now)) e.now = end.add(const Duration(minutes: 10));
  await e.svc.sync(e.now);
}

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
      expect(find.text('아직 걷기 기록이 없어요'), findsNothing);

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
      // 남기면 방명록 읽기로 이어지고, 뒤로 가면 노트 (들어온 곳)
      await settle(tester, () => find.byType(GuestbookReadScreen).evaluate().isNotEmpty);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await settle(tester, () => find.text('새로 남긴 글').evaluate().isNotEmpty);

      expect(find.byType(GuestbookWriteScreen), findsNothing);
      expect(find.byType(GuestbookReadScreen), findsNothing);
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

  group('걷기 기록 탭 (물감 길, 캔버스 6-3)', () {
    testWidgets('물감 길이 없으면 빈 상태', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _openWalksTab(tester, waitFor: '아직 걷기 기록이 없어요');

      expect(find.text('아직 걷기 기록이 없어요'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('최신순으로, 날짜 줄(걸음·거리) 아래 물감 길 줄(시각·물감 길 km)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 한국 11월 18일 10:00, 12:00, 11월 19일 20:00 (설치 뒤, 일부러 섞어 넣는다)
        await _trail(e, DateTime.utc(2026, 11, 18, 3), 20, 120);
        await _trail(e, DateTime.utc(2026, 11, 18, 1), 15, 100);
        await _trail(e, DateTime.utc(2026, 11, 19, 11), 30, 100);
      });
      await _open(tester, e);
      await _openWalksTab(tester, waitFor: '12:00');

      // 물감 길 거리: 2,400보 × 0.7 = 1.68km, 1,500보 = 1.05km, 3,000보 = 2.1km
      expect(find.text('1.7 km'), findsOneWidget);
      expect(find.text('1.1 km'), findsOneWidget);
      expect(find.text('2.1 km'), findsOneWidget);
      expect(find.text('물감 길'), findsNWidgets(3));
      // 날짜 줄: 그날 걸음·거리
      expect(find.text('3,900보 · 2.7 km'), findsOneWidget);
      expect(find.text('3,000보 · 2.1 km'), findsOneWidget);

      // 위에서 아래로: 11월 19일 → 20:00 → 11월 18일 → 12:00 → 10:00
      final order = [
        _y(tester, find.text('11월 19일')),
        _y(tester, find.text('20:00')),
        _y(tester, find.text('11월 18일')),
        _y(tester, find.text('12:00')),
        _y(tester, find.text('10:00')),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]), reason: '$i번째 줄');
      }
      await end(tester, e);
    });

    testWidgets('물감 길 줄을 누르면 그 물감 길의 걷기 기록이 열린다 (동기화 없이, 뒤로)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 15분 × 100보 = 1,500보, 1.05km, 물감 방울 10개(100m마다), 럭 10.5 + 10.5 → 21
        await e.svc.startJourney('kr003', t1);
        e.now = t1.add(const Duration(minutes: 30));
        await _trail(e, t1, 15, 100);
      });
      final syncedAt = (await tester.runAsync(() => e.svc.snapshot(e.now)))!.lastFetched;
      // 열 때 시계가 훌쩍 지나 있어도 동기화하지 않는다 (마지막 동기화 시각이 그대로)
      e.now = t1.add(const Duration(minutes: 90));
      await _open(tester, e);
      await _openWalksTab(tester, waitFor: '10:00');

      final id = (await tester.runAsync(() => e.db.select(e.db.paintTrails).getSingle()))!.id;
      await tester.tap(find.byKey(ValueKey('trail-$id')));
      await transition(tester);
      await settle(tester, () => find.text('기록을 정리하는 중').evaluate().isEmpty);
      await tester.pump();

      final screen = tester.widget<WalkRecordScreen>(find.byType(WalkRecordScreen));
      expect(screen.start, t1);
      expect(screen.end, t1.add(const Duration(minutes: 15)));

      expect(find.text('물감 길'), findsOneWidget);
      expect(find.text('11월 18일 10:00 ~ 10:15'), findsOneWidget);
      expect(find.text('1,500'), findsOneWidget);
      // 큰 거리 숫자와 1km 기록의 남은 구간 줄
      expect(find.text('1.05 km'), findsNWidgets(2));
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('걷기 100% · 달리기 0%'), findsOneWidget);
      expect(find.text('10개'), findsOneWidget);
      expect(find.text('+21 럭'), findsOneWidget);
      expect(find.text('오늘 함께 걷기 1/3'), findsOneWidget);
      // 실제/여행 두 줄·다음 방명록 지점·진행 막대 연출·쉼터로 버튼은 없다
      expect(find.textContaining('다음 방명록'), findsNothing);
      expect(find.textContaining('여행 '), findsNothing);
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

    testWidgets('지난 날의 물감 길은 오늘 대신 그 날짜와 그날의 몇 번째인지로 부른다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 같은 날 15분 물감 길 4번 (30분 간격): 앞 셋은 인정, 넷째는 하루 최대를 채워 인정 안 됨
        for (var i = 0; i < 4; i++) {
          await _trail(e, t1.add(Duration(minutes: 30 * i)), 15, 100);
        }
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
      await view('10:00', '11월 18일 함께 걷기 1/3');
      await view('10:30', '11월 18일 함께 걷기 2/3');
      await view('11:00', '11월 18일 함께 걷기 3/3');
      await view('11:30', '11월 18일은 3/3번을 다 채웠어요');
      await end(tester, e);
    });
  });
}
