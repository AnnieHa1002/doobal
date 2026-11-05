import 'package:doobal/domain/rules.dart';
import 'package:doobal/domain/scene_color.dart';
import 'package:doobal/domain/tint.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

int _r(int argb) => (argb >> 16) & 0xFF;
int _g(int argb) => (argb >> 8) & 0xFF;
int _b(int argb) => argb & 0xFF;

void main() {
  group('행렬', () {
    test('곱하기: 흰색은 그 색 쪽으로 세기만큼, 검정은 그대로', () {
      final m = multiplyMatrix(0xFFC79A5B, 0.18);
      final white = applyColorMatrix(m, 0xFFFFFFFF);
      expect(_r(white), (255 * (1 - .18 + .18 * 0xC7 / 255)).round());
      expect(_b(white), (255 * (1 - .18 + .18 * 0x5B / 255)).round());
      expect(applyColorMatrix(m, 0xFF000000), 0xFF000000);
    });

    test('채도: −1이면 회색, 회색은 그대로', () {
      final gray = applyColorMatrix(saturationMatrix(-1), 0xFFC04020);
      expect(_r(gray), _g(gray));
      expect(_g(gray), _b(gray));
      expect(applyColorMatrix(saturationMatrix(-0.45), 0xFF808080), 0xFF808080);
    });

    test('밝기: 곱해서 밝아지고 255에서 잘린다', () {
      final m = brightnessMatrix(0.12);
      expect(_r(applyColorMatrix(m, 0xFF646464)), 112);
      expect(_r(applyColorMatrix(m, 0xFFFFFFFF)), 255);
    });

    test('안개: 그 색 쪽으로 섞이고 알파는 그대로', () {
      final out = applyColorMatrix(hazeMatrix(0xFFD6E0D6, 0.25), 0x80000000);
      expect(_r(out), (0xD6 * .25).round());
      expect(out >> 24, 0x80);
    });

    test('곱한 행렬은 차례로 입힌 것과 같다 (반올림 오차 안)', () {
      final a = saturationMatrix(-0.45);
      final b = brightnessMatrix(0.12);
      final c = multiplyMatrix(0xFF1F2A3C, 0.65);
      const px = 0xFF9A6B3C;
      final one = applyColorMatrix(chainMatrix(c, chainMatrix(b, a)), px);
      final three = applyColorMatrix(c, applyColorMatrix(b, applyColorMatrix(a, px)));
      expect((_r(one) - _r(three)).abs(), lessThanOrEqualTo(2));
      expect((_g(one) - _g(three)).abs(), lessThanOrEqualTo(2));
      expect((_b(one) - _b(three)).abs(), lessThanOrEqualTo(2));
    });

    test('chainAll: null은 건너뛰고 다 null이면 null', () {
      expect(chainAll([null, null]), isNull);
      final m = factorMatrix(0xFF808080);
      expect(chainAll([null, m]), m);
    });
  });

  group('계절 보정 (config scene.seasonTint)', () {
    test('가을: 후경·군락·들판에만 황갈 0.18', () {
      final t = rules.seasonTint['autumn'];
      expect(t!.layers, {SceneLayerId.backdrop, SceneLayerId.grove, SceneLayerId.meadow});
      expect(t.multiply, 0xFFC79A5B);
      expect(t.strength, 0.18);
      expect(seasonTintMatrix(t, SceneLayerId.ground), isNull);
      expect(seasonTintMatrix(t, SceneLayerId.roadside), isNull);
      expect(seasonTintMatrix(t, SceneLayerId.backdrop), multiplyMatrix(0xFFC79A5B, 0.18));
    });

    test('겨울: 후경은 그림을 바꾸므로 보정 없음, 군락·들판은 채도 −45%·밝기 +12%·#EEF0F2 15%', () {
      final t = rules.seasonTint['winter'];
      expect(t!.layers, {SceneLayerId.grove, SceneLayerId.meadow});
      expect(seasonTintMatrix(t, SceneLayerId.backdrop), isNull);
      final m = seasonTintMatrix(t, SceneLayerId.meadow)!;
      // 채도가 빠져 초록이 회색 쪽으로, 밝기는 올라간다
      const green = 0xFF507030;
      final out = applyColorMatrix(m, green);
      expect(_g(out) - _r(out), lessThan(_g(green) - _r(green)));
      expect(_r(out) + _g(out) + _b(out), greaterThan(_r(green) + _g(green) + _b(green)));
    });

    test('봄·여름은 보정이 없다', () {
      expect(rules.seasonTint['spring'], isNull);
      expect(rules.seasonTint['summer'], isNull);
      expect(seasonTintMatrix(null, SceneLayerId.meadow), isNull);
    });
  });
}
