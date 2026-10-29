import 'dart:math' as math;
import 'dart:ui';

import '../../domain/landmark.dart';
import '../../domain/map_projection.dart';
import '../../domain/map_regions.dart';

/// 지도 캔버스(2048×2560 px) 위에 그릴 도형과 명소 좌표. 데이터가 바뀔 때만 새로 만든다
class MapGeometry {
  MapGeometry({
    required this.projection,
    required this.regions,
    required this.landmarks,
  })  : regionPaths = [for (final r in regions) _pathOf(r)],
        landmarkPoints = {
          for (final l in landmarks) l.id: toOffset(projection.project(l.latLng)),
        },
        byId = {for (final l in landmarks) l.id: l},
        bounds = boundsOf(regions);

  final MapProjection projection;
  final List<MapRegion> regions;
  final List<Landmark> landmarks;

  /// regions와 같은 순서. 색칠은 even-odd (구멍·섬)
  final List<Path> regionPaths;

  /// 명소 id → 캔버스 px
  final Map<String, Offset> landmarkPoints;

  final Map<String, Landmark> byId;

  /// 모든 경계를 담는 사각형
  final MapRect bounds;

  /// 그 권역(capital·gangwon …)의 경계를 모두 담는 사각형
  MapRect boundsOfRegion(String region) => boundsOf(regions.where((r) => r.region == region));

  /// 캔버스 px → 화면 너비에 맞춘 child 좌표(pt)로 가는 배율
  double baseScale(double screenWidth) => screenWidth / projection.width;
}

Offset toOffset(MapPoint p) => Offset(p.x, p.y);

Path _pathOf(MapRegion r) {
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final ring in r.rings) {
    path.addPolygon([for (final p in ring) toOffset(p)], true);
  }
  return path;
}

/// 눌린 자리 [tap](child 좌표, pt)에서 화면 거리로 [maxDistance]pt 안에 있는 가장 가까운 명소 id.
/// 없으면 null. [points]는 캔버스 px, [base]는 캔버스 px → child pt 배율,
/// [zoom]은 child 1pt가 화면에서 몇 pt인지 (뷰어의 확대 배율)
String? nearestLandmark(
  Offset tap,
  Map<String, Offset> points, {
  required double base,
  required double zoom,
  double maxDistance = 24,
}) {
  String? best;
  var bestDistance = double.infinity;
  for (final e in points.entries) {
    final d = (e.value * base - tap).distance * zoom;
    if (d <= maxDistance && d < bestDistance) {
      best = e.key;
      bestDistance = d;
    }
  }
  return best;
}

/// [points]를 따라 이은 점선 경로. [dash]는 선, [gap]은 빈 길이 (좌표와 같은 단위)
Path dashedPath(List<Offset> points, double dash, double gap) {
  final path = Path();
  var on = true;
  // 지금 조각(선 또는 빈 곳)이 끝나기까지 남은 길이
  var left = dash;
  for (var i = 0; i + 1 < points.length; i++) {
    var a = points[i];
    final b = points[i + 1];
    final len = (b - a).distance;
    if (len == 0) continue;
    final dir = (b - a) / len;
    var remain = len;
    while (remain > 1e-9) {
      final step = math.min(left, remain);
      final next = a + dir * step;
      if (on) {
        path.moveTo(a.dx, a.dy);
        path.lineTo(next.dx, next.dy);
      }
      a = next;
      remain -= step;
      left -= step;
      if (left <= 1e-9) {
        on = !on;
        left = on ? dash : gap;
      }
    }
  }
  return path;
}
