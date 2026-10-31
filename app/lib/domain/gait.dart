import 'bucket.dart';
import 'rules.dart';

enum Gait { walk, run }

class GaitMinute {
  const GaitMinute(this.minute, this.steps, this.gait);

  final int minute;
  final int steps;
  final Gait gait;
}

/// 분당 걸음 하나의 걷기/뛰기. 경계 사이(131~139)와 걸음 0은 직전 상태 [prev]를 따른다
Gait judgeGait(int stepsPerMin, Gait prev, Rules rules) {
  if (stepsPerMin <= 0) return prev;
  if (stepsPerMin <= rules.walkMaxSpm) return Gait.walk;
  if (stepsPerMin >= rules.runMinSpm) return Gait.run;
  return prev;
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
      state = judgeGait(m.steps, state, rules);
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

/// 평균 페이스(초/km) = 시간 ÷ 거리, 반올림. 거리가 0 이하거나 시간이 0 이하면 null
int? paceSecPerKm(double distanceM, Duration time) {
  if (distanceM <= 0 || time <= Duration.zero) return null;
  return (time.inMilliseconds / 1000 / (distanceM / 1000)).round();
}

/// 지금 페이스(초/km) = 3600 ÷ 속도(km/h), 반올림. 속도가 0이면 null
int? livePaceSecPerKm(int stepsPerMin, Gait gait, Rules rules) {
  final kmh = speedKmh(stepsPerMin, gait, rules);
  return kmh <= 0 ? null : (3600 / kmh).round();
}
