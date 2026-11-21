// 물감 길 무늬 놓기 (T17b, config mapTrail.patterns, 16장 11/20 Codex 납품 뒤 결정 ②, 디자인 검토
// trail_curve_limits_v01·trail_design_review_v01): 이어진 물감 길 한 줄(색·무늬 구간 여럿)에서 끝 모양과
// 반복 무늬 자리를 정한다. 그리기(그림·코드 방울·테두리·밤 윤곽)는 ui가 한다. 자리는 모두 화면 px, 규칙은 pt × [k]
//
// - 무늬가 같은 구간끼리 한 덩어리로 그린다. 색만 바뀌면 끝 모양 없이 이어 그린다 (반복 무늬의 색만 바뀜).
// - 덩어리의 화면 길이가 shortUnderPt(36pt) 미만이면 끝 1개만 가운데에. 그 이상이면 양끝에 끝 모양, 반복 무늬는
//   앞뒤 여백 shortGapPt(18pt) 안쪽에만 (검토 README: ‘그 이상은 양끝을 유지하고 반복 무늬의 시작·끝 여백을 18pt’).
// - 무늬가 바뀌는 곳: 앞 무늬는 끝 1개로 닫고, 새 무늬는 시작 끝 없이 여백 switchGapPt(8pt) 뒤 첫 도형부터.
// - 끝 모양은 덩어리 안쪽에 둔다 (끝 모양의 바깥 가장자리 = 덩어리 끝).

import 'dart:math' as math;

/// 줄 위 한 자리: 좌표(px)와 진행 방향(라디안, x축에서 시계 방향 = 화면 y 아래가 +)
typedef TrailPose = ({double x, double y, double angle});

/// 화면 위 꺾은선 (px). 길이 [d]를 따라 자리·방향을 찾는다. 같은 점이 이어지면 하나로 본다
class TrailPolyline {
  TrailPolyline._(this._xs, this._ys, this._cum);

  factory TrailPolyline(List<(double, double)> points) {
    final xs = <double>[];
    final ys = <double>[];
    final cum = <double>[];
    for (final (x, y) in points) {
      if (xs.isNotEmpty && (x - xs.last).abs() < 1e-9 && (y - ys.last).abs() < 1e-9) continue;
      cum.add(xs.isEmpty ? 0 : cum.last + math.sqrt(math.pow(x - xs.last, 2) + math.pow(y - ys.last, 2)));
      xs.add(x);
      ys.add(y);
    }
    return TrailPolyline._(xs, ys, cum);
  }

  final List<double> _xs;
  final List<double> _ys;
  final List<double> _cum;

  double get length => _cum.isEmpty ? 0 : _cum.last;

  /// 길이 [d](0 ~ [length]로 자름)의 자리와 그 자리 선분의 방향. 점이 하나뿐이면 방향 0
  TrailPose at(double d) {
    if (_xs.isEmpty) return (x: 0, y: 0, angle: 0);
    if (_xs.length == 1) return (x: _xs.first, y: _ys.first, angle: 0);
    final t = d.clamp(0.0, length);
    // t가 든 선분 (마지막 선분의 끝은 그 선분)
    var lo = 0;
    var hi = _cum.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_cum[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final seg = _cum[hi] - _cum[lo];
    final f = seg <= 0 ? 0.0 : (t - _cum[lo]) / seg;
    final dx = _xs[hi] - _xs[lo];
    final dy = _ys[hi] - _ys[lo];
    return (x: _xs[lo] + dx * f, y: _ys[lo] + dy * f, angle: math.atan2(dy, dx));
  }
}

/// 물감 길 구간 하나 (색이나 무늬가 바뀌는 데까지): 점(px, 앞 구간과 이어진 줄이면 첫 점 = 앞 구간 끝 점),
/// 색 id, 그릴 무늬 id (그림이 없는 무늬는 부르는 쪽이 기본 무늬로 바꿔 넣는다, config paintPattern.missingArt)
class TrailPiece {
  const TrailPiece(this.points, {required this.colorId, required this.patternId});

  final List<(double, double)> points;
  final String colorId;
  final String patternId;
}

/// 놓기 규칙 (pt). [capPt]는 끝 모양 지름 (config mapTrail.paint.capPt)
class TrailLayoutRules {
  const TrailLayoutRules({
    required this.capPt,
    required this.shortUnderPt,
    required this.shortGapPt,
    required this.switchGapPt,
  });

  final double capPt;
  final double shortUnderPt;
  final double shortGapPt;
  final double switchGapPt;
}

/// 끝 모양 하나: 줄 위 길이 [d](px)의 자리, 무늬·색. [start]면 시작 끝 (끝 그림을 거꾸로 돌려 쓴다)
class TrailCap {
  const TrailCap(this.d, {required this.patternId, required this.colorId, this.start = false});

  final double d;
  final String patternId;
  final String colorId;
  final bool start;

  @override
  String toString() => 'TrailCap(${d.toStringAsFixed(1)} $patternId${start ? ' start' : ''})';
}

/// 반복 무늬를 까는 범위 [from, to](px)
class TrailSpan {
  const TrailSpan(this.from, this.to, {required this.patternId});

  final double from;
  final double to;
  final String patternId;

  double get length => to - from;

