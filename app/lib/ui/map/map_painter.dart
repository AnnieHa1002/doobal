import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/geo.dart';
import '../../domain/journey.dart' show Frame;
import '../../domain/map_album_rules.dart';
import '../../domain/paint_color.dart';
import '../../domain/paint_pattern_rules.dart';
import '../../domain/rules.dart';
import '../../domain/trail_layout.dart' show TrailPiece, layoutTrailRun;
import '../common/palette.dart';
import '../common/trail_pattern_paint.dart';
import 'map_geometry.dart';

// 아래 크기는 모두 화면 pt (캔버스 4-1, 16장 11/19 지도 연필 선·압정 핀). 확대해도 같게 보이도록 그릴 때 배율로 나눈다.
// 색·굵기는 디자인 값이라 config가 아니라 여기에 둔다 (config map.style.art code: 모두 코드 그림)

/// 시도 경계: 연필 #5E5148 80%, 1pt
const _borderColor = Color(0xCC5E5148);
const _borderWidth = 1.0;

/// 경계를 연필로 긋지 않을 때(map.style에서 뺐을 때)의 잉크 선
const _regionLine = 1.2;

/// 다음 길(지금 자리 → 목적지): 연필 점선 #4E4540 70%, 1.4pt, 5pt 긋고 4pt 띄움
const _nextColor = Color(0xB34E4540);
const _nextWidth = 1.4;
const _nextDash = 5.0;
const _nextGap = 4.0;

/// 뱃길(항구 사이, 늘 그림): 푸른 회색 연필 점 #5E6F80 80%, 1.2pt, 1.5pt 점 · 5pt 간격
const _seaColor = Color(0xCC5E6F80);
const _seaWidth = 1.2;
const _seaDash = 1.5;
const _seaGap = 5.0;

/// 안 가 본 명소: 연필 동그라미 (지름 7.5pt 바깥, 테두리 1.25pt #6E6058 70%, 안 #EFE4CC)
const _circleR = 3.1;
const _circleLine = 1.25;
const _circleColor = Color(0xB36E6058);
const _circleFill = Color(0xFFEFE4CC);

/// 연필 동그라미를 안 쓸 때의 흐린 점 (11/3 ‘잠금 표시 없음’)
const _faintR = 4.5;
const _faintAlpha = 0.3;
const _dotR = 5.5;

/// 압정 핀 머리 색 = 그 그림 액자 (캔버스 4-1 나무·은·금)
const pinHeadColors = {
  Frame.wood: Color(0xFFB8895C),
  Frame.silver: Color(0xFFC9CDD3),
  Frame.gold: Color(0xFFC99A3B),
};

/// 핀 그림 (바늘 끝 = 명소 자리 (0,0), 위가 -y)
const _pinShadow = Color(0x383E2C22);
const _needleColor = Color(0xFF5E5148);
const _needleTop = Offset(2.6, -15);
const _needleWidth = 1.6;
const _headAt = Offset(2.8, -18.5);
const _headR = 6.2;
const _headLine = 1.3;
const _shineAt = Offset(0.9, -20.4);
const _shineR = 1.7;
const _poleTop = Offset(3, -25);
const _flagLine = 1.2;
const _flagColor = Color(0xFFFBF6EC);

/// 떨어지는 핀 (연출 ① 도착, config ui.motion.arrivalPin): 그 명소 핀만 [liftPt]pt 위에 바늘 끝 기준 [scale]배로.
/// 그림자는 땅에 그대로
typedef PinLift = ({String id, double liftPt, double scale});

/// 고른 명소: 테라코타 25% 번짐 + 잉크 점 + 종이 속 (캔버스 4-1 selDot)
const _selectHalo = 13.0;
const _selectDot = 6.0;
const _selectCore = 3.5;

