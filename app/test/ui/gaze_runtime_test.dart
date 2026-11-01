import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/blink.dart';
import 'package:doobal/ui/scene/doobal_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('시선은 눈 영역 안에서만 바뀌고 입력 범위를 지킨다', (tester) async {
    await rive.RiveNative.init();
    final file = (await tester.runAsync(
      () => rive.File.asset(
        'assets/rive/doobal_custom.riv',
        riveFactory: rive.Factory.flutter,
      ),
    ))!;
    final controller = DoobalController(
      file,
      blinkRule: const BlinkRule(
        minGapSec: 3,
        maxGapSec: 6,
        doubleChance: 0,
        doubleGapSec: 0.3,
      ),
    );
    final instance = controller.dataBind(rive.DataBind.auto());
    addTearDown(() {
      controller.dispose();
      instance.dispose();
      file.dispose();
    });
    expect(
      controller.supportsLook,
      isTrue,
      reason: '시선 연결 후 다시 내보낸 .riv가 필요해요',
    );
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
    Future<List<int>> capture(String name) async {
      await tester.pump();
      return (await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final raw = (await image.toByteData())!.buffer.asUint8List().toList();
          final destination = Platform.environment['DOOBAL_CAPTURE_DIR'];
          if (destination != null) {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            await File('$destination/gaze_$name.png').writeAsBytes(png);
          }
          return raw;
        } finally {
          image.dispose();
        }
      }))!;
    }

    controller.setLook(0, 0);
    final baseline = await capture('center');
    for (final target in [
      const Offset(-5, -5),
      const Offset(5, -5),
      const Offset(-5, 5),
      const Offset(5, 5),
    ]) {
      expect(controller.setLook(target.dx, target.dy), isTrue);
      final shifted = await capture('${target.dx}_${target.dy}');
      var changed = 0;
      for (var i = 0; i < baseline.length; i += 4) {
        if (List.generate(
          4,
          (c) => (baseline[i + c] - shifted[i + c]).abs(),
        ).any((v) => v > 2)) {
          changed++;
          final x = (i ~/ 4) % 410;
          final y = (i ~/ 4) ~/ 410;
          // 원본 눈 범위(500~695, 360~470)의 렌더 좌표, 가장자리 여유 포함.
          expect(x, inInclusiveRange(198, 280));
          expect(y, inInclusiveRange(142, 190));
        }
      }
      expect(changed, greaterThan(0), reason: '시선 입력이 실제 눈동자를 움직여야 해요');
    }
    controller.setLook(999, -999);
    expect(instance.number('lookX')!.value, 5);
    expect(instance.number('lookY')!.value, -5);
    controller.setLook(double.nan, double.infinity);
    expect(instance.number('lookX')!.value, 0);
    expect(instance.number('lookY')!.value, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
