import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('spiritLookOf', () {
    test('첫 모습은 Rive 기본 얼굴에 기본 가방 큰 붓', () {
      expect(spiritLookOf(Look.initial), SpiritLook.base.copyWith(bag: 1));
      expect(
          (SpiritLook.base.eye, SpiritLook.base.brow, SpiritLook.base.nose, SpiritLook.base.mouth),
          (0, 1, 6, 1));
    });

    test('눈·눈썹·입은 번호에서 1을 뺀 값이다', () {
      final s = spiritLookOf(Look.initial.copyWith(eyes: 5, brows: 1, mouth: 6));
      expect((s.eye, s.brow, s.mouth), (4, 0, 5));
    });

    test('코는 명세 순서(없음·점·넓적·삼각·하트·고리·///)를 Rive 값으로 바꾼다', () {
      final styles = [
        for (var n = 1; n <= noseShapeCount; n++) spiritLookOf(Look.initial.copyWith(nose: n)).nose,
      ];
      expect(styles, [3, 1, 2, 4, 5, 0, 6]);
      // 빠짐없이 한 번씩
      expect(styles.toSet().length, noseShapeCount);
    });

    test('Rive에 붙은 소품만 값이 있고 나머지는 0이다', () {
      SpiritLook wear(String slot, String id) =>
          spiritLookOf(Look.initial.withSlot(slot, id));
      expect(wear('cloth', 'cloth_02').outfit, 1);
      expect(wear('cloth', 'cloth_05').outfit, 2);
      expect(wear('cloth', 'cloth_03').outfit, 0);
      expect(wear('bag', 'hand_01').bag, 1);
      expect(wear('bag', 'hand_02').bag, 2);
      expect(wear('bag', 'bag_02').bag, 0);
      expect(wear('pet', 'pet_05').companion, 1);
      expect(wear('pet', 'pet_02').companion, 0);
    });

    test('비운 칸은 0이다', () {
      final s = spiritLookOf(Look.initial.withSlot('bag', null).withSlot('pet', null));
      expect((s.bag, s.companion), (0, 0));
    });
  });
}
