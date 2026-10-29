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
}
