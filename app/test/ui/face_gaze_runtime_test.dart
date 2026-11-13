import 'dart:ui';

import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

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
  test('사용자 얼굴4개가 분리된 입력으로 연결되고 반응·자세 후 유지된다', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    final l = Look.initial
        .copyWith(eyes: 'sparkle', brows: 'none', nose: 'none', mouth: 'fangs');
    c.wear(spiritLookOf(l));
    expect(
      [
        for (final key in ['eye', 'brow', 'nose', 'mouth'])
          c.instance.number(key)!.value,
      ],
      [6, 0, 0, 3],
    );
    c.play(SpiritMotion.laugh);
    tick(c, 30);
    expect(c.instance.number('brow')!.value, 0);
    expect(c.instance.number('nose')!.value, 0);
    tick(c, 110);
    c.play(SpiritMotion.sit, direction: 1);
    tick(c, 10);
    c.play(SpiritMotion.sleep);
    tick(c, 10);
    c.play(SpiritMotion.idle);
    tick(c, 10);
    expect(
      [
        for (final key in ['eye', 'brow', 'nose', 'mouth'])
          c.instance.number(key)!.value,
      ],
      [6, 0, 0, 3],
    );
    expect(c.instance.color('beretColor')!.value, const Color(0xffd276a0));
  });
  test('시선은 제한된 눈 이동에만 적용되고 머리·몸·옷은 움직이지 않는다', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    c.setLook(0, 0);
    tick(c, 1);
    final eye = c.artboard.component('Gaze_Front_0')!;
    final head = c.artboard.component('Character_Float_front')!;
    final oldX = head.x;
    c.setLook(100, -100);
    tick(c, 1);
    expect(eye.x, closeTo(4, .001));
    expect(eye.y, closeTo(-3, .001));
    expect(head.x, oldX);
    c.instance.number('eye')!.value = 2;
    tick(c, 1);
    final soft = c.artboard.component('Gaze_Front_1')!;
    expect(soft.x, 4);
    expect(soft.y, -3);
    soft.dispose();
    c.setLook(double.nan, double.infinity);
    tick(c, 1);
    expect(eye.x, 0);
    expect(eye.y, 0);
    eye.dispose();
    head.dispose();
  });
  test('기존 게임 얼굴 호출도 새 PSD 선택으로 변환된다', () {
    final s = spiritLookOf(
      const Look(eyes: 'cat', brows: 'fierce', nose: 'heart', mouth: 'tongue'),
    );
    expect([s.eye, s.brow, s.nose, s.mouth], [2, 3, 3, 4]);
  });
}
