import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/geo.dart';
import '../common/palette.dart';
import 'map_geometry.dart';

// 아래 크기는 모두 화면 pt. 확대해도 같게 보이도록 그릴 때 배율로 나눈다
const _regionLine = 1.2;
const _hollowR = 4.5;

/// 지나온 길의 연필 선 (앱 없이 걸은 곳은 이 선만 남는다)
const _pencilLine = 1.6;
const _pencilAlpha = 0.6;

/// 물감 길 붓자국 (16장 11/13, M1 v0.5 ⑤). Codex codex_paint_trail_v01 납품 전 임시: 옅은 번짐 + 진한 심
const _paintWashLine = 7.0;
const _paintCoreLine = 3.0;
const _paintWash = Color(0x66C97B54);
const _paintCore = Color(0xCCB5603A);

/// 안 가 본 명소 점의 진하기 (잉크 흐린색)
const _faintAlpha = 0.3;
const _visitedR = 5.5;
const _destR = 9.0;
const _selectedRing = 5.0;
const _faceR = 11.0;

/// 지도 그리기: 시도 경계 → 지나온 길(연필 선, 그 위 물감 길 붓자국) → 명소 표시 → 캐릭터 얼굴.
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
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path line(List<LatLng> path) {
      final points = [for (final p in path) toOffset(geometry.projection.project(p))];
      final out = Path();
      if (points.isEmpty) return out;
      out.moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        out.lineTo(o.dx, o.dy);
      }
      return out;
    }

    final pencil = stroke(Palette.ink.withValues(alpha: _pencilAlpha), _pencilLine);
    for (final path in data.paths) {
      canvas.drawPath(line(path), pencil);
    }
    final wash = stroke(_paintWash, _paintWashLine);
    final core = stroke(_paintCore, _paintCoreLine);
    for (final path in data.paintLines) {
      final p = line(path);
      canvas
        ..drawPath(p, wash)
        ..drawPath(p, core);
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
      if (data.visited.containsKey(e.key)) {
        circle(e.value, _visitedR, Palette.moss, 1.5);
      } else {
        // 안 가 본 명소는 흐린 점 (테두리 없이, 11/3 ‘잠금 표시 없음’, UI 명세 v3 7장)
        fill.color = Palette.ink.withValues(alpha: _faintAlpha);
        canvas.drawCircle(e.value, _hollowR * k, fill);
      }
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
