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
}
