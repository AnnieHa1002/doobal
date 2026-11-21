import 'package:doobal/app/paint_trail_controller.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/guestbook.dart' show TicketKind;
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/guestbook/guestbook_write_screen.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/note/note_screen.dart';
import 'package:doobal/ui/profile/profile_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/settings/settings_screen.dart';
import 'package:doobal/ui/shop/shop_screen.dart';
import 'package:doobal/ui/tabs/home_tabs.dart';
import 'package:doobal/ui/tabs/tab_bar.dart' show TabBarMetrics;
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import 'ui_env.dart';

// 화면 3탭 (16장 11/18 ①④⑤⑥·11/19, config ui.tabs·rest.sideButtons·guestbook.sign, M2~M6 AB·AC,
// 캔버스 TabBar·2-2·3-1·9-1): 아래 탭 바 쉼터·걷기·나, 쉼터 옆 세로 버튼, 걸어도 탭은 저절로 안 바뀜,
// 걷기 탭 = 걷는 중(안 걸으면 쉬는 중), 나 탭 = 나의 정보·노트·설정, 도착 → 걷기 기록 → 쉼터 탭

final _bar = find.byKey(const ValueKey('tab-bar'));

/// 앱을 띄우고 쉼터 탭이 뜰 때까지
Future<ProviderContainer> _pumpApp(WidgetTester tester, UiEnv e, {double width = 390, double height = 844}) async {
  await pumpDoobal(tester, e, const DoobalApp(), width: width, height: height);
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty, tries: 80);
  await settle(tester, () => false, tries: 8);
  return ProviderScope.containerOf(tester.element(find.byType(HomeTabs)));
}

