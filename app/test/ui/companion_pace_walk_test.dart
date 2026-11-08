import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/companion.dart';
import 'package:doobal/domain/companion_pace.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/companion/companion_pacer.dart';
import 'package:doobal/ui/companion/companion_walk_layer.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/scene/doobal_character.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

// 걷는 중 동행 걸음 (M2 pace를 장면에, 캔버스 3-1)과 쉼터 늦은 도착. 계산은 test/domain/companion_pace_test.dart

Companion _c(String id) => companionCatalog.byId(id)!;

Landmark _farDest() => landmarks.firstWhere((l) {
      if (l.island != Island.mainland) return false;
      final km = buildRoute(nearGyeongbok, l.latLng, rules).totalEffectiveKm;
      return km >= 40 && km <= 90;
    });

final _mate = find.byKey(const ValueKey('walk-companion'));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('CompanionPacer', () {
    /// [seconds]초 동안 0.1초씩
    void steps(CompanionPacer p, Companion c, PaceMotion user, double seconds,
        {double userMps = 0, bool onSea = false}) {
      for (var t = 0.0; t < seconds - 1e-9; t += 0.1) {
        p.step(companion: c, user: user, userMps: userMps, onSea: onSea, dt: 0.1, rules: rules);
      }
    }

    test('walkOnly: 뛰면 뒤처지고 걸으면 따라온다, 모습이 바뀔 때만 알린다', () {
      final p = CompanionPacer();
      addTearDown(p.dispose);
      var notices = 0;
      p.frame.addListener(() => notices++);

      steps(p, _c('rest'), PaceMotion.walk, 1, userMps: 1.2);
      expect(p.lagM, 0);
      expect(p.frame.value.motion, PaceMotion.walk);
      expect(notices, 1, reason: '서 있기 → 걷기 한 번');

      steps(p, _c('rest'), PaceMotion.run, 5, userMps: 2.5);
      expect(p.lagM, closeTo((2.5 - rules.companionWalkMps) * 5, 1e-6));
      expect(p.frame.value.lagM, p.lagM);
      expect(notices, greaterThan(40), reason: '뒤처지는 동안은 프레임마다');

      final lag = p.lagM;
      steps(p, _c('rest'), PaceMotion.walk, 2, userMps: 1.2);
      expect(p.lagM, closeTo(lag - rules.companionLagCatchUpMps * 2, 1e-6));
    });

    test('match: 사용자 동작이 그대로면 알리지 않는다', () {
      final p = CompanionPacer();
      addTearDown(p.dispose);
      var notices = 0;
      p.frame.addListener(() => notices++);
      steps(p, _c('doctor'), PaceMotion.run, 10, userMps: 3);
      expect(notices, 1);
      expect(p.frame.value.motion, PaceMotion.run);
      expect(p.lagM, 0);
    });

    test('함께 걷는 동행이 바뀌면 처음부터 (뒤처진 거리 없음)', () {
      final p = CompanionPacer();
      addTearDown(p.dispose);
      steps(p, _c('rest'), PaceMotion.run, 3, userMps: 2.5);
      expect(p.lagM, greaterThan(0));
      steps(p, _c('bright'), PaceMotion.walk, 0.1, userMps: 1.2);
      expect(p.lagM, 0);
      expect(p.frame.value.lagM, 0);
    });
  });

  group('장면 자리 (캔버스 3-1)', () {
    const spot = SceneCompanionSpot(
      size: Size(390, 844),
      spiritFoot: Offset(195, 724),
      figureHeight: 180,
      groundPtPerM: 13.65,
      tint: 0xFFFFFFFF,
    );
    const w = 90 * 0.77;

    test('곁: 정령 가운데에서 120pt 뒤 (정령 키 180pt)', () {
      expect(walkCompanionFootX(const PaceFrame(motion: PaceMotion.walk), spot, w), closeTo(75, 1e-9));
    });

    test('앞서 나가면 화면 오른쪽 밖, 뒤처지면 땅 거리만큼 왼쪽', () {
      final ahead = walkCompanionFootX(const PaceFrame(motion: PaceMotion.run, aheadT: 1), spot, w);
      expect(ahead - w / 2, greaterThanOrEqualTo(390));
      final half = walkCompanionFootX(const PaceFrame(motion: PaceMotion.run, aheadT: .5), spot, w);
      expect(half, closeTo((75 + 390 + w / 2) / 2, 1e-9));
      final lag = walkCompanionFootX(const PaceFrame(motion: PaceMotion.walk, lagM: 4), spot, w);
      expect(lag, closeTo(75 - 4 * 13.65, 1e-9));
    });

    test('배 위면 배 그림의 동행 자리', () {
      const sea = SceneCompanionSpot(
        size: Size(390, 844),
        spiritFoot: Offset(195, 700),
        figureHeight: 180,
        groundPtPerM: 13.65,
        tint: 0xFFFFFFFF,
        boatFoot: Offset(120, 690),
      );
      expect(walkCompanionFootX(const PaceFrame(motion: PaceMotion.stand), sea, w), 120);
    });
  });

  group('걷는 중 화면', () {
    Future<void> met(UiEnv e, String id) async {
      await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(companionId: id, metUtc: 1));
      await e.db.into(e.db.companionStints).insert(
          CompanionStintsCompanion.insert(startUtc: const Value(1), companionId: Value(id)));
    }

    /// [id]와 함께 먼 여정의 걷는 중을 연다. 센서 기준값을 넣어 둔다
    Future<UiEnv> openWalking(WidgetTester tester, String id) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney(_farDest().id, t1, useFund: false);
        await met(e, id);
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.tap(find.text('출발하기'));
      await transition(tester);
      await settle(tester, () => _mate.evaluate().isNotEmpty, tries: 16);
      expect(find.byType(WalkingScreen), findsOneWidget);
      e.live.push(1000);
      await tester.pump(const Duration(milliseconds: 100));
      return e;
    }

    /// 6초 뒤 센서가 [steps]보를 더 준다 (30초 창에서 75보 = 분당 150보, 뛰기)
    Future<void> sensor(WidgetTester tester, UiEnv e, int total) async {
      e.now = e.now.add(const Duration(seconds: 6));
      e.live.push(total);
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> frames(WidgetTester tester, double seconds) async {
      for (var t = 0.0; t < seconds; t += 0.1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// 정령 가운데 x와 정령 키 (DoobalCharacter 상자: 600 폭에 머리 위~발 290)
    ({double x, double height}) spirit(WidgetTester tester) {
      final r = tester.getRect(find.byType(DoobalCharacter));
      return (x: r.center.dx, height: r.width * 290 / 600);
    }

    testWidgets('휴(walkOnly): 곁에서 걷다가 뛰면 뒤처져 사라지고, 마친 뒤 쉼터에 늦게 온다', (tester) async {
      final e = await openWalking(tester, 'rest');
      final s = spirit(tester);
      expect(tester.getCenter(_mate).dx, closeTo(s.x - walkBehindToSpirit * s.height, 0.5));
      // 동행은 정령 뒤 층
      final scene = find.byType(SceneView);
      final order = [
        for (final el in find.descendant(of: scene, matching: find.byWidgetPredicate(
          (w) => w is WalkCompanionLayer || w is DoobalCharacter,
        )).evaluate())
          el.widget.runtimeType,
      ];
      expect(order, [WalkCompanionLayer, DoobalCharacter]);

      // 분당 150보로 뛴다: 2초 뒤에는 왼쪽으로 밀려 있고, 8초 뒤에는 화면 밖
      await sensor(tester, e, 1075);
      final home = tester.getCenter(_mate).dx;
      await frames(tester, 2);
      expect(tester.getCenter(_mate).dx, lessThan(home - 10));
      await frames(tester, 8);
      expect(_mate, findsNothing);

      // 걷기를 마친다 → 걷기 기록 → 쉼터로: 불 옆은 비었다가, 늦은 도착 최대 시간이 지나면 앉는다
      await tester.tap(find.text('걷기 마치기'));
      await transition(tester);
      await settle(tester, () => find.text('쉼터로').evaluate().isNotEmpty);
      expect(find.byType(WalkRecordScreen), findsOneWidget);
      await tester.tap(find.text('쉼터로'));
      await transition(tester);
      await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
      final entry = find.byKey(const ValueKey('camp-object-companion'));
      await settle(tester, () => false, tries: 4);
      expect(entry, findsNothing, reason: '아직 걸어오는 중');

      final late = Duration(seconds: rules.companionLateArrivalMaxSec.ceil() + 1);
      e.now = e.now.add(late);
      await tester.pump(late);
      await settle(tester, () => entry.evaluate().isNotEmpty);
      expect(entry, findsOneWidget);
      await end(tester, e);
    });

    testWidgets('심 박사(match): 뛰어도 곁에 있다, 마친 뒤 쉼터에 바로 앉아 있다', (tester) async {
      final e = await openWalking(tester, 'doctor');
      final home = tester.getCenter(_mate).dx;
      await sensor(tester, e, 1075);
      await frames(tester, 5);
      expect(tester.getCenter(_mate).dx, closeTo(home, 0.5));

      await tester.tap(find.text('걷기 마치기'));
      await transition(tester);
      await settle(tester, () => find.text('쉼터로').evaluate().isNotEmpty);
      await tester.tap(find.text('쉼터로'));
      await transition(tester);
      final entry = find.byKey(const ValueKey('camp-object-companion'));
      await settle(tester, () => entry.evaluate().isNotEmpty);
      expect(entry, findsOneWidget);
      await end(tester, e);
    });

    testWidgets('혼자 걷기면 장면에 동행이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney(_farDest().id, t1, useFund: false);
        await e.db.into(e.db.companions).insert(
            CompanionsCompanion.insert(companionId: 'bright', metUtc: 1));
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.tap(find.text('출발하기'));
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      expect(find.byType(WalkingScreen), findsOneWidget);
      expect(_mate, findsNothing);
      expect(find.byType(WalkCompanionLayer), findsNothing);
      await end(tester, e);
    });
  });
}
