import 'dart:math' as math;

import 'gait.dart';
import 'rules.dart';
import 'walk_record.dart';

class _Gain {
  const _Gain(this.at, this.steps);

  final DateTime at;
  final int steps;
}

/// 기기 걸음 센서(부팅 이후 누적값)로 내는 걷는 중의 실시간 걸음·거리·분당 걸음.
/// health 기록과 달리 늦게 들어오지 않아서 걷는 중 화면 표시에 쓰고, 진행·보상 기준은 아니다.
/// 시각은 부르는 쪽이 넘겨서 순수하게 계산한다
class LiveWalk {
  LiveWalk(this.rules);

  final Rules rules;

  /// 마지막으로 본 누적값. 기준을 잡기 전(처음, [rebase] 직후)에는 null
  int? _last;
  var _steps = 0;
  var _distanceM = 0.0;
  var _gait = Gait.walk;
  DateTime? _lastStepAt;
  final _gains = <_Gain>[];

  /// 기준값을 잡았는가 (센서가 값을 주고 있다)
  bool get active => _last != null;

  /// 기준 뒤 늘어난 걸음 (재부팅·resume으로 기준을 다시 잡아도 쌓인 값은 그대로)
  int get steps => _steps;

  /// 늘어난 걸음 × 그때의 보폭을 쌓은 거리(m)
  double get distanceM => _distanceM;

  /// 마지막으로 판정한 걷기/뛰기. 걸음이 없던 동안에는 그대로 둔다 (그래서 달리는 중인지는 분당 걸음 > 0도 본다)
  Gait get gait => _gait;

  /// 센서 값 하나. 처음(또는 [rebase] 뒤) 값은 기준값이라 세지 않고, 그 뒤 증가분만 센다.
  /// 값이 기준보다 작아지면 재부팅으로 카운터가 0부터 다시 시작한 것이라 그 값을 새 기준으로 잡는다
  void onCount(int total, DateTime at) {
    final last = _last;
    _last = total;
    if (last == null || total <= last) return;
    final gain = total - last;

    // 걸음이 없던 시간이 sessionMaxGapMin보다 길면 새 걷기라 walk로 다시 시작한다 (classifyGait와 같은 규칙)
    final lastStepAt = _lastStepAt;
    if (lastStepAt != null &&
        at.difference(lastStepAt) > Duration(minutes: rules.sessionMaxGapMin)) {
      _gait = Gait.walk;
    }
    _lastStepAt = at;

    _gains
      ..removeWhere((g) => !_inWindow(g.at, at))
      ..add(_Gain(at, gain));
    _gait = judgeGait(stepsPerMin(at), _gait, rules);
    _steps += gain;
    _distanceM += gain * strideM(_gait, rules);
  }

  /// 앱이 다시 켜졌다: 다음 값을 새 기준으로 잡는다. 꺼져 있던 동안 쌓인 센서 걸음은 세지 않는다
  void rebase() {
    _last = null;
    _gains.clear();
  }

  /// [now] 기준 최근 liveCadenceWindowSec초 동안의 걸음을 분당으로 환산한 값.
  /// 창이 차기 전에는 낮게 나온다 (첫 걸음 몇 개로 뛰기로 튀지 않게)
  int stepsPerMin(DateTime now) {
    final recent = _gains.where((g) => _inWindow(g.at, now)).fold(0, (sum, g) => sum + g.steps);
    return (recent * 60 / rules.liveCadenceWindowSec).round();
  }

  bool _inWindow(DateTime at, DateTime now) =>
      now.difference(at) < Duration(seconds: rules.liveCadenceWindowSec);
}

/// 걷는 중 화면에 보이는 이번 걷기 숫자: 걸음·거리는 health 기록과 센서 중 큰 쪽,
/// 분당 걸음과 걷기/뛰기는 센서 기준. 센서가 아직 값을 주지 않으면 health 그대로
/// (health 기록도 아직 없으면 null)
WalkSummary? liveSummary(WalkSummary? health, LiveWalk live, DateTime now) {
  if (!live.active) return health;
  return WalkSummary(
    steps: math.max(health?.steps ?? 0, live.steps),
    distanceM: math.max(health?.distanceM ?? 0, live.distanceM),
    activeMinutes: health?.activeMinutes ?? 0,
    runSteps: health?.runSteps ?? 0,
    lastSteps: live.stepsPerMin(now),
    lastGait: live.gait,
  );
}
