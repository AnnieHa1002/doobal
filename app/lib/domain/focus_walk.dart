import 'bucket.dart';
import 'gait.dart';
import 'rules.dart';
import 'session.dart';
import 'time_kst.dart';

// 본격 걷기 (M1 명세 v0.3 4.7장). 걷는 중 화면(앱 걷기 창)을 열어 둔 채로 걷기 1번을 채우면
// 그 구간의 이동 거리가 실제 거리의 config bonus.travelMultiplier배가 된다.
// 실제 거리(actual)는 걸음 × 보폭 그대로, 보너스(bonus)는 그 위에 얹는 값, 이동 거리(travel)는
// 실제 + 보너스 + 상점(아직 0)이다. 여정 진행·도착·경비·도착 예정일은 이동 거리로,
// 액자 등급은 실제 거리로 센다.

/// 앱 걷기 창 하나: 걷는 중 화면을 연 때부터 닫은 때까지 ([start] 이상 [end] 미만).
/// [end]가 null이면 아직 열려 있어서 지금까지로 센다
class AppWalkWindow {
  const AppWalkWindow(this.start, [this.end]);

  final DateTime start;
  final DateTime? end;
}

/// 열려 있던 앱 걷기를 닫을 시각: 마지막으로 살아 있던 시각([lastAlive]), 그게 없거나 시작보다
/// 앞서면 시작 시각 (길이 0)
DateTime orphanEnd(DateTime start, DateTime? lastAlive) =>
    lastAlive != null && !lastAlive.isBefore(start) ? lastAlive : start;

/// 분 하나를 실제·보너스·상점으로 나눈 값
class MinuteTravel {
  const MinuteTravel({
    required this.minute,
    required this.steps,
    required this.actualM,
    required this.bonusM,
    required this.inWindow,
    required this.isBonus,
    this.shopM = 0,
  });

  /// UTC epoch 분
  final int minute;
  final int steps;

  /// 실제 거리(m) = 걸음 × 보폭
  final double actualM;

  /// 보너스 거리(m). 앱 걷기 창 안이고 인정된 걷기 1번 구간일 때만 실제 거리 × (배수 − 1), 아니면 0
  final double bonusM;

  /// 상점 효과 거리(m). 아직 0
  final double shopM;

  /// 이 분이 앱 걷기 창 안인가
  final bool inWindow;

  /// 이 분에 보너스가 붙는가 (앱 걷기 창 안 ∧ 인정된 걷기 1번 구간). 배수가 1이라 보너스 거리가 0이어도
  /// 럭은 보너스 분으로 센다
  final bool isBonus;

  /// 이동 거리(m)
  double get travelM => actualM + bonusM + shopM;

  /// 앱 걷기 창 안에서 걸은 이동 거리(m). 상점은 뺀다 (소품 거리의 기준)
  double get walkTravelM => inWindow ? actualM + bonusM : 0.0;
}

/// 분별 나눔의 합
class TravelTotals {
  const TravelTotals({
    this.actualM = 0,
    this.bonusM = 0,
    this.shopM = 0,
    this.walkTravelM = 0,
    this.bonusActualM = 0,
  });

  final double actualM;
  final double bonusM;
  final double shopM;
  final double walkTravelM;

  /// 보너스 분의 실제 거리(m). 럭 계산에 쓴다
  final double bonusActualM;

  double get travelM => actualM + bonusM + shopM;

  TravelTotals operator +(TravelTotals o) => TravelTotals(
        actualM: actualM + o.actualM,
        bonusM: bonusM + o.bonusM,
        shopM: shopM + o.shopM,
        walkTravelM: walkTravelM + o.walkTravelM,
        bonusActualM: bonusActualM + o.bonusActualM,
      );
}

/// 시각 구간 [start, end) (epoch ms)
typedef _Span = ({int start, int end});

