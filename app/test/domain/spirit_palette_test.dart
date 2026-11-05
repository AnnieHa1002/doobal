import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _json() =>
    jsonDecode(File('assets/data/palette.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('BodyPalette (palette.json body)', () {
    test('견본 10개를 번호 1~10과 이름·색으로, 기준 밝기 200, 기본 견본 1을 읽는다', () {
      final b = spiritPalette.body;
      expect(b.swatches.map((s) => s.id), [for (var i = 1; i <= 10; i++) i]);
      expect(b.swatches.first.name, '크림');
      expect(b.swatches.first.color, 0xFFF3E4C4);
      expect(b.swatches.last.name, '남청');
      expect(b.swatches.last.color, 0xFF7F8DB3);
      expect(b.swatches.every((s) => s.color >> 24 == 0xFF), isTrue);
      expect(b.swatches.map((s) => s.name).toSet(), hasLength(10));
      expect((b.base, b.defaultId), (200, 1));
      // 몸 그림의 기준색: Rive v25 몸통의 평면색 (렌더해서 잰 값)
      expect(b.baseArgb, 0xFFFFF5E2);
      expect(b.defaultId, defaultBody.i);
    });

    test('argbOf: 견본은 그 번호의 색, 모르는 번호는 기본 견본, 직접 고른 색은 그대로', () {
      final b = spiritPalette.body;
      expect(b.argbOf(const SwatchBodyColor(9)), 0xFFC9775A);
      expect(b.argbOf(const SwatchBodyColor(99)), b.swatches.first.color);
      expect(b.argbOf(const CustomBodyColor('#102030')), 0xFF102030);
    });

    test('nameOf: 견본 이름, 직접 고른 색은 "직접 고르기"', () {
      final b = spiritPalette.body;
      expect(b.nameOf(const SwatchBodyColor(2)), '살구');
      expect(b.nameOf(const CustomBodyColor('#102030')), '직접 고르기');
    });
  });

  group('SpiritPalette', () {
    test('얼굴 파츠: 눈 5 · 눈썹 5 · 코 7 · 입 6, 이름은 palette.json 그대로', () {
      final f = spiritPalette.faces;
      expect(
          f.map((k, v) => MapEntry(k, v.length)), {'eyes': 5, 'brows': 5, 'nose': 7, 'mouth': 6});
      expect(f['eyes']!.first, (id: 'dot', name: '점+반짝'));
      expect(f['nose']!.last, (id: 'shy', name: '쑥스러움'));
    });

    test('모양이 틀리면 FormatException (모르는 파츠 id, 기본 견본 없음, 기준 밝기 0)', () {
      expect(() {
        final j = _json();
        ((j['customParts'] as Map)['eyes'] as List).add({'id': 'laser', 'name': 'x', 'rive': 9});
        SpiritPalette.fromJson(j);
      }, throwsFormatException);
      expect(() {
        final j = _json();
        (j['body'] as Map)['default'] = 99;
        SpiritPalette.fromJson(j);
      }, throwsFormatException);
      expect(() {
        final j = _json();
        (j['body'] as Map)['base'] = 0;
        SpiritPalette.fromJson(j);
      }, throwsFormatException);
    });
  });
}
