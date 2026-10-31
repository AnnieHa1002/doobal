import 'package:doobal/domain/bucket.dart';
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

  group('minutes: 분·걷기/뛰기별로 쌓은 걸음 (걷기 기록이 health 대신 쓴다)', () {
    // _t0 = 01:00:00. 분 번호는 첫 분 기준 상대값으로 본다
    final m0 = epochMinute(_t0);

    /// (분 - m0, 걸음, 걷기/뛰기)로 줄여서 비교한다
    List<(int, int, Gait)> shape(LiveWalk w) =>
        [for (final m in w.minutes) (m.minute - m0, m.steps, m.gait)];

    test('센 게 없거나 기준값만 받았으면 비어 있다 (첫 값은 버킷을 만들지 않는다)', () {
      final w = LiveWalk(rules);
      expect(w.minutes, isEmpty);
      _feed(w, 0, 123456);
      expect(w.minutes, isEmpty);
      // 같은 값이 또 와도 증가가 없다
      _feed(w, 5, 123456);
      expect(w.minutes, isEmpty);
    });

    test('다른 두 분의 증가는 버킷 둘: 0분 10+15 = 25보, 1분 20보', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 1000);
      _feed(w, 10, 1010);
      _feed(w, 50, 1025);
      // 60초부터는 1분
      _feed(w, 70, 1045);
      expect(shape(w), [(0, 25, Gait.walk), (1, 20, Gait.walk)]);
      expect(w.steps, 45);
    });

    test('한 분 안에서 걷기에서 뛰기로 바뀌면 그 분이 두 번 나온다 (걷기 먼저)', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      // 10초에 35보: 창 35보 → 70 → 걷기. 20초에 35보 더: 창 70보 → 140 → 뛰기
      _feed(w, 10, 35);
      _feed(w, 20, 70);
      // 25초에 10보 더: 창 80보 → 160 → 뛰기
      _feed(w, 25, 80);
      expect(shape(w), [(0, 35, Gait.walk), (0, 45, Gait.run)]);
    });

    test('Σ 걸음 × 보폭은 distanceM과 같다: 35 × 0.7 + 45 × 1.0 = 24.5 + 45 = 69.5m', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 35);
      _feed(w, 20, 70);
      _feed(w, 25, 80);
      expect(w.distanceM, closeTo(69.5, 1e-9));
      expect(distanceM(w.minutes, rules), closeTo(69.5, 1e-9));
      expect(w.minutes.fold(0, (sum, m) => sum + m.steps), w.steps);
    });

    test('분 순서로 돌려주고, 같은 분이면 걷기가 먼저다 (뛰다가 걷기로 내려와도)', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 35); // 창 35보 → 70 → 걷기: 0분 걷기 35
      _feed(w, 20, 70); // 창 70보 → 140 → 뛰기: 0분 뛰기 35
      _feed(w, 40, 103); // 10초 증가는 창 밖, 20초(35) + 33 = 68보 → 136 → 직전(뛰기): 0분 뛰기 +33
      _feed(w, 60, 143); // 20초 증가도 창 밖, 40초(33) + 40 = 73보 → 146 → 뛰기: 1분 뛰기 40
      _feed(w, 75, 168); // 40초(33)도 창 밖, 60초(40) + 25 = 65보 → 130 → 걷기: 1분 걷기 25
      // 1분은 뛰기가 먼저 들어왔지만 걷기를 앞에 둔다
      expect(shape(w), [
        (0, 35, Gait.walk),
        (0, 68, Gait.run),
        (1, 25, Gait.walk),
        (1, 40, Gait.run),
      ]);
      // 35 × 0.7 + 68 × 1.0 + 25 × 0.7 + 40 × 1.0 = 24.5 + 68 + 17.5 + 40 = 150m
      expect(w.distanceM, closeTo(150, 1e-9));
      expect(distanceM(w.minutes, rules), closeTo(150, 1e-9));
      expect(w.steps, 168);
    });

    test('rebase·재부팅 뒤에도 쌓인 버킷은 그대로, 새로 센 것은 이어서 쌓인다', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 1000);
      _feed(w, 10, 1010);
      expect(shape(w), [(0, 10, Gait.walk)]);

      w.rebase();
      expect(shape(w), [(0, 10, Gait.walk)]);
      // 한 시간 뒤 돌아온 첫 값은 기준값이라 버킷이 늘지 않는다
      _feed(w, 3600, 1810);
      expect(shape(w), [(0, 10, Gait.walk)]);
      // 그다음 증가는 61분 버킷
      _feed(w, 3605, 1820);
      expect(shape(w), [(0, 10, Gait.walk), (60, 10, Gait.walk)]);

      // 재부팅(값이 작아짐)도 기준만 다시 잡는다
      _feed(w, 3610, 5);
      _feed(w, 3615, 12);
      expect(shape(w), [(0, 10, Gait.walk), (60, 17, Gait.walk)]);
    });

    test('돌려준 목록은 그 시점의 복사본이다 (이후 센 걸음이 섞이지 않는다)', () {
      final w = LiveWalk(rules);
      _feed(w, 0, 0);
      _feed(w, 10, 20);
      final snapshot = w.minutes;
      _feed(w, 20, 50);
      expect(snapshot.single.steps, 20);
      expect(w.minutes.single.steps, 50);
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
