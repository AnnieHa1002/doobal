import 'dart:io';

import 'package:doobal/ui/scene/doobal_item_art.dart';

import 'dart:ui' as ui;

import 'package:doobal/domain/blink.dart';
import 'package:doobal/ui/scene/doobal_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('앉기·서기·배 위 전환이 실제 자세를 바꾸고 발을 유지한다', (tester) async {
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
    final controller = DoobalController(
      file,
      blinkRule: const BlinkRule(
        minGapSec: 100,
        maxGapSec: 100,
        doubleChance: 0,
        doubleGapSec: 0.3,
      ),
    );
    final instance = controller.dataBind(rive.DataBind.auto());
    addTearDown(() {
      controller.dispose();
      instance.dispose();
      file.dispose();
      art.dispose();
    });
    expect(
      controller.supportsPose,
      isTrue,
      reason: '앉기와 배 위 상태를 저장한 새 .riv 파일이 필요해요',
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
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
    Future<List<int>> capture(String name) async {
      for (var i = 0; i < 90; i++) {
        controller.advance(1 / 60);
      }
      controller.scheduleRepaint();
      await tester.pump();
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final raw = (await image.toByteData())!.buffer.asUint8List().toList();
          final destination = Platform.environment['DOOBAL_CAPTURE_DIR'];
          if (destination != null) {
            await Directory(destination).create(recursive: true);
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            await File('$destination/pose_$name.png').writeAsBytes(png);
          }
          return raw;
        } finally {
          image.dispose();
        }
      }))!;
    }

    (int, int) verticalBounds(List<int> raw) {
      var top = 512;
      var bottom = -1;
      for (var i = 3; i < raw.length; i += 4) {
        if (raw[i] < 20) continue;
        final y = (i ~/ 4) ~/ 410;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
      expect(bottom, greaterThan(top));
      return (top, bottom);
    }

    controller.stand();
    final standing = await capture('standing');
    final standingBounds = verticalBounds(standing);
    expect(controller.sit(), isTrue);
    expect(instance.number('pose')!.value, 1);
    final sitting = await capture('sitting');
    final sittingBounds = verticalBounds(sitting);
    expect(
      sittingBounds.$1 - standingBounds.$1,
      inInclusiveRange(55, 110),
      reason: '앉으면 몸통과 머리가 낮아져야 해요',
    );
    expect(
      (sittingBounds.$2 - standingBounds.$2).abs(),
      lessThanOrEqualTo(15),
      reason: '앉아도 발이 기준 바닥 근처에 있어야 해요',
    );
    controller.stand();
    final returned = await capture('stood_up');
    expect(
      (verticalBounds(returned).$1 - standingBounds.$1).abs(),
      lessThanOrEqualTo(5),
    );
    expect(controller.setPose(DoobalPose.boat), isTrue);
    expect(instance.number('pose')!.value, 2);
    final boat = await capture('boat');
    expect(boat, isNot(orderedEquals(returned)));
    expect(
      boat.skip(420 * 410 * 4),
      orderedEquals(returned.skip(420 * 410 * 4)),
      reason: '배 위 동작은 하체와 신발을 움직이지 않아야 해요',
    );
    controller.sit();
    final fromBoat = await capture('boat_to_sit');
    expect(
      verticalBounds(fromBoat).$1 - standingBounds.$1,
      inInclusiveRange(55, 110),
    );
    controller.stand();
    instance.number('speed')!.value = 1;
    final walking = await capture('walk_after_sit');
    expect(walking, isNot(orderedEquals(standing)));
    controller.blinkNow();
    controller.advance(0.1);
    controller.advance(0);
    expect(controller.isBlinking, isTrue);
    expect(instance.number('pose')!.value, 0);
    expect(instance.number('speed')!.value, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
