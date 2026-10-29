import 'geo.dart';
import 'landmark.dart';
import 'route.dart';
import 'rules.dart';
import 'time_kst.dart';

enum Season { spring, summer, autumn, winter }

/// 배 위에서 쓰는 후경 이름 (landmarks.json의 울릉도 backdrop도 같은 값)
const seaBackdrop = 'sea';

/// 한국 날짜의 계절. 달은 config.seasons
Season seasonOf(String kstDayKey, Rules rules) {
  final month = dayFromKey(kstDayKey).month;
  for (final e in rules.seasons.entries) {
    if (e.value.contains(month)) return Season.values.byName(e.key);
  }
  throw StateError('계절이 정해지지 않은 달: $month');
}

/// 가장 가까운 명소. 목록이 비어 있으면 StateError
Landmark nearestLandmark(LatLng p, List<Landmark> landmarks, double earthRadiusKm) {
  return landmarks.reduce((a, b) =>
      haversineKm(p, a.latLng, earthRadiusKm) <= haversineKm(p, b.latLng, earthRadiusKm)
          ? a
          : b);
}

/// 후경 지역: 배 구간이면 sea, 아니면 가장 가까운 명소의 backdrop
String backdropAt(RoutePosition pos, List<Landmark> landmarks, Rules rules) {
  if (pos.onSea) return seaBackdrop;
  return nearestLandmark(pos.latLng, landmarks, rules.earthRadiusKm).backdrop;
}
