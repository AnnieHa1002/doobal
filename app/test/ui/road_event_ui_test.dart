import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:doobal/ui/walking/walking_hud.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/route.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

// 길 위 이벤트(2km 이정표 카드)·도장(걸음 알약 아래 줄, 토스트, 배낭 점)의 화면 쪽. 도장 목록은 나 탭(profile_screen_test).
// 계산·판정은 test/app/road_event_sync_test.dart가 본다

Landmark _farDest() => landmarks.firstWhere((l) {
      if (l.island != Island.mainland) return false;
      final km = buildRoute(nearGyeongbok, l.latLng, rules).totalEffectiveKm;
      return km >= 40 && km <= 90;
    });

Finder _card() => find.byKey(const Key('walk-event-card'));
Finder _badgeLine() => find.byKey(const Key('walk-badge-line'));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    // 실제 시간이 지나야 사라지므로 시험에서는 짧게 한다
    HudMetrics.eventCardOverride = const Duration(milliseconds: 400);
    HudMetrics.badgeLineOverride = const Duration(milliseconds: 400);
  });
  tearDown(() {
    HudMetrics.eventCardOverride = null;
    HudMetrics.badgeLineOverride = null;
  });

  /// 먼 여정 중 걷는 중 화면을 연다. 센서 기준값(1,000)도 받아 둔다
  Future<UiEnv> openWalking(WidgetTester tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await placeAt(e.db, nearGyeongbok, t0);
      await e.svc.startJourney(_farDest().id, t1, useFund: false);
      // 첫 칸은 동행 첫 만남이 대신한다 (test/ui/meet_flow_test.dart). 여기서는 이벤트만 보려고 셋 다 만나 둔다
      for (final c in companionCatalog.companions) {
        await e.db
            .into(e.db.companions)
            .insert(CompanionsCompanion.insert(companionId: c.id, metUtc: 1));
      }
      // 셋 다 만난 도장은 받은 것으로 둔다 (도장 토스트·줄 시험에 안 끼게)
      await e.db.into(e.db.badgesOwned).insert(BadgesOwnedCompanion.insert(
            badgeId: badgeCatalog.badges.firstWhere((b) => b.cond['kind'] == 'companionsMet').id,
            atUtc: 1,
            seen: const Value(true),
          ));
    });
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await startTrailNow(tester);
    await settle(tester, () => false, tries: 8);
    expect(find.byType(WalkingScreen), findsOneWidget);
    e.live.push(1000);
    await tester.pump(const Duration(milliseconds: 100));
    return e;
  }

  /// 센서가 [steps]보를 더 센다 (6초 뒤)
  Future<void> sensorSteps(WidgetTester tester, UiEnv e, int base, int steps) async {
    e.now = e.now.add(const Duration(seconds: 6));
    e.live.push(base + steps);
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('걷는 중: 2km 이정표 카드', () {
    testWidgets('2km 칸을 넘으면 카드(칭찬 한 줄 + 풍경 한 줄)가 뜨고 몇 초 뒤 사라진다', (tester) async {
      final e = await openWalking(tester);
      // 1.5km(1,500보를 한 번에 받으면 뛰기라 보폭 1m): 아직 칸 전
      await sensorSteps(tester, e, 1000, 1500);
      await settle(tester, () => false, tries: 4);
      expect(_card(), findsNothing);

      // 2.1km(2,100보): 칸을 넘는다
      await sensorSteps(tester, e, 1000, 2100);
      await settle(tester, () => _card().evaluate().isNotEmpty);
      expect(_card(), findsOneWidget);
      expect(find.text('2km 이정표'), findsOneWidget);

      final rows = (await tester.runAsync(() => e.db.select(e.db.journeyEvents).get()))!;
      expect(rows, hasLength(1));
      final scene = eventCatalog.scene(rows.single.terrain, rows.single.season, rows.single.night);
      expect(find.byKey(const Key('walk-event-praise')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('walk-event-praise'))).data,
          rows.single.praiseText);
      expect(tester.widget<Text>(find.byKey(const Key('walk-event-scene'))).data,
          scene.texts[rows.single.sceneTextId]);

      // 몇 초 뒤 사라진다
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(seconds: 1));
      expect(_card(), findsNothing);
      await end(tester, e);
    });

    testWidgets('접기 버튼을 누르면 바로 사라진다', (tester) async {
      final e = await openWalking(tester);
      await sensorSteps(tester, e, 1000, 2100);
      await settle(tester, () => _card().evaluate().isNotEmpty);
      expect(_card(), findsOneWidget);

      await tester.tap(find.byKey(const Key('walk-event-close')));
      await tester.pump();
      expect(_card(), findsNothing);
      await end(tester, e);
    });

    testWidgets('화면이 꺼진 동안 따라잡은 걸음도 물감 길이라 칸을 넘기고, 다시 켜지면 마지막 카드 1장만 (11/13)',
        (tester) async {
      final e = await openWalking(tester);
      // 앱이 숨고 걸음 센서는 5,000보를 더 세서, 돌아올 때 한꺼번에 들어온다
      // (30분 평균 분당 167보 → 뛰기 1m → 5km: 2km·4km 두 칸)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      e.now = e.now.add(const Duration(minutes: 30));
      e.live.push(6000);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester, () => _card().evaluate().isNotEmpty);

      final rows = (await tester.runAsync(() => e.db.select(e.db.journeyEvents).get()))!
        ..sort((a, b) => a.k.compareTo(b.k));
      expect(rows.map((r) => r.k), [1, 2]);
      // 카드는 마지막 칸(4km) 하나 (config events.offScreenCards 1)
      expect(_card(), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('walk-event-praise'))).data,
          rows.last.praiseText);
      await tester.tap(find.byKey(const Key('walk-event-close')));
      await tester.pump();
      await settle(tester, () => false, tries: 4);
      expect(_card(), findsNothing, reason: '첫 칸 카드는 뒤이어 뜨지 않는다');
      await end(tester, e);
    });
  });

  group('도장 알림', () {
    /// 걷기 기록을 건강 앱에 넣고 앱 자신의 동기화가 돌게 한다 (걷는 중 화면은 주기 타이머, 그 밖에는 앞으로 돌아올 때)
    Future<void> earnFirstWalk(WidgetTester tester, UiEnv e, {required bool walking}) async {
      e.source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), 20, 100));
      e.now = t1.add(const Duration(hours: 1));
      if (walking) {
        await tester.pump(Duration(seconds: e.appRules.walkingRefreshSec + 1));
      } else {
        for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
          tester.binding.handleAppLifecycleStateChanged(s);
        }
        await settle(tester, () => false, tries: 4);
        for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
          tester.binding.handleAppLifecycleStateChanged(s);
        }
      }
    }

    testWidgets('걷는 중에 도장을 받으면 걸음 알약 아래 작은 줄이 뜨고(토스트는 없다) 몇 초 뒤 사라진다',
        (tester) async {
      // 동기화 주기(30초)를 한 번에 흘려보내므로 그동안 사라지지 않게 길게 두었다가 그 뒤 흘려보낸다
      HudMetrics.badgeLineOverride = const Duration(seconds: 60);
      final e = await openWalking(tester);
      await earnFirstWalk(tester, e, walking: true);
      await settle(tester, () => _badgeLine().evaluate().isNotEmpty);
      expect(find.descendant(of: _badgeLine(), matching: find.text('도장을 받았어요 · 첫 걸음')),
          findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(const Duration(seconds: 61));
      expect(_badgeLine(), findsNothing);
      await end(tester, e);
    });

    testWidgets('쉼터에서 도장을 받으면 한 줄 토스트가 뜨고 배낭 알림 점이 켜진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await earnFirstWalk(tester, e, walking: false);
      await settle(tester, () => find.byType(SnackBar).evaluate().isNotEmpty);
      // 같은 동기화의 `그동안 n km 걸었어요` 토스트 뒤에 이어서 뜬다
      for (var i = 0; i < 4 && find.text('도장을 받았어요 · 첫 걸음').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(seconds: 3));
      }
      expect(find.text('도장을 받았어요 · 첫 걸음'), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(find.byType(DoobalApp)));
      final snap = await tester.runAsync(() => container.read(snapshotProvider.future));
      expect(snap!.unseenBadges, 1);
      await end(tester, e);
    });
  });

  // 도장 탭 시험은 16장 11/19 ③(도장은 나 탭)로 profile_screen_test.dart ‘나 탭 도장’으로 옮겼다

  group('걷기 기록 다시 보기: 그 걷기 시간대의 이정표', () {
    testWidgets('이정표 줄(칭찬 + 풍경)이 걷기 시간대 안의 것만 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        Future<void> event(int k, DateTime at, String praise, String sceneId) =>
            e.db.into(e.db.journeyEvents).insert(JourneyEventsCompanion.insert(
                  journeyId: 'j1',
                  k: k,
                  terrain: 'field',
                  season: 'autumn',
                  night: false,
                  sceneTextId: sceneId,
                  praiseId: 'R10',
                  praiseText: praise,
                  atUtc: at.millisecondsSinceEpoch,
                ));
        await event(1, t1.add(const Duration(minutes: 10)), '칭찬 하나', 'FLD_AUT_DAY_A');
        await event(2, t1.add(const Duration(minutes: 20)), '칭찬 둘', 'FLD_AUT_DAY_B');
        // 이 걷기 밖
        await event(3, t1.add(const Duration(hours: 5)), '다른 날 칭찬', 'FLD_AUT_DAY_C');
      });
      final scene = eventCatalog.scene('field', 'autumn', false);
      await tester.pumpWidget(ProviderScope(
        overrides: e.overrides,
        child: MaterialApp(
          home: WalkRecordScreen(
            start: t1,
            end: t1.add(const Duration(minutes: 30)),
          ),
        ),
      ));
      await settle(tester, () => find.text('칭찬 하나').evaluate().isNotEmpty);
      expect(find.text('2km 이정표'), findsOneWidget);
      expect(find.text('칭찬 하나'), findsOneWidget);
      expect(find.text('칭찬 둘'), findsOneWidget);
      expect(find.text('다른 날 칭찬'), findsNothing);
      expect(find.text(scene.texts['FLD_AUT_DAY_A']!), findsOneWidget);
      expect(find.text(scene.texts['FLD_AUT_DAY_B']!), findsOneWidget);
      await end(tester, e);
    });
  });
}
