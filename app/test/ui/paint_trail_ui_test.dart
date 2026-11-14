import 'package:doobal/app/paint_trail_controller.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/walking/paint_drop_layer.dart';
import 'package:doobal/ui/walking/paint_trail_host.dart';
import 'package:doobal/ui/walking/walking_hud.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 물감 길 화면 (16장 11/13, M2~M6 명세 v0.17 T①·②·⑦, 캔버스 2-1·2-2·3-1):
// 앱을 연 채 걸으면 저절로 걷는 중, 걸음이 5분 멈추면 저절로 쉼터 + 토스트, 쉼터 아이콘, 상시 알림 N0,
// 시트·꾸미기 중에는 기다림, 물감 방울, 첫날 말풍선

/// 앱을 띄우고 쉼터·물감 길 판정이 시작될 때까지 기다린다 (앞 실행의 물감 길 닫기 → 판정 시작)
Future<void> _pumpApp(WidgetTester tester, UiEnv e) async {
  await pumpDoobal(tester, e, const DoobalApp());
  await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty, tries: 80);
  await settle(tester, () => false, tries: 8);
}

/// 시계를 [sec]초 옮기고 센서가 누적 걸음 [total]을 준다
Future<void> _sensor(WidgetTester tester, UiEnv e, int sec, int total) async {
  e.now = e.now.add(Duration(seconds: sec));
  e.live.push(total);
  await tester.pump(const Duration(milliseconds: 50));
}

/// 쉼터에서 센서 값을 넣어 물감 길을 연다: 기준 [base] 뒤 30초에 10보 → 열림, 걷는 중으로 넘어가길 기다린다
Future<void> _startTrail(WidgetTester tester, UiEnv e, {int base = 50000}) async {
  await _sensor(tester, e, 0, base);
  await _sensor(tester, e, 30, base + 10);
  await settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 80);
  await transition(tester);
}

