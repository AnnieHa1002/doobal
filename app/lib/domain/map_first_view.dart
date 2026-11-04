import 'dart:math' as math;

import 'map_projection.dart';
import 'map_regions.dart';

/// 지도를 처음 열 때 이 곳에서 최소 몇 곳은 보이게 할지.
/// config로 옮길 값 (11/4 Annie: 명소가 3곳 이상 보이게)
const mapFirstViewMinLandmarks = 3;

/// 보이는 범위 가장자리 여백 비율 (명소가 가장자리에 딱 붙지 않게).
/// config로 옮길 값
const mapFirstViewMargin = 0.15;

/// 지도 첫 보기: 가운데(캔버스 px)와 확대 배율
class MapFirstView {
  const MapFirstView(this.center, this.zoom);

  final MapPoint center;
  final double zoom;

  @override
  String toString() => 'MapFirstView($center, x$zoom)';
}

/// 지도를 처음 열 때의 가운데와 확대 배율. 현재 위치 [current]를 가운데에 두고, 가까운 명소
/// [minCount]곳 이상이 화면 안에 들어오는 가장 큰 배율을 고른다.
/// [viewW]·[viewH]는 확대 1배일 때 지도 영역이 덮는 캔버스 px (영역 px ÷ 기본 배율),
/// [bounds]는 지도 전체 경계 상자 (보이는 범위가 이 밖으로 나가지 않게 가운데를 안쪽으로 민다),
/// 배율은 [minZoom]~[maxZoom]으로 자른다.
/// 가운데를 민 뒤에도 [minCount]곳이 안 보이면(섬·끝 위치) 배율을 줄여 맞춘다.
/// 명소가 [minCount]곳보다 적으면 있는 만큼으로 본다
MapFirstView mapFirstView({
  required MapPoint current,
  required List<MapPoint> landmarks,
  required MapRect bounds,
  required double viewW,
  required double viewH,
  int minCount = mapFirstViewMinLandmarks,
  double margin = mapFirstViewMargin,
  double minZoom = 1,
  double maxZoom = 6,
}) {
  final need = math.min(minCount, landmarks.length);
  if (need == 0) return MapFirstView(_clampCenter(current, bounds, viewW, viewH, 1), minZoom);

  // 가운데에서 필요한 반폭·반높이: 영역 비율로 맞춘 거리가 가까운 순으로 need곳을 덮는 크기
  double reach(MapPoint p) =>
      math.max((p.x - current.x).abs() / viewW, (p.y - current.y).abs() / viewH);
  final nearest = [...landmarks]..sort((a, b) => reach(a).compareTo(reach(b)));
  final r = reach(nearest[need - 1]) * 2 * (1 + margin);
  // 영역의 (viewW·z)분의 1 크기가 r 이하가 되게: z = 1 / r
  var zoom = (r <= 0 ? maxZoom : 1 / r).clamp(minZoom, maxZoom).toDouble();

  while (true) {
    final center = _clampCenter(current, bounds, viewW, viewH, zoom);
    final visible = MapRect(
      center.x - viewW / zoom / 2,
      center.y - viewH / zoom / 2,
      center.x + viewW / zoom / 2,
      center.y + viewH / zoom / 2,
    );
    final seen = landmarks.where(visible.contains).length;
    if (seen >= need || zoom <= minZoom) return MapFirstView(center, zoom);
    // 조금씩 줄여 가며 다시 본다 (한 번에 줄이면 꼭 맞는 배율을 지나친다)
    zoom = math.max(minZoom, zoom * 0.95);
  }
}

/// 보이는 범위(영역 ÷ 배율)가 [bounds] 밖으로 나가지 않게 가운데를 민다.
/// 범위가 경계보다 크면 경계의 가운데에 둔다
MapPoint _clampCenter(MapPoint c, MapRect bounds, double viewW, double viewH, double zoom) {
  double fit(double v, double lo, double hi, double half) {
    if (hi - lo <= half * 2) return (lo + hi) / 2;
    return v.clamp(lo + half, hi - half).toDouble();
  }

  return MapPoint(
    fit(c.x, bounds.left, bounds.right, viewW / zoom / 2),
    fit(c.y, bounds.top, bounds.bottom, viewH / zoom / 2),
  );
}
