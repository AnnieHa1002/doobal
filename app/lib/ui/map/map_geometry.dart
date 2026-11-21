import 'dart:math' as math;
import 'dart:ui';

import '../../domain/geo.dart';
import '../../domain/landmark.dart';
import '../../domain/map_projection.dart';
import '../../domain/map_regions.dart';
import '../../domain/route.dart';

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

  /// 시도 경계 연필 선 (고리마다 하나, 처음 그릴 때 만든다)
  late final List<PencilLine> borderLines = [
    for (final r in regions)
      for (final ring in r.rings) PencilLine.of([for (final p in ring) toOffset(p)], closed: true),
  ];
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

/// 진행 중인 여정의 남은 길: 지금 자리([progressKm]만큼 간 곳)에서 목적지까지 (배 구간은 항구를 거친다).
/// 다 왔거나 경로가 비었으면 빈 목록
List<LatLng> remainingRoute(TravelRoute route, double progressKm) {
  if (route.legs.isEmpty || progressKm >= route.totalEffectiveKm) return const [];
  final at = positionAt(route, progressKm);
  return [at.latLng, for (final l in route.legs.skip(at.legIndex)) l.to];
}

/// 늘 그리는 뱃길: 섬 항구와 본토 항구 (config route.ports, domain/route.dart의 섬 순서와 같다)
const seaRoutePorts = [('wando', 'jeju'), ('pohang', 'dodong')];

/// 연필 선: 점을 [step](캔버스 px)마다 나누고, 점마다 밀 방향(길이 0~1)을 붙인다. 방향은 자리(캔버스 px)로 정하는
/// 매끈한 2차원 잡음이라(캔버스 4-1의 feDisplacementMap과 같은 생각), 두 시도가 같이 쓰는 경계는 같은 모양으로 떨리고
/// 확대해도 떨림 모양이 흔들리지 않는다. 그릴 때 [at]에 화면 떨림 폭(캔버스 px)을 주면 그만큼 민 경로
class PencilLine {
  PencilLine._(this.points, this.push, this.closed);

  /// [points](캔버스 px)로 만든다
  factory PencilLine.of(List<Offset> points, {bool closed = false, double step = _pencilStep}) {
    final src = [...points, if (closed && points.length > 2) points.first];
    final out = <Offset>[];
    for (var i = 0; i < src.length; i++) {
      if (i == 0) {
        out.add(src[0]);
        continue;
      }
      final a = src[i - 1];
      final b = src[i];
      final len = (b - a).distance;
      if (len == 0) continue;
      final n = math.max(1, (len / step).ceil());
      for (var j = 1; j <= n; j++) {
        out.add(Offset.lerp(a, b, j / n)!);
      }
    }
    return PencilLine._(out, [for (final p in out) pencilPush(p)], closed);
  }

  /// 나눈 점 (캔버스 px)
  final List<Offset> points;

  /// 점마다 밀 방향 (x·y 각각 -1~1)
  final List<Offset> push;
  final bool closed;

  /// 떨림 폭 [amp](캔버스 px)만큼 민 점
  List<Offset> pointsAt(double amp) =>
      [for (var i = 0; i < points.length; i++) points[i] + push[i] * amp];

  /// 떨림 폭 [amp](캔버스 px)만큼 민 경로
  Path at(double amp) {
    final p = Path();
    if (points.isEmpty) return p;
    final pts = pointsAt(amp);
    p.moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    if (closed) p.close();
    return p;
  }
}

/// 연필 선을 나누는 간격과 떨림 한 번의 길이 (캔버스 px, 화면 너비 390pt에서 1pt ≈ 5.3px). 화면 구성값
const _pencilStep = 7.0;
const _pencilWave = 21.0;

/// 캔버스 자리 [p]에서 연필 선을 밀 방향 (x·y 각각 -1~1, 같은 자리면 늘 같다)
Offset pencilPush(Offset p) => Offset(
      smoothNoise2(p.dx / _pencilWave, p.dy / _pencilWave, 1),
      smoothNoise2(p.dx / _pencilWave, p.dy / _pencilWave, 2),
    );

/// 매끈한 2차원 잡음 (-1~1): 정수 격자마다 정한 값 사이를 부드럽게 잇는다. 같은 [x]·[y]·[seed]면 늘 같다
double smoothNoise2(double x, double y, int seed) {
  final ix = x.floor();
  final iy = y.floor();
  double s(double f) => f * f * (3 - 2 * f);
  final fx = s(x - ix);
  final fy = s(y - iy);
  final top = _hash(ix, iy, seed) * (1 - fx) + _hash(ix + 1, iy, seed) * fx;
  final bottom = _hash(ix, iy + 1, seed) * (1 - fx) + _hash(ix + 1, iy + 1, seed) * fx;
  return top * (1 - fy) + bottom * fy;
}

double _hash(int x, int y, int seed) {
  var h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
  h = h ^ (h >> 16);
  return (h & 0xFFFF) / 0x7FFF - 1;
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
