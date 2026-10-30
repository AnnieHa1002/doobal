import 'dart:convert';

import 'package:doobal/domain/look.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// JSON 문자열을 거쳐 돌려 읽는다 (DB에는 문자열로 들어간다)
Look _roundTrip(Look look) =>
    Look.fromJson(jsonDecode(jsonEncode(look.toJson())) as Map<String, dynamic>);

void main() {
  group('Look', () {
    test('기본값은 머리 1, 견본 1', () {
      expect(Look.initial.hair, 1);
      expect(Look.initial.hairColor, const SwatchHairColor(1));
    });

    test('JSON 왕복: 견본', () {
      const look = Look(hair: 3, hairColor: SwatchHairColor(7));
      expect(look.toJson(), {
        'hair': 3,
        'hairColor': {'kind': 'swatch', 'i': 7},
      });
      expect(_roundTrip(look), look);
    });

    test('JSON 왕복: 직접 고른 색', () {
      const look = Look(hair: 6, hairColor: CustomHairColor('#A1B2C3'));
      expect(look.toJson(), {
        'hair': 6,
        'hairColor': {'kind': 'custom', 'hex': '#A1B2C3'},
      });
      expect(_roundTrip(look), look);
    });

    test('JSON 왕복: 그러데이션', () {
      const look = Look(hair: 2, hairColor: GradientHairColor('#2B2522', '#E39AB0'));
      expect(look.toJson(), {
        'hair': 2,
        'hairColor': {'kind': 'gradient', 'root': '#2B2522', 'tip': '#E39AB0'},
      });
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