/// 지금 자리: 내 얼굴 (지름 20pt, 잉크 테두리 2.5pt, 속 = 내 정령 몸 색, 눈 둘). 모자는 그리지 않는다
const _faceR = 10.0;
const _faceRing = 2.5;
const _faceFallback = Color(0xFFF1D9C4);
const _eyeDx = 2.8;
const _eyeDy = 0.6;
const _eyeR = 1.1;

/// 지도 그리기 (캔버스 4-1): 시도 색 → 연필 경계 → 뱃길 → 지나온 길(연필 선, 그 위 물감 길) → 다음 길(연필 점선)
/// → 명소(안 가 봄 연필 동그라미 · 다녀옴 압정 핀 · 목적지 종이 깃발) → 지금 자리(내 얼굴) → 고른 명소 표시.
/// [zoom]은 뷰어의 확대 배율이다 (캔버스는 화면 너비에 맞춰 그리고, 그 위에 zoom을 곱해 본다). 선 두께·핀 크기는
/// 화면 pt라 확대해도 그대로다(map.style.pinsNonScaling). 연필 선은 [style].jitterPt만큼 살짝 떨린다.
/// 물감 길(config mapTrail, T17b 무늬): 이어진 구간을 한 줄로 놓고([layoutTrailRun]) 구간 무늬의 반복 무늬(heightPt)와
/// 끝 모양(capPt)을 그린다. 색은 그 구간에 칠한 물감 색([MapData.paintLineColors]를 [palette]로), 무늬는
/// [MapData.paintLinePatterns](그림이 없는 무늬는 기본 방울, [patternArt]). 그 아래 낮에는 잉크 25% 1pt, [night]면
/// #D9E4EF 1.2pt 테두리(config mapTrail.patterns.night). 무늬 그림이 오기 전에는 코드로 그린 방울이다
class MapPainter extends CustomPainter {
  MapPainter({
    required this.geometry,
    required this.data,
    required this.selectedId,
    required this.zoom,
    required this.trail,
    required this.palette,
    required this.style,
    required this.patterns,
    this.patternArt,
    this.night = false,
    this.nextRoute = const [],
    this.seaRoutes = const [],
    this.faceColor,
    this.lift,
  });

  final MapGeometry geometry;
  final MapData data;
  final String? selectedId;
  final double zoom;
  final MapTrailRules trail;

  /// 물감 색 id → 색 (config paintColor)
  final PaintColorRules palette;

  /// 연필 선·핀 (config map.style)
  final MapStyleRules style;

  /// 무늬 숫자 규칙 (config mapTrail.patterns·paintPattern)
  final PaintPatternRules patterns;

  /// 읽어 둔 무늬 그림. 없으면 모든 구간을 코드 방울로
  final TrailArt? patternArt;

  /// 밤 지도 (config mapTrail.patterns.night.when mapNight): 무늬 아래 밝은 윤곽. 지금 지도에는 밤 모습이 없어 늘 false
  final bool night;

  /// 진행 중인 여정의 남은 길 (지금 자리 → 목적지, [remainingRoute]). 없으면 빈 목록
  final List<LatLng> nextRoute;

  /// 늘 그리는 뱃길 (항구 → 항구)
  final List<(LatLng, LatLng)> seaRoutes;

  /// 내 정령 몸 색. 없으면 기본 살색
  final Color? faceColor;

  /// 도착 연출 중 떨어지는 핀 (없으면 null)
  final PinLift? lift;

  @override
  void paint(Canvas canvas, Size size) {
    final base = geometry.baseScale(size.width);
    canvas.save();
    canvas.scale(base);
    // 화면 1pt = 캔버스 k px
    final k = 1 / (base * zoom);
    // 핀은 확대해도 같은 크기(기본), 아니면 1배 크기로 그려 지도와 같이 커진다
    final pinK = style.pinsNonScaling ? k : 1 / base;
    _regions(canvas, k);
    _sea(canvas, k);
    _paths(canvas, k);
    _next(canvas, k);
    _markers(canvas, pinK);
    _face(canvas, pinK);
    _selected(canvas, pinK);
    canvas.restore();
  }

