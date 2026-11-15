import 'bucket.dart';
import 'gait.dart';
import 'paint_trail.dart' show paintDrops;
import 'rules.dart';
import 'time_kst.dart';

// 하루 카드·걷기 리포트 (16장 11/13, M1 명세 v0.5 ⑥, M2~M6 v0.17 U). 화면·DB 없이 순수하게.
// 자료는 기기 안 하루 요약(걸음·실제 거리·물감 길 거리)과 분 걸음뿐이다 (서버로 보내지 않는다).
// 날은 모두 한국 날짜 키 'yyyy-MM-dd', 하루는 한국 시간 0~24시다.

/// 하루 하나의 기록 (하루 요약 한 줄). 기록이 없는 날은 [DayTotals.empty]
class DayTotals {
  const DayTotals({required this.day, this.steps = 0, this.actualM = 0, this.trailM = 0});

  const DayTotals.empty(this.day)
      : steps = 0,
        actualM = 0,
        trailM = 0;

  final String day;
  final int steps;

  /// 실제로 걸은 거리(m, 걸음 × 보폭)
  final double actualM;

  /// 물감 길 안에서 걸은 실제 거리(m)
  final double trailM;
}

/// 카드가 덮는 날 [from]~[to] (둘 다 포함)
class DayRange {
  const DayRange(this.from, this.to);

  const DayRange.single(String day)
      : from = day,
        to = day;

  final String from;
  final String to;

  /// 날 수 (하루면 1)
  int get days => dayFromKey(to).difference(dayFromKey(from)).inDays + 1;

  /// 하루짜리 카드인가 (아니면 ‘지난 n일’)
  bool get single => from == to;

  bool contains(String day) => day.compareTo(from) >= 0 && day.compareTo(to) <= 0;

  /// 날 키를 [from]부터 차례로
  List<String> get dayKeys => [for (var i = 0; i < days; i++) addDays(from, i)];

  @override
  bool operator ==(Object other) => other is DayRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'DayRange($from~$to)';
}

/// 하루 카드의 ‘오늘’: 한국 시각에서 config report.dayStartHour 시간을 뺀 날.
/// 05:00 전에 열면 아직 전날이라 어제는 카드에 안 들어간다 (그저께까지)
String cardToday(DateTime nowUtc, ReportRules rules) =>
    kstDayKey(nowUtc.toUtc().subtract(Duration(hours: rules.dayStartHour)));

/// 처음 설치한 날에는 카드가 없게 하는 [lastShownDay]의 처음 값: 설치(첫 기록) 전날 (M1 v0.5 ⑥)
String initialLastShownDay(String firstRecordDay) => addDays(firstRecordDay, -1);

/// 앱을 열 때 보여 줄 하루 카드의 날: [lastShownDay] 다음 날 ~ 카드 어제([cardToday] 전날).
/// 그 어제가 [lastShownDay]보다 뒤가 아니면 null (같은 날 두 번째 열기 포함).
/// 밀린 날이 config report.maxMergeDays보다 많으면 어제까지 그 날 수만 (더 앞의 날은 카드에 안 나온다)
DayRange? dueCardRange({
  required DateTime nowUtc,
  required String lastShownDay,
  required ReportRules rules,
}) {
  final last = addDays(cardToday(nowUtc, rules), -1);
  if (last.compareTo(lastShownDay) <= 0) return null;
  var from = addDays(lastShownDay, 1);
  final earliest = addDays(last, 1 - rules.maxMergeDays);
  if (from.compareTo(earliest) < 0) from = earliest;
  return DayRange(from, last);
}

/// [day]가 든 주의 7일 (config report.weekStartsMonday면 월~일, 아니면 일~토), 앞 날부터
List<String> weekOf(String day, ReportRules rules) {
  // DateTime.weekday: 월 1 … 일 7
  final weekday = dayFromKey(day).weekday;
  final back = rules.weekStartsMonday ? weekday - 1 : weekday % 7;
  final first = addDays(day, -back);
  return [for (var i = 0; i < 7; i++) addDays(first, i)];
}

/// 이번 주 막대 하나. [steps]가 null이면 카드 끝날 뒤라 아직 보여 주지 않는 날 (빈 칸)
class WeekBar {
  const WeekBar(this.day, this.steps, {required this.inCard});

  final String day;
  final int? steps;

  /// 카드가 덮는 날인가 (막대를 진하게)
  final bool inCard;
}

/// 가장 많이 걸은 날 (‘지난 n일’ 카드)
class BestDay {
  const BestDay(this.day, this.steps);

