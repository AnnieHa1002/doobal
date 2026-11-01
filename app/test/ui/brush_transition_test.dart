import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:doobal/domain/blink.dart';
import 'package:doobal/ui/scene/doobal_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('앉기와 일어서기를 중간에 바꿔도 붓 각도가 튀지 않는다', () async {
    await rive.RiveNative.init();
    final file = (await rive.File.asset(
      'assets/rive/doobal_custom.riv',
      riveFactory: rive.Factory.flutter,
    ))!;
    final controller = DoobalController(
      file,
      blinkRule: const BlinkRule(
        minGapSec: 3,
        maxGapSec: 6,
        doubleChance: 0,
        doubleGapSec: .3,
      ),
    );
    final instance = controller.dataBind(rive.DataBind.auto());
    addTearDown(() {
      controller.dispose();
      instance.dispose();
      file.dispose();
    });
    controller.advance(0);
    controller.sit();
    expect(controller.brushAngle, 0, reason: '자세 입력만으로 붓이 꺾이지 않아야 한다');
    controller.advance(.175);
    final halfway = controller.brushAngle;
    expect(halfway, greaterThan(0));
    expect(halfway, lessThan(pi / 3));
    controller.stand();
    expect(controller.brushAngle, halfway);
    controller.advance(.35);
    expect(controller.brushAngle, 0);
    controller.sit();
    controller.advance(.35);
    expect(controller.brushAngle, closeTo(pi / 3, .0001));
    controller.stand();
    controller.advance(.35);
    expect(controller.brushAngle, 0);
  });
}
