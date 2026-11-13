
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/unified_wardrobe.dart';
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
        .copyWith(eyes: 'e6', brows: 'none', nose: 'none', mouth: 'm3');
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
    // 소품 색은 직접 고르지 않아서 Rive에 넣는 기본색 그대로 (16장 11/4)
    expect(c.instance.color('beretColor')!.value.toARGB32(), unifiedProp('hat_01')!.argb);
  });
  test('v33에는 시선 입력이 없어서 setLook은 아무것도 바꾸지 않고 멈추지도 않는다 (11/13)', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    expect(c.instance.number('lookX'), isNull);
    final before = c.instance.number('eye')!.value;
    c.setLook(100, -100);
    c.setLook(double.nan, double.infinity);
    tick(c, 1);
    expect(c.instance.number('eye')!.value, before);
  });
  test('옛 v24 얼굴 id는 계약 v0.5대로 기본 얼굴(e1·b1·n7·m7)로 읽는다', () {
    final s = spiritLookOf(
      const Look(eyes: 'cat', brows: 'fierce', nose: 'heart', mouth: 'tongue'),
    );
    expect([s.eye, s.brow, s.nose, s.mouth], [0, 1, 6, 6]);
  });
}
