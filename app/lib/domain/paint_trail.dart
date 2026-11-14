import 'dart:math' as math;

import 'bucket.dart';
import 'gait.dart';
import 'rules.dart';
import 'time_kst.dart';

// 물감 길 (M1 명세 v0.5 ①~⑤). 걷기 세션·본격 걷기 보너스를 없앤 거리 규칙.
// 분마다 실제 거리(actual = 걸음 × 보폭)와 상점 효과(shop)만 있고, 여행 거리(travel) = actual + shop이다.
// 앱을 켰든 안 켰든 모든 걸음이 여정·도착·경비·도착 예정일(travel)과 액자·거리 소품·배지(actual)에 같게 든다.
// 물감 길은 앱이 앞에 있을 때 걸으면 저절로 시작하고, 걸음이 멈추거나 앱이 끝나면 저절로 끝나는 창이다.
// 물감 길 안의 실제 거리(trail)는 럭 덤·길 위 이벤트·지도 물감 구간에만 쓴다.

/// 물감 길이 끝난 까닭: idle은 걸음이 config paintTrail.idleEndMin 동안 멈춤, appEnded는 앱이 끝나서
/// 다음 실행에서 마지막으로 살아 있던 시각에 닫음
enum PaintTrailEnd { idle, appEnded }

/// 물감 길 창 하나 ([start] 이상 [end] 미만). [end]가 null이면 아직 열려 있다 (지금까지로 센다)
class PaintTrailWindow {
  const PaintTrailWindow(this.start, [this.end, this.endReason]);

  final DateTime start;
  final DateTime? end;
  final PaintTrailEnd? endReason;

  bool get open => end == null;

  @override
  bool operator ==(Object other) =>
      other is PaintTrailWindow &&
      other.start == start &&
      other.end == end &&
      other.endReason == endReason;

  @override
  int get hashCode => Object.hash(start, end, endReason);

  @override
  String toString() => 'PaintTrailWindow($start, $end, ${endReason?.name})';
}

/// 기기 걸음 센서가 늘어난 한 번: [at]에 [steps]보. [foreground]는 그때 앱이 앞에 있었는지,
/// [catchUp]은 앱이 숨어 있던 동안 쌓인 걸음이 돌아올 때 한꺼번에 들어온 것인지 (시작 판정에 안 쓴다)
class SensorGain {
  const SensorGain(this.at, this.steps, {this.foreground = true, this.catchUp = false});

  final DateTime at;
  final int steps;
  final bool foreground;
  final bool catchUp;
}

/// 센서 걸음으로 물감 길의 시작·끝을 가리는 판정기 (화면·DB 없이 순수하게, 시각은 부르는 쪽이 넘긴다).
/// - 시작: 열린 물감 길이 없고 앱이 앞에 있을 때, 최근 config paintTrail.startMinSteps.withinSec초 안에
///   늘어난 걸음이 steps 이상이면 그 걸음들 중 첫 걸음의 분(분 시작)에 연다.
///   숨어 있던 걸음이 한꺼번에 들어온 것(catchUp)과 숨어 있을 때 센 걸음은 시작에 세지 않는다.
/// - 끝: 마지막 걸음이 든 분의 끝 뒤로 걸음 없이 idleEndMin분이 지나면 그 분의 끝에 닫는다 (idle).
///   열려 있는 동안은 숨어 있어도 걸음을 센다 (화면을 꺼도 앱이 살아 있으면 이어진다)
class PaintTrailTracker {
  PaintTrailTracker(this.rules);

  final Rules rules;
  final _recent = <SensorGain>[];
  DateTime? _start;
  DateTime? _lastStep;
  var _lastStartSteps = 0;

  /// 마지막으로 물감 길을 연 걸음들의 합 (시작 판정 창 안에서 늘어난 걸음)
  int get lastStartSteps => _lastStartSteps;

  /// 열린 물감 길이 있는가
  bool get active => _start != null;

  /// 열린 물감 길의 시작 (없으면 null)
  DateTime? get start => _start;

  /// 열린 물감 길에서 마지막으로 걸음이 늘어난 시각 (없으면 null)
  DateTime? get lastStep => _lastStep;

