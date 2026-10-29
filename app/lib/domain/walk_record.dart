import 'gait.dart';
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
}

/// 이미 걷기/뛰기로 나눈 분 중 [fromMinute, toMinute)(UTC epoch 분)만 모은다.
/// 걷기/뛰기 상태는 창 밖 분까지 이어서 판정한 값을 받으므로 창 앞쪽 분도 포함한 목록을 넘긴다
WalkSummary summarizeWalk(
  List<GaitMinute> minutes,
  int fromMinute,
  int toMinute,
  Rules rules,
) {
  final inWindow =
      minutes.where((m) => m.minute >= fromMinute && m.minute < toMinute).toList();
  final last = inWindow.where((m) => m.steps > 0).lastOrNull;
  return WalkSummary(
    steps: inWindow.fold(0, (sum, m) => sum + m.steps),
    distanceM: distanceM(inWindow, rules),
    activeMinutes: inWindow.where((m) => m.steps > 0).length,
    runSteps: inWindow
        .where((m) => m.gait == Gait.run)
        .fold(0, (sum, m) => sum + m.steps),
    lastSteps: last?.steps ?? 0,
    lastGait: last?.gait ?? Gait.walk,
  );
}
