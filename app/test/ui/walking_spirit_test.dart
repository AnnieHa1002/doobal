import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/scene/doobal_character.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

// 걷는 중 화면의 정령 (16장 11/11·11/13): 옆 이동·멈춤 둥둥 옆을 오른쪽으로 뒤집기, 길 위 만남 놀람 + 인사,
// 가로 화면은 이 화면만

Landmark _farDest() => landmarks.firstWhere((l) {
      if (l.island != Island.mainland) return false;
      final km = buildRoute(nearGyeongbok, l.latLng, rules).totalEffectiveKm;
      return km >= 40 && km <= 90;
    });

DoobalCharacter _doobal(WidgetTester tester) =>
    tester.widget<DoobalCharacter>(find.byType(DoobalCharacter));

const _orientations = 'SystemChrome.setPreferredOrientations';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// 먼 여정 중 걷는 중 화면을 연다. 플랫폼에 보낸 화면 방향 잠금을 [calls]에 모은다
  Future<UiEnv> openWalking(WidgetTester tester, List<List<String>> calls) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == _orientations) calls.add([for (final o in call.arguments as List) '$o']);
      return null;
    });
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final e = UiEnv();
    await e.seed(tester, () async {
      await placeAt(e.db, nearGyeongbok, t0);
      await e.svc.startJourney(_farDest().id, t1, useFund: false);
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

  Future<void> sensorSteps(WidgetTester tester, UiEnv e, int steps) async {
    e.now = e.now.add(const Duration(seconds: 6));
    e.live.push(1000 + steps);
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('걷기 탭 처음 화면만 가로로 돌릴 수 있고, 다른 탭으로 가면 다시 세로로 잠근다 (config ui.orientation)', (tester) async {
    final calls = <List<String>>[];
    final e = await openWalking(tester, calls);
    expect(calls.last, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    await openTab(tester, 'rest');
    await tester.pump(const Duration(seconds: 1));
    // 걷기 탭은 숨어서 남아 있다 (keepState)
    expect(find.byType(WalkingScreen), findsNothing);
    expect(find.byType(WalkingScreen, skipOffstage: false), findsOneWidget);
    expect(calls.last, ['DeviceOrientation.portraitUp']);
    // 다시 걷기 탭이면 가로를 연다
    await openTab(tester, 'walk');
    await tester.pump(const Duration(seconds: 1));
    expect(calls.last, hasLength(3));
    await end(tester, e);
  });

  testWidgets('걸으면 옆 이동을 오른쪽으로, 2km 칸의 길 위 만남에서는 멈춘 옆모습으로 놀라고 인사한다', (tester) async {
    final e = await openWalking(tester, []);
    await sensorSteps(tester, e, 300);
    await settle(tester, () => _doobal(tester).posePick == 6);
    expect(_doobal(tester).mirrored, isTrue);
    expect(_doobal(tester).cue, isNull);

    // 첫 실제 여정의 2km: 이정표 카드 대신 길 위 만남
    await sensorSteps(tester, e, 2100);
    await settle(tester, () => find.byKey(const Key('meet-approach')).evaluate().isNotEmpty);
    await tester.pump();
    expect((_doobal(tester).posePick, _doobal(tester).mirrored), (1, true));
    final cue = _doobal(tester).cue!;
    expect((cue.expr, cue.holdSec, cue.trigger), (2, 2, 'greet'));
    await end(tester, e);
  });
}
