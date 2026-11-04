import 'package:doobal/main.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import 'ui_env.dart';

// 걷는 중 100% → 걷기 자동 마침 → 도착 (11/4). 진행 기준은 언제나 health 동기화 값이다:
// 센서 미리보기가 남은 거리를 넘으면 동기화를 바로 돌려 보고, 도착이 확정돼야 넘어간다.

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// 경복궁 근처에서 경복궁으로 가는 여정 중 걷는 중 화면을 연다.
  /// 시계는 health 기록(걷기 30분)이 들어 있을 만큼 지나 있다
  Future<UiEnv> openWalking(WidgetTester tester, {bool healthArrives = true}) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await placeAt(e.db, nearGyeongbok, t0);
      await e.svc.startJourney('kr001', t1, useFund: false);
    });
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await tester.tap(find.text('출발하기'));
    await transition(tester);
    await settle(tester, () => false, tries: 8);
    expect(find.byType(WalkingScreen), findsOneWidget);
    if (healthArrives) {
      e.source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), 30, 100));
    }
    e.now = t1.add(const Duration(hours: 2));
    e.live.push(50000);
    await tester.pump(const Duration(milliseconds: 100));
    return e;
  }

  /// 6초마다 센서가 [steps]보를 더 센다
  Future<void> sensorSteps(WidgetTester tester, UiEnv e, int base, int steps) async {
    e.now = e.now.add(const Duration(seconds: 6));
    e.live.push(base + steps);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }

  testWidgets('센서 미리보기가 남은 거리를 넘으면 30초 주기를 기다리지 않고 동기화해 도착으로 넘어간다',
      (tester) async {
    final e = await openWalking(tester);
    // 경복궁까지 약 1km: 100보(70m)씩 센다. 중간에는 health 기록이 있어도 아직 동기화하지 않았다
    var steps = 0;
    for (var i = 0; i < 8; i++) {
      steps += 100;
      await sensorSteps(tester, e, 50000, steps);
    }
    expect(find.byType(ArrivalScreen), findsNothing);
    expect(find.byType(WalkingScreen), findsOneWidget);

    // 남은 거리(약 1km = 약 1,430보)를 넘는다
    for (var i = 0; i < 12 && find.byType(ArrivalScreen).evaluate().isEmpty; i++) {
      steps += 100;
      await sensorSteps(tester, e, 50000, steps);
    }
    for (var i = 0; i < 20 && find.byType(ArrivalScreen).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(find.byType(ArrivalScreen), findsOneWidget);
    await transition(tester);
    expect(find.byType(WalkingScreen, skipOffstage: false), findsNothing);

    // 도착 화면을 닫으면 그 걷기의 걷기 기록
    await tester.tap(find.byTooltip('닫기'));
    await transition(tester);
    await settle(tester, () => find.byType(WalkRecordScreen).evaluate().isNotEmpty);
    expect(find.byType(WalkRecordScreen), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('센서가 100%를 넘어도 health 동기화가 도착을 정해 주지 않으면 도착하지 않는다 (진행 기준은 동기화 값)',
      (tester) async {
    // health 기록이 없다: 센서만 앞서 간다
    final e = await openWalking(tester, healthArrives: false);
    var steps = 0;
    for (var i = 0; i < 25; i++) {
      steps += 100;
      await sensorSteps(tester, e, 50000, steps);
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(ArrivalScreen, skipOffstage: false), findsNothing);
    expect(find.byType(WalkingScreen), findsOneWidget);
    await end(tester, e);
  });
}