  final String day;
  final int steps;
}

/// 하루 카드 한 장의 값 (M1 v0.5 ⑥ dayCard)
class DayCard {
  const DayCard({
    required this.range,
    required this.steps,
    required this.actualM,
    required this.trailM,
    required this.drops,
    required this.best,
    required this.week,
    required this.paintings,
  });

  final DayRange range;

  /// 카드 날들의 합
  final int steps;
  final double actualM;
  final double trailM;

  /// 주운 물감 방울 (날마다 내림(물감 길 거리 ÷ paintDrop.spacingM)의 합, 방울마다 +1 럭)
  final int drops;

  /// 가장 많이 걸은 날. 하루 카드이거나 모든 날이 0보면 null
  final BestDay? best;

  /// 카드 끝날이 든 주의 7일
  final List<WeekBar> week;

  /// 카드 날들에 얻은 그림 (도착한 명소 id, 첫 그림은 'sketch'), 도착 순서대로. 다시 간 명소도 든다
  final List<String> paintings;

  /// 카드 날들이 모두 0보 = ‘쉬어 간 날’ 카드 (16장 11/15: 숫자·공유 없이 잠든 정령과 글 한 줄)
  bool get rested => steps <= 0;

  /// 하루 평균 걸음·거리 (‘지난 n일’ 카드, 반올림)
  int get avgSteps => (steps / range.days).round();
  double get avgM => actualM / range.days;
}

/// 도착 하나 (카드에 그날 그림을 넣으려고): 명소 id와 도착 시각
typedef CardArrival = ({String landmarkId, DateTime at});

/// 하루 카드 값을 만든다. [days]는 카드 날과 이번 주 날의 하루 기록 (없는 날은 0으로 본다),
/// [arrivals]는 도착 기록 (카드 날 안의 것만 그림으로 쓴다)
DayCard buildDayCard(
  DayRange range,
  Map<String, DayTotals> days, {
  required Rules rules,
  List<CardArrival> arrivals = const [],
}) {
  DayTotals of(String day) => days[day] ?? DayTotals.empty(day);
  final inCard = [for (final d in range.dayKeys) of(d)];
  BestDay? best;
  if (!range.single) {
    for (final d in inCard) {
      // 같은 걸음이면 앞 날
      if (d.steps > 0 && (best == null || d.steps > best.steps)) best = BestDay(d.day, d.steps);
    }
  }
  final sorted = [...arrivals]..sort((a, b) => a.at.compareTo(b.at));
  return DayCard(
    range: range,
    steps: inCard.fold(0, (s, d) => s + d.steps),
    actualM: inCard.fold(0.0, (s, d) => s + d.actualM),
    trailM: inCard.fold(0.0, (s, d) => s + d.trailM),
    drops: inCard.fold(0, (s, d) => s + paintDrops(d.trailM, rules)),
    best: best,
    week: [
      for (final d in weekOf(range.to, rules.report))
        WeekBar(d, d.compareTo(range.to) > 0 ? null : of(d).steps, inCard: range.contains(d)),
    ],
    paintings: [
      for (final a in sorted)
        if (range.contains(kstDayKey(a.at))) a.landmarkId,
    ],
  );
}

/// 앱을 열 때의 하루 카드 (M1 v0.5 ⑥ dayCard(days, nowKst, lastShownDay)): 보여 줄 날이 없으면 null
DayCard? dayCard({
  required Map<String, DayTotals> days,
  required DateTime nowUtc,
  required String lastShownDay,
  required Rules rules,
  List<CardArrival> arrivals = const [],
}) {
  final range = dueCardRange(nowUtc: nowUtc, lastShownDay: lastShownDay, rules: rules.report);
  if (range == null) return null;
  return buildDayCard(range, days, rules: rules, arrivals: arrivals);
}

/// 하루 카드에 쓸 하루 기록의 날들: 카드 날과 이번 주 날
Set<String> dayCardDays(DayRange range, ReportRules rules) =>
    {...range.dayKeys, ...weekOf(range.to, rules)};

/// 걷기 리포트가 보는 기간: 카드 어제([cardToday] 전날)까지 최근 [days]일 (하루 카드처럼 다 지난 날만).
/// 첫 기록일(설치한 날) [firstRecordDay]보다 앞은 자른다. 아직 다 지난 날이 없으면 null
DayRange? reportRange({
  required DateTime nowUtc,
  required int days,
  required String firstRecordDay,
  required ReportRules rules,
}) {
  final to = addDays(cardToday(nowUtc, rules), -1);
  var from = addDays(to, 1 - days);
  if (from.compareTo(firstRecordDay) < 0) from = firstRecordDay;
  return from.compareTo(to) > 0 ? null : DayRange(from, to);
}

