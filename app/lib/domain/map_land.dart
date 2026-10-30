import 'geo.dart';
import 'map_projection.dart';
import 'map_regions.dart';

/// 경계의 권역이 어느 섬인지: jeju는 제주, ulleung은 울릉, 나머지는 본토
Island _islandOfRegion(String region) => switch (region) {
      'jeju' => Island.jeju,
      'ulleung' => Island.ulleung,
      _ => Island.mainland,
    };

/// [p]가 [island]의 땅 위인가. 지도 px로 투영해서 그 섬에 속한 경계(시도)들의 고리로
/// even-odd 점-다각형 판정을 한다 (본토는 시도 15곳, 제주·울릉은 하나씩).
/// 지도는 간략본이라 해안선 근처는 몇백 m 틀릴 수 있다
bool onIsland(LatLng p, Island island, MapProjection projection, List<MapRegion> regions) {
  final at = projection.project(p);
  for (final r in regions) {
    if (_islandOfRegion(r.region) == island && _insideEvenOdd(at, r.rings)) return true;
  }
  return false;
}

/// 고리들 전체에 대한 even-odd 안쪽 판정 (구멍·섬이 있는 경계). 고리는 마지막 점에서 첫 점으로 닫힌다
bool _insideEvenOdd(MapPoint p, List<List<MapPoint>> rings) {
  var inside = false;
  for (final ring in rings) {
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      // p에서 오른쪽으로 쏜 반직선이 변 a-b와 만나면 한 번 뒤집는다
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
  }
  return inside;
}
