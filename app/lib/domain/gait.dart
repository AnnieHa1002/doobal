import 'bucket.dart';
import 'rules.dart';

enum Gait { walk, run }

class GaitMinute {
  const GaitMinute(this.minute, this.steps, this.gait);

  final int minute;
  final int steps;
  final Gait gait;
}

/// 시간순 분 목록의 걷기/뛰기. 분당 걸음 = 그 분의 걸음.
/// 경계 사이(131~139)와 걸음 0인 분은 직전 상태를 따른다.
/// 빈 분이 sessionMaxGapMin보다 길면 새 걷기 구간이라 walk로 다시 시작한다
List<GaitMinute> classifyGait(
  List<StepMinute> minutes,
  Rules rules, {
  Gait initial = Gait.walk,
}) {
  var state = initial;
  int? lastActive;
  final out = <GaitMinute>[];
  for (final m in minutes) {
    if (m.steps > 0) {
      if (lastActive != null && m.minute - lastActive - 1 > rules.sessionMaxGapMin) {
        state = Gait.walk;
      }
      if (m.steps <= rules.walkMaxSpm) {
        state = Gait.walk;
      } else if (m.steps >= rules.runMinSpm) {
        state = Gait.run;
      }
      lastActive = m.minute;
    }
    out.add(GaitMinute(m.minute, m.steps, state));
  }
  return out;
}

/// 보폭(m): 걷기·뛰기별로 config에서 읽는다
double strideM(Gait gait, Rules rules) =>
    gait == Gait.run ? rules.runStrideM : rules.walkStrideM;

/// 거리(m) = Σ 걸음 × 보폭
double distanceM(List<GaitMinute> minutes, Rules rules) =>
    minutes.fold(0.0, (sum, m) => sum + m.steps * strideM(m.gait, rules));

/// 속도(km/h) = 분당 걸음 × 보폭(m) × 60 ÷ 1000
double speedKmh(int stepsPerMin, Gait gait, Rules rules) =>
    stepsPerMin * strideM(gait, rules) * 60 / 1000;

/// 속도(m/s) = 분당 걸음 × 보폭(m) ÷ 60
double speedMps(int stepsPerMin, Gait gait, Rules rules) =>
    stepsPerMin * strideM(gait, rules) / 60;
