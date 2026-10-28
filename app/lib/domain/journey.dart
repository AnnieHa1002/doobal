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
    required this.sketchStage,
  });

  final double progressKm;
  final double ratio;
  final double remainingKm;
  final bool arrived;

  /// 도착하고 남은 거리 → 여행 경비로
  final double overflowKm;
  final int sketchStage;
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
    sketchStage: sketchStage(ratio, rules),
  );
}

/// 여행 경비에 더하되 상한을 넘지 않는다
double addToFund(double fundKm, double km, Rules rules) {
  final sum = fundKm + km;
  return sum < rules.travelFundCapKm ? sum : rules.travelFundCapKm;
}

/// 밑그림 단계 = 넘은 지점 수 (0~3)
int sketchStage(double ratio, Rules rules) =>
    rules.sketchSteps.where((s) => ratio >= s).length;

enum Frame { wood, silver, gold }

/// 그 그림을 얻으려고 걸은 환산 거리로 액자 등급. 경계값은 위 등급
Frame frameFor(double journeyEffectiveKm, Rules rules) {
  if (journeyEffectiveKm >= rules.frameGoldKm) return Frame.gold;
  if (journeyEffectiveKm >= rules.frameSilverKm) return Frame.silver;
  return Frame.wood;
}
