import 'dart:convert';

import 'geo.dart';
import 'landmark.dart';
import 'look.dart';
import 'rules.dart';

/// 첫 여정 '내 동네 스케치'의 목적지·그림 id. 명소 id(kr001…)와 겹치지 않는다.
/// 명소가 아니라서 액자 등급·권역 완성에는 넣지 않는다
const sketchId = 'sketch';
const sketchName = '내 동네 스케치';

/// 동네 스케치를 다시 그리는 값 (PaintingsOwned.sketch JSON). 하늘·계절·시간대는
/// [arrivedAt]으로 다시 계산하고, 후경은 도착 때 적어 둔 [backdrop]을 쓴다.
/// [look]은 도착했을 때의 꾸미기 스냅샷 (그 뒤에 꾸며도 이 그림은 그대로)
class Sketch {
  const Sketch({
    required this.point,
    required this.arrivedAt,
    required this.backdrop,
    required this.look,
  });

  final LatLng point;
  final DateTime arrivedAt;
  final String backdrop;
  final Look look;

  Map<String, dynamic> toJson() => {
        'lat': point.lat,
        'lng': point.lng,
        'arrivedUtc': arrivedAt.millisecondsSinceEpoch,
        'backdrop': backdrop,
        'look': look.toJson(),
      };

  factory Sketch.fromJson(Map<String, dynamic> j) => Sketch(
        point: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        arrivedAt: DateTime.fromMillisecondsSinceEpoch(j['arrivedUtc'] as int, isUtc: true),
        backdrop: j['backdrop'] as String,
        look: Look.fromJson(j['look'] as Map<String, dynamic>),
      );

  /// DB 열(JSON 글자)에서 읽기
  factory Sketch.decode(String text) => Sketch.fromJson(jsonDecode(text) as Map<String, dynamic>);

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is Sketch &&
      other.point == point &&
      other.arrivedAt == arrivedAt &&
      other.backdrop == backdrop &&
      other.look == look;

  @override
  int get hashCode => Object.hash(point, arrivedAt, backdrop, look);
}

/// FNV-1a 32비트 해시
int _fnv1a32(List<int> bytes) {
  var h = 0x811C9DC5;
  for (final b in bytes) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// xorshift32 한 걸음 (0이 아닌 32비트 값 → 다음 값)
int _xorshift32(int x) {
  x ^= (x << 13) & 0xFFFFFFFF;
  x ^= x >> 17;
  x ^= (x << 5) & 0xFFFFFFFF;
  return x;
}

/// 내 동네 스케치의 목적지: [home]에서 거리 [minKm]~[maxKm], 방위 0~360°. 같은 [installId]면 늘 같은 점이다.
/// 거리·방위는 시드 hash(installId, 'sketch')에서 뽑는다 (설치마다 다르고 다시 열어도 그대로).
/// [ok]가 거절하면(바다·다른 섬) 방위를 90°씩 돌려 b, b+90, b+180, b+270 순서로 첫 [ok]인 점을 돌려준다.
/// 넷 다 거절되면 첫 후보를 돌려준다 (섬이 아주 작은 경우뿐이다. 도착 판정은 거리라 여정은 그대로 간다)
LatLng sketchDestination({
  required LatLng home,
  required String installId,
  required double minKm,
  required double maxKm,
  required double earthRadiusKm,
  required bool Function(LatLng) ok,
}) {
  var state = _fnv1a32(utf8.encode('$installId:$sketchId'));
  // xorshift는 0에서 멈추므로 0이면 다른 시작값을 쓴다
  if (state == 0) state = 0x9E3779B9;
  state = _xorshift32(state);
  final u1 = state / 0x100000000;
  state = _xorshift32(state);
  final u2 = state / 0x100000000;

  final km = minKm + (maxKm - minKm) * u1;
  final bearing = 360 * u2;
  final candidates = [
    for (var i = 0; i < 4; i++)
      destinationPoint(home, (bearing + 90 * i) % 360, km, earthRadiusKm),
  ];
  return candidates.firstWhere(ok, orElse: () => candidates.first);
}

/// 스케치 목적지를 명소 자리에 끼워 넣는 가짜 명소. 여정·진행·장면 코드가 목적지를 Landmark로
/// 다뤄서 만든다. 시도·시군구·권역·후경·지형·섬은 가장 가까운 명소 [nearest]에서 가져온다
Landmark sketchLandmark(LatLng point, Landmark nearest) => Landmark(
      id: sketchId,
      name: sketchName,
      sido: nearest.sido,
      sigungu: nearest.sigungu,
      region: nearest.region,
      backdrop: nearest.backdrop,
      terrain: nearest.terrain,
      types: const [],
      latLng: point,
      island: nearest.island,
      painting: '',
    );

/// 남은 거리 [remainingKm]를 걷는 보폭으로 환산한 걸음 수, 100보 단위로 반올림 (쉼터 말풍선의 "약 3,600보")
int sketchSteps(double remainingKm, Rules rules) =>
    (remainingKm * 1000 / rules.walkStrideM / 100).round() * 100;
