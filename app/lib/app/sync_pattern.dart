part of 'sync_service.dart';

// 물감 길 무늬 거리 보상 (T17b, 16장 11/19 밤 Annie 창구 Q005, config paintPattern.reward). 동기화 끝, 소품 해금과
// 같은 자리에서 판정한다 (sync_service.dart 본문이 부딪히지 않게 이 파일에 둔다)

extension PatternSync on SyncService {
  /// 물감 길 누적 실제 거리(km): 하루 요약 trailM의 합 (물감 길 안에서 걸은 실제 거리, 상점 효과·경비 구간 밖 걸음
  /// 제외, config paintPattern.reward.distanceBasis paintTrailActual). 디버그 거리 배수는 안 곱한다 (소품 거리와 같다)
  Future<double> paintTrailKm() async =>
      (await db.select(db.daySummaries).get()).fold(0.0, (s, d) => s + d.trailM) / 1000;

  /// 무늬 거리 보상을 준다 ([planPatternRewards]): 문턱(10·50·100km)에 새로 닿으면 아직 없는 무늬 중 표 차례로
  /// 첫 번째를 PatternsOwned에(rewardKm = 그 문턱, 새 무늬 표시 켬, 저절로 고르지 않음 — config autoSelectOnGain
  /// false), 이미 다 가졌으면 그 대신 럭을 럭 장부 gift(하루 상한 밖, refId [patternCoinsRef])로. 이미 준 문턱은
  /// rewardKm 줄과 장부 refId로 알아서 다시 주지 않는다 (백업 복원 뒤에도 같은 결과). 새로 준 것을 돌려준다
  Future<List<PatternReward>> _awardPatterns(DateTime now) async {
    final catalog = trailCatalog;
    if (catalog == null) return const [];
    final owned = await db.select(db.patternsOwned).get();
    final paid = {
      for (final r in await (db.select(db.coinLedger)
            ..where((t) => t.kind.equalsValue(CoinKind.gift) & t.refId.isNotNull()))
          .get())
        r.refId!,
    };
    final rewards = planPatternRewards(
      catalog: catalog,
      trailKm: await paintTrailKm(),
      owned: {for (final r in owned) r.patternId},
      givenKms: {
        for (final r in owned) ?r.rewardKm,
        for (final km in catalog.rewardKms)
          if (paid.contains(patternCoinsRef(km))) km,
      },
      allOwnedCoins: rules.paintPattern.allOwnedCoins,
    );
    final at = now.toUtc().millisecondsSinceEpoch;
    for (final r in rewards) {
      if (r.patternId case final id?) {
        await db.into(db.patternsOwned).insert(
            PatternsOwnedCompanion.insert(patternId: id, gotUtc: at, rewardKm: Value(r.km)));
      } else {
        await db.into(db.coinLedger).insert(CoinLedgerCompanion.insert(
              day: kstDayKey(now),
              kind: CoinKind.gift,
              amount: r.coins,
              refId: Value(patternCoinsRef(r.km)),
            ));
      }
    }
    return rewards;
  }
}
