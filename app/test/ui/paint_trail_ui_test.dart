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
import 'package:doobal/ui/tabs/home_tabs.dart';
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
// 앱을 연 채 걸으면 물감 길이 열리고(탭은 그대로, 걷기 탭 발자국), 걸음이 5분 멈추면 끝나고 토스트, 상시 알림 N0,
// 물감 방울, 첫날 말풍선, iOS 화면 꺼짐 메우기(16장 11/14).
// 11/16 쉼터↔걷는 중 6규칙은 16장 11/18 3탭이 대신한다: 걸어도·끝나도 탭은 저절로 안 바뀐다 (home_tabs_test)

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

/// 물감 길이 열렸는가
bool _trailOpen(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeTabs))).read(paintTrailProvider).active;

/// 쉼터에서 센서 값을 넣어 물감 길을 연다: 기준 [base] 뒤 30초에 10보 → 열림. 걸어도 탭은 그대로라
/// 걷기 탭을 눌러 걷는 중을 본다
Future<void> _startTrail(WidgetTester tester, UiEnv e, {int base = 50000}) async {
  await _sensor(tester, e, 0, base);
  await _sensor(tester, e, 30, base + 10);
  await settle(tester, () => _trailOpen(tester), tries: 80);
  await openTab(tester, 'walk');
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

  testWidgets('여정이 없으면 지도 옆 버튼에 알림 점', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _pumpApp(tester, e);
    expect(find.byKey(const ValueKey('rest-side-map-dot')), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('센서 60초에 9보면 그대로, 10보면 물감 길이 열리고 상시 알림이 켜진다. 탭은 쉼터 그대로 (16장 11/18)',
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
    await settle(tester, () => _trailOpen(tester), tries: 80);
    final rows = (await tester.runAsync(() => e.db.select(e.db.paintTrails).get()))!;
    expect(rows, hasLength(1));
    expect(rows.single.endUtc, isNull);
    expect(e.walkNotice.running, isTrue);
    await settle(tester, () => false, tries: 6);
    expect(find.byType(RestScreen), findsOneWidget);
    expect(find.byType(WalkingScreen), findsNothing);
    expect(find.byKey(const ValueKey('tab-walk-steps')), findsOneWidget);
    // 걷는 중에는 ‘걷기 마치기’·×1.3 딱지·왼쪽 위 쉼터 아이콘이 없다
    await openTab(tester, 'walk');
    expect(find.byType(WalkingScreen), findsOneWidget);
    expect(find.text('걷기 마치기'), findsNothing);
    expect(find.textContaining('×'), findsNothing);
    expect(find.byKey(const Key('walk-rest')), findsNothing);
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
    await settle(tester, () => _trailOpen(tester), tries: 80);
    await openTab(tester, 'walk');
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

  testWidgets('걸음이 5분 멈추면 물감 길이 idle로 닫히고 알림을 끄며 `물감 길 n km를 그렸어요`. 걷기 탭은 그대로 쉬는 중',
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
    expect(_trailOpen(tester), isTrue);
    // 5초씩 보내며 끝나길 기다린다 (토스트가 떠 있는 동안 본다)
    for (var i = 0; i < 40 && _trailOpen(tester); i++) {
      await _elapse(tester, e, 5);
      await settle(tester, () => false, tries: 2);
    }
    await transition(tester);
    // 탭은 저절로 안 바뀐다: 걷기 탭 그대로 (쉬는 중, 숫자는 0)
    expect(find.byType(WalkingScreen), findsOneWidget);
    expect(find.byType(RestScreen), findsNothing);
    expect(tester.widget<WalkingHud>(find.byType(WalkingHud)).shownSteps, 0);
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

  testWidgets('다른 화면(꾸미기·화집)에서 걸어도 그 화면 그대로, 닫아도 쉼터 (16장 11/18 ⑤)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    for (final (i, screen) in [const DecorateScreen(), const AlbumScreen()].indexed) {
      final nav = Navigator.of(tester.element(find.byType(RestScreen)));
      nav.push(MaterialPageRoute<void>(builder: (_) => screen));
      await transition(tester);
      await settle(tester, () => false, tries: 6);
      await _sensor(tester, e, 0, 50000 + i * 1000);
      await _sensor(tester, e, 30, 50010 + i * 1000);
      await settle(tester, () => _trailOpen(tester), tries: 80);
      await settle(tester, () => false, tries: 10);
      expect(find.byType(screen.runtimeType), findsOneWidget);
      nav.pop();
      await transition(tester);
      await settle(tester, () => false, tries: 10);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(find.byType(WalkingScreen), findsNothing);
      // 다음 화면 전에 물감 길을 닫는다
      for (var j = 0; j < 80 && _trailOpen(tester); j++) {
        await _elapse(tester, e, 5);
      }
    }
    await end(tester, e);
  });

  testWidgets('앱을 다시 열어도 탭은 그대로 (열린 물감 길로 저절로 가지 않는다)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, e.startSketch);
    await _pumpApp(tester, e);
    await _sensor(tester, e, 0, 50000);
    await _sensor(tester, e, 30, 50010);
    await settle(tester, () => _trailOpen(tester), tries: 80);
    _hide(tester);
    await tester.pump(const Duration(milliseconds: 100));
    e.now = e.now.add(const Duration(seconds: 20));
    _show(tester);
    await settle(tester, () => false, tries: 20);
    expect(_trailOpen(tester), isTrue);
    expect(find.byType(RestScreen), findsOneWidget);
    expect(find.byType(WalkingScreen), findsNothing);
    await end(tester, e);
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
      expect(c.read(paintTrailProvider).active, isFalse);
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
