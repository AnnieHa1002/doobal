import 'dart:math' as math;

import 'gait.dart' as gait;
import 'rules.dart';

/// 거리를 비교할 때 허용하는 오차(m). 보폭 곱셈의 부동소수점 찌꺼기를 흡수한다
const _epsM = 1e-6;

/// 걷기 기록의 랩 하나. 가득 찬 랩은 [lapM] 길이이고, 마지막에 남은 구간은 [partial]이다
class Lap {
  const Lap({
    required this.index,
    required this.distanceM,
    required this.duration,
    required this.steps,
    required this.lapM,
  });

  /// 1부터
  final int index;
  final double distanceM;

  /// 이 랩에 걸린 시간. 걸음이 없던(쉰) 시간도 들어간다
  final Duration duration;
  final int steps;

  /// 한 랩의 길이(m) (config record.lapKm × 1000)
  final double lapM;

  /// 랩 길이를 못 채운 마지막 구간
  bool get partial => distanceM < lapM;

  int? get paceSecPerKm => gait.paceSecPerKm(distanceM, duration);
}

/// 이미 걷기/뛰기로 나눈 분 중 [fromMinute, toMinute)(UTC epoch 분)의 걸음 있는 분을
/// rules.lapKm마다 끊어 랩으로 나눈다. 시간의 기준(0초)은 [fromMinute]의 시작이다.
///
/// 한 분의 거리(걸음 × 보폭)는 그 분 안에서 고르게 났다고 보고(근사), 랩 경계를 넘는 시각과
/// 그때까지의 걸음은 그 분 안에서 비례로 구한다. 한 분 안에 경계가 여러 개일 수 있다.
/// 반올림이 쌓이지 않게 경계 시각·누적 걸음을 실수로 들고 가다 랩마다 반올림 차이를 쓴다:
/// 랩 시간의 합 = 마지막 끝 시각(반올림), 랩 걸음의 합 = 전체 걸음.
/// 마지막 가득 찬 랩 뒤에 거리가 남으면 걸음이 있던 마지막 분의 끝까지를 부분 랩으로 더한다
/// (toMinute까지 늘리지 않아서 끝의 쉰 시간이 페이스를 늘리지 않는다). 걸음이 없으면 빈 목록
List<Lap> splitLaps(
  List<gait.GaitMinute> minutes,
  int fromMinute,
  int toMinute,
  Rules rules,
) {
  final lapM = rules.lapKm * 1000;
  final active = [
    for (final m in minutes)
      if (m.minute >= fromMinute && m.minute < toMinute && m.steps > 0) m,
  ]..sort((a, b) => a.minute.compareTo(b.minute));
  if (active.isEmpty) return const [];

  final laps = <Lap>[];
  // 지난 랩이 끝난 곳 (반올림 전). 처음은 fromMinute의 시작, 걸음 0
  var prevSec = 0.0;
  var prevSteps = 0.0;
  var cumM = 0.0;
  var cumSteps = 0.0;

  void add(double endSec, double endSteps, double distanceM) {
    laps.add(Lap(
      index: laps.length + 1,
      distanceM: distanceM,
      duration: Duration(seconds: endSec.round() - prevSec.round()),
      steps: endSteps.round() - prevSteps.round(),
      lapM: lapM,
    ));
    prevSec = endSec;
    prevSteps = endSteps;
  }

  for (final m in active) {
    final d = m.steps * gait.strideM(m.gait, rules);
    final minuteSec = (m.minute - fromMinute) * 60.0;
    while (cumM + d >= (laps.length + 1) * lapM - _epsM) {
      // 이 분 안에서 경계까지 간 비율 (0~1)
      final f = math.min(1.0, math.max(0.0, ((laps.length + 1) * lapM - cumM) / d));
      add(minuteSec + 60 * f, cumSteps + m.steps * f, lapM);
    }
    cumM += d;
    cumSteps += m.steps;
  }

  final rest = cumM - laps.length * lapM;
  if (rest > _epsM) {
    add((active.last.minute - fromMinute + 1) * 60.0, cumSteps, rest);
  }
  return laps;
}
