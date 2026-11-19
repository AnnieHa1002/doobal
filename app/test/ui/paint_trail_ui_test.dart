import 'package:doobal/app/paint_trail_controller.dart';
import 'package:doobal/app/providers.dart' show appSuspendsWhenHiddenProvider;
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_screen.dart';
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

import '../domain/helpers.dart' show testHome;
import 'ui_env.dart';

// 물감 길 화면 (16장 11/13, M2~M6 명세 v0.17 T①·②·⑦, 캔버스 2-1·2-2·3-1):
// 앱을 연 채 걸으면 저절로 걷는 중, 걸음이 5분 멈추면 저절로 쉼터 + 토스트, 쉼터 아이콘, 상시 알림 N0,
// 시트·꾸미기 중에는 기다림, 물감 방울, 첫날 말풍선, iOS 화면 꺼짐 메우기(16장 11/14),
// 쉼터↔걷는 중 6규칙(16장 11/16, 8장 3번, 캔버스 2-2 ‘걷는 중 · 물감 길 n km ›’)

/// 앱을 띄우고 쉼터·물감 길 판정이 시작될 때까지 기다린다 (앞 실행의 물감 길 닫기 → 판정 시작).
/// [suspends]면 iOS처럼 앱이 뒤로 가면 멈추는 기기로 돈다 (화면 꺼짐 메우기)
Future<void> _pumpApp(WidgetTester tester, UiEnv e, {bool suspends = false}) async {
  await pumpDoobal(tester, e, const DoobalApp(),
      extra: [if (suspends) appSuspendsWhenHiddenProvider.overrideWithValue(true)]);
  await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty, tries: 80);
  await settle(tester, () => false, tries: 8);
}

/// 시계를 [sec]초 옮기고 센서가 누적 걸음 [total]을 준다
Future<void> _sensor(WidgetTester tester, UiEnv e, int sec, int total) async {
  e.now = e.now.add(Duration(seconds: sec));
  e.live.push(total);
  await tester.pump(const Duration(milliseconds: 50));
}

