import 'package:doobal/domain/color.dart';
import 'package:doobal/domain/tint.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

int _gray(int g) => 0xFF000000 | g << 16 | g << 8 | g;

int _r(int argb) => (argb >> 16) & 0xFF;
int _g(int argb) => (argb >> 8) & 0xFF;
int _b(int argb) => argb & 0xFF;

void main() {
  group('tintMatrix', () {
    test('20개: R·G·B 줄은 견본 채널 ÷ 기준 밝기 × 휘도 계수, 알파 줄은 그대로, 더하는 값은 0', () {
      final m = tintMatrix(0xFF6E4A32, 182);
      expect(m, hasLength(20));
      expect(m.sublist(0, 5), [
        closeTo(0x6E / 182 * 0.299, 1e-12),
        closeTo(0x6E / 182 * 0.587, 1e-12),
        closeTo(0x6E / 182 * 0.114, 1e-12),
        0,
        0,
      ]);
      expect(m.sublist(5, 8).reduce((a, b) => a + b), closeTo(0x4A / 182, 1e-12));
      expect(m.sublist(10, 13).reduce((a, b) => a + b), closeTo(0x32 / 182, 1e-12));
      expect(m.sublist(15), [0, 0, 0, 1, 0]);
      for (final row in [0, 5, 10]) {
        expect(m[row + 3], 0);
        expect(m[row + 4], 0);
      }
    });

    test('기준 밝기의 회색은 견본색 그대로 (머리 견본 10개, 기준 182)', () {
      for (final s in lookPalette.hair.swatches) {
        final out = applyColorMatrix(tintMatrix(s.color, lookPalette.hair.base), _gray(182));
        expect(out, s.color, reason: s.name);
      }
    });

    test('기준 밝기의 회색은 견본색 그대로 (피부 견본 7개, 기준 196)', () {
      for (final s in lookPalette.skin.swatches) {
        final out = applyColorMatrix(tintMatrix(s.color, lookPalette.skin.base), _gray(196));
        expect(out, s.color, reason: s.name);
      }
    });

    test('경계: 기준 밝기에서 한 단계 어두우면 견본보다 어둡고, 밝으면 견본보다 밝다', () {
      const swatch = 0xFF6E4A32;
      final m = tintMatrix(swatch, 182);
      final dark = applyColorMatrix(m, _gray(181));
      final bright = applyColorMatrix(m, _gray(183));
      expect(_r(dark), lessThanOrEqualTo(_r(swatch)));
      expect(_r(bright), greaterThanOrEqualTo(_r(swatch)));
      expect(dark, isNot(bright));
    });

    test('출력 = 견본 × L ÷ base (회색이 아닌 입력, L = 0.299R + 0.587G + 0.114B)', () {
      const swatch = 0xFF6E4A32;
      const src = 0xFFC86432; // (200, 100, 50)
      const l = 0.299 * 200 + 0.587 * 100 + 0.114 * 50;
      int expected(int c) => (c * l / 182).round();
      expect(
        applyColorMatrix(tintMatrix(swatch, 182), src),
        0xFF000000 | expected(_r(swatch)) << 16 | expected(_g(swatch)) << 8 | expected(_b(swatch)),
      );
    });

    test('회색조 입력은 밝기에 비례한다: 반이면 견본의 반, 검정은 검정', () {
      const swatch = 0xFF8C3E2A;
      final m = tintMatrix(swatch, 182);
      final half = applyColorMatrix(m, _gray(91));
      expect(_r(half), (_r(swatch) / 2).round());
      expect(_g(half), (_g(swatch) / 2).round());
      expect(applyColorMatrix(m, _gray(0)), 0xFF000000);
    });

    test('밝은 쪽은 255에서 잘린다 (흰 입력 × 밝은 견본)', () {
      const swatch = 0xFFE3E0DA; // 백발
      final out = applyColorMatrix(tintMatrix(swatch, 182), _gray(255));
      expect([_r(out), _g(out), _b(out)], [255, 255, 255]);
    });

    test('알파는 그대로 (입력 알파 0x80 → 출력 알파 0x80, 0이면 0)', () {
      final m = tintMatrix(0xFF2B2522, 182);
      expect(applyColorMatrix(m, 0x80B6B6B6) >> 24, 0x80);
      expect(applyColorMatrix(m, 0x00B6B6B6) >> 24, 0);
      expect(applyColorMatrix(m, 0xFFB6B6B6) >> 24, 0xFF);
    });
  });

  group('clampLightness', () {
    int clampHair(int argb) => clampLightness(argb, minPercent: 15, maxPercent: 90);
    int clampSkin(int argb) => clampLightness(argb, minPercent: 35, maxPercent: 95);

    test('범위 안의 색은 그대로 (불투명으로)', () {
      expect(clampHair(0xFF4F6F9E), 0xFF4F6F9E);
      expect(clampHair(0x004F6F9E), 0xFF4F6F9E);
    });

    test('견본은 모두 제 범위 안이라 그대로 (머리 15~90, 피부 35~95)', () {
      for (final s in lookPalette.hair.swatches) {
        expect(clampHair(s.color), s.color, reason: s.name);
      }
      for (final s in lookPalette.skin.swatches) {
        expect(clampSkin(s.color), s.color, reason: s.name);
      }
    });

    test('너무 어두우면 min으로, 너무 밝으면 max로 (색조·채도는 그대로)', () {
      final dark = hslOfArgb(clampHair(0xFF000000));
      expect(dark.l, closeTo(0.15, 0.004));
      final bright = hslOfArgb(clampHair(0xFFFFFFFF));
      expect(bright.l, closeTo(0.90, 0.004));

      // 색이 있는 색: 색조·채도를 지킨다
      const src = 0xFF3A0A0A; // 어두운 빨강
      final before = hslOfArgb(src);
      final after = hslOfArgb(clampHair(src));
      expect(before.l, lessThan(0.15));
      expect(after.l, closeTo(0.15, 0.004));
      expect(after.h, closeTo(before.h, 1.5));
      expect(after.s, closeTo(before.s, 0.02));
    });

    test('피부는 35~95%: 어두운 갈색은 35%로, 거의 흰색은 95%로', () {
      expect(hslOfArgb(clampSkin(0xFF301810)).l, closeTo(0.35, 0.004));
      expect(hslOfArgb(clampSkin(0xFFFFFFFF)).l, closeTo(0.95, 0.004));
      expect(hslOfArgb(clampSkin(0xFFFFFFFF)).l, greaterThan(0.9));
    });

    test('경계값 자체는 안 건드린다 (0.15·0.90 정확히)', () {
      final atMin = argbOfHsl(30, 0.5, 0.15);
      final atMax = argbOfHsl(30, 0.5, 0.90);
      expect(hslOfArgb(clampHair(atMin)).l, closeTo(0.15, 0.003));
      expect(hslOfArgb(clampHair(atMax)).l, closeTo(0.90, 0.003));
    });

    test('결과는 늘 [min, max] 안 (반올림 오차 0.4% 안)', () {
      for (var i = 0; i < 256; i += 5) {
        final out = clampSkin(_gray(i));
        final l = hslOfArgb(out).l;
        expect(l, inInclusiveRange(0.35 - 0.004, 0.95 + 0.004), reason: 'gray $i');
      }
    });
  });

  group('그러데이션', () {
    test('stop은 [0, rootUntil, tipFrom, 1]', () {
      expect(gradientStops(0.3, 0.85), [0, 0.3, 0.85, 1]);
    });

    test('palette.json의 구간은 30%·85%', () {
      expect(lookPalette.hair.rootUntil, 0.3);
      expect(lookPalette.hair.tipFrom, 0.85);
      expect(gradientStops(lookPalette.hair.rootUntil, lookPalette.hair.tipFrom),
          [0, 0.3, 0.85, 1]);
    });

    test('tipMixAt: 30%까지 뿌리색, 85%부터 끝색, 그 사이는 직선', () {
      double mix(double t) => tipMixAt(t, rootUntil: 0.3, tipFrom: 0.85);
      expect(mix(0), 0);
      expect(mix(0.3), 0);
      expect(mix(0.575), closeTo(0.5, 1e-12));
      expect(mix(0.85), 1);
      expect(mix(1), 1);
      // 범위 밖은 자른다
      expect(mix(-1), 0);
      expect(mix(2), 1);
    });
  });
}
