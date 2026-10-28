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
}