  Paint _stroke(Color color, double width, double k, {StrokeCap cap = StrokeCap.round}) => Paint()
    ..style = PaintingStyle.stroke
    ..color = color
    ..strokeWidth = width * k
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round;

  /// 연필 선이면 떨림 폭(캔버스 px), 아니면 0
  double _jitter(String line, double k) => style.isPencil(line) ? style.jitterPt * k : 0;

  List<Offset> _points(List<LatLng> path) =>
      [for (final p in path) toOffset(geometry.projection.project(p))];

  void _regions(Canvas canvas, double k) {
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < geometry.regions.length; i++) {
      fill.color = Color(geometry.regions[i].fill);
      canvas.drawPath(geometry.regionPaths[i], fill);
    }
    // 이웃한 색이 선을 덮지 않게 선은 색칠을 다 한 뒤에 긋는다
    if (style.isPencil('regionBorders')) {
      final line = _stroke(_borderColor, _borderWidth, k);
      final amp = _jitter('regionBorders', k);
      for (final l in geometry.borderLines) {
        canvas.drawPath(l.at(amp), line);
      }
      return;
    }
    final line = _stroke(Palette.ink, _regionLine, k);
    for (final p in geometry.regionPaths) {
      canvas.drawPath(p, line);
    }
  }

  /// [points](캔버스 px)를 연필로: [amp]만큼 떨고, [dash]가 있으면 점선
  void _pencil(Canvas canvas, List<Offset> points, Paint paint, double amp, {(double, double)? dash}) {
    if (points.length < 2) return;
    final wobbly = amp == 0 ? points : PencilLine.of(points).pointsAt(amp);
    if (dash case (final on, final off)) {
      canvas.drawPath(dashedPath(wobbly, on, off), paint);
      return;
    }
    final path = Path()..moveTo(wobbly.first.dx, wobbly.first.dy);
    for (final o in wobbly.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _sea(Canvas canvas, double k) {
    final paint = _stroke(_seaColor, _seaWidth, k);
    final amp = _jitter('seaRoute', k);
    for (final (a, b) in seaRoutes) {
      _pencil(canvas, _points([a, b]), paint, amp, dash: (_seaDash * k, _seaGap * k));
    }
  }

  void _next(Canvas canvas, double k) {
    if (nextRoute.length < 2) return;
    _pencil(
      canvas,
      _points(nextRoute),
      _stroke(_nextColor, _nextWidth, k),
      _jitter('nextRoute', k),
      dash: style.nextRouteDashed ? (_nextDash * k, _nextGap * k) : null,
    );
  }

  void _paths(Canvas canvas, double k) {
    final pencil = _stroke(Color(trail.pencilColor), trail.pencilWidthPt, k);
    final amp = _jitter('offAppTrail', k);
    for (final path in data.paths) {
      _pencil(canvas, _points(path), pencil, amp);
    }
    final art = patternArt ?? TrailArt.none(patterns.defaultId);
    final rules = trailLayoutRules(trail, patterns);
    // 연한 색이 종이에 묻히지 않게 잉크 25%를 1pt 크게 먼저 깐다 (config mapTrail.paint.border, 11/15),
    // 밤 지도는 그 대신 밝은 윤곽 (mapTrail.patterns.night, 16장 11/20 Q010 ①)
    final paintStyle = trailPaintStyle(trail, patterns, k: k, night: night);
    for (final run in paintRuns(data, art)) {
      paintTrailRun(canvas, layoutTrailRun(run, rules, k: k), art, paintStyle, (id) => Color(palette.hexOf(id)));
    }
  }

  /// 물감 길 줄을 이어진 것끼리 묶는다 ([MapData.paintLineJoined]): 한 묶음 = 한 줄로 놓는 구간들 (캔버스 px)
  List<List<TrailPiece>> paintRuns(MapData data, TrailArt art) {
    final runs = <List<TrailPiece>>[];
    for (final (i, path) in data.paintLines.indexed) {
      final piece = TrailPiece(
        [for (final o in _points(path)) (o.dx, o.dy)],
        colorId: i < data.paintLineColors.length ? data.paintLineColors[i] : palette.defaultId,
        patternId: art.drawn(i < data.paintLinePatterns.length ? data.paintLinePatterns[i] : null),
      );
      final joined = i < data.paintLineJoined.length && data.paintLineJoined[i];
      if (joined && runs.isNotEmpty) {
        runs.last.add(piece);
      } else {
        runs.add([piece]);
      }
    }
    return runs;
  }

  /// 목적지 자리: 명소면 그 자리, 내 동네 스케치처럼 명소가 아닌 가상 지점이면 그 좌표
  Offset? get _dest {
    final virtual = data.destPoint;
    return geometry.landmarkPoints[data.destId] ??
        (virtual == null ? null : toOffset(geometry.projection.project(virtual)));
  }

  void _markers(Canvas canvas, double k) {
    final pins = <(String, Offset, Frame)>[];
    if (style.unvisitedCircle) {
      final fill = Paint()..color = _circleFill;
      final ring = _stroke(_circleColor, _circleLine, k);
      for (final e in geometry.landmarkPoints.entries) {
        if (e.key == data.destId || data.visited.containsKey(e.key)) continue;
        canvas
          ..drawCircle(e.value, _circleR * k, fill)
          ..drawCircle(e.value, _circleR * k, ring);
      }
    } else {
      final faint = Paint()..color = Palette.ink.withValues(alpha: _faintAlpha);
      for (final e in geometry.landmarkPoints.entries) {
        if (e.key == data.destId || data.visited.containsKey(e.key)) continue;
        canvas.drawCircle(e.value, _faintR * k, faint);
      }
    }
    for (final e in geometry.landmarkPoints.entries) {
      final frame = data.visited[e.key];
      if (e.key == data.destId || frame == null) continue;
      pins.add((e.key, e.value, frame));
    }
    final dest = _dest;
    // 아래(y가 큰) 핀이 앞에 오게 위에서부터 그린다
    final marks = <(String?, Offset, Frame?)>[
      for (final p in pins) p,
      if (dest != null) (null, dest, null),
    ]..sort((a, b) => a.$2.dy.compareTo(b.$2.dy));
    final lifted = lift;
    for (final (id, at, frame) in marks) {
      if (frame == null) {
        _flag(canvas, at, k);
      } else if (lifted != null && id == lifted.id) {
        _liftedPin(canvas, at, frame, k, lifted);
      } else {
        _pin(canvas, at, frame, k);
      }
    }
  }

  void _pinShadowAt(Canvas canvas, Offset at, double k) => canvas.drawOval(
        Rect.fromCenter(center: at, width: 10 * k, height: 3.6 * k),
        Paint()..color = _pinShadow,
      );

  void _pinNeedle(Canvas canvas, Offset at, double k, {bool shadow = true}) {
    if (shadow) _pinShadowAt(canvas, at, k);
    canvas.drawLine(at, at + _needleTop * k, _stroke(_needleColor, _needleWidth, k));
  }

  /// 다녀온 명소: 압정 핀, 머리 색 = 그 그림 액자 (map.style.visited headColor). 점으로 둘 때는 액자 색 점
  void _pin(Canvas canvas, Offset at, Frame frame, double k, {bool shadow = true}) {
    final color = pinHeadColors[frame]!;
    if (!style.visitedPin) {
      canvas
        ..drawCircle(at, _dotR * k, Paint()..color = color)
        ..drawCircle(at, _dotR * k, _stroke(Palette.ink, 1.5, k));
      return;
    }
    _pinNeedle(canvas, at, k, shadow: shadow);
    final head = at + _headAt * k;
    canvas
      ..drawCircle(head, _headR * k, Paint()..color = color)
      ..drawCircle(head, _headR * k, _stroke(Palette.ink, _headLine, k))
      ..drawCircle(at + _shineAt * k, _shineR * k, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  /// 떨어지는 핀: 그림자는 땅에, 핀은 [lift]만큼 위에서 바늘 끝을 기준으로 키워 그린다
  void _liftedPin(Canvas canvas, Offset at, Frame frame, double k, PinLift lift) {
    if (style.visitedPin) _pinShadowAt(canvas, at, k);
    canvas
      ..save()
      ..translate(at.dx, at.dy - lift.liftPt * k)
      ..scale(lift.scale)
      ..translate(-at.dx, -at.dy);
    _pin(canvas, at, frame, k, shadow: false);
    canvas.restore();
  }

  /// 목적지: 종이 깃발 핀 (map.style.destination). 아니면 테라코타 점
  void _flag(Canvas canvas, Offset at, double k) {
    if (!style.destinationFlag) {
      canvas
        ..drawCircle(at, 9 * k, Paint()..color = Palette.terracotta)
        ..drawCircle(at, 9 * k, _stroke(Palette.ink, 2.5, k));
      return;
    }
    _pinNeedle(canvas, at, k);
    canvas.drawLine(at + _needleTop * k, at + _poleTop * k, _stroke(Palette.ink, _needleWidth, k));
    final flag = Path()
      ..moveTo(at.dx + 3 * k, at.dy - 24 * k)
      ..lineTo(at.dx + 15 * k, at.dy - 20.5 * k)
      ..lineTo(at.dx + 3 * k, at.dy - 16.5 * k)
      ..close();
    canvas
      ..drawPath(flag, Paint()..color = _flagColor)
      ..drawPath(flag, _stroke(Palette.ink, _flagLine, k));
  }

  /// 지금 자리: 내 얼굴 (11/17 폰: 베레모 얼굴이 지금 모습과 달라 모자를 뺌, 캔버스 4-1 ‘지금 (내 얼굴)’)
  void _face(Canvas canvas, double k) {
    final p = data.position;
    if (p == null) return;
    final at = toOffset(geometry.projection.project(p));
    final ink = Paint()..color = Palette.ink;
    canvas
      ..drawCircle(at, _faceR * k, ink)
      ..drawCircle(at, (_faceR - _faceRing) * k, Paint()..color = faceColor ?? _faceFallback);
    for (final dx in const [-_eyeDx, _eyeDx]) {
      canvas.drawCircle(at + Offset(dx, _eyeDy) * k, _eyeR * k, ink);
    }
  }

  /// 고른 명소 (목적지는 깃발이 있어 따로 표시하지 않는다)
  void _selected(Canvas canvas, double k) {
    final id = selectedId;
    if (id == null || id == data.destId) return;
    final at = geometry.landmarkPoints[id];
    if (at == null) return;
    canvas
      ..drawCircle(at, _selectHalo * k, Paint()..color = Palette.terracotta.withValues(alpha: 0.25))
      ..drawCircle(at, _selectDot * k, Paint()..color = Palette.ink)
      ..drawCircle(at, _selectCore * k, Paint()..color = Palette.card);
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      old.zoom != zoom ||
      old.selectedId != selectedId ||
      old.faceColor != faceColor ||
      old.lift != lift ||
      old.night != night ||
      !identical(old.patternArt, patternArt) ||
      !identical(old.patterns, patterns) ||
      !identical(old.data, data) ||
      !identical(old.geometry, geometry) ||
      !identical(old.trail, trail) ||
      !identical(old.palette, palette) ||
      !identical(old.style, style) ||
      !identical(old.nextRoute, nextRoute) ||
      !identical(old.seaRoutes, seaRoutes);
}