  /// DB에 열려 있던 물감 길을 이어 받는다 (앱이 살아 있는 채 판정기를 새로 만들 때). [lastStep]이 없으면 시작 시각
  void resume(DateTime start, {DateTime? lastStep}) {
    _start = start;
    _lastStep = lastStep ?? start;
    _recent.clear();
  }

  /// 걸음 증가 하나를 넣는다. 이 걸음으로 물감 길이 열렸으면 그 시작 시각, 아니면 null
  DateTime? add(SensorGain g) {
    if (g.steps <= 0) return null;
    if (_start != null) {
      final last = _lastStep;
      if (last == null || g.at.isAfter(last)) _lastStep = g.at;
      return null;
    }
    if (!g.foreground || g.catchUp) {
      _recent.clear();
      return null;
    }
    final within = Duration(seconds: rules.paintTrailStartWithinSec);
    _recent
      ..removeWhere((r) => g.at.difference(r.at) > within)
      ..add(g);
    final sum = _recent.fold(0, (a, r) => a + r.steps);
    if (sum < rules.paintTrailStartSteps) return null;
    final start = minuteStart(_recent.first.at);
    _start = start;
    _lastStartSteps = sum;
    _lastStep = g.at;
    _recent.clear();
    return start;
  }

  /// [now]에 걸음이 idleEndMin분 멈춰 끝날 때가 됐으면 끝 시각(마지막 걸음 분의 끝), 아니면 null.
  /// 상태는 바꾸지 않는다 ([close]로 닫는다)
  DateTime? idleEnd(DateTime now) {
    final last = _lastStep;
    if (_start == null || last == null) return null;
    final end = minuteStart(last).add(const Duration(minutes: 1));
    final due = end.add(Duration(minutes: rules.paintTrailIdleEndMin));
    return now.isBefore(due) ? null : end;
  }

  /// 열린 물감 길을 [end]에 [reason]으로 닫고 그 창을 돌려준다. 끝이 시작보다 앞이면 시작에 닫는다.
  /// 열린 것이 없으면 null
  PaintTrailWindow? close(DateTime end, PaintTrailEnd reason) {
    final start = _start;
    if (start == null) return null;
    _start = null;
    _lastStep = null;
    _recent.clear();
    return PaintTrailWindow(start, end.isBefore(start) ? start : end, reason);
  }
}

/// 센서 걸음 [events](시각순이 아니어도 된다)로 낸 물감 길 창 목록 (M1 명세 v0.5 ②의 순수 함수).
/// [aliveUtc]는 앱이 끝났을 때 마지막으로 살아 있던 시각이다: 주면 그 뒤의 걸음은 보지 않고, 그때까지 걸음이
/// 멈춰 끝나지 않은 창은 그 시각에 appEnded로 닫는다. 없으면 앱이 [now]까지 살아 있어서
/// 그때까지 끝나지 않은 창은 열린 채(end null) 돌려준다
List<PaintTrailWindow> paintTrailWindows(
  List<SensorGain> events, {
  DateTime? aliveUtc,
  required DateTime now,
  required Rules rules,
}) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  final limit = aliveUtc != null && aliveUtc.isBefore(now) ? aliveUtc : now;
  final tracker = PaintTrailTracker(rules);
  final out = <PaintTrailWindow>[];
  for (final e in sorted) {
    if (e.at.isAfter(limit)) break;
    if (tracker.idleEnd(e.at) case final end?) out.add(tracker.close(end, PaintTrailEnd.idle)!);
    tracker.add(e);
  }
  if (tracker.idleEnd(limit) case final end?) {
    out.add(tracker.close(end, PaintTrailEnd.idle)!);
  } else if (tracker.active) {
    out.add(aliveUtc == null
        ? PaintTrailWindow(tracker.start!)
        : tracker.close(limit, PaintTrailEnd.appEnded)!);
  }
  return out;
}

/// 열려 있던 물감 길을 닫을 시각: 마지막으로 살아 있던 시각([lastAlive]), 그게 없거나 시작보다
/// 앞서면 시작 시각 (길이 0)
DateTime orphanEnd(DateTime start, DateTime? lastAlive) =>
    lastAlive != null && !lastAlive.isBefore(start) ? lastAlive : start;

/// [t]가 든 분의 시작 (UTC)
DateTime minuteStart(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
    epochMinute(t) * Duration.millisecondsPerMinute,
    isUtc: true);

