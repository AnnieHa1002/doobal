import 'dart:math' as math;

class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

enum Island { mainland, jeju, ulleung }

class Bounds {
  const Bounds(this.latMin, this.latMax, this.lngMin, this.lngMax);

  final double latMin;
  final double latMax;
  final double lngMin;
  final double lngMax;

  bool contains(LatLng p) =>
      p.lat >= latMin && p.lat <= latMax && p.lng >= lngMin && p.lng <= lngMax;
}

/// 대원거리(km)
double haversineKm(LatLng a, LatLng b, double radiusKm) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * radiusKm * math.asin(math.sqrt(h));
}

/// [from]에서 방위 [bearingDeg](북 0°, 시계 방향)로 대원을 따라 [distanceKm] 간 지점
LatLng destinationPoint(LatLng from, double bearingDeg, double distanceKm, double radiusKm) {
  double rad(double d) => d * math.pi / 180;
  final delta = distanceKm / radiusKm;
  final theta = rad(bearingDeg);
  final phi1 = rad(from.lat);
  final phi2 = math.asin(math.sin(phi1) * math.cos(delta) +
      math.cos(phi1) * math.sin(delta) * math.cos(theta));
  final dLng = math.atan2(math.sin(theta) * math.sin(delta) * math.cos(phi1),
      math.cos(delta) - math.sin(phi1) * math.sin(phi2));
  return LatLng(phi2 * 180 / math.pi, from.lng + dLng * 180 / math.pi);
}

/// 섬 경계 상자 안이면 그 섬, 아니면 본토
Island islandOf(LatLng p, Map<Island, Bounds> islands) {
  for (final e in islands.entries) {
    if (e.value.contains(p)) return e.key;
  }
  return Island.mainland;
}