/// 가짜 시간을 [sec]초 보낸다 (물감 길 판정은 paintTrailTick마다). 시계도 같이 옮기고 DB 일을 기다린다
Future<void> _elapse(WidgetTester tester, UiEnv e, int sec) async {
  for (var i = 0; i < sec; i += 5) {
    e.now = e.now.add(const Duration(seconds: 5));
    await tester.pump(paintTrailTick);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  await tester.pump();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('쉼터에는 출발하기가 없고, 첫날은 아래 말풍선 ‘걸으면 출발해요’ (캔버스 2-1)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    expect(find.text('출발하기'), findsNothing);
    expect(find.byKey(const ValueKey('first-sketch-bubble')), findsOneWidget);
    expect(find.text('걸으면 출발해요'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('여정이 없으면 지도에 알림 점', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _pumpApp(tester, e);
    expect(find.byKey(const ValueKey('map-dot')), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('센서 60초에 9보면 그대로, 10보면 저절로 걷는 중 (물감 길이 열리고 상시 알림이 켜진다)',
      (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);

    await _sensor(tester, e, 0, 50000);
    await _sensor(tester, e, 30, 50009);
    await settle(tester, () => false, tries: 10);
    expect(find.byType(WalkingScreen), findsNothing);
    expect(await tester.runAsync(() => e.db.select(e.db.paintTrails).get()), isEmpty);

    // 9보를 넣은 뒤 61초가 지나 처음 걸음은 창 밖: 새로 10보
    await _sensor(tester, e, 61, 50019);
    await settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 80);
    expect(find.byType(WalkingScreen), findsOneWidget);
    final rows = (await tester.runAsync(() => e.db.select(e.db.paintTrails).get()))!;
    expect(rows, hasLength(1));
    expect(rows.single.endUtc, isNull);
    expect(e.walkNotice.running, isTrue);
    // 걷는 중에는 ‘걷기 마치기’·×1.3 딱지가 없고 왼쪽 위에 쉼터 아이콘
    await transition(tester);
    expect(find.text('걷기 마치기'), findsNothing);
    expect(find.textContaining('×'), findsNothing);
    expect(find.byKey(const Key('walk-rest')), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('쉼터 아이콘은 화면만 쉼터로: 물감 길은 이어지고 상태 알약 ‘걷는 중’을 누르면 다시 걷는 중',
      (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await _startTrail(tester, e);

    await tester.tap(find.byKey(const Key('walk-rest')));
    await transition(tester);
    expect(find.byType(WalkingScreen), findsNothing);
    expect(find.textContaining('걷는 중 ·'), findsOneWidget);
    expect(find.byKey(const ValueKey('rest-walking-pill')), findsOneWidget);
    // 물감 길은 그대로 열려 있다
    final c = ProviderScope.containerOf(tester.element(find.byType(RestScreen)));
    expect(c.read(paintTrailProvider).active, isTrue);

    await tester.tap(find.byKey(const ValueKey('rest-walking-pill')));
    await transition(tester);
    expect(find.byType(WalkingScreen), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('걸음이 5분 멈추면 저절로 쉼터 + `물감 길 n km를 그렸어요`, 물감 길은 idle로 닫히고 알림을 끈다',
      (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await _startTrail(tester, e);
    // 30초마다 50보씩 두 번 더 (분당 100보 걷기: 모두 110보 × 0.7 = 77m)
    await _sensor(tester, e, 30, 50060);
    await _sensor(tester, e, 30, 50110);
    final last = e.now;
    // 마지막 걸음 분의 끝 + 5분이 지나야 끝난다 (그 전에는 그대로)
    await _elapse(tester, e, 4 * 60);
    expect(find.byType(WalkingScreen), findsOneWidget);
    // 5초씩 보내며 끝나길 기다린다 (토스트가 떠 있는 동안 본다)
    for (var i = 0; i < 40 && find.byType(WalkingScreen).evaluate().isNotEmpty; i++) {
      await _elapse(tester, e, 5);
      await settle(tester, () => false, tries: 2);
    }
    await transition(tester);
    expect(find.byType(WalkingScreen), findsNothing);
    expect(find.byType(RestScreen), findsOneWidget);
    expect(paintTrailEndedToast(0.077), '물감 길 0.1km를 그렸어요');
    expect(find.text('물감 길 0.1km를 그렸어요'), findsOneWidget);

    final row = (await tester.runAsync(() => e.db.select(e.db.paintTrails).getSingle()))!;
    expect(row.endReason, PaintTrailEnd.idle);
    final lastMinuteEnd = minuteStart(last).add(const Duration(minutes: 1));
    expect(row.endUtc, lastMinuteEnd.millisecondsSinceEpoch);
    expect(e.walkNotice.running, isFalse);
    expect(e.walkNotice.stops, greaterThanOrEqualTo(1));
    await end(tester, e);
  });

  testWidgets('꾸미기 중에 물감 길이 열리면 기다렸다가 꾸미기를 닫으면 걷는 중으로', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const DecorateScreen()));
    await transition(tester);
    await settle(tester, () => false, tries: 6);

    await _sensor(tester, e, 0, 50000);
    await _sensor(tester, e, 30, 50010);
    await settle(tester, () => false, tries: 20);
    expect(find.byType(DecorateScreen), findsOneWidget);
    expect(find.byType(WalkingScreen), findsNothing);

    nav.pop();
    await transition(tester);
    await settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 80);
    expect(find.byType(WalkingScreen), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('시트가 떠 있으면 닫힐 때까지 기다린다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    final context = tester.element(find.byType(RestScreen));
    showModalBottomSheet<void>(context: context, builder: (_) => const Text('시트'));
    await transition(tester);

    await _sensor(tester, e, 0, 50000);
    await _sensor(tester, e, 30, 50010);
    await settle(tester, () => false, tries: 20);
    expect(find.text('시트'), findsOneWidget);
    expect(find.byType(WalkingScreen), findsNothing);

    Navigator.of(tester.element(find.text('시트'))).pop();
    await settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 80);
    expect(find.byType(WalkingScreen), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('물감 방울: 땅 위 층이 있고, 펼친 알약에 ‘물감 길 n km · 물감 방울 n개’', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await _startTrail(tester, e);
    expect(find.byType(PaintDropLayer), findsOneWidget);
    // 분당 100보로 2분 더: 모두 210보 = 147m → 방울 1개
    await _sensor(tester, e, 30, 50060);
    await _sensor(tester, e, 30, 50110);
    await _sensor(tester, e, 30, 50160);
    await _sensor(tester, e, 30, 50210);
    final c = ProviderScope.containerOf(tester.element(find.byType(WalkingScreen)));
    expect(c.read(paintTrailProvider.notifier).live!.distanceM, closeTo(147, 1e-9));
    // 보이는 거리는 걷는 속도(분당 100보 = 1.17m/s)로 따라온다: 2분이면 다 온다
    for (var i = 0; i < 130; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      tester.widget<WalkingHud>(find.byType(WalkingHud)).shownM,
      closeTo(147, 0.5),
    );
    await tester.tap(find.byKey(const Key('walk-pill')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('물감 방울 1개'), findsOneWidget);
    await end(tester, e);
  });
}
