import 'package:doobal/domain/sky.dart';
import 'package:doobal/domain/time_tint.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('timeTintOf: config.json 값 그대로', () {
    test('새벽 #8C7BA8 32% / 25%', () {
      final t = timeTintOf(SkyPhase.dawn, rules)!;
      expect(t.color, 0xFF8C7BA8);
      expect(t.background, 0.32);
      expect(t.character, 0.25);
    });

    test('아침 #F2C9A0 20% / 15%', () {
      final t = timeTintOf(SkyPhase.morning, rules)!;
      expect(t.color, 0xFFF2C9A0);
      expect(t.background, 0.20);
      expect(t.character, 0.15);
    });

    test('노을 #E58A6A 32% / 25%', () {
      final t = timeTintOf(SkyPhase.sunset, rules)!;
      expect(t.color, 0xFFE58A6A);
      expect(t.background, 0.32);
      expect(t.character, 0.25);
    });

    test('밤 #1F2A3C 52% / 38%', () {
      final t = timeTintOf(SkyPhase.night, rules)!;
      expect(t.color, 0xFF1F2A3C);
      expect(t.background, 0.52);
      expect(t.character, 0.38);
    });

    test('낮은 입히지 않는다 (null)', () {
      expect(timeTintOf(SkyPhase.day, rules), isNull);
    });

    test('config의 키는 모두 하늘 단계 이름이고 낮은 없다', () {
      final phases = SkyPhase.values.map((p) => p.name).toSet();
      expect(rules.timeTint.keys.toSet(), phases.difference({'day'}));
    });
  });

  group('multiplyFactor: 흰색에서 색 쪽으로 세기만큼', () {
    test('세기 0은 흰색, 1은 그 색', () {
      expect(multiplyFactor(0xFF1F2A3C, 0), 0xFFFFFFFF);
      expect(multiplyFactor(0xFF1F2A3C, 1), 0xFF1F2A3C);
    });

    test('밤 배경 52%: 채널별 lerp(255, c, 0.52)', () {
      // R 255-224×0.52=138.52→139, G 255-213×0.52=144.24→144, B 255-195×0.52=153.6→154
      expect(multiplyFactor(0xFF1F2A3C, 0.52), 0xFF8B909A);
    });

    test('밤 캐릭터 38%', () {
      // R 255-224×0.38=169.88→170, G 255-213×0.38=174.06→174, B 255-195×0.38=180.9→181
      expect(multiplyFactor(0xFF1F2A3C, 0.38), 0xFFAAAEB5);
    });

    test('새벽 배경 32%', () {
      // R 255-115×0.32=218.2→218, G 255-132×0.32=212.76→213, B 255-87×0.32=227.16→227
      expect(multiplyFactor(0xFF8C7BA8, 0.32), 0xFFDAD5E3);
    });

    test('결과는 항상 불투명하고, 세기가 클수록 어두워진다 (config 값 전부)', () {
      for (final t in rules.timeTint.values) {
        final bg = multiplyFactor(t.color, t.background);
        final ch = multiplyFactor(t.color, t.character);
        expect(bg >> 24, 0xFF);
        expect(ch >> 24, 0xFF);
        // 배경이 더 세다: 채널마다 같거나 더 어둡다
        for (final shift in [16, 8, 0]) {
          expect((bg >> shift) & 0xFF, lessThanOrEqualTo((ch >> shift) & 0xFF));
        }
      }
    });
  });
}
