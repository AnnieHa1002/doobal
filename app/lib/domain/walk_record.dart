import 'gait.dart';
import 'laps.dart';
import 'rules.dart';

/// 걷기 기록 화면의 숫자
class WalkSummary {
  const WalkSummary({
    required this.steps,
    required this.distanceM,
    required this.activeMinutes,
    required this.runSteps,
    required this.lastSteps,
    required this.lastGait,
  });

  final int steps;
  final double distanceM;

  /// 걸음이 있었던 분 수
  final int activeMinutes;

  /// 뛴 분의 걸음
  final int runSteps;

  /// 창 안에서 걸음이 있었던 가장 최근 분의 걸음(= 분당 걸음)과 걷기/뛰기.
  /// 걸음이 한 번도 없었으면 0, walk
  final int lastSteps;
  final Gait lastGait;

  /// 뛴 분 걸음 / 전체 걸음 (WalkSession.runRatio와 같은 정의). 걸음이 없으면 0
  double get runRatio => steps == 0 ? 0.0 : runSteps / steps;

  /// 평균 분당 걸음 = 걸음 / 걸음이 있었던 분 수, 반올림. 걸음이 있던 분이 없으면 0
  int get avgSpm => activeMinutes == 0 ? 0 : (steps / activeMinutes).round();
}

/// 이미 걷기/뛰기로 나눈 분 중 [fromMinute, toMinute)(UTC epoch 분)만 모은다.
/// 걷기/뛰기 상태는 창 밖 분까지 이어서 판정한 값을 받으므로 창 앞쪽 분도 포함한 목록을 넘긴다.
/// 한 분이 두 번 나올 수 있다(LiveWalk.minutes: 한 분 안에서 걷기/뛰기가 바뀐 경우):
/// 걸음·거리는 더하고, 걸음이 있었던 분 수는 한 번만 센다
WalkSummary summarizeWalk(
  List<GaitMinute> minutes,
  int fromMinute,
  int toMinute,
  Rules rules,
) {
  final inWindow =
      minutes.where((m) => m.minute >= fromMinute && m.minute < toMinute).toList();
  final last = inWindow.where((m) => m.steps > 0).lastOrNull;
  // 가장 최근 걸음 분이 두 번 나오면 둘을 더해 그 분의 걸음으로 본다
  final lastSteps = last == null
      ? 0
      : inWindow.where((m) => m.minute == last.minute).fold(0, (sum, m) => sum + m.steps);
  return WalkSummary(
    steps: inWindow.fold(0, (sum, m) => sum + m.steps),
    distanceM: distanceM(inWindow, rules),
    activeMinutes: inWindow.where((m) => m.steps > 0).map((m) => m.minute).toSet().length,
    runSteps: inWindow
        .where((m) => m.gait == Gait.run)
        .fold(0, (sum, m) => sum + m.steps),
    lastSteps: lastSteps,
    lastGait: last?.gait ?? Gait.walk,
  );
}

/// 걷기 기록에 쓸 숫자 하나: [health]와 [live](기기 걸음 센서) 분 목록 중 창 [fromMinute, toMinute)의
/// 걸음이 더 많은 쪽 하나를 통째로 쓴다. 걸음·거리·걸은 분·뛴 비율·랩이 서로 맞게 한 출처에서만 가져오고,
/// 같으면(센서가 비었을 때 포함) health다. health 기록은 늦게 들어오고, 센서는 앱이 앞에 있는 동안만
/// 세므로 어느 쪽이 모자랄지 몰라서 큰 쪽을 믿는다
({WalkSummary summary, List<Lap> laps}) pickWalkNumbers({
  required List<GaitMinute> health,
  required List<GaitMinute> live,
  required int fromMinute,
  required int toMinute,
  required Rules rules,
}) {
  final fromHealth = summarizeWalk(health, fromMinute, toMinute, rules);
  final fromLive = summarizeWalk(live, fromMinute, toMinute, rules);
  final useLive = fromLive.steps > fromHealth.steps;
  return (
    summary: useLive ? fromLive : fromHealth,
    laps: splitLaps(useLive ? live : health, fromMinute, toMinute, rules),
  );
}
