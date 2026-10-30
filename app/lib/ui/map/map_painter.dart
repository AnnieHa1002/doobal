import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../common/palette.dart';
import 'map_geometry.dart';

// 아래 크기는 모두 화면 pt. 확대해도 같게 보이도록 그릴 때 배율로 나눈다
const _regionLine = 1.2;
const _pathLine = 2.0;
const _pathDash = 6.0;
const _pathGap = 4.0;
const _hollowR = 4.5;
const _visitedR = 5.5;
const _destR = 9.0;
const _selectedRing = 5.0;
const _faceR = 11.0;

/// 지도 그리기: 시도 경계 → 지나온 길(점선) → 명소 표시 → 캐릭터 얼굴.
/// [zoom]은 뷰어의 확대 배율이다 (캔버스는 화면 너비에 맞춰 그리고, 그 위에 zoom을 곱해 본다)
class MapPainter extends CustomPainter {
  MapPainter({
    required this.geometry,
    required this.data,
    required this.selectedId,
    required this.zoom,
  });

  final MapGeometry geometry;
  final MapData data;
  final String? selectedId;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final base = geometry.baseScale(size.width);
    canvas.save();
    canvas.scale(base);
    // 화면 1pt = 캔버스 k px
    final k = 1 / (base * zoom);
    _regions(canvas, k);
    _paths(canvas, k);
    _markers(canvas, k);
    _face(canvas, k);
    canvas.restore();
  }

  void _regions(Canvas canvas, double k) {
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < geometry.regions.length; i++) {
      fill.color = Color(geometry.regions[i].fill);
      canvas.drawPath(geometry.regionPaths[i], fill);
    }
    // 이웃한 색이 선을 덮지 않게 선은 색칠을 다 한 뒤에 긋는다
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Palette.ink
      ..strokeWidth = _regionLine * k
      ..strokeJoin = StrokeJoin.round;
    for (final p in geometry.regionPaths) {
      canvas.drawPath(p, line);
    }
  }

  void _paths(Canvas canvas, double k) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Palette.ink
      ..strokeWidth = _pathLine * k
      ..strokeCap = StrokeCap.round;
    for (final path in data.paths) {
      final points = [for (final p in path) toOffset(geometry.projection.project(p))];
      canvas.drawPath(dashedPath(points, _pathDash * k, _pathGap * k), line);
    }
  }

  void _markers(Canvas canvas, double k) {
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Palette.ink;

    void circle(Offset at, double r, Color color, double width) {
      fill.color = color;
      line.strokeWidth = width * k;
      canvas.drawCircle(at, r * k, fill);
      canvas.drawCircle(at, r * k, line);
    }

    for (final e in geometry.landmarkPoints.entries) {
      if (e.key == data.destId) continue;
      final visited = data.visited.containsKey(e.key);
      circle(e.value, visited ? _visitedR : _hollowR, visited ? Palette.moss : Palette.card, 1.5);
    }
    // 목적지: 명소면 그 자리, 내 동네 스케치처럼 명소가 아닌 가상 지점이면 그 좌표
    final virtual = data.destPoint;
    final dest = geometry.landmarkPoints[data.destId] ??
        (virtual == null ? null : toOffset(geometry.projection.project(virtual)));
    if (dest != null) circle(dest, _destR, Palette.terracotta, 2.5);

    final selected = geometry.landmarkPoints[selectedId];
    if (selected != null) {
      final r = selectedId == data.destId
          ? _destR
          : data.visited.containsKey(selectedId) ? _visitedR : _hollowR;
      line.strokeWidth = 2 * k;
      canvas.drawCircle(selected, (r + _selectedRing) * k, line);
    }
  }

  /// 캐릭터 자리: 서 있는 점 위에 얼굴(자리 표시용). 카드색 원 + 잉크 테두리 + 어두운 베레모
  void _face(Canvas canvas, double k) {
    final p = data.position;
    if (p == null) return;
    final at = toOffset(geometry.projection.project(p));
    final ink = Paint()..color = Palette.ink;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Palette.ink
      ..strokeWidth = 2 * k;

    canvas.drawCircle(at, 2.5 * k, ink);
    final c = at.translate(0, -(_faceR + 4) * k);
    canvas.drawCircle(c, _faceR * k, Paint()..color = Palette.card);
    canvas.drawCircle(c, _faceR * k, line);
    for (final dx in const [-3.5, 3.5]) {
      canvas.drawCircle(c.translate(dx * k, 2 * k), 1.3 * k, ink);
    }
    final beret = Rect.fromCenter(
      center: c.translate(1.5 * k, -_faceR * 0.72 * k),
      width: _faceR * 1.9 * k,
      height: _faceR * 0.85 * k,
    );
    canvas.drawOval(beret, ink);
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      old.zoom != zoom ||
      old.selectedId != selectedId ||
      !identical(old.data, data) ||
      !identical(old.geometry, geometry);
}
