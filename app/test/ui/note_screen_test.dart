import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/ui/note/note_screen.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

Future<void> _open(WidgetTester tester, UiEnv e) => openOnTop(tester, e, const NoteScreen(),
    height: 1200, ready: () => find.text('내 방명록').evaluate().isNotEmpty);

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

      expect(find.text('노트'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(find.text('내 방명록'), findsOneWidget);
      expect(find.text('걷기 기록'), findsOneWidget);
      expect(find.text('아직 남긴 방명록이 없어요'), findsOneWidget);
      expect(find.text('아직 감지된 걷기가 없어요'), findsNothing);

      // 걷기 기록 탭을 보고 돌아와도 빈 상태
      await _openWalksTab(tester);
      expect(find.text('아직 남긴 방명록이 없어요'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tab-guestbook')));
      await tester.pump();
      expect(find.text('아직 남긴 방명록이 없어요'), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('열기'), findsOneWidget);
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
