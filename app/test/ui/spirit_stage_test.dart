import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/screen_rules.dart';
import 'package:doobal/ui/scene/doobal_character.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import '../domain/helpers.dart';

/// 서울 낮 12시·밤 11시 (한국 시각)
final _noon = DateTime.utc(2026, 11, 16, 3);
final _night = DateTime.utc(2026, 11, 16, 14);

Widget _scene(
  SceneMode mode, {
  DateTime? now,
  bool moving = true,
  bool running = false,
  bool onSea = false,
  int? restPose,
  SpiritCue? cue,
}) =>
    MaterialApp(
      home: SceneView(
        mode: mode,
        distanceM: 20,
        nowUtc: now ?? _noon,
        position: const LatLng(37.5776, 126.9769),
        onSea: onSea,
        rules: rules,
        landmarks: landmarks,
        camp: mode == SceneMode.rest ? campTheme : null,
        moving: moving,
        running: running,
        seated: false,
        restPose: restPose,
        spiritCue: cue,
        spiritCues: spiritPalette.cues,
      ),
    );

DoobalCharacter _doobal(WidgetTester tester) =>
    tester.widget<DoobalCharacter>(find.byType(DoobalCharacter));

SpiritCharacter _spirit(WidgetTester tester) =>
    tester.widget<SpiritCharacter>(find.byType(SpiritCharacter));

Future<void> _waitRive(WidgetTester tester) async {
  for (var i = 0; i < 80 && find.byType(rive.RiveWidget).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  expect(find.byType(rive.RiveWidget), findsOneWidget);
}

void main() {

  testWidgets('걷는 중: 걸으면 옆 이동·멈추면 둥둥 옆, 둘 다 오른쪽을 보게 뒤집는다 (config screens·flipSideOn)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_scene(SceneMode.walking));
    await _waitRive(tester);
    expect((_doobal(tester).posePick, _doobal(tester).mirrored), (6, true));
    expect(find.byKey(const ValueKey('spirit-mirrored')), findsOneWidget);

    await tester.pumpWidget(_scene(SceneMode.walking, running: true));
    expect((_doobal(tester).posePick, _doobal(tester).mirrored), (6, true));

    await tester.pumpWidget(_scene(SceneMode.walking, moving: false));
    await tester.pump();
    expect((_doobal(tester).posePick, _doobal(tester).mirrored), (1, true));

    // 배 위는 지금처럼 장면이 정한다 (뒤집지 않음)
    await tester.pumpWidget(_scene(SceneMode.walking, onSea: true));
    await tester.pump();
    expect((_doobal(tester).posePick, _doobal(tester).mirrored), (null, false));
    expect(find.byKey(const ValueKey('spirit-mirrored')), findsNothing);
  });

  testWidgets('쉼터: 낮에는 쉼터가 고른 자세, 밤에는 잠들기 + 졸림, 뒤집지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_scene(SceneMode.rest));
    await _waitRive(tester);
    // 쉼터가 아직 안 골랐으면 restSwap 첫 자세(떠 있기 정면)
    expect((_doobal(tester).posePick, _doobal(tester).mirrored, _doobal(tester).expression), (0, false, 0));

    await tester.pumpWidget(_scene(SceneMode.rest, restPose: 3));
    expect((_doobal(tester).posePick, _doobal(tester).expression), (3, 0));
    expect(_spirit(tester).pose, 3);

    await tester.pumpWidget(_scene(SceneMode.rest, restPose: 3, now: _night));
    expect((_doobal(tester).posePick, _doobal(tester).expression), (4, 4));
    expect((_spirit(tester).pose, _spirit(tester).expression), (4, 4));
  });

  testWidgets('표정 신호는 정령까지 그대로 간다', (tester) async {
    final cue = SpiritCue(2, holdSec: 2, trigger: 'greet');
    await tester.pumpWidget(_scene(SceneMode.walking, moving: false, cue: cue));
    expect(_spirit(tester).cue, same(cue));
    expect(_spirit(tester).cues, same(spiritPalette.cues));
  });
}