/// 걷기 리포트 (캔버스 6-4): 하루 평균, 시간대별 걸음 24칸, 걷기/달리기, 물감 길 비율, 요일별
class WalkReport {
  const WalkReport({
    required this.range,
    required this.steps,
    required this.actualM,
    required this.trailM,
    required this.hourSteps,
    required this.walkSteps,
    required this.runSteps,
    required this.weekdaySteps,
  });

  final DayRange range;

  /// 기간의 걸음·실제 거리·그중 물감 길 거리(m, 하루 요약에서)
  final int steps;
  final double actualM;
  final double trailM;

  /// 한국 시각 0~23시마다 걸음 (24칸, 분 걸음에서)
  final List<int> hourSteps;

  /// 걷기·뛰기로 나눈 분의 걸음
  final int walkSteps;
  final int runSteps;

  /// 요일마다 하루 평균 걸음 (7칸, 이번 주 막대와 같은 순서: 월~일 또는 일~토, 반올림).
  /// 기간에 그 요일이 없으면 0
  final List<int> weekdaySteps;

  /// 하루 평균 걸음(반올림)·거리(m) = 기간 합 ÷ 기간 날 수
  int get avgSteps => (steps / range.days).round();
  double get avgM => actualM / range.days;

  /// 뛴 분 걸음 / 걷기·뛰기 분 걸음 (걷기 기록의 runRatio와 같은 정의). 걸음이 없으면 0
  double get runRatio {
    final all = walkSteps + runSteps;
    return all == 0 ? 0 : runSteps / all;
  }

  /// 물감 길 거리 / 실제 거리 (나머지는 연필 선). 거리가 없으면 0
  double get trailRatio => actualM <= 0 ? 0 : (trailM / actualM).clamp(0.0, 1.0);

  /// 걸음이 가장 많은 두 시(많은 순, 같으면 이른 시). 걸음이 있는 시만 (없으면 빈 목록)
  List<int> get peakHours {
    final hours = [
      for (var h = 0; h < 24; h++)
        if (hourSteps[h] > 0) h,
    ]..sort((a, b) {
        final c = hourSteps[b].compareTo(hourSteps[a]);
        return c != 0 ? c : a.compareTo(b);
      });
    return hours.take(2).toList();
  }

  /// 하루 평균 걸음이 가장 많은 요일 칸 (같으면 앞 칸). 모두 0이면 null
  int? get peakWeekday {
    int? best;
    for (var i = 0; i < 7; i++) {
      if (weekdaySteps[i] > 0 && (best == null || weekdaySteps[i] > weekdaySteps[best])) best = i;
    }
    return best;
  }
}

/// 걷기 리포트를 만든다. [minutes]는 걷기/뛰기로 나눈 분 걸음 (기간 밖 분은 건너뛴다),
/// [days]는 기간의 하루 기록 (걸음·거리·물감 길 거리, 없는 날은 0)
WalkReport walkReport({
  required DayRange range,
  required List<GaitMinute> minutes,
  required Map<String, DayTotals> days,
  required ReportRules rules,
}) {
  final hours = List<int>.filled(24, 0);
  var walk = 0;
  var run = 0;
  for (final m in minutes) {
    if (m.steps <= 0) continue;
    final at = StepMinute(m.minute, 0).startUtc;
    if (!range.contains(kstDayKey(at))) continue;
    hours[kstDateTime(at).hour] += m.steps;
    if (m.gait == Gait.run) {
      run += m.steps;
    } else {
      walk += m.steps;
    }
  }
  final all = [for (final d in range.dayKeys) days[d] ?? DayTotals.empty(d)];
  final sums = List<int>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  for (final d in all) {
    final weekday = dayFromKey(d.day).weekday; // 월 1 … 일 7
    final slot = rules.weekStartsMonday ? weekday - 1 : weekday % 7;
    sums[slot] += d.steps;
    counts[slot]++;
  }
  return WalkReport(
    range: range,
    steps: all.fold(0, (s, d) => s + d.steps),
    actualM: all.fold(0.0, (s, d) => s + d.actualM),
    trailM: all.fold(0.0, (s, d) => s + d.trailM),
    hourSteps: hours,
    walkSteps: walk,
    runSteps: run,
    weekdaySteps: [for (var i = 0; i < 7; i++) counts[i] == 0 ? 0 : (sums[i] / counts[i]).round()],
  );
}
