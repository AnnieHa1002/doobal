import 'journey.dart' show Frame;
import 'landmark.dart';
import 'prop.dart';

/// 같은 명소로 도착한 여정 하나 (도착 시각과 환산 거리)
class ArrivedTrip {
  const ArrivedTrip(this.arrivedAt, this.km);

  final DateTime arrivedAt;
  final double km;
}

/// [arrivedAt]보다 먼저 도착한 여정 중 가장 먼 환산 거리(km). 먼저 도착한 여정이 없으면 null.
/// 같은 시각은 먼저가 아니다 (지금 도착한 여정 자신이 들어 있어도 된다)
double? previousBestKm(Iterable<ArrivedTrip> trips, DateTime arrivedAt) {
  double? best;
  for (final t in trips) {
    if (!t.arrivedAt.isBefore(arrivedAt)) continue;
    if (best == null || t.km > best) best = t.km;
  }
  return best;
}

/// 이번 도착이 [region] 권역을 채웠으면 그 권역 소품, 아니면 null.
/// 첫 방문(새 그림)일 때만 권역을 채울 수 있다. [visitedIds]는 이번 그림까지 들어간 그림 id
Prop? regionPropOnArrival({
  required int visitNo,
  required String region,
  required Set<String> visitedIds,
  required List<Landmark> landmarks,
  required List<Prop> props,
}) {
  if (visitNo != 1 || !completedRegions(visitedIds, landmarks).contains(region)) return null;
  return props
      .where((p) => p.kind == PropUnlockKind.region && p.region == region)
      .firstOrNull;
}

/// 도착 화면의 재방문 줄 종류
enum RevisitKind { first, frameUp, unchanged }

/// 첫 방문이면 first, 재방문에서 액자가 올랐으면 frameUp, 아니면 unchanged.
/// 액자는 내려가지 않으니 낮아진 경우는 없다 (그래도 unchanged로 본다)
RevisitKind revisitKind(int visitNo, Frame? prev, Frame now) {
  if (visitNo <= 1 || prev == null) return RevisitKind.first;
  return now.index > prev.index ? RevisitKind.frameUp : RevisitKind.unchanged;
}
