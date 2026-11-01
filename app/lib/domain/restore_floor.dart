/// 하루 요약의 숫자들 (DaySummaries 한 행의 값). [distanceM]은 실제 거리고, 보너스·상점·이동 거리·
/// 앱 걷기 이동 거리(소품 거리의 기준)·럭은 본격 걷기에서 생긴 열이다
class DayTotals {
  const DayTotals(
    this.steps,
    this.distanceM,
    this.countedSessions, {
    this.bonusM = 0,
    this.shopM = 0,
    this.travelM = 0,
    this.walkTravelM = 0,
    this.coins = 0,
  });

  final int steps;
  final double distanceM;
  final int countedSessions;
  final double bonusM;
  final double shopM;
  final double travelM;
  final double walkTravelM;
  final int coins;
}

/// 복원한 하루를 지킨 결과
class RestoredDayOutcome {
  const RestoredDayOutcome(this.totals, {required this.useRecomputedSessions});

  /// 하루 요약에 적을 값
  final DayTotals totals;

  /// 그날의 걷기 구간 행을 다시 계산한 것으로 바꾸는가. false면 복원한 행을 그대로 둔다
  final bool useRecomputedSessions;
}

/// [day]가 복원한 날인가: 복원한 마지막 날 [floorDay] 이하 (한국 날짜 키는 글자 순서가 날짜 순서).
/// [floorDay]가 null이면 복원한 적이 없다
bool isRestoredDay(String day, String? floorDay) =>
    floorDay != null && day.compareTo(floorDay) <= 0;

/// 복원한 날의 하루 요약을 지킨다. 복원한 기기의 건강 앱에는 그 날의 기록이 없거나 모자랄 수 있어서
/// 건강 앱에서 다시 계산한 값 [recomputed]가 백업에서 되살린 값 [restored]보다 작으면 복원값을 둔다:
/// - 걸음·거리(실제·보너스·상점·이동·앱 걷기 이동)·럭은 둘 중 큰 쪽
/// - 걷기 구간과 인정된 걷기 수는 한 덩어리로 움직인다. 다시 계산한 쪽이 걸음도 인정 수도 복원값 이상이면
///   (건강 앱에 그 날의 기록이 다 있다는 뜻) 다시 계산한 것을 쓰고, 아니면 복원한 것을 그대로 둔다
///   (인정된 걷기 수는 줄지 않는다)
RestoredDayOutcome guardRestoredDay(DayTotals restored, DayTotals recomputed) {
  final recomputedCovers = recomputed.steps >= restored.steps &&
      recomputed.countedSessions >= restored.countedSessions;
  return RestoredDayOutcome(
    DayTotals(
      recomputed.steps > restored.steps ? recomputed.steps : restored.steps,
      _max(recomputed.distanceM, restored.distanceM),
      recomputedCovers ? recomputed.countedSessions : restored.countedSessions,
      bonusM: _max(recomputed.bonusM, restored.bonusM),
      shopM: _max(recomputed.shopM, restored.shopM),
      travelM: _max(recomputed.travelM, restored.travelM),
      walkTravelM: _max(recomputed.walkTravelM, restored.walkTravelM),
      coins: recomputed.coins > restored.coins ? recomputed.coins : restored.coins,
    ),
    useRecomputedSessions: recomputedCovers,
  );
}

double _max(double a, double b) => a > b ? a : b;
