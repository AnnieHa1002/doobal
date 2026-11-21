import 'package:doobal/domain/journey.dart' show Frame;
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/map/landmark_card.dart';
import 'package:doobal/ui/map/map_painter.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

// 연출 ① 도착 핀·카드 그림 칸 찍힘 (T19, 16장 11/20 Q008, config ui.motion.arrivalPin, 캔버스 4-1 메모):
// 도착 화면의 ‘다음 목적지’로 연 지도는 도착한 명소를 고르고, 그 핀이 24pt 위에서 0.25초(떨어질수록 빠르게) 떨어져
// 0.12초 동안 1 → 1.15 → 1배로 튄 뒤, 0.1초 뒤 카드 그림 칸이 1.3배에서 0.2초에 1배로 찍힌다(액자 등급 색).
// 움직임 줄이기면 끝 상태만. 쉼터의 지도 버튼으로 열면 연출 없음

final _a = rules.motion.arrivalPin!;
final _day = DateTime.utc(2026, 11, 18, 3);

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _openMap(WidgetTester tester, UiEnv e, {String? arrivedId}) => openOnTop(
      tester,
      e,
      MapScreen(arrivedId: arrivedId),
      ready: () => find.byType(InteractiveViewer).evaluate().isNotEmpty,
    );

PinLift? _lift(WidgetTester tester) => (tester
        .widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is MapPainter))
        .painter! as MapPainter)
    .lift;

Finder _key(String k) => find.byKey(ValueKey(k));

double _stampScale(WidgetTester tester) =>
    tester.widget<Transform>(_key('painting-slot-stamp')).transform.getMaxScaleOnAxis();

Duration _ms(int ms) => Duration(milliseconds: ms);

