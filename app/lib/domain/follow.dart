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

/// 화면에 보이는 걸음 수를 최신 걸음 수로 부드럽게 따라 올린다.
/// 걸음 센서는 걷기 시작하고 몇 걸음을 모아 한꺼번에 보내고, health 기록은 30초마다 몰려 들어와서
/// 숫자가 9 → 16처럼 뛰어 보인다. 몰려 온 만큼을 [catchUpSec] 안에 같은 빠르기로 따라잡되
/// 초당 [minPerSec]보다 느리지 않게 올린다 (사람 걸음 초당 약 2보보다 빨라서 걸을 때는 늘 바로 따라간다).
/// 빠르기는 남은 걸음이 그 빠르기로 [catchUpSec] 안에 못 닿을 만큼 몰려 왔을 때 다시 잰다
/// (남은 만큼을 매번 다시 나누면 끝에서 느려져 제때 닿지 않는다). 목표를 넘지 않고 뒤로 가지 않는다
class CountFollower {
  CountFollower({this.catchUpSec = 1.5, this.minPerSec = 3});

  final double catchUpSec;
  final double minPerSec;

  var _shown = 0.0;
  var _rate = 0.0;

  /// 화면에 쓰는 걸음 수 (버림)
  int get shown => _shown.floor();

  /// [dtSec]초 동안 [target]을 따라간다
  void step(int target, double dtSec) {
    final gap = target - _shown;
    if (gap <= 0 || dtSec <= 0) return;
    if (_rate * catchUpSec < gap) _rate = math.max(minPerSec, gap / catchUpSec);
    // 소수 덧셈 오차로 목표 바로 아래에 멈추지 않게 아주 작은 남은 몫은 닿은 것으로 본다
    if (_rate * dtSec >= gap - 1e-6) {
      _shown = target.toDouble();
      // 다 따라잡았으니 다음에 몰려 오면 빠르기를 새로 잰다
      _rate = 0;
    } else {
      _shown += _rate * dtSec;
    }
  }

  /// 따라가지 않고 바로 맞춘다 (화면이 꺼졌던 동안의 걸음이 한꺼번에 들어왔을 때, 거리와 같이)
  void snap(int target) {
    if (target > _shown) _shown = target.toDouble();
    _rate = 0;
  }
}
