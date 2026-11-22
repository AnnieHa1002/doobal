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
  /// 색 소품은 기본 소품을 가져야 산다 (처음부터 가진 기본 소품은 기록이 없어도 가진 것).
  /// 물감 통은 [tubeColor](그날 색)의 통이 상한이면 막는다
  Future<ShopBlock?> whyNotBuy(String itemId, {String? tubeColor}) async {
    final item = _shopItem(itemId);
    if (item == null) return ShopBlock.unknownItem;
    final needs = item.requires;
    final tube = item.paintTubes != null;
    if (tube && tubeColor == null) return ShopBlock.unknownItem;
    return buyBlock(
      item,
      balance: await coinBalance(),
      held: tube ? await _tubesHeld(tubeColor!) : await _held(item.id),
      maxHold: tube ? rules.paintColor.maxTubesPerColor : rules.shopMaxHoldPerItem,
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
  /// 순풍은 지금 열린 물감 길에 묶어 두고(그 물감 길이 끝날 때까지 실제 거리 × 비율) [_shopMetersByDay]가
  /// 다시 계산한다.
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
      final walk = await (db.select(db.paintTrails)
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
            paintTrailId: Value(instant ? null : walk!.id),
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

  Future<bool> _ownsItem(ShopItem item) async => (await _owned()).has(item);

  /// 지금 가진 물품 (한 번 읽어 여러 상품에 쓴다). 처음부터 가진 기본 소품·기본 배도 가진 것
  Future<_Owned> _owned() async => _Owned(
        props: havePropIds(props, await ownedPropIds()),
        boats: await ownedBoatIds(),
        decor: {for (final r in await db.select(db.decorOwned).get()) r.decorId},
        patterns: {for (final r in await db.select(db.patternsOwned).get()) r.patternId},
      );

  /// 산 상품을 준다. 물감 통은 [tubeColor] 색 통을 [cartSeed]·[cartDay]로 정한 양으로 더한다
  Future<void> _grantItem(ShopItem item, int at, {String? tubeColor, String cartSeed = '', String? cartDay}) async {
    if (item.effect != null) {
      await _setHeld(item.id, await _held(item.id) + 1);
    } else if (item.propId case final id?) {
      await db.into(db.propsOwned).insert(PropsOwnedCompanion.insert(propId: id, unlockedUtc: at));
    } else if (item.boatId case final id?) {
      await db.into(db.boatsOwned).insert(BoatsOwnedCompanion.insert(boatId: id, atUtc: at));
    } else if (item.decorId case final id?) {
      await db.into(db.decorOwned).insert(DecorOwnedCompanion.insert(decorId: id, gotUtc: at));
    } else if (item.trailId case final id?) {
      // 산 무늬는 거리 보상이 아니다 (rewardKm null). 새로 얻어도 저절로 고르지 않는다 (T17b)
      await db.into(db.patternsOwned).insert(PatternsOwnedCompanion.insert(patternId: id, gotUtc: at));
    } else if (item.paintTubes case final n?) {
      await _addCartTubes(tubeColor!, n, cartSeed, cartDay!, at);
    }
  }

  /// [colorId] 물감의 지금 통 수
  Future<int> _tubesHeld(String colorId) async =>
      (await (db.select(db.paintStock)..where((t) => t.colorId.equals(colorId))).getSingleOrNull())
          ?.tubes ??
      0;

  /// 수레에서 산 물감 통 [count]개를 물감 보관에 더한다 (길에서 줍는 통과 같은 양·같은 보관, 색마다 상한).
  /// 통 줄(PaintTubes)은 물감 길 대신 [cartTubeTrailId]·(수레 날 × 10 + 번호)를 키로 둔다: 통 수를 주운 차례로
  /// 다시 세는 PaintService가 같이 센다. 같은 날 같은 칸은 한 번만 팔리니 키가 겹치지 않는다
  Future<void> _addCartTubes(String colorId, int count, String seed, String day, int at) async {
    final pc = rules.paintColor;
    final tube = pc.rewards.whereType<TubeReward>().firstOrNull;
    if (tube == null) throw StateError('물감 통 양이 config에 없다 (paintColor.tube)');
    final row = await (db.select(db.paintStock)..where((t) => t.colorId.equals(colorId))).getSingleOrNull();
    final room = pc.maxTubesPerColor - (row?.tubes ?? 0);
    final n = math.min(count, room);
    if (n <= 0) return;
    final dayNo = dayFromKey(day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    var added = 0.0;
    for (var i = 0; i < n; i++) {
      final amount = cartTubeAmountM(tube.minM, tube.maxM, seed, day, i).toDouble();
      await db.into(db.paintTubes).insert(PaintTubeRow(
          trailId: cartTubeTrailId, dropNo: dayNo * 10 + i, colorId: colorId, amountM: amount, atUtc: at));
      added += amount;
    }
    final tubes = await (db.select(db.paintTubes)
          ..where((t) => t.colorId.equals(colorId))
          ..orderBy([(t) => OrderingTerm(expression: t.atUtc), (t) => OrderingTerm(expression: t.dropNo)]))
        .get();
    final amounts = [for (final r in tubes) r.amountM];
    final total = amounts.fold(0.0, (a, b) => a + b);
    if (row == null) {
      await db.into(db.paintStock).insert(PaintStockCompanion.insert(
          colorId: colorId, tubes: n, remainM: added, firstGotAt: at, lastGotAt: at));
    } else {
      final remain = row.remainM + added;
      await (db.update(db.paintStock)..where((t) => t.colorId.equals(colorId))).write(PaintStockCompanion(
          remainM: Value(remain), tubes: Value(tubesLeft(amounts, total - remain)), lastGotAt: Value(at)));
    }
  }

  // 오늘의 수레 (16장 11/19·11/20, M2~M6 AC, config shop.cart, DB 21 shop_cart_slots·shop_shown)

  /// 상점 화면이 읽는 그날 수레. 그날 줄이 없으면 지금 정해 저장하고(그날은 다시 정하지 않는다) 지난 날 줄은
  /// 지운다. 줄에 있는 칸 중 그사이 가지게 된 물건(사거나 걸어서 얻음, 물감 통·여행 효과 빼고)은 지금 시각으로
  /// 팔림 표시를 한다. 상점 데이터가 없으면 빈 수레.
  /// 설치 번호(만 14세 확인 때 생김)가 없으면 정하지도 저장하지도 않고 빈 수레: 계정 삭제 직후 쉼터가 닫히기 전에
  /// 이 값을 다시 읽으면 빈 DB에 설치 번호 없는 수레 줄·나온 횟수가 다시 생겨서다 (계정삭제_경합 노트)
  Future<TodayCart> todayCart(DateTime now) async {
    final shop = shopCatalog;
    if (shop == null) return TodayCart.empty;
    final cart = rules.shopCart;
    final day = cart.dayOf(now);
    final at = now.toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      final seed = (await _profileRow())?.installId;
      if (seed == null) return TodayCart.empty;
      final summaries = await db.select(db.daySummaries).get();
      final cartKm = summaries.where((d) => d.day.compareTo(day) < 0).fold(0.0, (a, d) => a + d.distanceM) / 1000;
      final totalKm = summaries.fold(0.0, (a, d) => a + d.distanceM) / 1000;
      final owned = await _owned();
      var rows = await _cartRows(day);
      if (rows.isEmpty) {
        await _decideCart(day, cartKm, seed, owned);
        rows = await _cartRows(day);
      }
      final shown = {for (final r in await db.select(db.shopShown).get()) r.itemId: r};
      final slots = <CartSlot>[];
      for (final r in rows) {
        final item = _shopItem(r.itemId);
        // 데이터가 바뀌어 없어진 상품은 그날 칸에서 뺀다
        if (item == null) continue;
        var sold = r.soldUtc;
        if (sold == null && !cart.ownedStillSold.contains(cartKindOf(item)) && owned.has(item)) {
          sold = at;
          await (db.update(db.shopCartSlots)..where((t) => t.kstDay.equals(day) & t.slot.equals(r.slot)))
              .write(ShopCartSlotsCompanion(soldUtc: Value(sold)));
        }
        slots.add(CartSlot(
          slot: r.slot,
          item: item,
          soldUtc: sold,
          fresh: !cart.consumableKinds.contains(cartKindOf(item)) && shown[item.id]?.firstShownDay == day,
          tubeColor: item.paintTubes == null ? null : _cartTubeColor(seed, day),
        ));
      }
      final sync = await (db.select(db.syncState)..where((t) => t.id.equals(1))).getSingleOrNull();
      final seen = sync?.shopSeenUtc ?? sync?.installUtc;
      // 마지막으로 본 날의 칸 수 (연출 ③ 새 칸 열림, 그날 수레를 정한 거리 = 그 수레 날 전날까지)
      final seenDay = seen == null ? null : cart.dayOf(DateTime.fromMillisecondsSinceEpoch(seen, isUtc: true));
      final seenKm = seenDay == null
          ? cartKm
          : summaries.where((d) => d.day.compareTo(seenDay) < 0).fold(0.0, (a, d) => a + d.distanceM) / 1000;
      return TodayCart(
        day: day,
        fixed: [
          for (final i in shop.items)
            if (cart.fixedKinds.contains(cartKindOf(i)) && isSellable(i)) i,
        ]..sort((a, b) => a.order.compareTo(b.order)),
        slots: slots,
        cartKm: cartKm,
        totalKm: totalKm,
        news: cart.newDotOnNeverShown &&
            seen != null &&
            seen < cart.dayStartUtc(day).millisecondsSinceEpoch &&
            slots.any((s) => s.fresh),
        seenUtc: seen,
        seenSlots: cart.slotsAt(seenKm),
      );
    });
  }

  Future<List<ShopCartSlotRow>> _cartRows(String day) => (db.select(db.shopCartSlots)
        ..where((t) => t.kstDay.equals(day))
        ..orderBy([(t) => OrderingTerm(expression: t.slot)]))
      .get();

  /// 그날 줄을 정해 넣고, 나온 상품의 나온 횟수를 더하고(소모품 빼고), 지난 날 줄을 지운다
  Future<void> _decideCart(String day, double cartKm, String seed, _Owned owned) async {
    final shop = shopCatalog!;
    final cart = rules.shopCart;
    final shown = {for (final r in await db.select(db.shopShown).get()) r.itemId: r};
    final known = {for (final p in props) p.id};
    final items = [
      for (final i in [...shop.items, ...colorShopItems(props)])
        // 소품 상품은 앱 소품 목록(MVP)에 있는 것만
        if (isSellable(i) && (i.propId == null || known.contains(i.propId))) i,
    ];
    final ids = planCart(
      rules: cart,
      items: items,
      owned: owned.has,
      haveBase: owned.props.contains,
      totalKm: cartKm,
      timesShown: {for (final e in shown.entries) e.key: e.value.timesShown},
      seed: seed,
      day: day,
    );
    await (db.delete(db.shopCartSlots)..where((t) => t.kstDay.equals(day).not())).go();
    final kinds = {for (final i in items) i.id: cartKindOf(i)};
    await db.batch((b) {
      b.insertAll(db.shopCartSlots, [
        for (final (slot, id) in ids.indexed) ShopCartSlotsCompanion.insert(kstDay: day, slot: slot, itemId: id),
      ]);
      for (final id in ids.toSet()) {
        if (cart.consumableKinds.contains(kinds[id])) continue;
        final before = shown[id];
        b.insert(
          db.shopShown,
          ShopShownCompanion.insert(
            itemId: id,
            timesShown: (before?.timesShown ?? 0) + 1,
            firstShownDay: before?.firstShownDay ?? day,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// 그날 물감 통 칸의 색: 그날 계절의 16색 중 하나 (계절 변주가 없으면 16색 중), 지역 색 없음
  String _cartTubeColor(String seed, String day) {
    final pc = rules.paintColor;
    final colors = pc.seasonal ? pc.seasonIds(seasonOf(day, rules)) : pc.colorIds;
    return cartTubeColor(colors, seed, day);
  }

  /// 그날 수레 [day]의 [slot]칸을 지금 살 수 없는 까닭. 살 수 있으면 null (시트를 열기 전에 본다)
  Future<ShopBlock?> whyNotBuyCart(String day, int slot, DateTime now) async {
    final row = await _cartSlot(day, slot);
    if (row == null || row.soldUtc != null || rules.shopCart.dayOf(now) != day) return ShopBlock.soldOut;
    return whyNotBuy(row.itemId, tubeColor: _tubeColorFor(row.itemId, day, await _seed()));
  }

  /// 그날 수레 [day]의 [slot]칸을 산다: 한 트랜잭션에서 spend 줄·소유 기록(물감 통은 물감 보관)·그 칸 팔림.
  /// 팔린 칸은 다시 채우지 않는다 (config shop.cart.boughtToday removeOnBuy). 살 수 없으면 [ShopBlocked]를
  /// 던지고 아무것도 바꾸지 않는다
  Future<void> buyCartSlot(String day, int slot, DateTime now) async {
    final block = await db.transaction<ShopBlock?>(() async {
      final block = await whyNotBuyCart(day, slot, now);
      if (block != null) return block;
      final row = (await _cartSlot(day, slot))!;
      final item = _shopItem(row.itemId)!;
      final seed = await _seed();
      final at = now.toUtc().millisecondsSinceEpoch;
      await db.into(db.coinLedger).insert(CoinLedgerCompanion.insert(
            day: kstDayKey(now),
            kind: CoinKind.spend,
            amount: item.price,
            refId: Value(item.id),
          ));
      await _grantItem(item, at,
          tubeColor: _tubeColorFor(item.id, day, seed), cartSeed: seed, cartDay: day);
      if (rules.shopCart.removeOnBuy) {
        await (db.update(db.shopCartSlots)..where((t) => t.kstDay.equals(day) & t.slot.equals(slot)))
            .write(ShopCartSlotsCompanion(soldUtc: Value(at)));
      }
      return null;
    });
    if (block != null) throw ShopBlocked(block);
  }

  Future<ShopCartSlotRow?> _cartSlot(String day, int slot) =>
      (db.select(db.shopCartSlots)..where((t) => t.kstDay.equals(day) & t.slot.equals(slot))).getSingleOrNull();

  Future<String> _seed() async => (await _profileRow())?.installId ?? '';

  String? _tubeColorFor(String itemId, String day, String seed) =>
      _shopItem(itemId)?.paintTubes == null ? null : _cartTubeColor(seed, day);

  /// 상점을 본 것으로 적는다 (새 상품 점이 꺼진다, DB 19 sync_state.shop_seen_utc)
  Future<void> markShopSeen(DateTime now) => (db.update(db.syncState)..where((t) => t.id.equals(1)))
      .write(SyncStateCompanion(shopSeenUtc: Value(now.toUtc().millisecondsSinceEpoch)));

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

  /// 순풍이 더하고 싶은 km: 묶인 물감 길이 그 여정과 겹친 동안의 실제 거리 × [ratio].
  /// 물감 길이나 여정 기록이 없으면 적힌 값 그대로
  Future<double> _tailwindWantKm(
    ShopUseRow use,
    double ratio,
    List<GaitMinute> gaits,
    DateTime now,
  ) async {
    final walkId = use.paintTrailId;
    if (walkId == null) return use.km;
    final walk =
        await (db.select(db.paintTrails)..where((t) => t.id.equals(walkId))).getSingleOrNull();
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

/// 수레에서 산 물감 통의 통 줄(PaintTubes) 물감 길 자리. 물감 길 id는 1부터라 겹치지 않는다
const cartTubeTrailId = -1;

/// 가진 물품 한 번 읽은 것
class _Owned {
  const _Owned({required this.props, required this.boats, required this.decor, required this.patterns});

  final Set<String> props;
  final Set<String> boats;
  final Set<String> decor;
  final Set<String> patterns;

  /// [item]을 가졌는가. 여행 효과·물감 통(소모품)은 가진 것으로 치지 않는다
  bool has(ShopItem item) => switch (item) {
        ShopItem(propId: final id?) => props.contains(id),
        ShopItem(boatId: final id?) => boats.contains(id),
        ShopItem(decorId: final id?) => decor.contains(id),
        ShopItem(trailId: final id?) => patterns.contains(id),
        _ => false,
      };
}
