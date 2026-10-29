import 'dart:math' as math;

/// 화면에 보이는 거리(shownM)가 최신 목표(targetM)를 따라가는 한 걸음(dtSec초).
/// 속도 = max(speedMps, 남은 거리 ÷ refreshSec). 목표를 넘지 않고 뒤로 가지 않는다.
/// 남은 거리를 매번 다시 나누면 지수로 줄어(1주기에 약 63%) 끝없이 가까워지기만 하므로,
/// 한 주기 안에 확실히 닿게 하려면 부르는 쪽이 목표가 바뀔 때 잰
/// (그때 남은 거리 ÷ refreshSec)을 speedMps에 넣어 준다
double followDistance(
  double shownM,
  double targetM,
  double speedMps,
  double dtSec,
  double refreshSec,
) {
  final gap = targetM - shownM;
  if (gap <= 0 || dtSec <= 0) return shownM;
  final rate = math.max(speedMps, gap / refreshSec);
  return rate * dtSec >= gap ? targetM : shownM + rate * dtSec;
}