/// 분 하나의 거리
class MinuteTravel {
  const MinuteTravel({
    required this.minute,
    required this.steps,
    required this.actualM,
    required this.inTrail,
    this.shopM = 0,
  });

  /// UTC epoch 분
  final int minute;
  final int steps;

  /// 실제 거리(m) = 걸음 × 보폭
  final double actualM;

  /// 이 분(분 시작 시각)이 물감 길 창 안인가
  final bool inTrail;

  /// 상점 효과 거리(m). 효과는 분에 나누지 않아 늘 0이다 (하루 요약은 ShopUses에서 더한다)
  final double shopM;

  /// 여행 거리(m) = 실제 + 상점
  double get travelM => actualM + shopM;

  /// 물감 길 안에서 걸은 실제 거리(m). 물감 길 밖이면 0
  double get trailM => inTrail ? actualM : 0.0;
}

/// 분별 거리의 합
class TravelTotals {
  const TravelTotals({this.actualM = 0, this.shopM = 0, this.trailM = 0});

  final double actualM;
  final double shopM;

  /// 물감 길 안의 실제 거리(m)
  final double trailM;

  double get travelM => actualM + shopM;

  TravelTotals operator +(TravelTotals o) => TravelTotals(
        actualM: actualM + o.actualM,
        shopM: shopM + o.shopM,
        trailM: trailM + o.trailM,
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

/// 물감 길 창 [windows]를 합친 구간으로 (열린 창은 [now]까지)
List<_Span> _trailSpans(List<PaintTrailWindow> windows, DateTime now) => _merge([
      for (final w in windows)
        (start: w.start.millisecondsSinceEpoch, end: (w.end ?? now).millisecondsSinceEpoch),
    ]);

/// 걷기/뛰기로 나눈 분 [minutes]를 실제 거리로 바꾸고 물감 길 안인지 적는다.
/// 분 시작 시각이 물감 길 창 [windows] 안이면(열린 창은 [now]까지) 물감 길 분이다
List<MinuteTravel> splitTravel({
  required List<GaitMinute> minutes,
  required List<PaintTrailWindow> windows,
  required DateTime now,
  required Rules rules,
}) {
  final spans = _trailSpans(windows, now);
  return [
    for (final m in minutes)
      MinuteTravel(
        minute: m.minute,
        steps: m.steps,
        actualM: m.steps * strideM(m.gait, rules),
        inTrail: _covers(spans, m.minute * Duration.millisecondsPerMinute),
      ),
  ];
}

/// 물감 길 안의 실제 거리(m) 합 (M1 명세 v0.5 ②의 trailM). 분 값은 health 기준이다
double trailM(
  List<GaitMinute> minutes,
  List<PaintTrailWindow> windows, {
  required DateTime now,
  required Rules rules,
}) =>
    sumTravel(splitTravel(minutes: minutes, windows: windows, now: now, rules: rules)).trailM;

/// 합. 걷기/뛰기 분 목록이 같은 분을 두 번 담을 수 있어도 그대로 더한다
TravelTotals sumTravel(Iterable<MinuteTravel> minutes) {
  var actual = 0.0;
  var shop = 0.0;
  var trail = 0.0;
  for (final m in minutes) {
    actual += m.actualM;
    shop += m.shopM;
    trail += m.trailM;
  }
  return TravelTotals(actualM: actual, shopM: shop, trailM: trail);
}

/// 한국 날짜별 합 (분 시작 시각의 한국 날짜)
Map<String, TravelTotals> dailyTravel(Iterable<MinuteTravel> minutes) {
  final byDay = <String, List<MinuteTravel>>{};
  for (final m in minutes) {
    final day = kstDayKey(StepMinute(m.minute, 0).startUtc);
    byDay.putIfAbsent(day, () => []).add(m);
  }
  return {for (final e in byDay.entries) e.key: sumTravel(e.value)};
}

/// 하루 럭 = 내림(min(실제 km × coins.perKm + 물감 길 km × paintDrop.coinsPerKm, coins.dailyCap))
/// (M1 명세 v0.5 ③). coins.perKm가 null이면 0. 같은 하루 합으로 몇 번을 다시 계산해도 같다
int dailyCoins(TravelTotals day, Rules rules) =>
    trailCoins(actualM: day.actualM, trailM: day.trailM, rules: rules);

/// [dailyCoins]와 같은 식을 거리 둘로: 물감 길 하나(걷기 기록)의 럭에도 쓴다.
/// 하루 럭은 하루 합에 내림해서 내므로, 물감 길마다 낸 값의 합과 하루 값은 조금 다를 수 있다
int trailCoins({required double actualM, required double trailM, required Rules rules}) {
  final perKm = rules.coinsPerKm;
  if (perKm == null) return 0;
  // 나눗셈·곱셈의 부동소수 오차가 정수 바로 아래로 떨어져 한 개 모자라지 않게 아주 작은 값을 더한다
  final coins =
      (actualM / 1000 * perKm + trailM / 1000 * rules.paintDropCoinsPerKm + 1e-9).floor();
  return math.min(coins, rules.coinsDailyCap);
}

/// 물감 방울 수 = 내림(물감 길 거리 ÷ config paintDrop.spacingM). 보이는 연출이고 저장하지 않는다
int paintDrops(double trailM, Rules rules) =>
    trailM <= 0 ? 0 : (trailM / rules.paintDropSpacingM + 1e-9).floor();

/// 액자 등급의 기준 거리(km) = min(경비 + 여정 시작 뒤 실제로 걸은 거리, 여정 전체 환산 거리).
/// 상점 효과는 안 들어간다 (효과로 거리를 늘려 높은 액자를 받지 못하게)
double frameBasisKm(double fundKm, double actualWalkedKm, double totalEffectiveKm) {
  final km = fundKm + actualWalkedKm;
  return km < totalEffectiveKm ? km : totalEffectiveKm;
}

/// 지도 여정 길의 구간 종류: paint는 물감 길(앱을 켜고 걸은 곳, 수채 붓자국), pencil은 연필 선
enum TrailKind { paint, pencil }

/// 여정 길 위 한 구간 (여정 진행 km, [fromKm] 이상 [toKm] 이하)
class TrailSegment {
  const TrailSegment(this.fromKm, this.toKm, this.kind);

  final double fromKm;
  final double toKm;
  final TrailKind kind;

  @override
  bool operator ==(Object other) =>
      other is TrailSegment &&
      (other.fromKm - fromKm).abs() < 1e-9 &&
      (other.toKm - toKm).abs() < 1e-9 &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(fromKm.toStringAsFixed(6), toKm.toStringAsFixed(6), kind);

  @override
  String toString() => 'TrailSegment($fromKm~$toKm ${kind.name})';
}

/// 여정 길을 물감·연필 구간으로 나눈다 (M1 명세 v0.5 ⑤). 여정 진행 km 순서로:
/// 먼저 경비 [fundKm]와 상점 효과 [shopKm]만큼 연필(앱 밖 걸음·효과는 연필, 효과의 자리는 가안),
/// 그다음 여정 시작 뒤 분 [minutes](시간순)마다 실제 거리 × [scale](디버그 거리 배수) km를
/// 물감 길 분이면 물감·아니면 연필로 잇는다. 같은 종류가 이어지면 한 구간으로 합치고, 길이 0인 분은 건너뛴다.
/// [totalKm]가 있으면 그 거리에서 자른다 (도착 뒤 넘친 걸음은 그리지 않는다)
List<TrailSegment> trailSegments({
  required double fundKm,
  required List<MinuteTravel> minutes,
  double shopKm = 0,
  double scale = 1,
  double? totalKm,
}) {
  final out = <TrailSegment>[];
  var at = 0.0;
  void add(double km, TrailKind kind) {
    if (!(km > 0)) return;
    final cap = totalKm;
    if (cap != null && at >= cap) return;
    var to = at + km;
    if (cap != null && to > cap) to = cap;
    if (out.isNotEmpty && out.last.kind == kind) {
      out[out.length - 1] = TrailSegment(out.last.fromKm, to, kind);
    } else {
      out.add(TrailSegment(at, to, kind));
    }
    at = to;
  }

  add(fundKm + shopKm, TrailKind.pencil);
  for (final m in minutes) {
    add(m.actualM / 1000 * scale, m.inTrail ? TrailKind.paint : TrailKind.pencil);
  }
  return out;
}
