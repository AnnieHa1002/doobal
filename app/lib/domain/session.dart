import 'bucket.dart';
import 'gait.dart';
import 'rules.dart';
import 'time_kst.dart';

class WalkSession {
  const WalkSession({
    required this.start,
    required this.end,
    required this.steps,
    required this.distanceM,
    required this.runRatio,
    required this.qualified,
    required this.counted,
  });

  final DateTime start;
  final DateTime end;
  final int steps;
  final double distanceM;

  /// 뛴 분 걸음 / 전체 걸음
  final double runRatio;

  /// 길이·걸음 기준을 넘은 '걷기 1번'
  final bool qualified;

  /// qualified 중 그날(시작 시각의 한국 날짜) 앞에서부터 하루 최대 횟수까지
  final bool counted;

  Duration get length => end.difference(start);
}

/// 걸음 > 0인 분이 이어진 구간을 찾는다. 빈 분이 sessionMaxGapMin 이하면 같은 구간.
/// 길이는 첫 분 시작 ~ 마지막 분 끝(빈틈 포함). minutes는 시간순
List<WalkSession> detectSessions(List<StepMinute> minutes, Rules rules) {
  final groups = <List<StepMinute>>[];
  for (final m in minutes.where((m) => m.steps > 0)) {
    if (groups.isEmpty ||
        m.minute - groups.last.last.minute - 1 > rules.sessionMaxGapMin) {
      groups.add([]);
    }
    groups.last.add(m);
  }

  final countedPerDay = <String, int>{};
  return [
    for (final g in groups) _toSession(g, rules, countedPerDay),
  ];
}

WalkSession _toSession(
  List<StepMinute> g,
  Rules rules,
  Map<String, int> countedPerDay,
) {
  final gaits = classifyGait(g, rules);
  final steps = g.fold(0, (sum, m) => sum + m.steps);
  final runSteps = gaits
      .where((m) => m.gait == Gait.run)
      .fold(0, (sum, m) => sum + m.steps);
  final start = g.first.startUtc;
  final end = StepMinute(g.last.minute + 1, 0).startUtc;
  final lengthMin = g.last.minute - g.first.minute + 1;
  final qualified =
      lengthMin >= rules.sessionMinMin && steps >= rules.sessionMinSteps;

  var counted = false;
  if (qualified) {
    final day = kstDayKey(start);
    final n = countedPerDay[day] ?? 0;
    if (n < rules.sessionMaxPerDay) {
      countedPerDay[day] = n + 1;
      counted = true;
    }
  }

  return WalkSession(
    start: start,
    end: end,
    steps: steps,
    distanceM: distanceM(gaits, rules),
    runRatio: runSteps / steps,
    qualified: qualified,
    counted: counted,
  );
}
