part of 'sync_service.dart';

// 하루 카드 엽서 (T10b, 16장 11/19 하루 카드 개편). 하루 요약에 없는 값: 카드 끝날의 여정과 칠한 물감 구간.
// 계산만 하고 아무것도 쓰지 않는다 (sync_service.dart 본문이 부딪히지 않게 이 파일에 둔다)

extension ReportSync on SyncService {
  /// [range] 하루 카드의 이야기: 카드 날 안에 도착한 여정(마지막)이 있으면 그 여정, 없으면 카드 끝날 24시에
  /// 진행 중이던 여정과 그 진행 (카드 첫날 0시·끝날 24시, 그 사이 시작했으면 시작 때부터), 카드 날에 칠한 물감 구간
  Future<CardStory> cardStory(DayRange range, DateTime now) async {
    final fromMs = kstDayStartUtc(range.from).millisecondsSinceEpoch;
    final toMs = kstDayStartUtc(addDays(range.to, 1)).millisecondsSinceEpoch;
    JourneyRow? arrived;
    JourneyRow? open;
    for (final r in await (db.select(db.journeys)
          ..where((t) => t.startUtc.isSmallerThanValue(toMs))
          ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
        .get()) {
      final a = r.arrivedUtc;
      if (a != null && a >= fromMs && a < toMs) {
        if (arrived == null || a >= arrived.arrivedUtc!) arrived = r;
        continue;
      }
      final endMs = r.arrivedUtc ?? r.endedUtc;
      if (endMs == null || endMs >= toMs) open = r;
    }
    final pick = arrived ?? open;
    CardJourney? journey;
    LatLng? position;
    if (pick != null) {
      final j = _toJourney(pick);
      final total = j.route.totalEffectiveKm;
      final before = await _progressAt(pick, j, math.max(fromMs, pick.startUtc), now);
      final end = arrived != null ? total : await _progressAt(pick, j, toMs, now);
      journey = CardJourney(
        destId: pick.destId,
        destName: _placeNameOf(pick.destId),
        totalKm: total,
        beforeKm: before,
        endKm: end,
        arrived: arrived != null,
        frame: pick.newFrame,
        visitNo: pick.visitNo,
      );
      position = positionAt(j.route, math.min(end, total)).latLng;
    }
    final trailPaints = await _trailPaints();
    final defaultId = rules.paintColor.defaultId;
    final minutes = await _travelFrom(_minuteOf(fromMs), now, beforeMinute: _minuteOf(toMs));
    return CardStory(
      journey: journey,
      strokes: mergeStrokes([
        for (final m in minutes)
          if (m.inTrail)
            (paintedColorAt(trailPaints, m.minute * Duration.millisecondsPerMinute, defaultId), m.actualM),
      ]),
      position: position,
    );
  }

  /// 여정 [r]의 [atMs] 시각 진행 거리 (km): 경비 + 여정 시작부터 그 시각 전까지 걸은 여행 거리 × 디버그 거리 배수
  /// + 그 시각이 든 날 전에 쓴 상점 효과. [atMs]가 시작 전이면 경비만
  Future<double> _progressAt(JourneyRow r, Journey j, int atMs, DateTime now) async {
    if (atMs <= r.startUtc) return progress(j, 0, rules).progressKm;
    final walked = sumTravel(
          await _travelFrom(_minuteOf(r.startUtc), now, beforeMinute: _minuteOf(atMs)),
        ).travelM /
        1000 *
        distanceScale;
    final day = kstDayKey(_utc(atMs));
    final shop = (await (db.select(db.shopUses)
              ..where((t) => t.journeyId.equals(r.id) & t.day.isSmallerThanValue(day)))
            .get())
        .fold<double>(0, (s, u) => s + u.km);
    return progress(j, walked + shop, rules).progressKm;
  }
}
