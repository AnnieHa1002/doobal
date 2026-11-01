import 'dart:io';
import 'package:doobal/ui/scene/doobal_item_art.dart';
import 'dart:math';

import 'package:doobal/domain/blink.dart';
import 'package:doobal/ui/scene/doobal_controller.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('내보낸 두발 파일의 이동 상태 머신과 speed 바인딩을 재생한다', () async {
    await rive.RiveNative.init();
    final file = await rive.File.asset(
      'assets/rive/doobal_custom.riv',
      riveFactory: rive.Factory.flutter,
    );
    expect(file, isNotNull);
    addTearDown(file!.dispose);
    final controller = rive.RiveWidgetController(
      file,
      stateMachineSelector: rive.StateMachineSelector.byName('State Machine 1'),
    );
    final instance = controller.dataBind(rive.DataBind.auto());
    addTearDown(() {
      controller.dispose();
      instance.dispose();
    });
    expect(controller.artboard.width, 1024);
    expect(controller.artboard.height, 1280);
    final speed = instance.number('speed');
    expect(speed, isNotNull);
    for (final value in [0.0, 0.5, 1.0, 1.5, 2.0, 1.0, 0.0]) {
      speed!.value = value;
      for (var frame = 0; frame < 120; frame++) {
        controller.stateMachine.advanceAndApply(1 / 60);
      }
      expect(speed.value, closeTo(value, 0.001));
    }
  });
  test('무작위 깜빡임이 이동 speed를 유지하고 눈을 다시 연다', () async {
    await rive.RiveNative.init();
    final file = (await rive.File.asset(
      'assets/rive/doobal_custom.riv',
      riveFactory: rive.Factory.flutter,
    ))!;
    final controller = DoobalController(
      file,
      blinkRule: const BlinkRule(
        minGapSec: 3,
        maxGapSec: 3,
        doubleChance: 0,
        doubleGapSec: 0.3,
      ),
      random: Random(1),
    );
    final instance = controller.dataBind(rive.DataBind.auto());
    addTearDown(() {
      controller.dispose();
      instance.dispose();
      file.dispose();
    });
    final speed = instance.number('speed')!..value = 2;
    for (var i = 0; i < 179; i++) {
      controller.advance(1 / 60);
    }
    expect(controller.isBlinking, isFalse);
    controller.advance(0.03);
    expect(controller.isBlinking, isTrue);
    final blink = controller.artboard.animationNamed('blink')!;
    final duration = blink.duration;
    blink.dispose();
    controller.advance(duration + 0.01);
    controller.advance(0);
    expect(controller.isBlinking, isFalse);
    expect(speed.value, 2);
  });
  testWidgets('정지·걷기·뛰기 화면을 그리고 서로 다른 자세로 표시한다', (tester) async {
    await rive.RiveNative.init();
    final art = DoobalItemArt();
    await tester.runAsync(art.load);
    final file = (await tester.runAsync(
      () => rive.File.asset(
        'assets/rive/doobal_custom.riv',
        riveFactory: rive.Factory.flutter,
        assetLoader: art.assetLoader,
      ),
    ))!;
    await tester.runAsync(art.decodeArm);
    expect(art.replacements,10);
    final controller = DoobalController(
      file,
      itemArt: art,
      blinkRule: const BlinkRule(
        minGapSec: 3,
        maxGapSec: 6,
        doubleChance: 0,
        doubleGapSec: 0.3,
      ),
      random: Random(1),
    );
    final instance = controller.dataBind(rive.DataBind.auto());
    controller.initializeItems();
    expect(controller.supportsItems,isTrue);
    final speed = instance.number('speed')!;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 410,
              height: 512,
              child: rive.RiveWidget(
                controller: controller,
                fit: rive.Fit.contain,
              ),
            ),
          ),
        ),
      ),
    );
    final captures = <List<int>>[];
    final cornerAlpha = <int>[];
    for (final entry in {0.0: 'idle', 1.0: 'walk', 2.0: 'run', 3.0:'sit', 4.0:'boat'}.entries) {
      speed.value = entry.key > 2 ? 0 : entry.key;
      controller.setPose(entry.key == 3 ? DoobalPose.sitting : entry.key == 4 ? DoobalPose.boat : DoobalPose.standing);
      controller.scheduleRepaint();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final raw = (await image.toByteData())!.buffer.asUint8List();
          // 배경 위에 합성해야 하므로 캔버스 모서리는 투명해야 한다.
          cornerAlpha.add(raw[3]);
          expect(
            [for (var i = 3; i < raw.length; i += 4) raw[i]].any((a) => a != 0),
            isTrue,
          );
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
          captures.add(png.toList());
          final destination = Platform.environment['DOOBAL_CAPTURE_DIR'];
          if (destination != null) {
            await Directory(destination).create(recursive: true);
            await File('$destination/${entry.value}.png').writeAsBytes(png);
          }
        } finally {
          image.dispose();
        }
      });
    }
    controller.blinkNow();
    controller.advance(0.1);
    controller.advance(0);
    controller.scheduleRepaint();
    await tester.pump();
    final destination = Platform.environment['DOOBAL_CAPTURE_DIR'];
    if (destination != null) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        await File('$destination/blink_closed.png').writeAsBytes(png);
        image.dispose();
      });
    }
    expect(cornerAlpha, everyElement(0), reason: '캐릭터 캔버스 배경은 투명해야 해요');
    expect(captures[0], isNot(orderedEquals(captures[1])));
    expect(captures[1], isNot(orderedEquals(captures[2])));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    instance.dispose();
    file.dispose();
  });
}