/// 지금 보이는(Offstage가 아닌) 것만
Finder _onstage(Type t) => find.byType(t);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('탭 바 아래 여백: 안드로이드는 버튼 줄을 다 비우고, iOS는 홈 막대에 12pt 겹친다, 안전 영역이 없으면 4', () {
    expect(TabBarMetrics.bottomPad(48, TargetPlatform.android), 48);
    expect(TabBarMetrics.bottomPad(16, TargetPlatform.android), 16);
    expect(TabBarMetrics.bottomPad(34, TargetPlatform.iOS), 22);
    expect(TabBarMetrics.bottomPad(0, TargetPlatform.android), 4);
    expect(TabBarMetrics.bottomPad(0, TargetPlatform.iOS), 4);
  });

  testWidgets('좁은 폰(360pt)에서도 걷기 탭 표지판은 화면 안에 있다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await e.startSketch();
      await e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
            id: 'a:j1',
            kind: TicketKind.arrival,
            scope: 'kr001',
            openedUtc: t1.millisecondsSinceEpoch,
          ));
    });
    await _pumpApp(tester, e, width: 360, height: 880);
    await openTab(tester, 'walk');
    final sign = find.byKey(const ValueKey('road-signpost'));
    await settle(tester, () => sign.evaluate().isNotEmpty, tries: 40);
    expect(tester.getRect(sign).right, lessThanOrEqualTo(360 - 4 + 0.01));
    await end(tester, e);
  });

  testWidgets('앱은 쉼터 탭으로 열리고 아래 탭 바는 쉼터·걷기·나, 위에는 럭 보석과 쉬는 중 알약만', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    final c = await _pumpApp(tester, e);
    expect(c.read(currentTabProvider), HomeTab.rest);
    expect(_bar, findsOneWidget);
    for (final t in ['rest', 'walk', 'me']) {
      expect(find.byKey(ValueKey('tab-$t')), findsOneWidget, reason: t);
    }
    expect(find.text('쉼터'), findsOneWidget);
    expect(find.text('걷기'), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
    // 캔버스 TabBar: 390×844 폰(아래 안전 영역 없음)에서 보이는 62 + 아래 4
    expect(tester.getRect(_bar), const Rect.fromLTWH(0, 844 - 66, 390, 66));
    // 나의 정보·설정 모서리 버튼은 나 탭으로 옮겨 없다
    expect(find.byTooltip('나의 정보'), findsNothing);
    expect(find.byTooltip('설정'), findsNothing);
    expect(find.byKey(const ValueKey('rest-gem')), findsOneWidget);
    // 옆 버튼은 지도·배낭·상점·꾸미기 (꾸미기는 T15가 켰다), 오른쪽 12pt에 위에서부터
    final ids = ['map', 'backpack', 'shop', 'decorate'];
    final rects = [for (final id in ids) tester.getRect(find.byKey(ValueKey('rest-side-$id')))];
    for (final r in rects) {
      expect(r.right, closeTo(390 - 12, 0.5));
      expect(r.width, 56);
    }
    expect(rects[0].top, lessThan(rects[1].top));
    expect(rects[1].top, lessThan(rects[2].top));
    expect(rects[2].top, lessThan(rects[3].top));
    // 걷기·나 탭은 아직 짓지 않았다 (처음 갈 때 짓는다)
    expect(find.byType(WalkingScreen, skipOffstage: false), findsNothing);
    await end(tester, e);
  });

  testWidgets('옆 버튼: 지도·배낭(화집)·상점은 쉼터 탭 안에서 열려 탭 바가 남고, 탭을 누르면 쉼터 처음 화면', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    for (final (id, screen) in [('map', MapScreen), ('backpack', AlbumScreen), ('shop', ShopScreen)]) {
      await openSide(tester, id);
      await settle(tester, () => _onstage(screen).evaluate().isNotEmpty, tries: 40);
      expect(_onstage(screen), findsOneWidget, reason: id);
      expect(_bar, findsOneWidget, reason: id);
      await openTab(tester, 'rest');
      expect(_onstage(screen), findsNothing, reason: id);
      expect(_onstage(RestScreen), findsOneWidget);
    }
    await end(tester, e);
  });

  testWidgets('여정이 없으면 지도 옆 버튼에 알림 점', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _pumpApp(tester, e);
    expect(find.byKey(const ValueKey('rest-side-map-dot')), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('걸어도 탭은 그대로이고 걷기 아이콘 발자국만 움직인다. 걷기 탭을 누르면 걷는 중', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    final c = await _pumpApp(tester, e);
    expect(find.byKey(const ValueKey('tab-walk-still')), findsOneWidget);
    for (var i = 0; i < 80 && !c.read(paintTrailProvider).active; i++) {
      await tester.runAsync(() => c.read(paintTrailProvider.notifier).startNow());
      await tester.pump();
    }
    expect(c.read(paintTrailProvider).active, isTrue);
    await settle(tester, () => false, tries: 8);
    expect(c.read(currentTabProvider), HomeTab.rest);
    expect(_onstage(RestScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-walk-steps')), findsOneWidget);
    // 쉼터 위 ‘걷는 중’ 알약은 없다 (16장 11/18)
    expect(find.byKey(const ValueKey('rest-walking-pill')), findsNothing);
    await openTab(tester, 'walk');
    await settle(tester, () => _onstage(WalkingScreen).evaluate().isNotEmpty, tries: 40);
    expect(_onstage(WalkingScreen), findsOneWidget);
    expect(_onstage(RestScreen), findsNothing);
    // 왼쪽 위 쉼터 아이콘은 없다 (탭 바가 대신)
    expect(find.byKey(const Key('walk-rest')), findsNothing);
    expect(c.read(walkFrontProvider), isTrue);
    expect(c.read(walkingActiveProvider), 1);
    // 쉼터 탭으로 가도 물감 길은 그대로
    await openTab(tester, 'rest');
    expect(c.read(paintTrailProvider).active, isTrue);
    expect(c.read(walkFrontProvider), isFalse);
    expect(c.read(walkingActiveProvider), 0);
    await end(tester, e);
  });

  testWidgets('걷기 탭은 안 걸을 때도 열리고(쉬는 중), 숨은 쉼터 탭은 그대로 남는다 (keepState)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    final c = await _pumpApp(tester, e);
    await openTab(tester, 'walk');
    await settle(tester, () => _onstage(WalkingScreen).evaluate().isNotEmpty, tries: 40);
    expect(c.read(paintTrailProvider).active, isFalse);
    expect(_onstage(WalkingScreen), findsOneWidget);
    expect(find.byType(RestScreen, skipOffstage: false), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('나 탭: 뒤로 버튼 없는 나의 정보, 노트·설정 줄은 나 탭 안에서 열린다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await openTab(tester, 'me');
    await settle(tester, () => _onstage(ProfileScreen).evaluate().isNotEmpty, tries: 40);
    expect(find.text('나의 정보'), findsOneWidget);
    expect(find.byTooltip('뒤로'), findsNothing);
    // 노트·설정 줄은 도장(T18, config ui.tabs.me 차례) 아래라 도장이 다 뜬 뒤 내려서 누른다
    await settle(tester, () => find.byKey(const ValueKey('me-stamps')).evaluate().isNotEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('me-note')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('me-note')));
    await transition(tester);
    expect(_onstage(NoteScreen), findsOneWidget);
    expect(_bar, findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await transition(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('me-settings')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('me-settings')));
    await transition(tester);
    expect(_onstage(SettingsScreen), findsOneWidget);
    expect(_bar, findsOneWidget);
    await end(tester, e);
  });

  testWidgets('나 탭 닉네임 연필: 검사를 거쳐 닉네임만 바꾼다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await openTab(tester, 'me');
    await settle(tester, () => find.byKey(const ValueKey('nickname-edit')).evaluate().isNotEmpty, tries: 40);
    await tester.tap(find.byKey(const ValueKey('nickname-edit')));
    await transition(tester);
    // 시트는 탭 바까지 덮는다 (앱 Navigator 위)
    await tester.enterText(find.byKey(const ValueKey('nickname-field')), '');
    await tester.pump();
    expect(find.textContaining('자로 지어 주세요'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('nickname-field')), '걷는화가');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nickname-save')));
    await settle(tester, () => find.byKey(const ValueKey('nickname-field')).evaluate().isEmpty, tries: 40);
    await transition(tester);
    final row = (await tester.runAsync(() => e.db.select(e.db.profile).getSingle()))!;
    expect(row.nickname, '걷는화가');
    await settle(tester, () => find.text('걷는화가').evaluate().isNotEmpty, tries: 40);
    expect(find.text('걷는화가'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('시스템 뒤로: 탭 안에서 한 단계, 탭 처음 화면이면 쉼터 탭으로', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    final c = await _pumpApp(tester, e);
    await openTab(tester, 'me');
    await tester.tap(find.byKey(const ValueKey('me-note')));
    await transition(tester);
    expect(_onstage(NoteScreen), findsOneWidget);
    // 뒤로는 비동기(maybePop)라 닫힘 애니메이션이 한 박자 늦게 시작한다: 닫힐 때까지 본다
    await tester.binding.handlePopRoute();
    await settle(tester, () => _onstage(NoteScreen).evaluate().isEmpty, tries: 40);
    await transition(tester);
    expect(_onstage(NoteScreen), findsNothing);
    expect(_onstage(ProfileScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await transition(tester);
    expect(c.read(currentTabProvider), HomeTab.rest);
    expect(_onstage(RestScreen), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('쉼터에서 정령을 길게 누르면 정령 꾸미기 (16장 11/19 ③)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    // 정령 riv(11.8MB)를 다 읽어야 정령이 눌린다
    await settle(tester, () => find.byType(rive.RiveWidget).evaluate().isNotEmpty, tries: 200);
    await tester.longPress(find.byKey(const ValueKey('spirit-long-press')));
    await transition(tester);
    await settle(tester, () => _onstage(DecorateScreen).evaluate().isNotEmpty, tries: 40);
    expect(_onstage(DecorateScreen), findsOneWidget);
    expect(_bar, findsOneWidget);
    await end(tester, e);
  });

  testWidgets('걷기 탭을 가로로 돌리면 탭 바를 숨기고, 쉼터 탭은 가로여도 탭 바가 있다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await openTab(tester, 'walk');
    phone(tester, width: 844, height: 390);
    await tester.pump();
    await tester.pump();
    expect(_bar, findsNothing);
    phone(tester);
    await tester.pump();
    expect(_bar, findsOneWidget);
    await end(tester, e);
  });

  group('걷기 탭 방명록 표지판·동행', () {
    testWidgets('방명록을 쓸 수 있으면 걷기 탭 아이콘에 점, 걷기 탭 길가에 표지판(화면 폭 78%), 누르면 방명록 쓰기',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.startSketch();
        await e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
              id: 'a:j1',
              kind: TicketKind.arrival,
              scope: 'kr001',
              openedUtc: t1.millisecondsSinceEpoch,
            ));
      });
      await _pumpApp(tester, e);
      await settle(tester, () => find.byKey(const ValueKey('tab-walk-dot')).evaluate().isNotEmpty, tries: 40);
      expect(find.byKey(const ValueKey('tab-walk-dot')), findsOneWidget);
      // 쉼터에는 표지판이 없다
      expect(find.byKey(const ValueKey('road-signpost')), findsNothing);
      await openTab(tester, 'walk');
      final sign = find.byKey(const ValueKey('road-signpost'));
      await settle(tester, () => sign.evaluate().isNotEmpty, tries: 40);
      expect(tester.getRect(sign).left, closeTo(390 * 0.78, 0.5));
      await tester.tap(sign);
      await transition(tester);
      expect(_onstage(GuestbookWriteScreen), findsOneWidget);
      expect(_bar, findsOneWidget);
      await end(tester, e);
    });
  });

  group('도착 → 걷기 기록 → 쉼터 탭 (16장 11/18 ⑤, config walk.arrivalFlow)', () {
    testWidgets('걷기 탭에서 도착하면 걷기 탭 안에 도착 화면, 닫으면 그 물감 길 걷기 기록, 닫으면 쉼터 탭', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.insertSketchJourney(0.3);
      });
      final c = await _pumpApp(tester, e);
      await startTrailNow(tester);
      expect(c.read(currentTabProvider), HomeTab.walk);
      // 분당 100보로 걷는다 (센서 6초마다 10보 + 같은 때의 health 기록): 0.3km를 넘으면 걷는 중 화면이 도착을
      // 미리 보고 동기화를 당기고, 동기화가 도착을 정해 물감 길을 arrived로 닫는다
      final start = c.read(paintTrailProvider).start!;
      e.source.records.add(walkRecord(start, 10, 100));
      var total = 1000;
      e.live.push(total);
      for (var i = 0; i < 120 && find.byType(ArrivalScreen).evaluate().isEmpty; i++) {
        e.now = e.now.add(const Duration(seconds: 6));
        total += 10;
        e.live.push(total);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      }
      await settle(tester, () => find.byType(ArrivalScreen).evaluate().isNotEmpty, tries: 40);
      await transition(tester);
      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(c.read(currentTabProvider), HomeTab.walk);
      expect(_bar, findsOneWidget);
      // 첫 물감 길은 도착으로 끝났다 (도착 뒤에도 걸어서 새 물감 길이 열렸을 수 있다)
      final rows = (await tester.runAsync(() => e.db.select(e.db.paintTrails).get()))!;
      expect(rows.first.endReason, PaintTrailEnd.arrived);
      await tester.tap(find.byTooltip('닫기'));
      await settle(tester, () => _onstage(WalkRecordScreen).evaluate().isNotEmpty, tries: 80);
      await transition(tester);
      expect(_onstage(WalkRecordScreen), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await settle(tester, () => _onstage(RestScreen).evaluate().isNotEmpty, tries: 40);
      expect(c.read(currentTabProvider), HomeTab.rest);
      expect(_onstage(WalkRecordScreen), findsNothing);
      // 걷기 탭은 처음 화면으로 돌아가 있다
      await openTab(tester, 'walk');
      expect(_onstage(WalkingScreen), findsOneWidget);
      await end(tester, e);
    });
  });
}
