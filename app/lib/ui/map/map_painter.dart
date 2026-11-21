import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/geo.dart';
import '../../domain/journey.dart' show Frame;
import '../../domain/map_album_rules.dart';
import '../../domain/paint_color.dart';
import '../../domain/rules.dart';
import '../common/palette.dart';
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

/// 물감 길 방울 타일 임시 그림: 방울 지름 = 타일 높이, 방울 사이 = 지름 × 이 값 (그림 납품 전 화면 구성값)
const _dropGap = 0.9;

/// 지도 그리기 (캔버스 4-1): 시도 색 → 연필 경계 → 뱃길 → 지나온 길(연필 선, 그 위 물감 길) → 다음 길(연필 점선)
/// → 명소(안 가 봄 연필 동그라미 · 다녀옴 압정 핀 · 목적지 종이 깃발) → 지금 자리(내 얼굴) → 고른 명소 표시.
/// [zoom]은 뷰어의 확대 배율이다 (캔버스는 화면 너비에 맞춰 그리고, 그 위에 zoom을 곱해 본다). 선 두께·핀 크기는
/// 화면 pt라 확대해도 그대로다(map.style.pinsNonScaling). 연필 선은 [style].jitterPt만큼 살짝 떨린다.
/// 물감 길(config mapTrail): 방울을 구간 방향으로 늘어놓고(heightPt) 끝에 끝 방울(capPt), 색은 그 구간에 칠한 물감 색
/// ([MapData.paintLineColors]를 [palette]로), 그 아래 잉크 25% 1pt 테두리. 타일 그림이 오기 전에는 코드로 그린 점이다
class MapPainter extends CustomPainter {
  MapPainter({
    required this.geometry,
    required this.data,
    required this.selectedId,
    required this.zoom,
    required this.trail,
    required this.palette,
    required this.style,
    this.nextRoute = const [],
    this.seaRoutes = const [],
    this.faceColor,
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

  /// 진행 중인 여정의 남은 길 (지금 자리 → 목적지, [remainingRoute]). 없으면 빈 목록
  final List<LatLng> nextRoute;

  /// 늘 그리는 뱃길 (항구 → 항구)
  final List<(LatLng, LatLng)> seaRoutes;

  /// 내 정령 몸 색. 없으면 기본 살색
  final Color? faceColor;

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
    Path line(List<LatLng> path) {
      final points = _points(path);
      final out = Path();
      if (points.isEmpty) return out;
      out.moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        out.lineTo(o.dx, o.dy);
      }
      return out;
    }

    // 물감 길: 지름 heightPt 방울을 길을 따라 늘어놓고 끝에 capPt 끝 방울 (임시, 옅은 번짐 + 진한 속).
    // 구간마다 칠한 물감 색, 모든 구간 아래에 잉크 테두리를 먼저 깐다
    final r = trail.paintHeightPt / 2 * k;
    final step = trail.paintHeightPt * _dropGap * k;
    // 연한 색이 종이에 묻히지 않게 잉크 25%를 방울보다 1pt 크게 먼저 깐다 (config mapTrail.paint.border, 11/15)
    final outline = Paint()..color = Color(trail.borderColor).withValues(alpha: trail.borderAlpha);
    final drops = [
      for (final path in data.paintLines) <(Offset, double)>[
        for (final metric in line(path).computeMetrics()) ...[
          for (var d = 0.0; d <= metric.length; d += step)
            (metric.getTangentForOffset(d)!.position, r),
        ],
      ],
    ];
    for (final (i, path) in data.paintLines.indexed) {
      Offset? end;
      for (final metric in line(path).computeMetrics()) {
        end = metric.getTangentForOffset(metric.length)?.position;
      }
      if (end != null) drops[i].add((end, trail.paintCapPt / 2 * k));
    }
    for (final line in drops) {
      for (final (at, radius) in line) {
        canvas.drawCircle(at, radius + trail.borderExtraPt * k, outline);
      }
    }
    for (final (i, line) in drops.indexed) {
      final color = Color(i < data.paintLineColors.length
          ? palette.hexOf(data.paintLineColors[i])
          : palette.defaultHex);
      final wash = Paint()..color = color.withValues(alpha: 0.35);
      final core = Paint()..color = color.withValues(alpha: 0.85);
      for (final (at, radius) in line) {
        canvas
          ..drawCircle(at, radius, wash)
          ..drawCircle(at, radius * 0.62, core);
      }
    }
  }

  /// 목적지 자리: 명소면 그 자리, 내 동네 스케치처럼 명소가 아닌 가상 지점이면 그 좌표
  Offset? get _dest {
    final virtual = data.destPoint;
    return geometry.landmarkPoints[data.destId] ??
        (virtual == null ? null : toOffset(geometry.projection.project(virtual)));
  }

  void _markers(Canvas canvas, double k) {
    final pins = <(Offset, Frame)>[];
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
      pins.add((e.value, frame));
    }
    final dest = _dest;
    // 아래(y가 큰) 핀이 앞에 오게 위에서부터 그린다
    final marks = <(Offset, Frame?)>[
      for (final p in pins) (p.$1, p.$2),
      if (dest != null) (dest, null),
    ]..sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (final (at, frame) in marks) {
      if (frame == null) {
        _flag(canvas, at, k);
      } else {
        _pin(canvas, at, frame, k);
      }
    }
  }

  void _pinNeedle(Canvas canvas, Offset at, double k) {
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 10 * k, height: 3.6 * k),
      Paint()..color = _pinShadow,
    );
    canvas.drawLine(at, at + _needleTop * k, _stroke(_needleColor, _needleWidth, k));
  }

  /// 다녀온 명소: 압정 핀, 머리 색 = 그 그림 액자 (map.style.visited headColor). 점으로 둘 때는 액자 색 점
  void _pin(Canvas canvas, Offset at, Frame frame, double k) {
    final color = pinHeadColors[frame]!;
    if (!style.visitedPin) {
      canvas
        ..drawCircle(at, _dotR * k, Paint()..color = color)
        ..drawCircle(at, _dotR * k, _stroke(Palette.ink, 1.5, k));
      return;
    }
    _pinNeedle(canvas, at, k);
    final head = at + _headAt * k;
    canvas
      ..drawCircle(head, _headR * k, Paint()..color = color)
      ..drawCircle(head, _headR * k, _stroke(Palette.ink, _headLine, k))
      ..drawCircle(at + _shineAt * k, _shineR * k, Paint()..color = Colors.white.withValues(alpha: 0.7));
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
      !identical(old.data, data) ||
      !identical(old.geometry, geometry) ||
      !identical(old.trail, trail) ||
      !identical(old.palette, palette) ||
      !identical(old.style, style) ||
      !identical(old.nextRoute, nextRoute) ||
      !identical(old.seaRoutes, seaRoutes);
}
