import 'geo.dart';
import 'rules.dart';

enum LegKind { land, sea }

class Leg {
  const Leg(this.from, this.to, this.kind, this.rawKm, this.effectiveKm);

  final LatLng from;
  final LatLng to;
  final LegKind kind;
  final double rawKm;

  /// 배 구간은 rawKm × seaFactor
  final double effectiveKm;
}

/// 출발지 → 목적지 경로. Flutter의 Route와 겹치지 않게 TravelRoute라고 부른다
class TravelRoute {
  const TravelRoute(this.start, this.end, this.legs);

  final LatLng start;
  final LatLng end;
  final List<Leg> legs;

  double get totalEffectiveKm => legs.fold(0.0, (sum, l) => sum + l.effectiveKm);
}

class RoutePosition {
  const RoutePosition(this.latLng, this.legIndex, this.onSea);

  final LatLng latLng;
  final int legIndex;
  final bool onSea;
}

/// 섬(항구 쪽 → 본토 쪽 항구) 순서. 제주 = 제주항·완도, 울릉 = 도동항·포항
List<LatLng> _islandPorts(Island i, Rules rules) => switch (i) {
      Island.jeju => [rules.ports['jeju']!, rules.ports['wando']!],
      Island.ulleung => [rules.ports['dodong']!, rules.ports['pohang']!],
      Island.mainland => [],
    };

/// 직선(대원거리)으로 잇되, 섬이 끼면 고정 항구를 거치고 항구 사이는 배로 간다.
/// 예: 본토 → 제주 = 출발지→완도(땅), 완도→제주항(배), 제주항→목적지(땅). 거리 0인 다리는 뺀다
TravelRoute buildRoute(LatLng from, LatLng to, Rules rules) {
  final a = islandOf(from, rules.islands);
  final b = islandOf(to, rules.islands);

  final points = <LatLng>[from];
  final kinds = <LegKind>[];
  if (a != b) {
    final out = _islandPorts(a, rules);
    if (out.isNotEmpty) {
      points.addAll(out);
      kinds.addAll([LegKind.land, LegKind.sea]);
    }
    final into = _islandPorts(b, rules).reversed.toList();
    if (into.isNotEmpty) {
      points.addAll(into);
      kinds.addAll([LegKind.land, LegKind.sea]);
    }
  }
  points.add(to);
  kinds.add(LegKind.land);

  final legs = <Leg>[];
  for (var i = 0; i < kinds.length; i++) {
    final raw = haversineKm(points[i], points[i + 1], rules.earthRadiusKm);
    if (raw == 0) continue;
    final eff = kinds[i] == LegKind.sea ? raw * rules.seaFactor : raw;
    legs.add(Leg(points[i], points[i + 1], kinds[i], raw, eff));
  }
  return TravelRoute(from, to, legs);
}

/// 환산 거리만큼 간 지점. 다리 안에서는 위경도를 직선 보간한다(이 규모에서 오차 무시)
RoutePosition positionAt(TravelRoute r, double effectiveKm) {
  if (r.legs.isEmpty) return RoutePosition(r.end, 0, false);
  var left = effectiveKm.clamp(0.0, r.totalEffectiveKm);
  for (var i = 0; i < r.legs.length; i++) {
    final leg = r.legs[i];
    if (left < leg.effectiveKm || i == r.legs.length - 1) {
      final t = (left / leg.effectiveKm).clamp(0.0, 1.0);
      final p = LatLng(
        leg.from.lat + (leg.to.lat - leg.from.lat) * t,
        leg.from.lng + (leg.to.lng - leg.from.lng) * t,
      );
      return RoutePosition(p, i, leg.kind == LegKind.sea);
    }
    left -= leg.effectiveKm;
  }
  throw StateError('unreachable');
}
