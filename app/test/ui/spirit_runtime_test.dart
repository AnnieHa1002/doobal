import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import '../domain/helpers.dart' show rules;

Future<(rive.File, SpiritController)> load() async {
  await rive.RiveNative.init();
  final f = (await rive.File.asset(
    SpiritCharacter.asset,
    riveFactory: rive.Factory.flutter,
  ))!;
  return (f, SpiritController(f));
}

void tick(SpiritController c, int n) {
  for (var i = 0; i < n; i++) {
    c.advance(1 / 60);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('확정 통합 파일에 옆앉기 다리와 모든 반응·잠들기 호흡이 있다', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    // 앱용 v33: 정령 전용 아트보드 Spirit 502×600 (11/13)
    expect(c.artboard.name, 'Spirit');
    expect(c.artboard.width, 502);
    expect(c.artboard.height, 600);
    for (final name in [
      'GreetOneShot',
      'JoyOneShot',
      'ImportedHeadPress',
      'ImportedBellyPress',
      'ImportedAngryOneShot',
      'IdleMicroAndBlink',
    ]) {
      final a = c.artboard.animationNamed(name);
      expect(a, isNotNull, reason: name);
      a?.dispose();
    }
  });
  test('장면 이동·앉기·잠들기와 반응 후 최신 장면 복귀', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    c.setScene(speed: 1, sitting: false);
    expect(c.poseChoice, 6);
    c.play(SpiritMotion.sit, direction: 1);
    expect(c.poseChoice, 3);
    c.press(SpiritPress.head);
    expect(c.poseChoice, 0);
    expect(c.headPressed, true);
    c.release();
    c.setScene(speed: 0, sitting: true);
    tick(c, 90);
    expect(c.poseChoice, 2);
    c.play(SpiritMotion.sleep);
    expect(c.poseChoice, 4);
    c.play(SpiritMotion.idle);
    expect(c.poseChoice, 0);
    c.play(SpiritMotion.wave);
    tick(c, 30);
    final arm = c.artboard.component('Right_arm_pivot')!;
    expect(arm.rotation.abs(), greaterThan(1));
    arm.dispose();
    c.setScene(speed: 2, sitting: false);
    tick(c, 150);
    expect(c.poseChoice, 6);
  });
  test('몸 색과 색 소품의 색은 각자 입력에 적용하고 반응·자세 변경 후 유지된다 (소품 색은 직접 고르지 않음, 16장 11/4)', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    // 봄하늘 베레모(하늘)와 단풍 신발(테라코타)은 기본 소품 그림에 색만 바꾼다
    final look = Look.initial
        .copyWith(body: const CustomBodyColor('#8CBBD0'))
        .withSlot('hat', 'hat_01_c1')
        .withSlot('shoe', 'shoe_01_c1');
    c.wear(spiritLookOf(
      look,
      bodyArgb: 0xff8cbbd0,
      baseOf: const {'hat_01_c1': 'hat_01', 'shoe_01_c1': 'shoe_01'},
      variantColors: const {'hat_01_c1': 0xffbcd9e8, 'shoe_01_c1': 0xffc9775a},
    ));
    expect(c.instance.number('hatChoice')!.value, 1);
    expect(c.instance.number('shoeChoice')!.value, 4);
    expect(c.instance.color('beretColor')!.value.toARGB32(), 0xffbcd9e8);
    expect(c.instance.color('bodyColor')!.value.toARGB32(), 0xff8cbbd0);
    c.press(SpiritPress.belly);
    tick(c, 80);
    c.play(SpiritMotion.sleep);
    tick(c, 80);
    expect(c.instance.color('brownShoesColor')!.value.toARGB32(), 0xffc9775a);
    expect(c.instance.color('beretColor')!.value.toARGB32(), 0xffbcd9e8);
  });
  test('꾸미기 동작 버튼은 같은 인사도 다시 재생하고 잠들기에서 기본으로 돌아간다', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    for (var repeat = 0; repeat < 2; repeat++) {
      c.setExpression(2, force: true);
      tick(c, 30);
      final arm = c.artboard.component('Right_arm_pivot')!;
      expect(arm.rotation.abs(), greaterThan(1));
      arm.dispose();
      tick(c, 150);
    }
    c.setExpression(4, force: true);
    expect(c.poseChoice, 4);
    c.setExpression(0, force: true);
    expect(c.poseChoice, 0);
  });
  test('연타 화남은 실제 화남 입력을 재생하고 복귀한다', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    c.tapRules = rules;
    var at = DateTime.utc(2026, 11, 12);
    c.clock = () => at;
    for (var i = 0; i < rules.tapReaction.angryTaps; i++) {
      c.press(SpiritPress.head);
      c.release();
      at = at.add(const Duration(milliseconds: 20));
    }
    tick(c, 90);
    expect(c.poseChoice, 0);
  });
}
