part of 'sync_service.dart';

// 상점·배 (M4.5). 상점 일의 동기화는 이 파일에 둔다 (병렬 개발 때 sync_service.dart 본문이 부딪히지 않게)

extension ShopSync on SyncService {
  /// 가진 럭 = 들어온 럭(earn·gift·ad) − 쓴 럭(spend). 음수로 보이지 않는다
  Future<int> coinBalance() async {
    var credited = 0;
    var spent = 0;
    for (final r in await db.select(db.coinLedger).get()) {
      if (r.kind == CoinKind.spend) {
        spent += r.amount;
      } else {
        credited += r.amount;
      }
    }
    return coinBalanceOf(credited: credited, spent: spent);
  }

  /// 보관한 여행 효과: 상품 id → 개수 (없는 상품은 키가 없다)
  Future<Map<String, int>> shopHeld() async =>
      {for (final r in await db.select(db.shopInventory).get()) r.itemId: r.count};

  /// 상품 [itemId]: shop.json 상품, 아니면 props.json 색 소품 (shop.json colorVariantItems).
  /// 상점 데이터가 없으면 null
  ShopItem? _shopItem(String itemId) {
    final shop = shopCatalog;
    if (shop == null) return null;
    return shop.byId(itemId) ?? colorShopItem(props, itemId);
  }

  /// 지금 [itemId]를 살 수 없는 까닭. 살 수 있으면 null (상점 칸을 누를 때 시트를 열기 전에도 본다).
  /// 색 소품은 기본 소품을 가져야 산다 (처음부터 가진 기본 소품은 기록이 없어도 가진 것)
  Future<ShopBlock?> whyNotBuy(String itemId) async {
    final item = _shopItem(itemId);
    if (item == null) return ShopBlock.unknownItem;
    final needs = item.requires;
    return buyBlock(
      item,
      balance: await coinBalance(),
      held: await _held(item.id),
      maxHold: rules.shopMaxHoldPerItem,
      owned: await _ownsItem(item),
      hasRequired: needs == null || havePropIds(props, await ownedPropIds()).contains(needs),
    );
  }

  /// 상품을 산다. 한 트랜잭션에서 spend 줄과 소유 기록을 함께 쓴다: 여행 효과는 보관함, 소품·꾸밈 효과·색 소품은
  /// 얻은 소품, 상점 배는 얻은 배. 살 수 없으면 [ShopBlocked]를 던지고 아무것도 바꾸지 않는다
  Future<void> buyItem(String itemId, DateTime now) async {
    final block = await db.transaction<ShopBlock?>(() async {
      final block = await whyNotBuy(itemId);
      if (block != null) return block;
      final item = _shopItem(itemId)!;
      await db.into(db.coinLedger).insert(CoinLedgerCompanion.insert(
            day: kstDayKey(now),
            kind: CoinKind.spend,
            amount: item.price,
            refId: Value(item.id),
          ));
      await _grantItem(item, now.toUtc().millisecondsSinceEpoch);
      return null;
    });
    if (block != null) throw ShopBlocked(block);
  }

