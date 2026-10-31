import 'package:doobal/domain/gait.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _t0 = DateTime.utc(2026, 11, 18, 1);

List<Gait> _gaits(List<int> spm) =>
    classifyGait(minutesFrom(_t0, spm), rules).map((m) => m.gait).toList();

void main() {
  test('#1 연속 5분 판정과 거리', () {
    final g = classifyGait(minutesFrom(_t0, [100, 135, 145, 135, 120]), rules);
    expect(g.map((m) => m.gait).toList(),
        [Gait.walk, Gait.walk, Gait.run, Gait.run, Gait.walk]);
    expect(distanceM(g, rules), closeTo(528.5, 1e-9));
  });

  group('#2 경계값', () {
    test('130 walk, 140 run, 139는 직전 run', () {
      expect(_gaits([130, 140, 139]), [Gait.walk, Gait.run, Gait.run]);
    });
    test('131은 직전 walk면 walk', () {
      expect(_gaits([120, 131]), [Gait.walk, Gait.walk]);
    });
  });

  test('judgeGait: 130 이하 walk, 140 이상 run, 131~139와 0은 직전 상태', () {
    expect(judgeGait(130, Gait.run, rules), Gait.walk);
    expect(judgeGait(140, Gait.walk, rules), Gait.run);
    expect(judgeGait(135, Gait.walk, rules), Gait.walk);
    expect(judgeGait(135, Gait.run, rules), Gait.run);
    expect(judgeGait(0, Gait.run, rules), Gait.run);
    expect(judgeGait(0, Gait.walk, rules), Gait.walk);
  });

  test('걸음 0인 분은 상태를 바꾸지 않고, 빈 분이 3분 이상이면 walk로 다시 시작', () {
    expect(_gaits([145, 0, 0, 135]), [Gait.run, Gait.run, Gait.run, Gait.run]);
    expect(_gaits([145, 0, 0, 0, 135]),
        [Gait.run, Gait.run, Gait.run, Gait.run, Gait.walk]);
  });
  group('보폭·속도', () {
    test('보폭은 걷기 0.7m, 뛰기 1.0m (config)', () {
      expect(strideM(Gait.walk, rules), 0.7);
      expect(strideM(Gait.run, rules), 1.0);
    });

    test('속도 km/h = 분당 걸음 × 보폭 × 60 ÷ 1000: 걷기 100보 → 4.2, 뛰기 160보 → 9.6', () {
      expect(speedKmh(100, Gait.walk, rules), closeTo(4.2, 1e-9));
      expect(speedKmh(160, Gait.run, rules), closeTo(9.6, 1e-9));
      expect(speedKmh(0, Gait.walk, rules), 0);
    });

    test('속도 m/s는 km/h ÷ 3.6과 같다', () {
      expect(speedMps(100, Gait.walk, rules), closeTo(70 / 60, 1e-12));
      expect(speedMps(160, Gait.run, rules), closeTo(speedKmh(160, Gait.run, rules) / 3.6, 1e-12));
    });

    test('distanceM은 보폭 함수와 같은 값을 쓴다', () {
      final g = classifyGait(minutesFrom(_t0, [100, 150]), rules);
      expect(distanceM(g, rules), closeTo(100 * 0.7 + 150 * 1.0, 1e-9));
    });
  });

  group('페이스', () {
    test('평균 페이스: 1000m를 12분 30초에 → 750초/km', () {
      expect(paceSecPerKm(1000, const Duration(minutes: 12, seconds: 30)), 750);
    });

    test('평균 페이스는 반올림: 700m를 10분에 → 600 ÷ 0.7 = 857.14 → 857', () {
      expect(paceSecPerKm(700, const Duration(minutes: 10)), 857);
      // 1050m를 15분에 → 900 ÷ 1.05 = 857.14 → 857
      expect(paceSecPerKm(1050, const Duration(minutes: 15)), 857);
    });

    test('거리가 0 이하면 null (시간이 0이어도 null)', () {
      expect(paceSecPerKm(0, const Duration(minutes: 5)), isNull);
      expect(paceSecPerKm(-1, const Duration(minutes: 5)), isNull);
      expect(paceSecPerKm(100, Duration.zero), isNull);
    });

    test('지금 페이스 = 3600 ÷ 속도: 걷기 100보 → 4.2km/h → 857, 뛰기 140보 → 8.4km/h → 429', () {
      expect(livePaceSecPerKm(100, Gait.walk, rules), 857);
      // 3600 ÷ 8.4 = 428.57 → 429
      expect(livePaceSecPerKm(140, Gait.run, rules), 429);
    });

    test('분당 걸음이 0이면 null', () {
      expect(livePaceSecPerKm(0, Gait.walk, rules), isNull);
      expect(livePaceSecPerKm(0, Gait.run, rules), isNull);
    });
  });
}
