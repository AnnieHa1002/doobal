import 'geo.dart';

/// sigungu.json의 시·군·구 하나 (출발 동네 후보). 좌표는 그 행정구역의 대표 좌표
class Sigungu {
  const Sigungu({
    required this.id,
    required this.sido,
    required this.name,
    required this.label,
    required this.lat,
    required this.lng,
    required this.island,
  });

  final String id;
  final String sido;
  final String name;

  /// 시·도를 붙인 이름 ("서울 중구"). 같은 이름의 구를 가린다. 세종은 "세종"
  final String label;
  final double lat;
  final double lng;
  final Island island;

  LatLng get latLng => LatLng(lat, lng);

  factory Sigungu.fromJson(Map<String, dynamic> j) => Sigungu(
        id: j['id'] as String,
        sido: j['sido'] as String,
        name: j['name'] as String,
        label: j['label'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        island: Island.values.byName(j['island'] as String),
      );
}

/// sigungu.json 전체. 파일 순서를 지킨다
List<Sigungu> parseSigungu(Map<String, dynamic> json) => [
      for (final e in json['items'] as List) Sigungu.fromJson(e as Map<String, dynamic>),
    ];

/// 시·도 이름. 파일에 처음 나오는 순서대로, 중복 없이
List<String> sidoList(List<Sigungu> items) => {for (final s in items) s.sido}.toList();

/// 한 시·도의 시·군·구 (파일 순서)
List<Sigungu> inSido(List<Sigungu> items, String sido) =>
    [for (final s in items) if (s.sido == sido) s];

/// 이름으로 찾기: 공백을 무시한 부분 일치, 기준은 [Sigungu.label] ("수원" → 경기 수원시,
/// "서울중구" → 서울 중구). 검색어가 비면(공백뿐 포함) 빈 목록. 결과는 파일 순서
List<Sigungu> searchSigungu(List<Sigungu> items, String query) {
  final q = _squash(query);
  if (q.isEmpty) return const [];
  return [for (final s in items) if (_squash(s.label).contains(q)) s];
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');
