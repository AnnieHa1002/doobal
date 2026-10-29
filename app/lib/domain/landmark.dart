import 'geo.dart';

/// landmarks.json의 명소 하나
class Landmark {
  const Landmark({
    required this.id,
    required this.name,
    required this.sido,
    required this.sigungu,
    required this.region,
    required this.backdrop,
    required this.terrain,
    required this.types,
    required this.latLng,
    required this.island,
    required this.painting,
  });

  final String id;
  final String name;
  final String sido;
  final String sigungu;

  /// 권역 7: capital·gangwon·chungcheong·jeolla·gyeongsang·jeju·ulleung
  final String region;

  /// 후경 지역 7종
  final String backdrop;

  /// mountain·coast·field·city
  final String terrain;
  final List<String> types;
  final LatLng latLng;
  final Island island;
  final String painting;

  factory Landmark.fromJson(Map<String, dynamic> j) => Landmark(
        id: j['id'] as String,
        name: j['name'] as String,
        sido: j['sido'] as String,
        sigungu: j['sigungu'] as String,
        region: j['region'] as String,
        backdrop: j['backdrop'] as String,
        terrain: j['terrain'] as String,
        types: (j['types'] as List).cast<String>(),
        latLng: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        island: Island.values.byName(j['island'] as String),
        painting: j['painting'] as String,
      );
}

/// 명소를 하나도 빠짐없이 다녀온 권역
Set<String> completedRegions(Set<String> visitedLandmarkIds, List<Landmark> landmarks) {
  final byRegion = <String, List<Landmark>>{};
  for (final l in landmarks) {
    byRegion.putIfAbsent(l.region, () => []).add(l);
  }
  return {
    for (final e in byRegion.entries)
      if (e.value.every((l) => visitedLandmarkIds.contains(l.id))) e.key,
  };
}

/// 권역별 다녀온 곳 수와 전체 명소 수 (지도 칩의 `경상 4/31`)
Map<String, ({int visited, int total})> regionProgress(
  Set<String> visitedIds,
  List<Landmark> landmarks,
) {
  final out = <String, ({int visited, int total})>{};
  for (final l in landmarks) {
    final p = out[l.region] ?? (visited: 0, total: 0);
    out[l.region] = (
      visited: p.visited + (visitedIds.contains(l.id) ? 1 : 0),
      total: p.total + 1,
    );
  }
  return out;
}
