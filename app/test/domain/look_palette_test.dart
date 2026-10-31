import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/look_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 실제 palette.json을 고칠 수 있는 맵으로 읽는다
Map<String, dynamic> _json() =>
    jsonDecode(File('assets/data/palette.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('LookPalette (palette.json)', () {
    test('머리: 기준 182, 직접 고르기 밝기 15~90, 그러데이션 30%·85%', () {
      final h = lookPalette.hair;
      expect(h.base, 182);
      expect((h.lightMin, h.lightMax), (15, 90));
      expect((h.rootUntil, h.tipFrom), (0.3, 0.85));
    });

    test('머리 견본 10개는 기존 loader와 같다', () {
      expect(lookPalette.hair.swatches.map((s) => (s.id, s.name, s.color)),
          hairSwatches.map((s) => (s.id, s.name, s.color)));
    });

    test('피부: 기준 196, 직접 고르기 밝기 35~95, 견본 7개', () {
      final s = lookPalette.skin;
      expect(s.base, 196);
      expect((s.lightMin, s.lightMax), (35, 95));
      expect(s.swatches.map((e) => e.id), [1, 2, 3, 4, 5, 6, 7]);
      expect(s.swatches.first.name, '피부 1');
      expect(s.swatches.first.color, 0xFFF6E1D3);
      expect(s.swatches.last.color, 0xFF966242);
      expect(s.swatches.every((e) => e.color >> 24 == 0xFF), isTrue);
    });

    test('skinArgb: 견본은 그 번호의 색, 모르는 번호는 첫 견본, 직접 고른 색은 그대로', () {
      final sw = lookPalette.skin.swatches;
      expect(skinArgb(const SwatchSkinColor(4), sw), 0xFFE2B48F);
      expect(skinArgb(const SwatchSkinColor(99), sw), sw.first.color);
      expect(skinArgb(const CustomSkinColor('#102030'), sw), 0xFF102030);
    });

    group('틀린 palette.json은 FormatException', () {
      void bad(String why, void Function(Map<String, dynamic> j) edit) {
        test(why, () {
          final j = _json();
          edit(j);
          expect(() => LookPalette.fromJson(j), throwsFormatException);
        });
      }

      Map<String, dynamic> hair(Map<String, dynamic> j) => j['hair'] as Map<String, dynamic>;
      Map<String, dynamic> skin(Map<String, dynamic> j) => j['skin'] as Map<String, dynamic>;

      bad('머리 밝기 범위가 거꾸로', (j) => hair(j)['custom'] = {'lightMin': 90, 'lightMax': 15});
      bad('피부 밝기가 100을 넘음', (j) => skin(j)['custom'] = {'lightMin': 35, 'lightMax': 101});
      bad('그러데이션 구간이 거꾸로',
          (j) => hair(j)['gradient'] = {'rootUntil': 0.85, 'tipFrom': 0.3});
      bad('그러데이션 구간이 1을 넘음',
          (j) => hair(j)['gradient'] = {'rootUntil': 0.3, 'tipFrom': 1.5});
      bad('기준 밝기가 0', (j) => hair(j)['base'] = 0);
      bad('피부 기준 밝기가 정수가 아님', (j) => skin(j)['base'] = '196');
      bad('피부 견본이 비어 있음', (j) => skin(j)['swatches'] = <dynamic>[]);
      bad('견본 색이 #RRGGBB가 아님', (j) {
        ((skin(j)['swatches'] as List).first as Map<String, dynamic>)['hex'] = 'F6E1D3';
      });
    });
  });
}
