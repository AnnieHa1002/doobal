part of 'sync_service.dart';

// 쉼터 꾸밈 물품 얻기 (T15, 16장 11/19 쉼터·상점 세부, M2~M6 AB). 동기화 끝 소품 해금 자리에서 돈다
// (병렬 개발 때 sync_service.dart 본문이 부딪히지 않게 이 파일에 둔다). 놓기·옮기기·그림 걸기는 DecorService

/// 동기화가 꾸밈 물품을 줄 때 쓰는 값: 물품 목록, 첫 그림 선물(물품·건 그림)과 그 첫 자리(장면 비율)
class DecorSeed {
  const DecorSeed({required this.catalog, this.gift, this.giftAt});

  final DecorCatalog catalog;
  final FirstSketchGift? gift;

  /// 첫 그림 선물이 처음 놓이는 자리 (camp_wide decor.easelStart를 비율로). 없으면 놓지 않고 서랍에
  final DecorRatio? giftAt;
}

extension DecorSync on SyncService {
  /// 새로 얻은 꾸밈 물품을 `decor_owned`에 더하고 새로 얻은 것을 돌려준다 (decor.json 순서).
  /// - 명소 n곳: 도착한 서로 다른 명소 수 (내 동네 스케치 빼고, 재방문은 안 셈)
  /// - 첫 그림 선물(이젤): 첫 그림을 가졌으면. 그 그림(sketch)을 건 채 첫 자리에 놓는다 (설명 글 없음).
  ///   T15 전에 첫 그림에 도착한 설치도 다음 동기화에 받는다
  /// - 보상 물품은 서랍으로 (산 물품처럼 저절로 놓지 않는다, 가안)
  Future<List<DecorItem>> _unlockDecor(DateTime now) async {
    final seed = decorSeed;
    if (seed == null) return const [];
    final owned = {for (final r in await db.select(db.decorOwned).get()) r.decorId};
    final sketch = await _ownedRow(sketchId);
    final fresh = decorToUnlock(
      seed.catalog,
      owned: owned,
      visitedLandmarks: (await _visitedLandmarkIds()).length,
      sketchArrived: sketch != null,
    );
    if (fresh.isEmpty) return const [];
    final at = now.toUtc().millisecondsSinceEpoch;
    await db.batch((b) {
      b.insertAll(db.decorOwned, [
        for (final i in fresh) DecorOwnedCompanion.insert(decorId: i.id, gotUtc: at),
      ]);
      final gift = seed.gift;
      final giftItem = gift == null ? null : seed.catalog.byId(gift.decorId);
      if (gift == null || giftItem == null || !fresh.any((i) => i.id == gift.decorId)) return;
      // 첫 그림 선물: 건 그림 (이젤 칸 0), 첫 자리
      if (giftItem.paintingSlots > 0) {
        b.insert(
          db.decorPaintings,
          DecorPaintingsCompanion.insert(decorId: gift.decorId, slot: 0, paintingKey: gift.hangs),
          mode: InsertMode.insertOrReplace,
        );
      }
      final where = seed.giftAt;
      if (where != null) {
        b.insert(
          db.decorPlaced,
          DecorPlacedCompanion.insert(decorId: gift.decorId, xRatio: where.x, yRatio: where.y, placedUtc: at),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    return fresh;
  }
}
