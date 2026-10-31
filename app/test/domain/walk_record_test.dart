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

  group('평균 분당 걸음', () {
    test('걸음 / 걸음이 있던 분, 반올림: 1750 ÷ 15 = 116.67 → 117', () {
      expect(summarizeWalk(gaits, from, from + 15, rules).avgSpm, 117);
      // 앞 10분은 100보 / 분
      expect(summarizeWalk(gaits, from, from + 10, rules).avgSpm, 100);
    });

    test('걸음 없는 분은 나누는 수에서 뺀다: [100, 0, 100] → 200 ÷ 2 = 100', () {
      final m = minutesFrom(_t0, [100, 0, 100]);
      expect(summarizeWalk(classifyGait(m, rules), from, from + 3, rules).avgSpm, 100);
    });

    test('걸음이 없으면 0', () {
      expect(summarizeWalk(const [], from, from + 3, rules).avgSpm, 0);
    });
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

  group('같은 분이 두 번 나오는 목록 (LiveWalk.minutes: 한 분 안에서 걷기/뛰기가 바뀐 경우)', () {
    final dup = [
      GaitMinute(from, 30, Gait.walk),
      GaitMinute(from, 40, Gait.run),
      GaitMinute(from + 1, 50, Gait.walk),
      GaitMinute(from + 2, 0, Gait.walk),
    ];

    test('걸은 분은 한 번만 센다: 0분(두 줄)·1분 = 2분, 평균 분당 걸음 120 ÷ 2 = 60', () {
      final s = summarizeWalk(dup, from, from + 3, rules);
      expect(s.activeMinutes, 2);
      expect(s.avgSpm, 60);
    });

    test('걸음·거리·뛴 걸음은 줄마다 더한다: 30 + 40 + 50 = 120보, 21 + 40 + 35 = 96m, 뛴 40보', () {
      final s = summarizeWalk(dup, from, from + 3, rules);
      expect(s.steps, 120);
      expect(s.distanceM, closeTo(96, 1e-9));
      expect(s.runSteps, 40);
    });

    test('가장 최근 걸음 분이 두 줄이면 둘을 더한다: 50 + 20 = 70보, 마지막 줄의 걷기/뛰기', () {
      final m = [
        GaitMinute(from, 100, Gait.walk),
        GaitMinute(from + 1, 50, Gait.walk),
        GaitMinute(from + 1, 20, Gait.run),
      ];
      final s = summarizeWalk(m, from, from + 2, rules);
      expect(s.lastSteps, 70);
      expect(s.lastGait, Gait.run);
    });
  });

  group('pickWalkNumbers: health와 센서 중 걸음이 많은 쪽 하나를 통째로', () {
    List<GaitMinute> live(int count, int steps, Gait gait, {int offset = 0}) =>
        [for (var i = 0; i < count; i++) GaitMinute(from + offset + i, steps, gait)];

    // health: 100보/분 15분 = 1,500보, 1,050m
    final health = classifyGait(minutesFrom(_t0, List.filled(15, 100)), rules);

    test('센서가 더 많으면 센서 값 전부 (걸음·거리·걸은 분·뛴 걸음·랩)', () {
      // 센서: 100보/분 10분 + 150보/분 5분 = 1,000 + 750 = 1,750보 > 1,500
      final sensor = [...live(10, 100, Gait.walk), ...live(5, 150, Gait.run, offset: 10)];
      final p = pickWalkNumbers(
        health: health,
        live: sensor,
        fromMinute: from,
        toMinute: from + 15,
        rules: rules,
      );
      expect(p.summary.steps, 1750);
      // 1,000 × 0.7 + 750 × 1.0 = 700 + 750 = 1,450m (health였다면 1,050m)
      expect(p.summary.distanceM, closeTo(1450, 1e-9));
      expect(p.summary.activeMinutes, 15);
      expect(p.summary.runSteps, 750);
      expect(p.summary.runRatio, closeTo(750 / 1750, 1e-12));
      // 700m는 10분 끝, 1km까지 300m는 분당 150m라 2분 더 = 12분 = 720초, 걸음 1,000 + 300 = 1,300.
      // 남은 450m는 900 - 720 = 180초, 걸음 1,750 - 1,300 = 450
      expect(p.laps.map((l) => l.duration.inSeconds), [720, 180]);
      expect(p.laps.map((l) => l.steps), [1300, 450]);
      expect(p.laps.last.distanceM, closeTo(450, 1e-9));
    });

    test('health가 더 많으면 health 값 전부', () {
      final p = pickWalkNumbers(
        health: health,
        live: live(10, 100, Gait.walk),
        fromMinute: from,
        toMinute: from + 15,
        rules: rules,
      );
      expect(p.summary.steps, 1500);
      expect(p.summary.distanceM, closeTo(1050, 1e-9));
      expect(p.summary.activeMinutes, 15);
      // 분당 70m: 1km는 14분 + 60초 × 20/70 = 857.14 → 857초, 걸음 1,428.57 → 1,429
      // 남은 50m는 900 - 857 = 43초, 걸음 1,500 - 1,429 = 71
      expect(p.laps.map((l) => l.duration.inSeconds), [857, 43]);
      expect(p.laps.map((l) => l.steps), [1429, 71]);
    });

    test('걸음이 같으면 health (센서가 뛰기로 쌓아 거리가 더 커도 섞지 않는다)', () {
      final p = pickWalkNumbers(
        health: health,
        live: live(15, 100, Gait.run),
        fromMinute: from,
        toMinute: from + 15,
        rules: rules,
      );
      // 센서였다면 1,500 × 1.0 = 1,500m, 뛴 걸음 1,500
      expect(p.summary.steps, 1500);
      expect(p.summary.distanceM, closeTo(1050, 1e-9));
      expect(p.summary.runSteps, 0);
      expect(p.laps.map((l) => l.steps), [1429, 71]);
    });

    test('센서 목록이 비었으면 health. 둘 다 비었으면 걸음 0에 랩 없음', () {
      final p = pickWalkNumbers(
        health: health,
        live: const [],
        fromMinute: from,
        toMinute: from + 15,
        rules: rules,
      );
      expect(p.summary.steps, 1500);
      expect(p.laps, hasLength(2));

      final none = pickWalkNumbers(
        health: const [],
        live: const [],
        fromMinute: from,
        toMinute: from + 15,
        rules: rules,
      );
      expect(none.summary.steps, 0);
      expect(none.laps, isEmpty);
    });

    test('health가 비어도 센서에 걸음이 있으면 센서', () {
      final p = pickWalkNumbers(
        health: const [],
        live: live(5, 100, Gait.walk),
        fromMinute: from,
        toMinute: from + 15,
        rules: rules,
      );
      expect(p.summary.steps, 500);
      expect(p.summary.distanceM, closeTo(350, 1e-9));
      expect(p.laps.single.partial, isTrue);
    });

    test('창 [from, to) 밖의 걸음은 비교에도 쓰지 않는다: 센서 20분이어도 창 10분이면 1,000보', () {
      // 창 10분: health 1,000보, 센서 1,000보(20분 중 10분) → 같아서 health.
      // 창 밖까지 셌다면 센서 2,000보라 센서가 이긴다
      final p = pickWalkNumbers(
        health: health,
        live: live(20, 100, Gait.run),
        fromMinute: from,
        toMinute: from + 10,
        rules: rules,
      );
      expect(p.summary.steps, 1000);
      expect(p.summary.distanceM, closeTo(700, 1e-9));
      expect(p.summary.runSteps, 0);
    });
  });
  group('창 안 가장 최근 걸음 분', () {
    test('마지막 걸음 있는 분의 걸음과 걷기/뛰기', () {
      // 100보 10분 → 150보 5분: 마지막은 150보, 뛰기
      final s = summarizeWalk(gaits, from, from + 15, rules);
      expect(s.lastSteps, 150);
      expect(s.lastGait, Gait.run);
      // 창을 앞 10분으로 자르면 마지막은 100보, 걷기
      final w = summarizeWalk(gaits, from, from + 10, rules);
      expect(w.lastSteps, 100);
      expect(w.lastGait, Gait.walk);
    });

    test('뒤쪽 걸음 없는 분은 건너뛰고 걸음이 있었던 마지막 분', () {
      final m = minutesFrom(_t0, [100, 120, 0, 0]);
      final s = summarizeWalk(classifyGait(m, rules), from, from + 4, rules);
      expect(s.lastSteps, 120);
      expect(s.lastGait, Gait.walk);
    });

    test('창 밖의 분은 보지 않고, 창 앞에서 이어진 뛰기 상태를 따른다', () {
      // 창 앞 150보(뛰기), 창 안 135보(직전 상태 = 뛰기), 창 뒤 100보
      final m = minutesFrom(_t0, [150, 135, 100]);
      final s = summarizeWalk(classifyGait(m, rules), from + 1, from + 2, rules);
      expect(s.lastSteps, 135);
      expect(s.lastGait, Gait.run);
    });

    test('창 안에 걸음이 없으면 0, 걷기', () {
      final m = minutesFrom(_t0, [150, 0, 0]);
      final s = summarizeWalk(classifyGait(m, rules), from + 1, from + 3, rules);
      expect(s.lastSteps, 0);
      expect(s.lastGait, Gait.walk);
      expect(summarizeWalk(const [], from, from + 3, rules).lastSteps, 0);
    });

    test('속도·보폭은 마지막 분의 걷기/뛰기로: 150보 뛰기 → 9.0km/h', () {
      final s = summarizeWalk(gaits, from, from + 15, rules);
      expect(speedKmh(s.lastSteps, s.lastGait, rules), closeTo(9.0, 1e-9));
      expect(strideM(s.lastGait, rules), 1.0);
    });
  });
}