  /// 보관한 여행 효과를 하나 쓴다. 쓸 수 없으면 [ShopBlocked]를 던지고 효과를 줄이지 않는다.
  /// 먼저 동기화한다 (이미 도착했는데 효과를 버리지 않게). 지름길은 쓰는 순간 오늘 남은 상한에서 잘라 정하고,
  /// 순풍은 지금 열린 걷는 중에 묶어 두고 [_shopMetersByDay]가 다시 계산한다.
  /// 쓴 뒤에 다시 동기화해서 효과로 도착했으면 바로 도착을 처리한다. 뒤의 동기화가 실패하면 예외가 나가지만
  /// 효과는 이미 쓴 것이고 도착은 다음 동기화가 처리한다
  Future<void> useTravelEffect(String itemId, DateTime now) async {
    await sync(now);
    final block = await db.transaction<ShopBlock?>(() async {
      final item = shopCatalog?.byId(itemId);
      final effect = item?.effect;
      if (item == null || effect == null) return ShopBlock.unknownItem;
      final today = kstDayKey(now);
      final uses = await (db.select(db.shopUses)..where((t) => t.day.equals(today))).get();
      final usedKm = uses.fold(0.0, (sum, u) => sum + u.km);
      final capKm = rules.shopDailyEffectCapKm;
      final active = await _activeJourney();
      final walk = await (db.select(db.appWalks)
            ..where((t) => t.endUtc.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startUtc)])
            ..limit(1))
          .getSingleOrNull();
      final held = await _held(item.id);
      final block = useBlock(
        item,
        held: held,
        hasJourney: active != null,
        inWalk: walk != null,
        usedToday: uses.where((u) => u.itemId == item.id).length,
        usedKmToday: usedKm,
        capKm: capKm,
      );
      if (block != null) return block;
      final instant = effect.kind == ShopEffectKind.travelKmInstant;
      await db.into(db.shopUses).insert(ShopUsesCompanion.insert(
            itemId: item.id,
            day: today,
            journeyId: active!.id,
            appWalkId: Value(instant ? null : walk!.id),
            km: Value(instant ? clipEffectKm(effect.km ?? 0, usedKm: usedKm, capKm: capKm) : 0.0),
          ));
      await _setHeld(item.id, held - 1);
      final state = await _ensureState(now);
      await _recomputeDays(today, today, state.restoreFloorDay, now);
      return null;
    });
    if (block != null) throw ShopBlocked(block);
    await sync(now);
  }

  /// 가진 배 id. 기본 배는 줄이 없어도 가진 것이다
  Future<Set<String>> ownedBoatIds() async => {
        if (shopCatalog case final shop?) shop.defaultBoat,
        for (final r in await db.select(db.boatsOwned).get()) r.boatId,
      };

  /// 지금 타는 배. 안 골랐으면 기본 배. 배 데이터가 없으면 null
  Future<Boat?> selectedBoat() async {
    final boats = boatCatalog;
    final shop = shopCatalog;
    if (boats == null || shop == null) return null;
    return boatOf(boats, (await _profileRow())?.boatId, shop.defaultBoat);
  }

  /// 탈 배를 고른다. 가진 배가 아니면 [ShopBlocked]
  Future<void> chooseBoat(String boatId) async {
    if (!(await ownedBoatIds()).contains(boatId)) throw ShopBlocked(ShopBlock.notOwned);
    await db
        .into(db.profile)
        .insertOnConflictUpdate(ProfileCompanion(id: const Value(1), boatId: Value(boatId)));
  }

  Future<int> _held(String itemId) async =>
      (await (db.select(db.shopInventory)..where((t) => t.itemId.equals(itemId)))
              .getSingleOrNull())
          ?.count ??
      0;

  /// 보관 개수를 적는다. 0이면 줄을 지운다
  Future<void> _setHeld(String itemId, int count) async {
    if (count <= 0) {
      await (db.delete(db.shopInventory)..where((t) => t.itemId.equals(itemId))).go();
      return;
    }
    await db
        .into(db.shopInventory)
        .insertOnConflictUpdate(ShopInventoryCompanion.insert(itemId: itemId, count: count));
  }

  Future<bool> _ownsItem(ShopItem item) async {
    if (item.propId case final id?) return (await ownedPropIds()).contains(id);
    if (item.boatId case final id?) return (await ownedBoatIds()).contains(id);
    return false;
  }

  Future<void> _grantItem(ShopItem item, int at) async {
    if (item.effect != null) {
      await _setHeld(item.id, await _held(item.id) + 1);
    } else if (item.propId case final id?) {
      await db.into(db.propsOwned).insert(PropsOwnedCompanion.insert(propId: id, unlockedUtc: at));
    } else if (item.boatId case final id?) {
      await db.into(db.boatsOwned).insert(BoatsOwnedCompanion.insert(boatId: id, atUtc: at));
    }
  }

  /// 이 여정에 더한 상점 효과(km). 진행 거리에만 더하는 값이다
  Future<double> _journeyShopKm(String journeyId) async {
    final rows =
        await (db.select(db.shopUses)..where((t) => t.journeyId.equals(journeyId))).get();
    return rows.fold<double>(0.0, (sum, u) => sum + u.km);
  }

  /// 이 여정의 거리 [km]에서 상점 효과를 뺀 값 (0 아래로 안 내려간다). 경비·도장은 효과를 안 친다
  Future<double> _withoutShopKm(String journeyId, double km) async =>
      math.max(0.0, km - await _journeyShopKm(journeyId));

  /// [days]의 상점 효과 거리(m, 날짜별). 하루 요약의 shopM이 된다.
  /// 지름길은 쓸 때 정한 km 그대로 두고, 순풍은 [gaits]로 다시 계산해서 ShopUses.km에 적는다:
  /// 지름길을 뺀 하루 상한 안에서 잘라 합이 늘 상한을 넘지 않고, 같은 기록이면 같은 값이다.
  /// 적어 둔 값보다 줄이지 않는다: 복원하면 걸음 분이 비어 다시 계산한 값이 모자라고,
  /// 걸음이 빠진 기록으로 다시 동기화해도 이미 더한 거리는 그대로 둔다
  Future<Map<String, double>> _shopMetersByDay(
    List<String> days,
    List<GaitMinute> gaits,
    DateTime now,
  ) async {
    final usedKm = {for (final d in days) d: 0.0};
    final rows = await (db.select(db.shopUses)
          ..where((t) => t.day.isIn(days))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
    final tailwinds = <(ShopUseRow, double)>[];
    for (final r in rows) {
      final effect = shopCatalog?.byId(r.itemId)?.effect;
      if (effect?.kind == ShopEffectKind.travelRatioUntilWalkEnd && effect?.ratio != null) {
        tailwinds.add((r, effect!.ratio!));
      } else {
        usedKm[r.day] = usedKm[r.day]! + r.km;
      }
    }
    for (final (r, ratio) in tailwinds) {
      final km = math.max(
        r.km,
        clipEffectKm(
          await _tailwindWantKm(r, ratio, gaits, now),
          usedKm: usedKm[r.day]!,
          capKm: rules.shopDailyEffectCapKm,
        ),
      );
      usedKm[r.day] = usedKm[r.day]! + km;
      if (km != r.km) {
        await (db.update(db.shopUses)..where((t) => t.id.equals(r.id)))
            .write(ShopUsesCompanion(km: Value(km)));
      }
    }
    return {for (final d in days) d: usedKm[d]! * 1000};
  }

  /// 순풍이 더하고 싶은 km: 묶인 걷는 중 창이 그 여정과 겹친 동안의 실제 거리 × [ratio].
  /// 창이나 여정 기록이 없으면 적힌 값 그대로
  Future<double> _tailwindWantKm(
    ShopUseRow use,
    double ratio,
    List<GaitMinute> gaits,
    DateTime now,
  ) async {
    final walkId = use.appWalkId;
    if (walkId == null) return use.km;
    final walk =
        await (db.select(db.appWalks)..where((t) => t.id.equals(walkId))).getSingleOrNull();
    final journey = await (db.select(db.journeys)..where((t) => t.id.equals(use.journeyId)))
        .getSingleOrNull();
    if (walk == null || journey == null) return use.km;
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final from = math.max(walk.startUtc, journey.startUtc);
    final to = math.min(walk.endUtc ?? nowMs, journey.arrivedUtc ?? journey.endedUtc ?? nowMs);
    return walkedMBetween(gaits, from, to, rules) * ratio / 1000;
  }

  /// 동기화 끝에 새로 얻은 보상 배를 더하고 돌려준다 (boats.json 순서). 도착은 그림을 얻은 명소로 보며
  /// 내 동네 스케치는 들어가지 않는다. 한 번 받은 배는 다시 안 주고, 자동으로 갈아타지 않는다
  Future<List<Boat>> _unlockBoats(DateTime now) async {
    final catalog = boatCatalog;
    if (catalog == null) return const [];
    final islands = {
      for (final id in await _visitedLandmarkIds())
        if (landmarks[id] case final l?) l.island.name,
    };
    final owned = {for (final r in await db.select(db.boatsOwned).get()) r.boatId};
    final fresh = [
      for (final b in earnedRewardBoats(catalog, islands))
        if (!owned.contains(b.id)) b,
    ];
    final at = now.toUtc().millisecondsSinceEpoch;
    await db.batch((b) => b.insertAll(db.boatsOwned, [
          for (final boat in fresh) BoatsOwnedCompanion.insert(boatId: boat.id, atUtc: at),
        ]));
    return fresh;
  }
}
