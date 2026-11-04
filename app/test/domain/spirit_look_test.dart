import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/face_parts.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('spiritLookOf', () {
    test('첫 모습은 Rive 기본 얼굴에 기본 가방 큰 붓', () {
      expect(spiritLookOf(Look.initial), SpiritLook.base.copyWith(bag: 1));
      expect(
          (SpiritLook.base.eye, SpiritLook.base.brow, SpiritLook.base.nose, SpiritLook.base.mouth),
          (0, 1, 6, 1));
      expect(SpiritLook.base.bodyArgb, isNull);
    });

    test('얼굴 id를 Rive 값으로 바꾼다', () {
      final s = spiritLookOf(
          Look.initial.copyWith(eyes: 'cat', brows: 'none', nose: 'none', mouth: 'smirk'));
      expect((s.eye, s.brow, s.nose, s.mouth), (4, 0, 3, 5));
    });

    test('코는 없음=3·고리=0 순서로 Rive 값을 바꾼다 (빠짐없이 한 번씩)', () {
      final styles = [
        for (final id in noseParts.keys) spiritLookOf(Look.initial.copyWith(nose: id)).nose,
      ];
      expect(styles, [3, 0, 1, 2, 4, 5, 6]);
      expect(styles.toSet().length, noseParts.length);
    });

    test('const 표는 palette.json customParts의 id와 rive 값, 순서까지 같다', () {
      final parts = (jsonDecode(File('assets/data/palette.json').readAsStringSync())
          as Map<String, dynamic>)['customParts'] as Map<String, dynamic>;
      for (final (key, table) in [
        ('eyes', eyeParts),
        ('brows', browParts),
        ('nose', noseParts),
        ('mouth', mouthParts),
      ]) {
        final json = {
          for (final p in parts[key] as List)
            (p as Map<String, dynamic>)['id'] as String: p['rive'] as int,
        };
        expect(table, json, reason: key);
        expect(table.keys.toList(), json.keys.toList(), reason: '$key 순서');
      }
    });

    test('Rive에 붙은 소품만 값이 있고 나머지는 0이다', () {
      SpiritLook wear(String slot, String id) => spiritLookOf(Look.initial.withSlot(slot, id));
      expect(wear('cloth', 'cloth_02').outfit, 1);
      expect(wear('cloth', 'cloth_05').outfit, 2);
      expect(wear('cloth', 'cloth_03').outfit, 0);
      expect(wear('bag', 'hand_01').bag, 1);
      expect(wear('bag', 'hand_02').bag, 2);
      expect(wear('bag', 'bag_02').bag, 0);
      expect(wear('pet', 'pet_05').companion, 1);
      expect(wear('pet', 'pet_02').companion, 0);
    });

    test('Rive 소품 id는 모두 props.json의 그 칸 소품이다', () {
      final byId = {for (final p in props) p.id: p.slot};
      expect([byId['hand_01'], byId['hand_02']], ['bag', 'bag']);
      expect([byId['cloth_02'], byId['cloth_05']], ['cloth', 'cloth']);
      expect(byId['pet_05'], 'pet');
    });

    test('비운 칸은 0이다', () {
      final s = spiritLookOf(Look.initial.withSlot('bag', null).withSlot('pet', null));
      expect((s.bag, s.companion), (0, 0));
    });

    test('몸 색은 팔레트가 정한 색과 기준 밝기를 그대로 담는다', () {
      final look = Look.initial.copyWith(body: const SwatchBodyColor(9));
      final s = spiritLookOf(
        look,
        bodyArgb: spiritPalette.body.argbOf(look.body),
        bodyBaseArgb: spiritPalette.body.baseArgb,
      );
      expect(s.bodyArgb, 0xFFC9775A);
      expect(s.bodyBaseArgb, 0xFFFFF5E2);
      // 팔레트의 기준색은 코드 기본값과 같다
      expect(spiritPalette.body.baseArgb, defaultBodyBaseArgb);
      expect(s == s.copyWith(bodyArgb: 0xFF000000), isFalse);
      expect(s.hashCode, s.copyWith().hashCode);
    });
  });
}
