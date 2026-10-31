import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/live_walk.dart';
import 'package:doobal/domain/walk_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _t0 = DateTime.utc(2026, 11, 18, 1);

DateTime _at(int sec) => _t0.add(Duration(seconds: sec));

/// 누적값 [total]을 [sec]초에 받는다
void _feed(LiveWalk w, int sec, int total) => w.onCount(total, _at(sec));

void main() {
  test('config의 분당 걸음 창은 30초', () {
    expect(rules.liveCadenceWindowSec, 30);
  });

  group('기준값과 증가', () {
    test('처음 받은 값은 기준값이라 세지 않는다', () {
      final w = LiveWalk(rules);
      expect(w.active, isFalse);

      _feed(w, 0, 123456);
      expect(w.active, isTrue);
      expect(w.steps, 0);
      expect(w.distanceM, 0);
      expect(w.stepsPerMin(_at(0)), 0);
    });

    test('그 뒤 증가분만 센다. 같은 값이 또 오면 그대로', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 1000);
      _feed(w, 5, 1010);
      expect(w.steps, 10);
      _feed(w, 6, 1010);
      expect(w.steps, 10);
      _feed(w, 10, 1025);
      expect(w.steps, 25);
    });

    test('누적값이 기준보다 작아지면(재부팅) 그 값이 새 기준이고, 쌓인 걸음은 그대로', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 50000);
      _feed(w, 5, 50020);
      expect(w.steps, 20);

      _feed(w, 10, 30);
      expect(w.steps, 20);
      expect(w.active, isTrue);

      _feed(w, 15, 45);
      expect(w.steps, 35);
    });

    test('재부팅 값이 0이어도 새 기준이다', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 900);
      _feed(w, 5, 910);
      _feed(w, 10, 0);
      expect(w.steps, 10);
      _feed(w, 15, 7);
      expect(w.steps, 17);
    });
  });

  group('resume: 꺼져 있던 동안의 증가는 버린다', () {
    test('rebase 뒤 첫 값이 새 기준이고 그 사이 늘어난 걸음은 세지 않는다', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 1000);
      _feed(w, 5, 1010);
      expect(w.steps, 10);

      w.rebase();
      expect(w.active, isFalse);
      // 한 시간 동안 800보가 쌓인 채로 돌아왔다
      _feed(w, 3600, 1810);
      expect(w.active, isTrue);
      expect(w.steps, 10);
      expect(w.distanceM, closeTo(7, 1e-9));

      _feed(w, 3605, 1820);
      expect(w.steps, 20);
    });

    test('rebase는 분당 걸음 창도 비운다', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 50);
      expect(w.stepsPerMin(_at(10)), 100);
      w.rebase();
      expect(w.stepsPerMin(_at(11)), 0);
    });
  });

  group('분당 걸음', () {
    test('최근 30초의 증가를 분당으로 바꾼다: 30초에 50보 → 100보', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 20);
      _feed(w, 20, 50);
      expect(w.stepsPerMin(_at(20)), 100);
      expect(w.stepsPerMin(_at(25)), 100);
    });

    test('창을 벗어난 증가는 빠진다: 30초가 지나면 오래된 것부터, 한참 멈추면 0', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 20);
      _feed(w, 20, 50);
      // 10초 증가(20보)는 정확히 30초 전이라 빠진다: 30보 → 60보
      expect(w.stepsPerMin(_at(40)), 60);
      expect(w.stepsPerMin(_at(49)), 60);
      expect(w.stepsPerMin(_at(50)), 0);
      expect(w.stepsPerMin(_at(300)), 0);
    });

    test('창이 차기 전에는 낮게 나와서 첫 몇 걸음으로 뛰기가 되지 않는다', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 2, 6);
      expect(w.stepsPerMin(_at(2)), 12);
      expect(w.gait, Gait.walk);
    });
  });

  group('걷기/뛰기', () {
    /// 10초에 [a]보, 20초에 [b]보 더 늘어난 걸음 (창 30초 안에 둘 다 있으니 분당 = (a + b) × 2)
    LiveWalk twoBursts(int a, int b) {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, a);
      _feed(w, 20, a + b);
      return w;
    }

    test('분당 130은 걷기, 140은 뛰기', () {
      final walk = twoBursts(35, 30);
      expect(walk.stepsPerMin(_at(20)), 130);
      expect(walk.gait, Gait.walk);

      final run = twoBursts(35, 35);
      expect(run.stepsPerMin(_at(20)), 140);
      expect(run.gait, Gait.run);
    });

    test('131~139는 직전 상태를 따른다: 걷다 올라오면 걷기', () {
      final w = twoBursts(30, 30);
      expect(w.gait, Gait.walk);
      // 한 번에 7보를 더해 60 + 7 = 67보 → 134
      _feed(w, 21, 67);
      expect(w.stepsPerMin(_at(21)), 134);
      expect(w.gait, Gait.walk);
    });

    test('131~139는 직전 상태를 따른다: 뛰다 내려오면 뛰기, 130 이하가 되어야 걷기', () {
      final w = twoBursts(35, 35);
      expect(w.gait, Gait.run);
      // 40초 시점 창(10초 초과분은 빠진다)에는 20초의 35보와 이번 33보 → 68보 → 136
      _feed(w, 40, 70 + 33);
      expect(w.stepsPerMin(_at(40)), 136);
      expect(w.gait, Gait.run);
      // 50초에는 40초의 33보와 이번 32보 → 65보 → 130
      _feed(w, 50, 70 + 33 + 32);
      expect(w.stepsPerMin(_at(50)), 130);
      expect(w.gait, Gait.walk);
    });

    test('걸음이 없던 시간이 sessionMaxGapMin(2분)보다 길면 새 걷기라 walk로 다시 시작', () {
      // 2분 뒤 134보(분당 134)가 한꺼번에: 정확히 2분이면 이어서 뛰는 중
      final cont = twoBursts(35, 35);
      _feed(cont, 20 + 120, 70 + 67);
      expect(cont.stepsPerMin(_at(140)), 134);
      expect(cont.gait, Gait.run);

      // 2분 1초면 새 걷기
      final fresh = twoBursts(35, 35);
      _feed(fresh, 20 + 121, 70 + 67);
      expect(fresh.stepsPerMin(_at(141)), 134);
      expect(fresh.gait, Gait.walk);
    });
  });

  group('거리 누적: 증가분 × 그때의 보폭', () {
    test('걷다가 뛰면 뛰기부터는 보폭 1.0m', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      // 10초에 35보: 창 35보 → 70 → 걷기 → 24.5m
      _feed(w, 10, 35);
      expect(w.distanceM, closeTo(24.5, 1e-9));
      // 20초에 35보 더: 창 70보 → 140 → 뛰기 → +35m
      _feed(w, 20, 70);
      expect(w.gait, Gait.run);
      expect(w.distanceM, closeTo(59.5, 1e-9));
      // 25초에 10보 더: 창 80보 → 160 → 뛰기 → +10m
      _feed(w, 25, 80);
      expect(w.distanceM, closeTo(69.5, 1e-9));
      expect(w.steps, 80);
    });

    test('재부팅·resume으로 기준을 다시 잡아도 쌓인 거리는 그대로', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 1000);
      _feed(w, 10, 1010);
      _feed(w, 20, 5);
      _feed(w, 30, 15);
      expect(w.distanceM, closeTo(20 * 0.7, 1e-9));
      w.rebase();
      _feed(w, 90, 900);
      expect(w.distanceM, closeTo(20 * 0.7, 1e-9));
    });
  });

  group('liveSummary: health 값과 합친다', () {
    const health = WalkSummary(
      steps: 1000,
      distanceM: 700,
      activeMinutes: 10,
      runSteps: 0,
      lastSteps: 100,
      lastGait: Gait.walk,
    );

    test('센서가 아직 기준값을 못 잡았으면 health 그대로 (health도 없으면 null)', () {
      final w = LiveWalk(rules);
      expect(identical(liveSummary(health, w, _at(0)), health), isTrue);
      expect(liveSummary(null, w, _at(0)), isNull);
    });

    test('센서 값이 더 크면 센서 값, health가 더 크면 health 값', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 35);
      final small = liveSummary(health, w, _at(10))!;
      expect(small.steps, 1000);
      expect(small.distanceM, 700);

      _feed(w, 20, 1500);
      final big = liveSummary(health, w, _at(20))!;
      expect(big.steps, 1500);
      expect(big.distanceM, greaterThan(700));
      expect(big.distanceM, w.distanceM);
    });

    test('분당 걸음과 걷기/뛰기는 센서 기준이고, 나머지(걸은 분·뛴 걸음)는 health 값', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 35);
      _feed(w, 20, 70);
      final s = liveSummary(health, w, _at(20))!;
      expect(s.lastSteps, 140);
      expect(s.lastGait, Gait.run);
      expect(s.activeMinutes, 10);
      expect(s.runSteps, 0);
    });

    test('health 기록이 아직 없어도 센서 값으로 만든다', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 20);
      final s = liveSummary(null, w, _at(10))!;
      expect(s.steps, 20);
      expect(s.distanceM, closeTo(14, 1e-9));
      expect(s.lastSteps, 40);
      expect(s.activeMinutes, 0);
    });

    test('가만히 서면 분당 걸음이 0으로 내려간다 (직전 걷기/뛰기는 유지)', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 35);
      _feed(w, 20, 70);
      final s = liveSummary(health, w, _at(100))!;
      expect(s.lastSteps, 0);
      expect(s.lastGait, Gait.run);
    });
  });
}