/// 연출이 시작된 첫 틱 뒤 [ms]밀리초까지 (시작 기준)
Future<void> _at(WidgetTester tester, int ms, {required int from}) => tester.pump(_ms(ms - from));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('도착 뒤 지도: 도착한 명소를 고르고 핀이 떨어져 튄 뒤 그림 칸이 찍힌다 (0.67초)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day, frame: Frame.silver));
    await _openMap(tester, e, arrivedId: 'kr001');
    // 도착한 명소 카드가 뜨고, 그림 칸은 찍히기 전이라 빈 칸
    expect(find.descendant(of: find.byType(LandmarkCard), matching: find.text(byId['kr001']!.name)), findsOneWidget);
    expect(_key('painting-slot-empty'), findsOneWidget);
    expect(_lift(tester), (id: 'kr001', liftPt: 24.0, scale: 1.0));

    await tester.pump();
    await _at(tester, 125, from: 0);
    expect(_lift(tester)!.liftPt, closeTo(24 * 0.75, 0.01));
    expect(_lift(tester)!.scale, 1);
    // 꽂힌 뒤 튐: 가운데(0.31초)가 가장 큼
    await _at(tester, 310, from: 125);
    expect(_lift(tester)!.liftPt, 0);
    expect(_lift(tester)!.scale, closeTo(_a.bounceScale, 0.01));
    // 다 꽂히면 핀은 보통 그림으로 (지도를 다시 그리지 않는다), 칸은 아직 빈 칸 (0.47초에 찍힘)
    await _at(tester, 400, from: 310);
    expect(_lift(tester), isNull);
    expect(_key('painting-slot-empty'), findsOneWidget);
    expect(_key('painting-slot-filled'), findsNothing);
    // 찍히기 시작: 1.3배에서 줄어든다, 액자 등급(은) 색 칸
    await _at(tester, 480, from: 400);
    expect(_key('painting-slot-filled'), findsOneWidget);
    expect(_stampScale(tester), closeTo(1.3 - 0.3 * (0.01 / 0.2), 0.01));
    final slot = tester.widget<PaintingSlot>(find.byType(PaintingSlot));
    expect(slot.frame, Frame.silver);
    await _at(tester, 570, from: 480);
    expect(_stampScale(tester), closeTo(1.15, 0.01));
    await _at(tester, 700, from: 570);
    expect(_stampScale(tester), 1);
    expect(_lift(tester), isNull);
    // 끝난 뒤 받은 칸은 누를 수 있다 (크게 보기)
    expect(tester.widget<PaintingSlot>(find.byType(PaintingSlot)).onTap, isNotNull);
    await end(tester, e);
  });

  testWidgets('걸어서 도착한 뒤: 지금 서 있는 명소 카드에는 남은 거리 줄이 없고, 다른 명소를 고르면 있다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.arriveAtGyeongbok);
    await _openMap(tester, e, arrivedId: 'kr001');
    await settle(tester, () => false, tries: 6);
    expect(find.descendant(of: find.byType(LandmarkCard), matching: find.text(byId['kr001']!.name)), findsOneWidget);
    expect(find.textContaining('남은 거리'), findsNothing);
    await tester.pump(_ms(700));
    final other = byId['kr002']!;
    await tester.enterText(find.byType(TextField), other.name);
    await tester.pump();
    await tester.tap(_key('result-kr002'));
    await transition(tester);
    await settle(tester, () => find.textContaining('남은 거리').evaluate().isNotEmpty);
    expect(find.descendant(of: find.byType(LandmarkCard), matching: find.text(other.name)), findsOneWidget);
    expect(find.textContaining('남은 거리'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('움직임 줄이기면 끝 상태만: 핀은 꽂힌 채, 그림 칸은 처음부터 찍힌 채', (tester) async {
    _reduceMotion(tester);
    final e = UiEnv();
    await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day));
    await _openMap(tester, e, arrivedId: 'kr001');
    expect(find.descendant(of: find.byType(LandmarkCard), matching: find.text(byId['kr001']!.name)), findsOneWidget);
    expect(_lift(tester), isNull);
    expect(_key('painting-slot-filled'), findsOneWidget);
    expect(_stampScale(tester), 1);
    await tester.pump();
    await tester.pump(_ms(200));
    expect(_lift(tester), isNull);
    expect(_stampScale(tester), 1);
    await end(tester, e);
  });

  testWidgets('쉼터 지도 버튼처럼 그냥 열면 연출 없음 (고른 명소도 없음)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day));
    await _openMap(tester, e);
    expect(_lift(tester), isNull);
    expect(find.byType(LandmarkCard), findsNothing);
    await end(tester, e);
  });

  testWidgets('명소가 아닌 도착(내 동네 스케치)이나 아직 안 간 명소면 연출 없음', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _openMap(tester, e, arrivedId: sketchId);
    expect(_lift(tester), isNull);
    expect(find.byType(LandmarkCard), findsNothing);
    await end(tester, e);

    final e2 = UiEnv();
    await e2.seed(tester);
    await _openMap(tester, e2, arrivedId: 'kr001');
    expect(_lift(tester), isNull);
    expect(find.byType(LandmarkCard), findsNothing);
    await end(tester, e2);
  });

  testWidgets('도착 화면의 ‘다음 목적지’는 도착한 명소로 지도를 연다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day));
    await openOnTop(tester, e, const ArrivalScreen(journeyId: 'j1'),
        ready: () => find.text('다음 목적지').evaluate().isNotEmpty);
    await tester.tap(find.text('다음 목적지'));
    await transition(tester);
    await settle(tester, () => find.byType(InteractiveViewer).evaluate().isNotEmpty);
    expect(tester.widget<MapScreen>(find.byType(MapScreen)).arrivedId, 'kr001');
    expect(find.descendant(of: find.byType(LandmarkCard), matching: find.text(byId['kr001']!.name)), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(_lift(tester), isNull);
    expect(_key('painting-slot-filled'), findsOneWidget);
    await end(tester, e);
  });
}
