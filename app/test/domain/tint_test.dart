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

    test('기준 밝기의 회색은 견본색 그대로 (몸 견본 10개)', () {
      final base = spiritPalette.body.base;
      for (final s in spiritPalette.body.swatches) {
        final out = applyColorMatrix(tintMatrix(s.color, base), _gray(base));
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

  group('bodyTintMatrix (정령 몸 색 곱하기)', () {
    test('20개: 대각선은 견본 채널 ÷ 기준색 채널, 알파는 그대로, 더하는 값은 0', () {
      final m = bodyTintMatrix(0xFFC9775A, 0xFFFFF5E2);
      expect(m, hasLength(20));
      expect([m[0], m[6], m[12], m[18]], [0xC9 / 0xFF, 0x77 / 0xF5, 0x5A / 0xE2, 1]);
      for (var i = 0; i < 20; i++) {
        if (i == 0 || i == 6 || i == 12 || i == 18) continue;
        expect(m[i], 0, reason: '$i');
      }
    });

    test('기준색의 픽셀은 견본색 그대로 (몸 견본 10개 × 기준색 #FFF5E2·회색 200)', () {
      for (final base in [spiritPalette.body.baseArgb, _gray(200)]) {
        for (final s in spiritPalette.body.swatches) {
          expect(applyColorMatrix(bodyTintMatrix(s.color, base), base), s.color,
              reason: '${s.name} / ${base.toRadixString(16)}');
        }
      }
    });

    test('채널별로 곱한다: 각 채널 x 견본 채널 / 기준색 채널', () {
      const swatch = 0xFF8C6446; // (140, 100, 70)
      final out = applyColorMatrix(
          bodyTintMatrix(swatch, _gray(200)), 0xFF64C832); // (100, 200, 50)
      expect([_r(out), _g(out), _b(out)], [70, 100, 18]);
    });

    test('기준색보다 밝은 입력은 255에서 잘리고, 알파는 그대로', () {
      final m = bodyTintMatrix(0xFFF3E4C4, _gray(200));
      final bright = applyColorMatrix(m, _gray(255));
      // 크림의 R·G는 기준보다 커서 잘리고, B(196)는 기준(200)보다 작아 250이다
      expect([_r(bright), _g(bright), _b(bright)], [255, 255, 250]);
      expect(applyColorMatrix(m, 0x80C8C8C8) >> 24, 0x80);
      expect(applyColorMatrix(m, _gray(0)), 0xFF000000);
    });
  });
}
