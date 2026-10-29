import 'geo.dart';
import 'route.dart';
import 'rules.dart';

class Journey {
  const Journey({
    required this.id,
    required this.origin,
    required this.destId,
    required this.startAt,
    required this.fundKm,
    required this.route,
  });

  final String id;
  final LatLng origin;
  final String destId;
  final DateTime startAt;

  /// 출발할 때 더한 여행 경비
  final double fundKm;
  final TravelRoute route;
}

class JourneyProgress {
  const JourneyProgress({
    required this.progressKm,
    required this.ratio,
    required this.remainingKm,
    required this.arrived,
    required this.overflowKm,
  });

  final double progressKm;
  final double ratio;
  final double remainingKm;
  final bool arrived;

  /// 도착하고 남은 거리 → 여행 경비로
  final double overflowKm;
}

/// 진행 거리 = 경비 + 여정 시작 이후 걸은 거리(km)
JourneyProgress progress(Journey j, double walkedKmSinceStart, Rules rules) {
  final total = j.route.totalEffectiveKm;
  final done = j.fundKm + walkedKmSinceStart;
  final ratio = total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
  return JourneyProgress(
    progressKm: done,
    ratio: ratio,
    remainingKm: done >= total ? 0 : total - done,
    arrived: done >= total,
    overflowKm: done > total ? done - total : 0,
  );
}

/// 이번 걷기 전의 진행 비율 = (지금 진행 거리 − 이번에 걸은 거리) ÷ 전체. 0~1
double ratioBeforeWalk(double progressKm, double walkedKm, double totalKm) =>
    totalKm <= 0 ? 1.0 : ((progressKm - walkedKm) / totalKm).clamp(0.0, 1.0);

/// 여행 경비에 더하되 상한을 넘지 않는다
double addToFund(double fundKm, double km, Rules rules) {
  final sum = fundKm + km;
  return sum < rules.travelFundCapKm ? sum : rules.travelFundCapKm;
}

enum Frame { wood, silver, gold }

/// 그 그림을 얻으려고 걸은 환산 거리로 액자 등급. 경계값은 위 등급
Frame frameFor(double journeyEffectiveKm, Rules rules) {
  if (journeyEffectiveKm >= rules.frameGoldKm) return Frame.gold;
  if (journeyEffectiveKm >= rules.frameSilverKm) return Frame.silver;
  return Frame.wood;
}

/// 소장한 그림 하나의 상태 (PaintingsOwned 한 행에 해당)
class OwnedPainting {
  const OwnedPainting(this.visits, this.frame, this.bestKm);

  final int visits;
  final Frame frame;

  /// 가장 멀리서 걸어 온 환산 거리(km)
  final double bestKm;
}

/// 도착 결과: 도착 뒤 그림 상태와 도착 전 액자(첫 방문이면 null)
class ArrivalOutcome {
  const ArrivalOutcome(this.painting, this.prevFrame);

  final OwnedPainting painting;
  final Frame? prevFrame;
}

/// 도착했을 때의 그림 상태. 방문 +1, 액자는 이전과 이번 중 높은 쪽(내려가지 않는다),
/// 가장 먼 거리도 큰 쪽. 액자 순서는 wood < silver < gold (enum 순서)
ArrivalOutcome paintingAfterArrival(
  OwnedPainting? previous,
  double journeyEffectiveKm,
  Rules rules,
) {
  final now = frameFor(journeyEffectiveKm, rules);
  if (previous == null) {
    return ArrivalOutcome(OwnedPainting(1, now, journeyEffectiveKm), null);
  }
  final frame = now.index > previous.frame.index ? now : previous.frame;
  final best =
      journeyEffectiveKm > previous.bestKm ? journeyEffectiveKm : previous.bestKm;
  return ArrivalOutcome(OwnedPainting(previous.visits + 1, frame, best), previous.frame);
}
