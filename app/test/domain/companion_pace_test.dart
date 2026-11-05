import 'package:doobal/domain/companion.dart';
import 'package:doobal/domain/companion_pace.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 동행 걷기 연출 (M2): 값은 모두 config companions.pace에서 읽는다

void main() {
  /// [seconds]초 동안 [step]초씩 나아간다
  PaceState run(
    PaceState s,
    CompanionPace pace,
    PaceMotion user, {
    required double seconds,
    double userMps = 0,
    bool onSea = false,
    double step = 0.5,
  }) {
    var out = s;
    for (var t = 0.0; t < seconds; t += step) {
      out = stepPace(out,
          pace: pace, user: user, userMps: userMps, onSea: onSea, dt: step, rules: rules);
    }
    return out;
  }

  PaceFrame frame(PaceState s, CompanionPace pace, PaceMotion user, {bool onSea = false}) =>
      paceFrame(s, pace: pace, user: user, onSea: onSea, rules: rules);

  final every = rules.companionAheadEverySec;
  final away = rules.companionAheadAwaySec;
  final walkMps = rules.companionWalkMps;
  const runMps = 2.5;

  group('match: 사용자와 같은 동작·자리', () {
    test('동작을 그대로 따르고 뒤처지거나 앞서지 않는다', () {
      for (final user in PaceMotion.values) {
        final s = run(const PaceState(), CompanionPace.match, user,
            seconds: every + away, userMps: runMps);
        final f = frame(s, CompanionPace.match, user);
        expect((f.motion, f.aheadT, f.lagM), (user, 0, 0));
      }
    });
  });

  group('ahead: 앞서 뛰어갔다 돌아오기', () {
    test('aheadEverySec 전에는 곁에서 같은 동작이다', () {
      final s = run(const PaceState(), CompanionPace.ahead, PaceMotion.walk, seconds: every - 1);
      final f = frame(s, CompanionPace.ahead, PaceMotion.walk);
      expect((f.motion, f.aheadT), (PaceMotion.walk, 0));
    });

    test('aheadEverySec마다 뛰어서 화면 밖까지 갔다가 aheadAwaySec 뒤 돌아온다', () {
      expect(aheadProgress(every - 0.01, rules), isNull);
      expect(aheadProgress(every, rules), 0);
      expect(aheadProgress(every + away, rules), isNull);
      expect(aheadProgress(every * 2 + away / 2, rules), closeTo(0.5, 1e-9));
      expect(aheadProgress(every * 2 + away, rules), isNull);

      PaceFrame at(double sec) =>
          frame(PaceState(clockSec: sec), CompanionPace.ahead, PaceMotion.walk);
      expect((at(every + away / 4).motion, at(every + away / 4).aheadT), (PaceMotion.run, 0.5));
      expect(at(every + away / 2).aheadT, 1, reason: '가운데에서 화면 밖');
      expect((at(every + away * 3 / 4).motion, at(every + away * 3 / 4).aheadT),
          (PaceMotion.walk, 0.5));
      expect((at(every + away).motion, at(every + away).aheadT), (PaceMotion.walk, 0));
    });

    test('뒤처지지 않는다: 사용자가 뛰면 같이 뛴다', () {
      final s = run(const PaceState(), CompanionPace.ahead, PaceMotion.run,
          seconds: every - 1, userMps: runMps);
      final f = frame(s, CompanionPace.ahead, PaceMotion.run);
      expect((f.motion, f.lagM), (PaceMotion.run, 0));
    });

    test('멈춰 있으면 시계가 안 가고, 시작한 앞서 뛰기는 끝까지 간다', () {
      final idle = run(const PaceState(), CompanionPace.ahead, PaceMotion.stand, seconds: every * 2);
      expect(idle.clockSec, 0);
      expect(frame(idle, CompanionPace.ahead, PaceMotion.stand).motion, PaceMotion.stand);

      final dash = run(PaceState(clockSec: every), CompanionPace.ahead, PaceMotion.stand,
          seconds: away + 1);
      expect(dash.clockSec, closeTo(every + away, 0.5));
      expect(aheadProgress(dash.clockSec, rules), isNull);
    });
  });

  group('walkOnly: 뛰면 뒤처지고 걸으면 따라온다', () {
    test('늘 걷기 동작이다', () {
      expect(frame(const PaceState(), CompanionPace.walkOnly, PaceMotion.run).motion, PaceMotion.walk);
      expect(frame(const PaceState(), CompanionPace.walkOnly, PaceMotion.walk).motion, PaceMotion.walk);
    });

    test('뛰면 lagM이 (뛰기 속도 − 걷기 속도)로 는다', () {
      final s = run(const PaceState(), CompanionPace.walkOnly, PaceMotion.run,
          seconds: 10, userMps: runMps);
      expect(s.lagM, closeTo((runMps - walkMps) * 10, 1e-9));
      expect(frame(s, CompanionPace.walkOnly, PaceMotion.run).lagM, s.lagM);
    });

    test('걷기 속도보다 느리게 뛰어도 줄지는 않는다', () {
      final s = run(const PaceState(lagM: 5), CompanionPace.walkOnly, PaceMotion.run,
          seconds: 10, userMps: walkMps - 0.5);
      expect(s.lagM, 5);
    });

    test('걸으면 lagCatchUpMps로 줄고 0에서 멈춘다', () {
      final catchUp = rules.companionLagCatchUpMps;
      final s = run(const PaceState(lagM: 10), CompanionPace.walkOnly, PaceMotion.walk,
          seconds: 4, userMps: walkMps);
      expect(s.lagM, closeTo(10 - catchUp * 4, 1e-9));
      final done = run(const PaceState(lagM: 1), CompanionPace.walkOnly, PaceMotion.walk,
          seconds: 60, userMps: walkMps);
      expect(done.lagM, 0);
    });

    test('사용자가 멈춰도 뒤에서 걸어온다. 곁에 오면 선다', () {
      final s = run(const PaceState(lagM: 10), CompanionPace.walkOnly, PaceMotion.stand, seconds: 2);
      expect(s.lagM, lessThan(10));
      expect(frame(s, CompanionPace.walkOnly, PaceMotion.stand).motion, PaceMotion.walk);
      expect(frame(const PaceState(), CompanionPace.walkOnly, PaceMotion.stand).motion,
          PaceMotion.stand);
    });
  });

  group('쉼터 늦은 도착', () {
    test('lagM ÷ 걷기 속도', () {
      expect(lateArrivalSec(0, rules), 0);
      expect(lateArrivalSec(13, rules), closeTo(13 / walkMps, 1e-9));
    });

    test('lateArrivalMaxSec에서 멈춘다', () {
      final max = rules.companionLateArrivalMaxSec;
      expect(lateArrivalSec(walkMps * max * 10, rules), max);
    });

    test('그 시간이 지나면 자리에 앉아 있다', () {
      final late = lateArrivalSec(13, rules);
      expect(seatedAtCamp(lateSec: late, sinceFinishSec: late - 1), isFalse);
      expect(seatedAtCamp(lateSec: late, sinceFinishSec: late), isTrue);
      expect(seatedAtCamp(lateSec: 0, sinceFinishSec: 0), isTrue);
    });
  });

  group('배 위', () {
    test('모두 서 있고 앞서 뛰지 않고 뒤처진 거리도 없어진다', () {
      for (final pace in CompanionPace.values) {
        final s = run(PaceState(clockSec: every, lagM: 9), pace, PaceMotion.run,
            seconds: 3, userMps: runMps, onSea: true);
        final f = frame(s, pace, PaceMotion.run, onSea: true);
        expect((s.lagM, f.motion, f.aheadT, f.lagM), (0, PaceMotion.stand, 0, 0), reason: '$pace');
        expect(s.clockSec, every, reason: '$pace: 배 위에서는 시계가 안 간다');
      }
    });
  });
}