/// 겹치거나 맞닿은 구간을 합치고 시작 순으로 늘어놓는다. 길이가 0 이하인 구간은 버린다
List<_Span> _merge(Iterable<_Span> spans) {
  final sorted = spans.where((s) => s.end > s.start).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final out = <_Span>[];
  for (final s in sorted) {
    if (out.isNotEmpty && s.start <= out.last.end) {
      if (s.end > out.last.end) out[out.length - 1] = (start: out.last.start, end: s.end);
    } else {
      out.add(s);
    }
  }
  return out;
}

/// 합친 구간 [spans] 중 [ms]를 품은 것이 있는가 (이분 탐색)
bool _covers(List<_Span> spans, int ms) {
  var lo = 0;
  var hi = spans.length - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (ms < spans[mid].start) {
      hi = mid - 1;
    } else if (ms >= spans[mid].end) {
      lo = mid + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// 걷기/뛰기로 나눈 분 [minutes]를 실제·보너스로 나눈다. 한 분이 보너스를 받으려면
/// (a) 분 시작 시각이 앱 걷기 창 [windows] 안이고 (열린 창은 [now]까지)
/// (b) 인정된([WalkSession.qualified]) 걷기 구간 [sessions] 안이어야 한다.
/// 인정은 구간 전체로 가리고(그래서 구간 앞쪽 분도 나중에 소급해서 보너스를 받는다),
/// 보너스는 창과 겹친 분에만 붙는다. 하루 3번 상한([WalkSession.counted])은 상관없다.
/// [sessions]에는 [minutes]의 걷기 구간 전체를 넘긴다 ([minutes]는 시간순, 같은 분이 두 번 나와도 된다)
List<MinuteTravel> splitTravel({
  required List<GaitMinute> minutes,
  required List<WalkSession> sessions,
  required List<AppWalkWindow> windows,
  required DateTime now,
  required Rules rules,
}) {
  final inWindows = _merge([
    for (final w in windows)
      (start: w.start.millisecondsSinceEpoch, end: (w.end ?? now).millisecondsSinceEpoch),
  ]);
  final inSessions = _merge([
    for (final s in sessions)
      if (s.qualified) (start: s.start.millisecondsSinceEpoch, end: s.end.millisecondsSinceEpoch),
  ]);
  final extra = rules.bonusTravelMultiplier - 1;
  return [
    for (final m in minutes)
      _minuteTravel(m, inWindows, inSessions, extra, rules),
  ];
}

MinuteTravel _minuteTravel(
  GaitMinute m,
  List<_Span> inWindows,
  List<_Span> inSessions,
  double extra,
  Rules rules,
) {
  final ms = m.minute * Duration.millisecondsPerMinute;
  final inWindow = _covers(inWindows, ms);
  final isBonus = inWindow && _covers(inSessions, ms);
  final actual = m.steps * strideM(m.gait, rules);
  return MinuteTravel(
    minute: m.minute,
    steps: m.steps,
    actualM: actual,
    bonusM: isBonus ? actual * extra : 0.0,
    inWindow: inWindow,
    isBonus: isBonus,
  );
}

/// 걷기 1번 인정을 [fromMinute] 앞에서 이어서 가리려고 불러오는 분의 시작 (UTC epoch 분):
/// [fromMinute]가 속한 한국 날짜의 전날 0시 (하루 요약을 다시 계산할 때 불러오는 범위와 같다)
int contextStartMinute(int fromMinute) => epochMinute(
    kstDayStartUtc(addDays(kstDayKey(StepMinute(fromMinute, 0).startUtc), -1)));

/// [context](시간순) 중 [fromMinute] 이후 분의 나눔. 걷기/뛰기는 [fromMinute]부터 이어서 판정하고
/// (여정 시작·경비 기준 분에서 새로 센다), 걷기 1번 인정은 [context] 전체로 가린다
/// (기준 분 앞쪽에서 이어진 걷기도 하나로 본다). 앱 걷기 창이 없으면 걷기 구간은 보지 않는다
List<MinuteTravel> travelFrom({
  required List<StepMinute> context,
  required int fromMinute,
  required List<AppWalkWindow> windows,
  required DateTime now,
  required Rules rules,
}) {
  final minutes = context.where((m) => m.minute >= fromMinute).toList();
  return splitTravel(
    minutes: classifyGait(minutes, rules),
    sessions: windows.isEmpty ? const [] : detectSessions(context, rules),
    windows: windows,
    now: now,
    rules: rules,
  );
}

/// 합. 걷기/뛰기 분 목록이 같은 분을 두 번 담을 수 있어도 그대로 더한다
TravelTotals sumTravel(Iterable<MinuteTravel> minutes) {
  var actual = 0.0;
  var bonus = 0.0;
  var shop = 0.0;
  var walk = 0.0;
  var bonusActual = 0.0;
  for (final m in minutes) {
    actual += m.actualM;
    bonus += m.bonusM;
    shop += m.shopM;
    walk += m.walkTravelM;
    if (m.isBonus) bonusActual += m.actualM;
  }
  return TravelTotals(
    actualM: actual,
    bonusM: bonus,
    shopM: shop,
    walkTravelM: walk,
    bonusActualM: bonusActual,
  );
}

/// 한국 날짜별 합 (분 시작 시각의 한국 날짜)
Map<String, TravelTotals> dailyTravel(Iterable<MinuteTravel> minutes) {
  final byDay = <String, List<MinuteTravel>>{};
  for (final m in minutes) {
    final day = kstDayKey(
        DateTime.fromMillisecondsSinceEpoch(m.minute * Duration.millisecondsPerMinute, isUtc: true));
    byDay.putIfAbsent(day, () => []).add(m);
  }
  return {for (final e in byDay.entries) e.key: sumTravel(e.value)};
}

/// 걷기 구간마다 그 구간 안 분의 보너스 거리(m) 합. [sessions]와 같은 순서.
/// [minutes]는 시간순이다
List<double> sessionBonusM(List<WalkSession> sessions, List<MinuteTravel> minutes) {
  final out = <double>[];
  for (final s in sessions) {
    final from = epochMinute(s.start);
    // s.end는 마지막 분의 끝(= 다음 분의 시작)이라 그 분 전까지
    final to = epochMinute(s.end);
    var lo = 0;
    var hi = minutes.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (minutes[mid].minute < from) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    var sum = 0.0;
    for (var i = lo; i < minutes.length && minutes[i].minute < to; i++) {
      sum += minutes[i].bonusM;
    }
    out.add(sum);
  }
  return out;
}

/// 걷기/뛰기 분을 같은 분끼리 더한 걸음 분 목록 (걷기 구간 판정용). 시간순
List<StepMinute> toStepMinutes(List<GaitMinute> minutes) {
  final byMinute = <int, int>{};
  for (final m in minutes) {
    byMinute[m.minute] = (byMinute[m.minute] ?? 0) + m.steps;
  }
  final keys = byMinute.keys.toList()..sort();
  return [for (final k in keys) StepMinute(k, byMinute[k]!)];
}

/// 하루 럭 = floor((보너스 밖 실제 km + 보너스 분의 실제 km × bonus.coinMultiplier) × coins.perKm).
/// coins.perKm가 null이면(기획 미정) 0. 같은 하루 합으로 몇 번을 다시 계산해도 같다
int dailyCoins(TravelTotals day, Rules rules) {
  final perKm = rules.coinsPerKm;
  if (perKm == null) return 0;
  final outsideKm = (day.actualM - day.bonusActualM) / 1000;
  final bonusKm = day.bonusActualM / 1000;
  // 나눗셈·곱셈의 부동소수 오차가 정수 바로 아래로 떨어져 한 개 모자라지 않게 아주 작은 값을 더한다
  return ((outsideKm + bonusKm * rules.bonusCoinMultiplier) * perKm + 1e-9).floor();
}

/// 액자 등급의 기준 거리(km) = min(경비 + 여정 시작 뒤 실제로 걸은 거리, 여정 전체 환산 거리).
/// 보너스·상점은 안 들어간다 (앱 걷기로 거리를 부풀려 높은 액자를 받지 못하게)
double frameBasisKm(double fundKm, double actualWalkedKm, double totalEffectiveKm) {
  final km = fundKm + actualWalkedKm;
  return km < totalEffectiveKm ? km : totalEffectiveKm;
}
