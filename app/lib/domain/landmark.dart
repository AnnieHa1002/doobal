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
