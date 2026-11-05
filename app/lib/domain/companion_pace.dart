import 'dart:math' as math;

import 'companion.dart';
import 'rules.dart';

// 동행 걷기 연출 (M2, 10/28 동행 성격). 화면 연출만이라 저장하지 않는다 (앱을 닫으면 처음부터).
// 값을 그리는 것은 장면 쪽이다: 쉼터 트랙(T3) 뒤에 scene이 이 값을 읽는다

/// 지금 동작
enum PaceMotion { stand, walk, run }

/// 프레임 사이에 이어 가는 값
class PaceState {
  const PaceState({this.clockSec = 0, this.lagM = 0});

  /// 앞서 뛰기 시계(초): 사용자가 움직인 시간. 멈춰 있으면 안 간다
  final double clockSec;

  /// 뒤처진 거리(m)
  final double lagM;
}

/// 한 순간의 모습
class PaceFrame {
  const PaceFrame({required this.motion, this.aheadT = 0, this.lagM = 0});

  final PaceMotion motion;

  /// 앞서 나간 정도: 0 = 사용자 곁, 1 = 화면 오른쪽 밖
  final double aheadT;

  /// 뒤처진 거리(m): 0 = 사용자 곁, 늘수록 화면 왼쪽으로 밀려 밖으로 사라진다
  final double lagM;
}

/// 앞서 뛰기 안에서 어디쯤인가: 0 이상 1 미만, 앞서 뛰는 중이 아니면 null.
/// [PaceState.clockSec]가 aheadEverySec의 배수(1배부터)에 닿으면 시작해서 aheadAwaySec 동안이다
double? aheadProgress(double clockSec, Rules rules) {
  final every = rules.companionAheadEverySec;
  if (clockSec < every) return null;
  final inCycle = clockSec % every;
  final away = rules.companionAheadAwaySec;
  return inCycle < away ? inCycle / away : null;
}

/// 프레임 하나만큼 나아간다. [user]는 사용자의 동작, [userMps]는 사용자의 속도(m/s).
/// - ahead: 움직이는 동안 시계가 가고, 시작한 앞서 뛰기는 사용자가 멈춰도 끝까지 간다
/// - walkOnly: 사용자가 뛰면 뒤처진 거리가 (뛰기 속도 − 걷기 속도)로 늘고,
///   안 뛰면 lagCatchUpMps로 줄어 0에서 멈춘다
/// - match: 늘 곁이다
/// - 배 위에서는 모두 곁에 서 있다 (뒤처진 거리도 없어진다)
PaceState stepPace(
  PaceState state, {
  required CompanionPace pace,
  required PaceMotion user,
  required double userMps,
  required bool onSea,
  required double dt,
  required Rules rules,
}) {
  if (onSea || pace == CompanionPace.match) return PaceState(clockSec: state.clockSec);
  if (pace == CompanionPace.ahead) {
    final moving = user != PaceMotion.stand || aheadProgress(state.clockSec, rules) != null;
    return PaceState(clockSec: moving ? state.clockSec + dt : state.clockSec);
  }
  final lag = user == PaceMotion.run
      ? state.lagM + math.max(0.0, userMps - rules.companionWalkMps) * dt
      : math.max(0.0, state.lagM - rules.companionLagCatchUpMps * dt);
  return PaceState(clockSec: state.clockSec, lagM: lag);
}

/// [state]일 때의 모습.
/// - match: 사용자와 같은 동작·자리
/// - ahead: 같은 동작으로 따라가다, 앞서 뛰기의 앞 절반은 뛰어서 화면 밖까지 나가고
///   뒤 절반은 사용자 동작으로 돌아온다 (장면이 뒤로 흐르니 돌아오는 것처럼 보인다)
/// - walkOnly: 늘 걷기 동작. 사용자가 멈췄고 곁에 있을 때만 서 있다
/// - 배 위에서는 모두 서 있기
PaceFrame paceFrame(
  PaceState state, {
  required CompanionPace pace,
  required PaceMotion user,
  required bool onSea,
  required Rules rules,
}) {
  if (onSea) return const PaceFrame(motion: PaceMotion.stand);
  switch (pace) {
    case CompanionPace.match:
      return PaceFrame(motion: user);
    case CompanionPace.walkOnly:
      final idle = user == PaceMotion.stand && state.lagM <= 0;
      return PaceFrame(motion: idle ? PaceMotion.stand : PaceMotion.walk, lagM: state.lagM);
    case CompanionPace.ahead:
      final p = aheadProgress(state.clockSec, rules);
      if (p == null) return PaceFrame(motion: user);
      if (p < 0.5) return PaceFrame(motion: PaceMotion.run, aheadT: p * 2);
      return PaceFrame(
        motion: user == PaceMotion.stand ? PaceMotion.walk : user,
        aheadT: (1 - p) * 2,
      );
  }
}

/// 걷기를 마칠 때 뒤처져 있던 [lagM]으로 쉼터에 늦게 도착하기까지의 시간(초).
/// lagM ÷ 걷기 속도, 최대 lateArrivalMaxSec. 뒤처지지 않았으면 0
double lateArrivalSec(double lagM, Rules rules) => lagM <= 0
    ? 0
    : math.min(lagM / rules.companionWalkMps, rules.companionLateArrivalMaxSec);

/// 쉼터 불 옆 자리에 앉아 있는가: 걷기를 마치고 [sinceFinishSec]초 지났을 때.
/// 그전에는 자리가 비어 있다가 걸어 들어온다
bool seatedAtCamp({required double lateSec, required double sinceFinishSec}) =>
    sinceFinishSec >= lateSec;
