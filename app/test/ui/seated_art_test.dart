import 'dart:math';

import 'package:doobal/domain/blink.dart';
import 'package:doobal/ui/scene/doobal_controller.dart';
import 'package:doobal/ui/scene/doobal_item_art.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('앉기 전용 하체 연결과 반복 장착·복귀가 유지된다', () async {
    await rive.RiveNative.init();
    final art = DoobalItemArt();
    await art.load();
    final file = (await rive.File.asset(
      'assets/rive/doobal_custom.riv',
      riveFactory: rive.Factory.flutter,
      assetLoader: art.assetLoader,
    ))!;
    final controller = DoobalController(
      file,
      itemArt: art,
      random: Random(1),
      blinkRule: const BlinkRule(
        minGapSec: 100,
        maxGapSec: 100,
        doubleChance: 0,
        doubleGapSec: .3,
      ),
    );
    final instance = controller.dataBind(rive.DataBind.auto());
    controller.initializeItems();
    addTearDown(() {
      controller.dispose();
      instance.dispose();
      file.dispose();
      art.dispose();
    });
    expect(art.supportsSeatedArt, isTrue);
    expect(art.replacements, 10);
    for (var i = 0; i < 3; i++) {
      controller.sit();
      controller.advance(.175);
      expect(controller.brushAngle, greaterThan(0));
      art.setSeatedArt(true);
      controller.blinkNow();
      controller.advance(.1);
      expect(controller.isBlinking, isTrue);
      controller.stand();
      controller.advance(.7);
      art.setSeatedArt(false);
      expect(controller.brushAngle, 0);
      expect(controller.setLook(3, -3), isTrue);
    }
  });
}
