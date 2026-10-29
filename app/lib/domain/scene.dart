import 'geo.dart';
import 'landmark.dart';
import 'route.dart';
import 'rules.dart';
import 'sky.dart';
import 'sun.dart';
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

/// 장면을 칠할 때 쓰는 값: 하늘 단계, 후경 지역, 계절
class SceneLook {
  const SceneLook(this.phase, this.backdrop, this.season);

  final SkyPhase phase;
  final String backdrop;
  final Season season;
}

/// 지금 시각·위치의 장면. 하늘은 그 위치의 일출·일몰로 환산한다.
/// 위치는 한국 안이어야 한다(sunTimes가 한국 밖 극지방에서 StateError)
SceneLook sceneLook(
  DateTime nowUtc,
  LatLng position,
  bool onSea,
  List<Landmark> landmarks,
  Rules rules,
) {
  final day = kstDayKey(nowUtc);
  final sun = sunTimes(position, day, rules.sunZenithDeg);
  return SceneLook(
    skyPhaseAt(skyRefHour(nowUtc, sun), rules),
    backdropAt(RoutePosition(position, 0, onSea), landmarks, rules),
    seasonOf(day, rules),
  );
}