/// 분당 100보로 [from] 뒤 [steps]보를 센서에 넣는다: 6초마다 10보 (분당 걸음 10초 창에서 걷기로 보이게, 16장 11/19)
Future<void> _walk100(WidgetTester tester, UiEnv e, int from, int steps) async {
  for (var n = 10; n <= steps; n += 10) {
    await _sensor(tester, e, 6, from + n);
  }
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

/// 앱을 뒤로 보낸다 (화면 끔)
void _hide(WidgetTester tester) {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

/// 앱을 다시 앞으로 (화면 켬)
void _show(WidgetTester tester) {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

/// 서울에서 60km 넘게 떨어진 육지 명소 (이정표가 쌓이는 보통 여정)
String _farDest(UiEnv e) => e.appLandmarks
    .firstWhere((l) =>
        l.island == Island.mainland &&
        buildRoute(testHome, l.latLng, e.appRules).totalEffectiveKm > 60)
    .id;

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

  testWidgets('감지 센서(16장 11/19): 걸음마다 오는 감지 걸음 10개(약 5초)로 걷는 중이 열리고, '
      '걸음 숫자는 카운터보다 먼저 오르며 카운터 값이 와도 뒤로 가지 않는다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);

    Future<void> detect(int n) async {
      for (var i = 0; i < n; i++) {
        e.now = e.now.add(const Duration(milliseconds: 500));
        e.live.detect();
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // 카운터는 아직 아무 값도 안 줬다 (폰은 처음 10걸음쯤 뒤에야 첫 값)
    await detect(9);
    await settle(tester, () => false, tries: 10);
    expect(find.byType(WalkingScreen), findsNothing);
    await detect(1);
    await settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 80);
    final rows = (await tester.runAsync(() => e.db.select(e.db.paintTrails).get()))!;
    expect(rows, hasLength(1));
    expect(e.walkNotice.running, isTrue);
    await transition(tester);
    int shown() => tester.widget<WalkingHud>(find.byType(WalkingHud)).shownSteps;
    expect(shown(), 10);

    await detect(6);
    await tester.pump(const Duration(seconds: 2));
    expect(shown(), 16);
    // 카운터 첫 값은 지금까지 감지한 걸음을 담았다고 본다 (센 걸음 16)
    await _sensor(tester, e, 0, 50000);
    final trail = ProviderScope.containerOf(tester.element(find.byType(WalkingScreen)))
        .read(paintTrailProvider.notifier);
    expect(trail.live!.steps, 16);
    // 4걸음 더 감지한 뒤 카운터가 2보만 담아 보내도 숫자는 뒤로 가지 않는다 (센 걸음은 카운터 값)
    await detect(4);
    await tester.pump(const Duration(seconds: 2));
    expect(shown(), 20);
    await _sensor(tester, e, 0, 50002);
    await tester.pump(const Duration(seconds: 1));
    expect(trail.live!.steps, 18);
    expect(shown(), 20);
    // 카운터가 더 세면 그 값으로 오른다
    await _sensor(tester, e, 1, 50007);
    await tester.pump(const Duration(seconds: 2));
    expect(shown(), 23);
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
    expect(find.text('걷는 중'), findsOneWidget);
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

  group('쉼터↔걷는 중 6규칙 (16장 11/16)', () {
    Finder pill() => find.byKey(const ValueKey('rest-walking-pill'));

    /// 쉼터 위에 [screen]을 연다
    Future<void> push(WidgetTester tester, Widget screen) async {
      tester.state<NavigatorState>(find.byType(Navigator).first)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
      await transition(tester);
      await settle(tester, () => false, tries: 6);
    }

    void pop(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first).pop();

    testWidgets('④ 쉼터 아이콘으로 오면 그 물감 길 동안 저절로 돌아가지 않는다 (걸어도, 쉼터에서 연 화면을 닫아도). '
        '위 가운데 ‘걷는 중 · 물감 길 n km ›’(지금 물감 색 점, 44pt)를 누르면 걷는 중', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await _pumpApp(tester, e);
      await _startTrail(tester, e);
      await tester.tap(find.byKey(const Key('walk-rest')));
      await transition(tester);
      expect(find.byType(WalkingScreen), findsNothing);

      // 쉼터에서 계속 걸어도 그대로, 알약 거리는 이번 물감 길 거리
      for (var i = 1; i <= 6; i++) {
        await _sensor(tester, e, 30, 50010 + i * 50);
        await _elapse(tester, e, 5);
      }
      await settle(tester, () => false, tries: 10);
      expect(find.byType(WalkingScreen), findsNothing);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(pill(), findsOneWidget);
      expect(tester.getSize(pill()).height, greaterThanOrEqualTo(44));
      expect(find.descendant(of: pill(), matching: find.text('걷는 중')), findsOneWidget);
      final km = tester.widget<Text>(find.byKey(const ValueKey('rest-walking-km'))).data!;
      expect(km, matches(RegExp(r'^· 물감 길 \d+\.\dkm$')));
      expect(km, isNot('· 물감 길 0.0km'));
      // 점 = 지금 물감 색 (고른 색이 없으니 기본 물감)
      final dot = tester.widget<Container>(find.byKey(const ValueKey('rest-walking-dot')));
      expect((dot.decoration as BoxDecoration).color, Color(e.appRules.paintColor.defaultHex));
      // 물감 길이 열려 있으니 ‘쉬는 중’은 아니다
      expect(find.textContaining('쉬는 중'), findsNothing);

      // 쉼터에서 다른 화면(화집)을 열었다 닫아도 쉼터
      await push(tester, const AlbumScreen());
      pop(tester);
      await transition(tester);
      await settle(tester, () => false, tries: 10);
      expect(find.byType(WalkingScreen), findsNothing);

      await tester.tap(pill());
      await transition(tester);
      expect(find.byType(WalkingScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('③ 다른 화면(화집)에서 걷기 시작하면 그 화면 그대로, 닫으면 걷는 중', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await _pumpApp(tester, e);
      await push(tester, const AlbumScreen());

      await _sensor(tester, e, 0, 50000);
      await _sensor(tester, e, 30, 50010);
      await settle(tester, () => false, tries: 20);
      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(find.byType(WalkingScreen), findsNothing);
      final c = ProviderScope.containerOf(tester.element(find.byType(AlbumScreen)));
      expect(c.read(paintTrailProvider).active, isTrue);

      pop(tester);
      await transition(tester);
      await settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 80);
      expect(find.byType(WalkingScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('① 앱을 다시 열어도 쉼터 아이콘으로 떠난 물감 길 동안은 쉼터 (④가 먼저, 16장 11/17). '
        '새 물감 길이 열리면 잊고 저절로 걷는 중', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await _pumpApp(tester, e);
      await _startTrail(tester, e);
      await tester.tap(find.byKey(const Key('walk-rest')));
      await transition(tester);
      expect(find.byType(WalkingScreen), findsNothing);

      _hide(tester);
      await tester.pump(const Duration(milliseconds: 100));
      e.now = e.now.add(const Duration(seconds: 20));
      _show(tester);
      await settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 20);
      expect(find.byType(WalkingScreen), findsNothing);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(pill(), findsOneWidget);
      final c = ProviderScope.containerOf(tester.element(find.byType(RestScreen)));
      final first = c.read(paintTrailProvider).id;
      expect(c.read(paintTrailProvider).active, isTrue);

      // 다시 켠 뒤 걸어도 그 물감 길 동안은 쉼터
      await _sensor(tester, e, 30, 50060);
      await _sensor(tester, e, 30, 50110);
      await settle(tester, () => false, tries: 10);
      expect(find.byType(WalkingScreen), findsNothing);
      expect(c.read(paintTrailProvider).id, first);

      // 걸음이 멈춰 물감 길이 닫힌 뒤 새 물감 길이 열리면 잊는다
      for (var i = 0; i < 80 && c.read(paintTrailProvider).active; i++) {
        await _elapse(tester, e, 5);
      }
      expect(c.read(paintTrailProvider).active, isFalse);
      await settle(tester, () => false, tries: 4);
      await _startTrail(tester, e, base: 50200);
      expect(c.read(paintTrailProvider).id, isNot(first));
      expect(find.byType(WalkingScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('⑤ 물감 길이 끝날 때 다른 화면(화집)이면 화면은 그대로, 토스트만. 그 뒤 닫으면 쉼터 ‘쉬는 중’', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await _pumpApp(tester, e);
      await _startTrail(tester, e);
      await tester.tap(find.byKey(const Key('walk-rest')));
      await transition(tester);
      await push(tester, const AlbumScreen());

      for (var i = 0; i < 80 && (ProviderScope.containerOf(tester.element(find.byType(AlbumScreen)))
              .read(paintTrailProvider)
              .active); i++) {
        await _elapse(tester, e, 5);
      }
      await settle(tester, () => false, tries: 4);
      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(find.textContaining('를 그렸어요'), findsOneWidget);

      pop(tester);
      await transition(tester);
      await settle(tester, () => false, tries: 6);
      expect(find.byType(WalkingScreen), findsNothing);
      expect(pill(), findsNothing);
      expect(find.textContaining('쉬는 중'), findsOneWidget);
      await end(tester, e);
    });
  });

  testWidgets('물감 방울: 땅 위 층이 있고, 펼친 알약에 ‘물감 길 n km · 물감 방울 n개’', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await _startTrail(tester, e);
    expect(find.byType(PaintDropLayer), findsOneWidget);
    // 분당 100보로 2분 더: 모두 210보 = 147m → 방울 1개
    await _walk100(tester, e, 50010, 200);
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

  group('iOS 화면 꺼짐 메우기 (16장 11/14, config paintTrail.iosBackfillPaint, M1 v0.6)', () {
    /// 먼 명소로 가는 중 10:00에 물감 길을 열고 10:01:30까지 110보(77m)를 센 뒤 화면을 끈 환경
    Future<UiEnv> walkThenHide(WidgetTester tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.svc.startJourney(_farDest(e), t1, useFund: false));
      await _pumpApp(tester, e, suspends: true);
      await _startTrail(tester, e);
      await _walk100(tester, e, 50010, 100);
      expect(e.now, t1.add(const Duration(minutes: 1, seconds: 30)));
      _hide(tester);
      await tester.pump();
      return e;
    }

    Future<double> eventM(UiEnv e, WidgetTester tester) async =>
        (await tester.runAsync(() => e.db.select(e.db.journeys).get()))!
            .firstWhere((j) => j.arrivedUtc == null && j.endedUtc == null)
            .eventM;

    testWidgets('화면 끈 20분 1,500보: 꺼진 동안은 끝내지 않고, 다시 켜면 health로 메워 같은 물감 길에 1.05km',
        (tester) async {
      final e = await walkThenHide(tester);
      // 10:02~10:21 분당 75보 (센서 값은 오지 않는다)
      e.source.records.add(walkRecord(t1.add(const Duration(minutes: 2)), 20, 75));
      e.now = t1.add(const Duration(minutes: 23));
      await _elapse(tester, e, 30);
      // 마지막 센서 걸음(10:01:30)에서 5분이 훨씬 지났어도 숨어 있는 동안은 판정하지 않는다
      final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));
      expect(c.read(paintTrailProvider).active, isTrue);

      _show(tester);
      await settle(tester, () => false, tries: 10);
      await _elapse(tester, e, 60);
      // 마지막 health 걸음 분 10:21 → 10:22 + 5분(10:27)까지는 이어진다
      expect(c.read(paintTrailProvider).active, isTrue);
      expect(find.byType(WalkingScreen), findsOneWidget);
      // 이정표 = 앞에서 센 77m + 메운 1,050m
      expect(await eventM(e, tester), closeTo(77 + 1050, 1e-6));

      for (var i = 0; i < 40 && c.read(paintTrailProvider).active; i++) {
        await _elapse(tester, e, 5);
      }
      await settle(tester, () => false, tries: 4);
      await transition(tester);
      final row = (await tester.runAsync(() => e.db.select(e.db.paintTrails).getSingle()))!;
      expect((row.endUtc, row.endReason),
          (t1.add(const Duration(minutes: 22)).millisecondsSinceEpoch, PaintTrailEnd.idle));
      expect(find.text('물감 길 1.1km를 그렸어요'), findsOneWidget);
      final day = (await tester.runAsync(() => e.db.select(e.db.daySummaries).get()))!
          .firstWhere((d) => d.trailM > 0);
      expect(day.trailM, closeTo(1050, 1e-6));
      await end(tester, e);
    });

    testWidgets('꺼진 동안 6분 쉬었으면 거기서 끝난다: 그 뒤 걸음은 물감 길이 아니고, 다시 켠 뒤 60초는 기다린다',
        (tester) async {
      final e = await walkThenHide(tester);
      // 10:02~10:06 걷고 10:07~10:12 쉬고 10:13~10:17 걷는다 (분당 75보)
      e.source.records
        ..add(walkRecord(t1.add(const Duration(minutes: 2)), 5, 75))
        ..add(walkRecord(t1.add(const Duration(minutes: 13)), 5, 75));
      e.now = t1.add(const Duration(minutes: 20));
      _show(tester);
      await settle(tester, () => false, tries: 10);
      // 다시 켠 뒤 60초(startMinSteps.withinSec)는 지금 걷는지 보느라 끝내지 않는다
      await _elapse(tester, e, 30);
      final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));
      expect(c.read(paintTrailProvider).active, isTrue);
      for (var i = 0; i < 20 && c.read(paintTrailProvider).active; i++) {
        await _elapse(tester, e, 5);
      }
      await settle(tester, () => false, tries: 4);
      await transition(tester);
      expect(find.byType(WalkingScreen), findsNothing);
      final row = (await tester.runAsync(() => e.db.select(e.db.paintTrails).getSingle()))!;
      expect((row.endUtc, row.endReason),
          (t1.add(const Duration(minutes: 7)).millisecondsSinceEpoch, PaintTrailEnd.idle));
      // 77m + 10:02~10:06 5분 × 75보 × 0.7m = 262.5m
      expect(find.text('물감 길 0.3km를 그렸어요'), findsOneWidget);
      expect(await eventM(e, tester), closeTo(77 + 262.5, 1e-6));
      final day = (await tester.runAsync(() => e.db.select(e.db.daySummaries).get()))!
          .firstWhere((d) => d.distanceM > 0);
      expect(day.distanceM, closeTo(525, 1e-6));
      expect(day.trailM, closeTo(262.5, 1e-6));
      await end(tester, e);
    });

    testWidgets('다시 켠 뒤 60초 안에 걸으면 이어진다 (health가 늦게 들어와도)', (tester) async {
      final e = await walkThenHide(tester);
      // health에는 아직 아무것도 없다
      e.now = t1.add(const Duration(minutes: 12));
      _show(tester);
      await settle(tester, () => false, tries: 10);
      await _sensor(tester, e, 20, 50300);
      await _sensor(tester, e, 20, 50330);
      await _elapse(tester, e, 60);
      final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));
      expect(c.read(paintTrailProvider).active, isTrue);
      expect(find.byType(WalkingScreen), findsOneWidget);
      await end(tester, e);
    });
  });
}
