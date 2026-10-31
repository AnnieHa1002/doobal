import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/debug/debug_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

final _picker = find.byKey(const ValueKey('distance-scale'));
final _note = find.byKey(const ValueKey('distance-scale-note'));
final _badge = find.byKey(const ValueKey('debug-scale-badge'));

ProviderContainer _container(WidgetTester tester, Type screen) =>
    ProviderScope.containerOf(tester.element(find.byType(screen)));

/// 지금 동기화 서비스가 쓰는 배수 (provider가 만든 SyncService)
Future<double> _serviceScale(WidgetTester tester, ProviderContainer container) async =>
    (await tester.runAsync(() => container.read(syncServiceProvider.future)))!.distanceScale;

/// 지금 고른 배수 (SegmentedButton의 선택)
Set<double> _selected(WidgetTester tester) =>
    tester.widget<SegmentedButton<double>>(_picker).selected;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('거리 배수 표시 글', () {
    expect(distanceScaleBadge(10), '거리 ×10');
    expect(distanceScaleBadge(100), '거리 ×100');
    expect(debugDistanceScales, [1.0, 10.0, 100.0]);
  });

  group('개발자 화면의 거리 배수', () {
    Future<void> openDebug(WidgetTester tester, UiEnv e) =>
        openOnTop(tester, e, const DebugScreen(),
            height: 1200, ready: () => _picker.evaluate().isNotEmpty);

    testWidgets('1×(기본)·10×·100×를 고르면 provider 값이 바뀌고, 동기화 서비스도 그 배수로 새로 만든다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openDebug(tester, e);

      final container = _container(tester, DebugScreen);
      expect(find.text('거리 배수 (테스트용, 다시 켜면 1×)'), findsOneWidget);
      for (final label in ['1×', '10×', '100×']) {
        expect(find.descendant(of: _picker, matching: find.text(label)), findsOneWidget);
      }
      // 처음은 1×, 안내 줄도 없다
      expect(container.read(debugDistanceScaleProvider), 1.0);
      expect(_selected(tester), {1.0});
      expect(_note, findsNothing);
      expect(await _serviceScale(tester, container), 1);

      await tester.tap(find.text('10×'));
      await tester.pump();
      expect(container.read(debugDistanceScaleProvider), 10.0);
      expect(_selected(tester), {10.0});
      expect(find.text('거리 ×10: 걸은 거리에 곱해서 빨리 도착해요 (경비·하루 요약은 그대로)'), findsOneWidget);
      expect(await _serviceScale(tester, container), 10);

      await tester.tap(find.text('100×'));
      await tester.pump();
      expect(container.read(debugDistanceScaleProvider), 100.0);
      expect(_selected(tester), {100.0});
      expect(find.textContaining('거리 ×100:'), findsOneWidget);
      expect(await _serviceScale(tester, container), 100);

      await tester.tap(find.text('1×'));
      await tester.pump();
      expect(container.read(debugDistanceScaleProvider), 1.0);
      expect(_selected(tester), {1.0});
      expect(_note, findsNothing);
      expect(await _serviceScale(tester, container), 1);
      await end(tester, e);
    });

    testWidgets('메모리에만 둔다: 앱을 다시 켜면(새 ProviderScope) 1×', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openDebug(tester, e);
      await tester.tap(find.text('10×'));
      await tester.pump();
      expect(_container(tester, DebugScreen).read(debugDistanceScaleProvider), 10.0);

      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      expect(restarted.read(debugDistanceScaleProvider), 1.0);
      await end(tester, e);
    });
  });

  group('첫 여정(내 동네 스케치) 중 개발자 화면의 멈추기·출발', () {
    // 서비스가 막으면(StateError) 화면은 아무 일도 안 하고 그 글을 한 줄로 보여 준다
    const lockedLine = '여정 실패: Bad state: $sketchLockedNote';

    Future<List<JourneyRow>> journeys(WidgetTester tester, UiEnv e) async =>
        (await tester.runAsync(() => e.db.select(e.db.journeys).get()))!;

    testWidgets('멈추기: 서비스의 안내가 화면에 나오고 여정은 그대로다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await openOnTop(tester, e, const DebugScreen(),
          height: 1200, ready: () => _picker.evaluate().isNotEmpty);

      await tester.tap(find.text('멈추기'));
      await settle(tester, () => find.text(lockedLine).evaluate().isNotEmpty);
      expect(find.text(lockedLine), findsOneWidget);
      final rows = await journeys(tester, e);
      expect((rows.single.destId, rows.single.status), (sketchId, JourneyStatus.active));
      // 막힌 뒤에도 버튼은 다시 눌린다 (눌린 채로 멈춰 있지 않는다)
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '멈추기')).onPressed,
          isNotNull);
      await end(tester, e);
    });

    testWidgets('지금 자리에서 출발: 서비스의 안내가 화면에 나오고 여정은 그대로다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await openOnTop(tester, e, const DebugScreen(),
          height: 1200, ready: () => _picker.evaluate().isNotEmpty);

      await tester.tap(find.text('목적지'));
      await tester.pump();
      await tester.tap(find.text('kr001 경복궁').last);
      await tester.pump();
      await tester.tap(find.text('지금 자리에서 출발'));
      await settle(tester, () => find.text(lockedLine).evaluate().isNotEmpty);
      expect(find.text(lockedLine), findsOneWidget);
      final rows = await journeys(tester, e);
      expect((rows.single.destId, rows.single.status), (sketchId, JourneyStatus.active));
      await end(tester, e);
    });
  });

  group('쉼터의 거리 배수 표시', () {
    testWidgets('1×가 아닐 때만 상태 알약 아래에 "거리 ×10"이 보인다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      final container = _container(tester, DoobalApp);

      expect(_badge, findsNothing);
      expect(find.textContaining('거리 ×'), findsNothing);

      container.read(debugDistanceScaleProvider.notifier).set(10);
      await settle(tester, () => _badge.evaluate().isNotEmpty);
      expect(find.text('거리 ×10'), findsOneWidget);
      // 상태 알약 바로 아래, 가운데
      final pill = tester.getRect(find.textContaining('쉬는 중'));
      final badge = tester.getRect(_badge);
      expect(badge.top, greaterThan(pill.bottom - 4));
      expect(badge.center.dx, closeTo(195, 1));

      container.read(debugDistanceScaleProvider.notifier).set(100);
      await settle(tester, () => find.text('거리 ×100').evaluate().isNotEmpty);
      expect(find.text('거리 ×100'), findsOneWidget);

      container.read(debugDistanceScaleProvider.notifier).set(1);
      await settle(tester, () => _badge.evaluate().isEmpty);
      expect(_badge, findsNothing);
      await end(tester, e);
    });
  });
}
