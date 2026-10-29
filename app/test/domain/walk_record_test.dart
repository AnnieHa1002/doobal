import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/walk_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// KST 10:00
final _t0 = DateTime.utc(2026, 11, 18, 1);

void main() {
  // 100보/분 10분 → 150보/분 5분
  final minutes = minutesFrom(_t0, [...List.filled(10, 100), ...List.filled(5, 150)]);
  final gaits = classifyGait(minutes, rules);
  final from = epochMinute(_t0);

  test('걸음 1750, 거리 700 + 750 = 1450m, 뛴 비율 750/1750', () {
    final s = summarizeWalk(gaits, from, from + 15, rules);
    expect(s.steps, 1750);
    expect(s.distanceM, closeTo(1450, 1e-9));
    expect(s.activeMinutes, 15);
    expect(s.runSteps, 750);
    expect(s.runRatio, closeTo(750 / 1750, 1e-12));
  });

  test('창 [from, to) 밖의 분은 뺀다', () {
    // 앞 3분 · 뒤 2분을 뺀 10분: 걷기 7분(700보) + 뛰기 3분(450보)
    final s = summarizeWalk(gaits, from + 3, from + 13, rules);
    expect(s.steps, 700 + 450);
    expect(s.distanceM, closeTo(490 + 450, 1e-9));
    expect(s.activeMinutes, 10);
    expect(s.runSteps, 450);
  });

  test('끝 분은 포함하지 않는다 (반열린 구간)', () {
    final s = summarizeWalk(gaits, from + 10, from + 11, rules);
    expect(s.steps, 150);
    expect(summarizeWalk(gaits, from, from, rules).steps, 0);
  });

  test('창 앞에서 이어진 뛰기 상태를 따른다 (135보는 직전 상태)', () {
    final m = minutesFrom(_t0, [150, 135, 135]);
    final s = summarizeWalk(classifyGait(m, rules), from + 1, from + 3, rules);
    expect(s.runSteps, 270);
    expect(s.runRatio, 1.0);
  });

  test('걸음 없는 분은 활동 시간에서 빼고, 걸음이 없으면 비율 0', () {
    final m = minutesFrom(_t0, [100, 0, 100]);
    final s = summarizeWalk(classifyGait(m, rules), from, from + 3, rules);
    expect(s.activeMinutes, 2);
    expect(summarizeWalk(const [], from, from + 3, rules).runRatio, 0);
  });
}
