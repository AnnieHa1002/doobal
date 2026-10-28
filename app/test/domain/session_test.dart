import 'package:doobal/domain/session.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// KST 10:00
final _t0 = DateTime.utc(2026, 11, 18, 1);

List<int> _run(int minutes, int steps) => List.filled(minutes, steps);

void main() {
  test('#3 12분 × 100보 → 인정', () {
    final s = detectSessions(minutesFrom(_t0, _run(12, 100)), rules).single;
    expect(s.steps, 1200);
    expect(s.length.inMinutes, 12);
    expect(s.qualified, isTrue);
    expect(s.counted, isTrue);
  });

  test('#4 9분 × 150보 → 짧아서 불인정', () {
    final s = detectSessions(minutesFrom(_t0, _run(9, 150)), rules).single;
    expect(s.steps, 1350);
    expect(s.qualified, isFalse);
  });

  test('#5 15분 × 60보 → 걸음 부족', () {
    final s = detectSessions(minutesFrom(_t0, _run(15, 60)), rules).single;
    expect(s.steps, 900);
    expect(s.qualified, isFalse);
  });

  test('#6 빈틈 2분 → 구간 1개', () {
    final m = minutesFrom(_t0, [..._run(6, 100), 0, 0, ..._run(6, 100)]);
    final s = detectSessions(m, rules).single;
    expect(s.length.inMinutes, 14);
    expect(s.steps, 1200);
    expect(s.qualified, isTrue);
  });

  test('#7 빈틈 3분 → 구간 2개, 둘 다 불인정', () {
    final m = minutesFrom(_t0, [..._run(6, 100), 0, 0, 0, ..._run(6, 100)]);
    final s = detectSessions(m, rules);
    expect(s, hasLength(2));
    expect(s.every((x) => !x.qualified), isTrue);
  });

  test('#8 같은 날 인정 구간 4개 → 앞 3개만 counted', () {
    final block = [..._run(12, 100), 0, 0, 0, 0, 0];
    final s = detectSessions(minutesFrom(_t0, [for (var i = 0; i < 4; i++) ...block]), rules);
    expect(s.map((x) => x.qualified).toList(), [true, true, true, true]);
    expect(s.map((x) => x.counted).toList(), [true, true, true, false]);
  });

  test('#9 자정을 넘는 구간은 시작한 날로 친다', () {
    // KST 2026-11-17 23:55 시작 15분, 이어서 다음 날 인정 구간 3개
    final midnight = DateTime.utc(2026, 11, 17, 14, 55);
    final nextDay = [for (var i = 0; i < 3; i++) ...[..._run(12, 100), 0, 0, 0, 0, 0]];
    final m = [
      ...minutesFrom(midnight, _run(15, 100)),
      ...minutesFrom(DateTime.utc(2026, 11, 17, 16), nextDay),
    ];
    final s = detectSessions(m, rules);
    expect(kstDayKey(s.first.start), '2026-11-17');
    expect(kstDayKey(s.first.end), '2026-11-18');
    // 첫 구간이 다음 날 몫을 쓰지 않아서 다음 날 3개도 모두 counted
    expect(s.map((x) => x.counted).toList(), [true, true, true, true]);
  });
}
