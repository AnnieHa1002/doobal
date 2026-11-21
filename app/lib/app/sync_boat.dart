part of 'sync_service.dart';

// 상점 배 색 (T4c, 16장 11/6 배 색, boats.json recolorRule). 저장은 BoatsOwned.colors(얻은 배 줄의 JSON,
// 고른 적 없으면 null = 그림 원래 색). 값은 0(무료, recolorRule.price)이라 럭을 쓰지 않는다

extension BoatColorSync on SyncService {
  /// 가진 배 중 색을 바꿀 수 있는 배 (상점 배 6척, boats.json recolor가 있는 배), order 순서
  Future<List<Boat>> colorableBoats() async {
    final boats = boatCatalog;
    if (boats == null) return const [];
    final owned = await ownedBoatIds();
    return [
      for (final b in boats.boats)
        if (b.recolor != null && owned.contains(b.id)) b,
    ];
  }

  /// [boatId]에 고른 색. 줄이 없거나 고른 적 없으면 원래 색 (저장 글이 틀려도 원래 색으로 읽는다)
  Future<BoatColors> boatColors(String boatId) async {
    final row = await (db.select(db.boatsOwned)..where((t) => t.boatId.equals(boatId))).getSingleOrNull();
    try {
      return BoatColors.decode(row?.colors);
    } on FormatException {
      return BoatColors.none;
    }
  }

  /// [boatId]의 색을 [colors]로 저장한다 (빈 값이면 null = 원래 색). 가진 상점 배가 아니면 [ShopBlocked].
  /// 구역은 그 배의 색 구역만 남긴다
  Future<void> setBoatColors(String boatId, BoatColors colors) async {
    final boat = boatCatalog?.byId(boatId);
    final recolor = boat?.recolor;
    if (boat == null || recolor == null) throw ShopBlocked(ShopBlock.unknownItem);
    final row = await (db.select(db.boatsOwned)..where((t) => t.boatId.equals(boatId))).getSingleOrNull();
    if (row == null) throw ShopBlocked(ShopBlock.notOwned);
    final kept = BoatColors({for (final z in recolor.zones) z: ?colors[z]});
    await (db.update(db.boatsOwned)..where((t) => t.boatId.equals(boatId)))
        .write(BoatsOwnedCompanion(colors: Value(kept.encode())));
  }
}
