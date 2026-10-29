import 'geo.dart';

/// 지도 캔버스 위의 점 (px)
class MapPoint {
  const MapPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is MapPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'MapPoint($x, $y)';
}

/// 위경도 → 지도 캔버스 px (ui_map_projection_v01.json).
/// 정거원통: x는 경도에 cos(36°)를 곱해 줄인 값
class MapProjection {
  const MapProjection({
    required this.width,
    required this.height,
    required this.lonOffset,
    required this.pxPerDegLon,
    required this.top,
    required this.latOffset,
    required this.pxPerDegLat,
  });

  /// 캔버스 크기 (px)
  final double width;
  final double height;
  final double lonOffset;
  final double pxPerDegLon;
  final double top;
  final double latOffset;
  final double pxPerDegLat;

  factory MapProjection.fromJson(Map<String, dynamic> j) {
    final canvas = (j['canvas'] as List).cast<num>();
    final x = j['x'] as Map<String, dynamic>;
    final y = j['y'] as Map<String, dynamic>;
    return MapProjection(
      width: canvas[0].toDouble(),
      height: canvas[1].toDouble(),
      lonOffset: (x['lonOffset'] as num).toDouble(),
      pxPerDegLon: (x['pxPerDegLon'] as num).toDouble(),
      top: (y['top'] as num).toDouble(),
      latOffset: (y['latOffset'] as num).toDouble(),
      pxPerDegLat: (y['pxPerDegLat'] as num).toDouble(),
    );
  }

  /// x = (lng − lonOffset) × pxPerDegLon, y = top + (latOffset − lat) × pxPerDegLat
  MapPoint project(LatLng p) => MapPoint(
        (p.lng - lonOffset) * pxPerDegLon,
        top + (latOffset - p.lat) * pxPerDegLat,
      );
}
