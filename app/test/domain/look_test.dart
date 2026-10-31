import 'dart:convert';

import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/prop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// JSON 문자열을 거쳐 돌려 읽는다 (DB에는 문자열로 들어간다)
Look _roundTrip(Look look) =>
    Look.fromJson(jsonDecode(jsonEncode(look.toJson())) as Map<String, dynamic>);

void main() {
  group('Look', () {
    test('기본값은 머리 1, 머리색 견본 1, 피부 견본 1, 얼굴 1, 칸마다 기본 소품', () {
      expect(Look.initial.hair, 1);
      expect(Look.initial.hairColor, const SwatchHairColor(1));
      expect(Look.initial.skin, const SwatchSkinColor(1));
      final l = Look.initial;
      expect([l.eyes, l.nose, l.brows, l.ears], [1, 1, 1, 1]);
      expect(Look.initial.slots, defaultSlots);
    });

    test('기본 슬롯은 props.json에서 unlock.kind가 default인 소품 (칸마다 하나)', () {
      final defaults = {
        for (final p in props)
          if (p.kind == PropUnlockKind.initial) p.slot: p.id,
      };
      // 칸마다 기본 소품이 정확히 하나
      expect(props.where((p) => p.kind == PropUnlockKind.initial), hasLength(lookSlots.length));
      expect(defaults.keys.toSet(), lookSlots.toSet());
      expect(defaultSlots, defaults);
      // 소품 칸 이름은 props.json의 slot과 같다
      expect(props.map((p) => p.slot).toSet(), lookSlots.toSet());
    });

    test('JSON 왕복: 견본', () {
      const look = Look(hair: 3, hairColor: SwatchHairColor(7));
      expect(look.toJson(), {
        'hair': 3,
        'hairColor': {'kind': 'swatch', 'i': 7},
        'skin': {'kind': 'swatch', 'i': 1},
        'eyes': 1,
        'nose': 1,
        'brows': 1,
        'ears': 1,
        'slots': {
          'hat': 'hat_01',
          'hand': 'hand_01',
          'pet': 'pet_01',
          'bag': 'bag_01',
          'shoe': 'shoe_01',
          'cloth': 'cloth_01',
        },
      });
      expect(_roundTrip(look), look);
    });

    test('JSON 왕복: 직접 고른 색', () {
      const look = Look(hair: 6, hairColor: CustomHairColor('#A1B2C3'));
      expect(look.toJson()['hairColor'], {'kind': 'custom', 'hex': '#A1B2C3'});
      expect(_roundTrip(look), look);
    });

    test('JSON 왕복: 그러데이션', () {
      const look = Look(hair: 2, hairColor: GradientHairColor('#2B2522', '#E39AB0'));
      expect(look.toJson()['hairColor'],
          {'kind': 'gradient', 'root': '#2B2522', 'tip': '#E39AB0'});
      expect(_roundTrip(look), look);
    });

    test('기본값도 왕복한다', () => expect(_roundTrip(Look.initial), Look.initial));

    test('같은 값이면 같고, 다른 종류는 같지 않다', () {
      expect(const SwatchHairColor(1), const SwatchHairColor(1));
      expect(const SwatchHairColor(1) == const SwatchHairColor(2), isFalse);
      expect(const CustomHairColor('#000000') == const GradientHairColor('#000000', '#000000'),
          isFalse);
      expect(const Look(hair: 1, hairColor: SwatchHairColor(1)).hashCode,
          const Look(hair: 1, hairColor: SwatchHairColor(1)).hashCode);
    });

    test('copyWith는 준 것만 바꾼다', () {
      final a = Look.initial.copyWith(hair: 4);
      expect((a.hair, a.hairColor), (4, const SwatchHairColor(1)));
      final b = a.copyWith(hairColor: const SwatchHairColor(9));
      expect((b.hair, b.hairColor), (4, const SwatchHairColor(9)));
    });

    test('머리 모양은 1~6만 (범위 밖은 읽을 때 FormatException)', () {
      for (final hair in [1, hairShapeCount]) {
        expect(Look(hair: hair, hairColor: const SwatchHairColor(1)).hair, hair);
      }
      Map<String, dynamic> json(int hair) =>
          {'hair': hair, 'hairColor': const SwatchHairColor(1).toJson()};
      expect(() => Look.fromJson(json(0)), throwsFormatException);
      expect(() => Look.fromJson(json(7)), throwsFormatException);
      expect(hairShapeCount, 6);
    });

    test('모르는 머리색 종류나 틀린 색 값은 FormatException', () {
      expect(() => HairColor.fromJson({'kind': 'rainbow'}), throwsFormatException);
      expect(() => HairColor.fromJson({'kind': 'custom', 'hex': 'A1B2C3'}), throwsFormatException);
      expect(() => HairColor.fromJson({'kind': 'custom', 'hex': '#A1B2C'}), throwsFormatException);
      expect(() => HairColor.fromJson({'kind': 'gradient', 'root': '#000000', 'tip': 5}),
          throwsFormatException);
      expect(() => HairColor.fromJson({'kind': 'swatch', 'i': '1'}), throwsFormatException);
    });
  });

  group('Look 얼굴·피부·소품 칸 (M4)', () {
    const full = Look(
      hair: 5,
      hairColor: GradientHairColor('#2B2522', '#E39AB0'),
      skin: CustomSkinColor('#C08060'),
      eyes: 3,
      nose: 2,
      brows: 3,
      ears: 2,
      slots: {
        'hat': 'hat_02',
        'hand': null,
        'pet': 'pet_03',
        'bag': 'bag_01',
        'shoe': 'shoe_02',
        'cloth': 'cloth_03',
      },
    );

    test('JSON 왕복: 모든 칸을 바꾼 모습 (비운 칸은 null로 남는다)', () {
      final json = full.toJson();
      expect(json['skin'], {'kind': 'custom', 'hex': '#C08060'});
      expect([json['eyes'], json['nose'], json['brows'], json['ears']], [3, 2, 3, 2]);
      expect((json['slots'] as Map)['hand'], isNull);
      expect((json['slots'] as Map).containsKey('hand'), isTrue);
      expect(_roundTrip(full), full);
      expect(_roundTrip(full).slots['hand'], isNull);
    });

    test('JSON 왕복: 피부 견본', () {
      const look = Look(hair: 1, hairColor: SwatchHairColor(1), skin: SwatchSkinColor(7));
      expect(look.toJson()['skin'], {'kind': 'swatch', 'i': 7});
      expect(_roundTrip(look), look);
    });

    test('옛 JSON({hair, hairColor}만)은 빠진 키를 기본값으로 읽는다', () {
      final look = Look.fromJson({
        'hair': 4,
        'hairColor': {'kind': 'swatch', 'i': 3},
      });
      expect(look, const Look(hair: 4, hairColor: SwatchHairColor(3)));
      expect(look.skin, const SwatchSkinColor(1));
      expect([look.eyes, look.nose, look.brows, look.ears], [1, 1, 1, 1]);
      expect(look.slots, defaultSlots);
      // 다시 적으면 새 모양(모든 키)이 된다
      expect(_roundTrip(look), look);
      expect(look.toJson().keys,
          ['hair', 'hairColor', 'skin', 'eyes', 'nose', 'brows', 'ears', 'slots']);
    });

    test('일부만 있는 JSON도 빠진 키만 기본값', () {
      final look = Look.fromJson({
        'hair': 2,
        'hairColor': {'kind': 'swatch', 'i': 1},
        'eyes': 3,
        'slots': {'hat': 'hat_02'},
      });
      expect(look.eyes, 3);
      expect(look.nose, 1);
      expect(look.slots['hat'], 'hat_02');
      // slots 안에서 빠진 칸은 그 칸의 기본 소품
      expect(look.slots['hand'], 'hand_01');
      expect(look.slots['cloth'], 'cloth_01');
    });

    test('slots 안의 null은 비운 칸, 빠진 칸은 기본 소품 (옷은 비울 수 없다)', () {
      Look read(Map<String, dynamic> slots) => Look.fromJson({
            'hair': 1,
            'hairColor': {'kind': 'swatch', 'i': 1},
            'slots': slots,
          });
      expect(read({'hat': null}).slots['hat'], isNull);
      expect(read(<String, dynamic>{}).slots, defaultSlots);
      expect(() => read({'cloth': null}), throwsFormatException);
    });

    test('모르는 칸 이름은 무시한다', () {
      final look = Look.fromJson({
        'hair': 1,
        'hairColor': {'kind': 'swatch', 'i': 1},
        'slots': {'wing': 'wing_01'},
      });
      expect(look.slots, defaultSlots);
      expect((look.toJson()['slots'] as Map).keys, lookSlots);
    });

    test('범위 밖이면 FormatException: 눈·코·눈썹 1~3, 귀 1~2', () {
      Map<String, dynamic> json(String key, Object? v) => {
            'hair': 1,
            'hairColor': {'kind': 'swatch', 'i': 1},
            key: v,
          };
      for (final (key, max) in [('eyes', 3), ('nose', 3), ('brows', 3), ('ears', 2)]) {
        expect(Look.fromJson(json(key, max)).toJson()[key], max, reason: key);
        expect(Look.fromJson(json(key, 1)).toJson()[key], 1, reason: key);
        expect(() => Look.fromJson(json(key, 0)), throwsFormatException, reason: key);
        expect(() => Look.fromJson(json(key, max + 1)), throwsFormatException, reason: key);
        expect(() => Look.fromJson(json(key, '1')), throwsFormatException, reason: key);
      }
      expect([eyeShapeCount, noseShapeCount, browShapeCount, earShapeCount], [3, 3, 3, 2]);
    });

    test('틀린 피부색·slots 값은 FormatException', () {
      Map<String, dynamic> json(String key, Object? v) => {
            'hair': 1,
            'hairColor': {'kind': 'swatch', 'i': 1},
            key: v,
          };
      expect(() => Look.fromJson(json('skin', {'kind': 'gradient'})), throwsFormatException);
      expect(() => Look.fromJson(json('skin', {'kind': 'custom', 'hex': 'C08060'})),
          throwsFormatException);
      expect(() => Look.fromJson(json('skin', {'kind': 'swatch', 'i': '1'})),
          throwsFormatException);
      expect(() => Look.fromJson(json('skin', 'swatch')), throwsFormatException);
      expect(() => Look.fromJson(json('slots', ['hat_01'])), throwsFormatException);
      expect(() => Look.fromJson(json('slots', {'hat': 5})), throwsFormatException);
      expect(() => Look.fromJson(json('slots', {'hat': ''})), throwsFormatException);
      expect(() => Look.fromJson({'hair': 1}), throwsFormatException);
    });

    test('withSlot: 그 칸만 바꾸고, 비우기는 옷만 막는다', () {
      final a = Look.initial.withSlot('hat', 'hat_02');
      expect(a.slots['hat'], 'hat_02');
      expect(a.slots['hand'], 'hand_01');
      // 원래 모습은 그대로 (기본 슬롯 상수도 안 바뀐다)
      expect(Look.initial.slots['hat'], 'hat_01');
      expect(defaultSlots['hat'], 'hat_01');
      expect(a.withSlot('hat', null).slots['hat'], isNull);
      expect(() => a.withSlot('cloth', null), throwsArgumentError);
      expect(() => a.withSlot('wing', 'wing_01'), throwsArgumentError);
      // 다른 항목은 그대로
      expect(a.hair, Look.initial.hair);
      expect(a.skin, Look.initial.skin);
    });

    test('copyWith는 소품 칸을 그대로 가져가고 새 항목도 바꾼다', () {
      final a = full.copyWith(eyes: 1, skin: const SwatchSkinColor(4), ears: 1);
      expect((a.eyes, a.nose, a.brows, a.ears), (1, 2, 3, 1));
      expect(a.skin, const SwatchSkinColor(4));
      expect(a.slots, full.slots);
    });

    test('같음: 칸 하나만 달라도 다르다 (소품 칸 포함)', () {
      expect(full == _roundTrip(full), isTrue);
      expect(full.hashCode, _roundTrip(full).hashCode);
      expect(full == full.copyWith(nose: 3), isFalse);
      expect(full == full.copyWith(skin: const SwatchSkinColor(1)), isFalse);
      expect(full == full.withSlot('hand', 'hand_02'), isFalse);
      expect(full == full.withSlot('pet', 'pet_02'), isFalse);
      expect(const SwatchSkinColor(1) == const CustomSkinColor('#F6E1D3'), isFalse);
      expect(const CustomSkinColor('#F6E1D3'), const CustomSkinColor('#F6E1D3'));
    });

    test('hairTipArgb: 그러데이션만 끝 색', () {
      expect(hairTipArgb(const GradientHairColor('#405060', '#FFFFFF')), 0xFFFFFFFF);
      expect(hairTipArgb(const SwatchHairColor(3)), isNull);
      expect(hairTipArgb(const CustomHairColor('#102030')), isNull);
    });
  });

  group('머리색 견본 (palette.json)', () {
    test('견본 10개를 번호 1~10과 이름·색으로 읽는다', () {
      expect(hairSwatches.map((s) => s.id), [for (var i = 1; i <= 10; i++) i]);
      expect(hairSwatches.first.name, '흑발');
      expect(hairSwatches.first.color, 0xFF2B2522);
      expect(hairSwatches.last.name, '분홍색');
      expect(hairSwatches.last.color, 0xFFE39AB0);
      expect(hairSwatches.every((s) => s.color >> 24 == 0xFF), isTrue);
      expect(hairSwatches.map((s) => s.name).toSet(), hasLength(10));
    });

    test('hairArgb: 견본은 그 번호의 색, 모르는 번호는 첫 견본', () {
      expect(hairArgb(const SwatchHairColor(6), hairSwatches), 0xFFD6B26E);
      expect(hairArgb(const SwatchHairColor(99), hairSwatches), hairSwatches.first.color);
    });

    test('hairArgb: 직접 고른 색은 그대로, 그러데이션은 뿌리 색', () {
      expect(hairArgb(const CustomHairColor('#102030'), hairSwatches), 0xFF102030);
      expect(hairArgb(const GradientHairColor('#405060', '#FFFFFF'), hairSwatches), 0xFF405060);
    });
  });
}