  @override
  String toString() => 'TrailSpan(${from.toStringAsFixed(1)}~${to.toStringAsFixed(1)} $patternId)';
}

/// 무늬가 같은 구간 덩어리 [from, to](px). [afterSwitch]면 앞에 다른 무늬 덩어리가 있다 (시작 끝 없이 여백 뒤부터)
class TrailGroup {
  const TrailGroup(this.from, this.to, {required this.patternId, required this.afterSwitch});

  final double from;
  final double to;
  final String patternId;
  final bool afterSwitch;
}

/// 반복 무늬 묶음 하나 (그림의 가로 chunkPx 한 묶음): 줄 위 시작 [from]·길이 [length](px), 그 묶음의 차례
/// [index](0부터, 그림 안 자리 = index × chunkPx를 그림 폭으로 나눈 나머지)
typedef TrailChunk = ({double from, double length, int index});

/// 이어진 물감 길 한 줄을 놓은 것
class TrailRunLayout {
  TrailRunLayout._(this.line, this.caps, this.spans, this.groups, this._ends, this._colors);

  final TrailPolyline line;
  final List<TrailCap> caps;
  final List<TrailSpan> spans;

  /// 무늬 덩어리 (길이 0인 것은 뺀다)
  final List<TrailGroup> groups;

  /// 구간마다 끝 길이(px), 차례대로
  List<double> get pieceEnds => List.unmodifiable(_ends);

  /// 구간마다 끝 길이(px)와 색
  final List<double> _ends;
  final List<String> _colors;

  /// 길이 [d]의 구간 색
  String colorAt(double d) => _colorAt(_ends, _colors, d);

  /// [span]을 길이 [chunk](px) 묶음으로 나눈다 (마지막은 남은 만큼). 급한 굽이에서 묶음마다 그 자리 방향으로
  /// 돌려 그리려고 (config mapTrail.patterns.curve perChunk)
  static List<TrailChunk> chunks(TrailSpan span, double chunk) {
    if (!(chunk > 0) || !(span.length > 0)) return const [];
    final out = <TrailChunk>[];
    var i = 0;
    for (var d = span.from; d < span.to - 1e-9; d += chunk, i++) {
      out.add((from: d, length: math.min(chunk, span.to - d), index: i));
    }
    return out;
  }
}

/// 이어진 [pieces] 한 줄을 놓는다. [k]는 화면 1pt의 px
TrailRunLayout layoutTrailRun(List<TrailPiece> pieces, TrailLayoutRules rules, {required double k}) {
  final points = <(double, double)>[];
  final ends = <double>[];
  final colors = <String>[];
  var length = 0.0;
  for (final piece in pieces) {
    for (final (i, p) in piece.points.indexed) {
      if (points.isNotEmpty) {
        final (x0, y0) = points.last;
        final step = math.sqrt(math.pow(p.$1 - x0, 2) + math.pow(p.$2 - y0, 2));
        // 이어진 구간의 첫 점(= 앞 끝 점)은 길이를 늘리지 않는다
        if (i == 0 && step < 1e-9) continue;
        length += step;
      }
      points.add(p);
    }
    ends.add(length);
    colors.add(piece.colorId);
  }
  final line = TrailPolyline(points);
  final caps = <TrailCap>[];
  final spans = <TrailSpan>[];
  final groups = <TrailGroup>[];
  final cap = rules.capPt * k;
  final gap = rules.shortGapPt * k;
  final change = rules.switchGapPt * k;
  String colorAt(double d) => _colorAt(ends, colors, d);

  // 무늬가 같은 구간끼리 덩어리 [a, b]
  var start = 0.0;
  for (var i = 0; i < pieces.length; i++) {
    final pattern = pieces[i].patternId;
    if (i + 1 < pieces.length && pieces[i + 1].patternId == pattern) continue;
    final a = start;
    final b = ends[i];
    final first = groups.isEmpty;
    start = b;
    if (!(b > a)) continue;
    groups.add(TrailGroup(a, b, patternId: pattern, afterSwitch: !first));
    if (b - a < rules.shortUnderPt * k) {
      final mid = (a + b) / 2;
      caps.add(TrailCap(mid, patternId: pattern, colorId: colorAt(mid)));
      continue;
    }
    // 무늬가 바뀐 뒤 덩어리는 시작 끝 없이 여백 8pt 뒤부터 (앞 덩어리가 끝 1개로 닫았다)
    final from = first ? a + gap : a + change;
    if (first) {
      caps.add(TrailCap(a + cap / 2, patternId: pattern, colorId: colorAt(a), start: true));
    }
    final to = b - gap;
    if (to > from) spans.add(TrailSpan(from, to, patternId: pattern));
    caps.add(TrailCap(b - cap / 2, patternId: pattern, colorId: colorAt(b)));
  }
  return TrailRunLayout._(line, caps, spans, groups, ends, colors);
}

/// 끝 길이가 [ends]인 구간들의 색 [colors] 중 길이 [d]가 든 구간 색 (경계는 앞 구간)
String _colorAt(List<double> ends, List<String> colors, double d) {
  for (var i = 0; i < ends.length; i++) {
    if (d <= ends[i]) return colors[i];
  }
  return colors.isEmpty ? '' : colors.last;
}
