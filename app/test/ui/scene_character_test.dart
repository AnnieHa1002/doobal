import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/ui/scene/doobal_character.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import '../domain/helpers.dart';

void main() {
  testWidgets('장면의 걸음·쉼터·배 상태가 캐릭터 속도와 자세에 연결된다', (tester) async {
    final key = GlobalKey();
    Widget scene(
      SceneMode mode, {
      bool running = false,
      bool moving = true,
      bool onSea = false,
      bool seated = true,
    }) => MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: SceneView(
          mode: mode,
          distanceM: 20,
          nowUtc: DateTime.utc(2026, 10, 31, 3),
          position: const LatLng(37.5776, 126.9769),
          onSea: onSea,
          rules: rules,
          landmarks: landmarks,
          camp: mode == SceneMode.rest ? campTheme : null,
          running: running,
          moving: moving,
          seated: seated,
        ),
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(scene(SceneMode.rest));
    for (
      var i = 0;
      i < 80 && find.byType(rive.RiveWidget).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    expect(find.byType(rive.RiveWidget), findsOneWidget);
    for (final state in [
      (SceneMode.rest, false, true, false, 0.0, 'rest', DoobalPose.sitting),
      (SceneMode.walking, false, true, false, 1.0, 'walk', DoobalPose.standing),
      (SceneMode.walking, true, true, false, 2.0, 'run', DoobalPose.standing),
      (
        SceneMode.walking,
        false,
        false,
        false,
        0.0,
        'stop',
        DoobalPose.standing,
      ),
      (SceneMode.walking, true, true, true, 0.0, 'boat', DoobalPose.boat),
    ]) {
      await tester.pumpWidget(
        scene(state.$1, running: state.$2, moving: state.$3, onSea: state.$4),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<DoobalCharacter>(find.byType(DoobalCharacter)).speed,
        state.$5,
      );
      expect(
        tester.widget<DoobalCharacter>(find.byType(DoobalCharacter)).pose,
        state.$7,
      );
      // 앉기 타임라인과 서기 복귀가 끝난 장면을 캡처한다.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
      final destination = Platform.environment['DOOBAL_CAPTURE_DIR'];
      if (destination != null) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
          await File('$destination/scene_${state.$6}.png').writeAsBytes(png);
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(scene(SceneMode.rest, seated: false));
    expect(
      tester.widget<DoobalCharacter>(find.byType(DoobalCharacter)).pose,
      DoobalPose.standing,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
