import 'package:doobal/domain/color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lerpArgb', () {
    test('t 0은 앞 색, 1은 뒤 색 (불투명)', () {
      expect(lerpArgb(0xFF102030, 0xFFA0B0C0, 0), 0xFF102030);
      expect(lerpArgb(0xFF102030, 0xFFA0B0C0, 1), 0xFFA0B0C0);
    });

    test('채널별로 섞고 반올림한다 (50.5 → 51)', () {
      // R (0x18+0x3E)/2=43 · G (0x21+0x44)/2=50.5→51 · B (0x3A+0x68)/2=81
      expect(lerpArgb(0xFF18213A, 0xFF3E4468, 0.5), 0xFF2B3351);
    });

    test('입력 알파와 상관없이 결과는 불투명', () {
      expect(lerpArgb(0x00FFFFFF, 0x00000000, 0.5) >> 24, 0xFF);
    });
  });

  group('hex', () {
    test('argbFromHex: #RRGGBB → 불투명 ARGB (대소문자 무관)', () {
      expect(argbFromHex('#2B2522'), 0xFF2B2522);
      expect(argbFromHex('#a1b2c3'), 0xFFA1B2C3);
      expect(argbFromHex('#000000'), 0xFF000000);
    });

    test('hexFromArgb: 대문자 #RRGGBB, 알파는 버리고 앞자리는 0으로 채운다', () {
      expect(hexFromArgb(0xFF2B2522), '#2B2522');
      expect(hexFromArgb(0x80A1B2C3), '#A1B2C3');
      expect(hexFromArgb(0xFF000001), '#000001');
    });

    test('왕복', () {
      for (final hex in ['#000000', '#FFFFFF', '#F6E1D3', '#4F6F9E']) {
        expect(hexFromArgb(argbFromHex(hex)), hex);
      }
    });
  });

  group('HSL', () {
    test('기본색: 빨강 0도, 초록 120도, 파랑 240도, 검정·흰색·회색은 채도 0', () {
      expect(hslOfArgb(0xFFFF0000), (h: 0.0, s: 1.0, l: 0.5));
      expect(hslOfArgb(0xFF00FF00), (h: 120.0, s: 1.0, l: 0.5));
      expect(hslOfArgb(0xFF0000FF), (h: 240.0, s: 1.0, l: 0.5));
      expect(hslOfArgb(0xFF000000), (h: 0.0, s: 0.0, l: 0.0));
      expect(hslOfArgb(0xFFFFFFFF), (h: 0.0, s: 0.0, l: 1.0));
      expect(hslOfArgb(0xFF808080).s, 0);
      expect(hslOfArgb(0xFF808080).l, closeTo(128 / 255, 1e-9));
    });

    test('노랑 60도, 보라 300도, 색조는 0~360', () {
      expect(hslOfArgb(0xFFFFFF00).h, 60);
      expect(hslOfArgb(0xFFFF00FF).h, 300);
      expect(hslOfArgb(0xFFFF0080).h, closeTo(329.88, 0.01));
    });

    test('argbOfHsl: 기본색과 360도 돌리기', () {
      expect(argbOfHsl(0, 1, 0.5), 0xFFFF0000);
      expect(argbOfHsl(120, 1, 0.5), 0xFF00FF00);
      expect(argbOfHsl(240, 1, 0.5), 0xFF0000FF);
      expect(argbOfHsl(360, 1, 0.5), 0xFFFF0000);
      expect(argbOfHsl(-120, 1, 0.5), 0xFF0000FF);
      expect(argbOfHsl(0, 0, 0.5), 0xFF808080);
      expect(argbOfHsl(77, 0.3, 0), 0xFF000000);
      expect(argbOfHsl(77, 0.3, 1), 0xFFFFFFFF);
    });

    test('견본색은 HSL을 거쳐 돌아와도 같다', () {
      for (final argb in [0xFF2B2522, 0xFF4F6F9E, 0xFFE39AB0, 0xFFF6E1D3, 0xFF966242]) {
        final c = hslOfArgb(argb);
        expect(argbOfHsl(c.h, c.s, c.l), argb, reason: argb.toRadixString(16));
      }
    });
  });
}
