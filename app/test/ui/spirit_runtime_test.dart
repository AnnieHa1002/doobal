import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/screen_rules.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/domain/spirit_palette.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import '../domain/helpers.dart' show rules;

final cues = SpiritPalette.fromJson(
        jsonDecode(File('assets/data/palette.json').readAsStringSync()) as Map<String, dynamic>)
    .cues;

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
    // 앱용 v36(11/14 정령 기준, v33과 같은 아트보드): 정령 전용 아트보드 Spirit 502×600
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
  test('화면이 정한 자세는 장면보다 앞서고, 반응이 끝나면 그 자세로 돌아간다 (config screens·restSwap)', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    c.setScene(speed: 0, sitting: false);
    expect(c.poseChoice, 0);
    // 쉼터 앉기 옆 → 머리 누르기 반응 중에는 정면 → 끝나면 앉기 옆
    c.setPose(3);
    expect(c.poseChoice, 3);
    c.press(SpiritPress.head);
    expect(c.poseChoice, 0);
    c.release();
    tick(c, 90);
    expect(c.poseChoice, 3);
    // 걷는 중 멈춤은 둥둥 옆: 장면 속도가 바뀌어도 화면 자세 그대로
    c.setPose(1);
    c.setScene(speed: 0, sitting: false);
    expect(c.poseChoice, 1);
    c.setPose(6);
    expect(c.poseChoice, 6);
    // 화면 자세를 거두면 장면 자세로
    c.setPose(null);
    expect(c.poseChoice, 0);
    // play는 화면 자세를 거둔다 (하루 카드 잠든 정령)
    c.setPose(2);
    c.play(SpiritMotion.sleep);
    expect(c.poseChoice, 4);
  });
  test('표정: 늘 두는 표정과 잠깐 표정(holdSec 뒤 돌아감), 트리거가 있으면 반응도 (정령 계약 4장)', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    final expr = c.instance.number('expr')!;
    expect(expr.value, 0);
    // 밤 쉼터: 잠들기 + 졸림
    c.setPose(4);
    c.setBaseExpression(4);
    expect((c.poseChoice, expr.value), (4, 4));
    // 길 위 만남: 놀람 2초 뒤 늘 두는 표정
    c.setPose(1);
    c.setBaseExpression(0);
    c.cue(const SpiritCue(2, holdSec: 2));
    expect((c.expression, expr.value, c.poseChoice), (2, 2, 1));
    tick(c, 60);
    expect(c.expression, 2);
    tick(c, 70);
    expect((c.expression, expr.value), (0, 0));
    // 잠깐 표정 중에 늘 두는 표정이 바뀌면 끝난 뒤 그것으로
    c.cue(const SpiritCue(1, holdSec: 1));
    c.setBaseExpression(4);
    expect(c.expression, 1);
    tick(c, 70);
    expect(c.expression, 4);
    c.setBaseExpression(0);
    // 도착: 기쁨 트리거 + 행복 1초. 반응 중 정면, 끝나면 화면 자세
    c.setPose(0);
    tick(c, 30);
    final arm = c.artboard.component('Right_arm_pivot')!;
    final rest = arm.rotation;
    c.cue(const SpiritCue(1, holdSec: 1, trigger: 'joy'));
    expect(c.expression, 1);
    tick(c, 30);
    expect((arm.rotation - rest).abs(), greaterThan(0.3), reason: '기쁨: 팔을 든다');
    arm.dispose();
    tick(c, 150);
    expect((c.expression, c.poseChoice), (0, 0));
    // holdSec가 없으면 늘 두는 표정이 된다
    c.cue(const SpiritCue(4));
    tick(c, 300);
    expect(c.expression, 4);
  });
  test('누르기는 행복 표정(palette tap 1초), 연타 화남은 화남 표정 2초 (config tapReaction)', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    c.tapRules = rules;
    c.cues = cues;
    var at = DateTime.utc(2026, 11, 12);
    c.clock = () => at;
    c.press(SpiritPress.belly);
    c.release();
    expect(c.expression, 1);
    tick(c, 70);
    expect(c.expression, 0);
    for (var i = 0; i < rules.tapReaction.angryTaps; i++) {
      c.press(SpiritPress.head);
      c.release();
      at = at.add(const Duration(milliseconds: 20));
    }
    expect(c.expression, 5);
    tick(c, 60);
    expect(c.expression, 5);
    tick(c, 70);
    expect(c.expression, 0);
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
