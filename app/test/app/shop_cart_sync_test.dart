import 'package:doobal/app/paint_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/color_props.dart';
import 'package:doobal/domain/scene.dart' show seasonOf;
import 'package:doobal/domain/shop.dart';
import 'package:doobal/domain/shop_cart.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:drift/drift.dart' show InsertMode, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

// 오늘의 수레 저장·사기 (16장 11/19·11/20, M2~M6 AC 테스트 목록 + 개발인계_20261120 3장 테스트, DB 21).
// 설치 KST 2026-11-18 09:00. 수레 날은 한국 시간 새벽 5시에 바뀐다

final _t0 = DateTime.utc(2026, 11, 18, 0);
final _cart = rules.shopCart;

/// 한국 시간 [day] 'YYYY-MM-DD'의 [hour]:[minute]
DateTime _kst(String day, int hour, [int minute = 0]) =>
    kstDayStartUtc(day).add(Duration(hours: hour, minutes: minute));

class _Env {
  _Env() : db = AppDb(NativeDatabase.memory()) {
    svc = SyncService(
      db: db,
      source: FakeStepSource(),
      rules: rules,
      allowedSources: const [],
      landmarks: {for (final l in landmarks) l.id: l},
      props: props,
      shopCatalog: shopCatalog,
      boatCatalog: boatCatalog,
    );
  }

  final AppDb db;
  late final SyncService svc;

  /// 설치하고(동기화 상태 = 설치 시각) 설치 번호가 있는 프로필을 둔다
  Future<void> install() async {
    await svc.sync(_t0);
    await completeOnboarding(db);
  }

  Future<void> give(int coins) => db
      .into(db.coinLedger)
      .insert(CoinLedgerCompanion.insert(day: '2026-11-18', kind: CoinKind.gift, amount: coins));

  /// [day]의 하루 요약에 실제 거리 [km]를 둔다 (수레는 하루 요약만 읽는다)
  Future<void> walked(String day, double km) => db.into(db.daySummaries).insertOnConflictUpdate(
      DaySummariesCompanion.insert(day: day, steps: 0, distanceM: km * 1000, countedSessions: 0));

  Future<void> ownProp(String id) => db
      .into(db.propsOwned)
      .insert(PropsOwnedCompanion.insert(propId: id, unlockedUtc: 1), mode: InsertMode.insertOrIgnore);

  /// 상점에서 살 수 있는 물품을 모두 가진다 ([except]만 빼고)
  Future<void> ownEverything({Set<String> except = const {}}) async {
    for (final i in [...shopCatalog.items, ...colorShopItems(props)]) {
      if (except.contains(i.id)) continue;
      if (i.propId case final id?) await ownProp(id);
      if (i.boatId case final id?) {
        await db.into(db.boatsOwned).insert(BoatsOwnedCompanion.insert(boatId: id, atUtc: 1));
      }
      if (i.decorId case final id?) {
        await db.into(db.decorOwned).insert(DecorOwnedCompanion.insert(decorId: id, gotUtc: 1));
      }
      if (i.trailId case final id?) {
        await db.into(db.patternsOwned).insert(PatternsOwnedCompanion.insert(patternId: id, gotUtc: 1));
      }
    }
  }

  Future<List<String>> ids(DateTime now) async => [for (final s in (await svc.todayCart(now)).slots) s.item.id];
}

Future<_Env> _env() async {
  final e = _Env();
  await e.install();
  return e;
}

/// 물감 통이 [tube]대로 나오는 수레 날 (설치 번호 0×32, 11/18부터 찾는다)
Future<String> _dayWith(_Env e, {required bool tube}) async {
  for (var n = 0; n < 40; n++) {
    final day = addDays('2026-11-18', n);
    final ids = await e.ids(_kst(day, 12));
    if (ids.contains('paint_tube') == tube) return day;
  }
  throw StateError('그런 날이 없다');
}

Matcher _blocked(ShopBlock b) =>
    throwsA(isA<ShopBlocked>().having((e) => e.block, 'block', b));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('그날 줄', () {
    test('같은 날은 같은 줄: 다시 열어도·밤에도·새벽 4시 59분에도, 저장한 줄 그대로', () async {
      final e = await _env();
      final first = await e.ids(_kst('2026-11-18', 9, 30));
      expect(first, hasLength(3));
      expect(await e.ids(_kst('2026-11-18', 23)), first);
      expect(await e.ids(_kst('2026-11-19', 4, 59)), first);
      final rows = await e.db.select(e.db.shopCartSlots).get();
      expect([for (final r in rows) (r.kstDay, r.slot, r.itemId)], [
        for (final (i, id) in first.indexed) ('2026-11-18', i, id),
      ]);
      // 여행 효과는 고정 칸 (order 순)
      expect([for (final i in (await e.svc.todayCart(_kst('2026-11-18', 10))).fixed) i.id], ['fx_shortcut', 'fx_tailwind']);
    });

    test('설치 번호가 없으면(만 14세 확인 전·계정 삭제 뒤) 정하지 않는다: 빈 수레, 줄·나온 횟수 0', () async {
      final e = _Env();
      await e.svc.sync(_t0);
      final cart = await e.svc.todayCart(_kst('2026-11-18', 10));
      expect(cart.slots, isEmpty);
      expect(cart.fixed, isEmpty);
      expect(await e.db.select(e.db.shopCartSlots).get(), isEmpty);
      expect(await e.db.select(e.db.shopShown).get(), isEmpty);
      // 확인을 마치면 그날 줄을 정한다
      await completeOnboarding(e.db);
      expect(await e.ids(_kst('2026-11-18', 10)), hasLength(3));
    });

    test('새벽 5시 전후로 바뀐다: 새 줄은 안 나온 것 먼저라 겹치지 않고, 지난 날 줄은 지운다', () async {
      final e = await _env();
      final day1 = await e.ids(_kst('2026-11-19', 4, 59));
      final day2 = await e.ids(_kst('2026-11-19', 5));
      final regular1 = day1.where((id) => id != 'paint_tube').toSet();
      expect(day2.toSet().intersection(regular1), isEmpty);
      final days = {for (final r in await e.db.select(e.db.shopCartSlots).get()) r.kstDay};
      expect(days, {'2026-11-19'});
    });

    test('나온 상품은 나온 날 수·처음 나온 날을 적는다 (물감 통은 안 적는다)', () async {
      final e = await _env();
      final first = await e.ids(_kst('2026-11-18', 10));
      await e.ids(_kst('2026-11-18', 20)); // 같은 날 다시 읽어도 세지 않는다
      final shown = {for (final r in await e.db.select(e.db.shopShown).get()) r.itemId: r};
      for (final id in first.where((id) => id != 'paint_tube')) {
        expect((shown[id]!.timesShown, shown[id]!.firstShownDay), (1, '2026-11-18'), reason: id);
      }
      expect(shown.containsKey('paint_tube'), isFalse);
    });

    test('50km 전에는 3칸, 50km를 넘은 날은 그대로 3칸, 다음 날 4칸', () async {
      final e = await _env();
      await e.walked('2026-11-18', 30);
      expect(await e.ids(_kst('2026-11-19', 8)), hasLength(3));
      // 11/19 낮에 50km를 넘었다: 그날 줄은 그대로, 아직 안 정한 날이어도 그날은 전날까지 거리로 정한다
      await e.walked('2026-11-19', 25);
      expect(await e.ids(_kst('2026-11-19', 20)), hasLength(3));
      final cart = await e.svc.todayCart(_kst('2026-11-20', 8));
      expect(cart.slots, hasLength(4));
      expect((cart.cartKm, cart.totalKm), (55, 55));
      expect(lockedSlotKms(_cart, cart.cartKm), [150, 300]);
    });

    test('가진 물품은 어떤 날에도 안 나온다 (기본 소품·산 것·걸어서 얻은 것)', () async {
      final e = await _env();
      for (final id in ['cloth_05', 'shoe_04', 'hat_01_c1', 'shoe_01_c2']) {
        await e.ownProp(id);
      }
      for (var n = 0; n < 14; n++) {
        final ids = await e.ids(_kst(addDays('2026-11-18', n), 12));
        expect(ids.toSet().intersection({'cloth_05', 'shoe_04', 'hat_01_c1', 'shoe_01_c2', 'hat_01', 'cloth_02', 'shoe_01'}),
            isEmpty);
      }
    });

    test('물감 통은 물감을 가져도 나오고, 여행 효과는 보관해도 고정 칸에 늘 있다', () async {
      final e = await _env();
      await e.db.into(e.db.shopInventory).insert(ShopInventoryCompanion.insert(itemId: 'fx_shortcut', count: 9));
      final tubeDay = await _dayWith(e, tube: true);
      final cart = await e.svc.todayCart(_kst(tubeDay, 12));
      final tube = cart.slots.firstWhere((s) => s.item.id == 'paint_tube');
      expect(rules.paintColor.seasonIds(seasonOf(tubeDay, rules)), contains(tube.tubeColor));
      expect([for (final i in cart.fixed) i.id], ['fx_shortcut', 'fx_tailwind']);
    });

    test('25km 전에는 미니 친구가 없고, 25km를 넘긴 다음 날부터 섞인다', () async {
      final e = await _env();
      for (var n = 0; n < 10; n++) {
        final ids = await e.ids(_kst(addDays('2026-11-18', n), 12));
        expect(ids.where((id) => id.startsWith('pet_')), isEmpty);
      }
      // 처음 묶음·무늬를 모두 가지면 25km 뒤 수레는 미니 친구만 (물감 통 빼고)
      final lower = {
        for (final i in [...shopCatalog.items, ...colorShopItems(props)])
          if (!{'cloth', 'hat', 'shoe', 'trail', 'paintTube'}.contains(cartKindOf(i))) i.id,
      };
      await e.ownEverything(except: lower);
      await e.walked('2026-11-27', 25);
      final ids = await e.ids(_kst('2026-11-28', 12));
      expect(ids.where((id) => id != 'paint_tube').map((id) => shopCatalog.byId(id)!.slot).toSet(), {'pet'});
    });

    test('모두 가지면 여행 효과 칸만 (빈 칸 없음)', () async {
      final e = await _env();
      await e.ownEverything();
      await e.walked('2026-11-17', 1000);
      final day = await _dayWith(e, tube: false);
      final cart = await e.svc.todayCart(_kst(day, 12));
      expect(cart.slots, isEmpty);
      expect(cart.fixed, hasLength(2));
    });
  });

  group('팔림 (SOLD)', () {
    test('사면 그 칸이 팔림이 되고 다시 채우지 않는다, 같은 칸은 다시 못 산다', () async {
      final e = await _env();
      await e.give(5000);
      final day = await _dayWith(e, tube: false);
      final at = _kst(day, 12);
      final before = await e.svc.todayCart(at);
      final slot = before.slots.first;
      final balance = await e.svc.coinBalance();
      await e.svc.buyCartSlot(day, slot.slot, at);
      final after = await e.svc.todayCart(at.add(const Duration(minutes: 5)));
      expect([for (final s in after.slots) s.item.id], [for (final s in before.slots) s.item.id]);
      expect(after.slots.first.soldUtc, at.millisecondsSinceEpoch);
      expect(after.slots.skip(1).every((s) => !s.sold), isTrue);
      expect(await e.svc.coinBalance(), balance - slot.item.price);
      expect(await e.svc.ownedPropIds(), contains(slot.item.propId));
      expect(await e.svc.whyNotBuyCart(day, slot.slot, at), ShopBlock.soldOut);
      await expectLater(e.svc.buyCartSlot(day, slot.slot, at), _blocked(ShopBlock.soldOut));
      expect(await e.svc.coinBalance(), balance - slot.item.price);
    });

    test('걸어서(다른 길로) 얻은 물건이 그날 칸에 있으면 그 칸도 팔림', () async {
      final e = await _env();
      final day = await _dayWith(e, tube: false);
      final at = _kst(day, 12);
      final second = (await e.svc.todayCart(at)).slots[1];
      await e.ownProp(second.item.propId!);
      final after = await e.svc.todayCart(at.add(const Duration(hours: 1)));
      expect(after.slots[1].soldUtc, at.add(const Duration(hours: 1)).millisecondsSinceEpoch);
      expect([for (final s in after.slots) s.sold], [false, true, false]);
    });

    test('새벽 5시 새 수레에서 팔림이 풀린다', () async {
      final e = await _env();
      await e.give(5000);
      final day = await _dayWith(e, tube: false);
      await e.svc.buyCartSlot(day, 0, _kst(day, 12));
      final next = await e.svc.todayCart(_kst(addDays(day, 1), 5));
      expect(next.day, addDays(day, 1));
      expect(next.slots.where((s) => s.sold), isEmpty);
      expect(await e.db.select(e.db.shopCartSlots).get(), hasLength(next.slots.length));
    });

    test('럭이 모자라면 막고 아무것도 안 바뀐다, 지난 날 칸은 못 산다', () async {
      final e = await _env();
      final day = await _dayWith(e, tube: false);
      final at = _kst(day, 12);
      await e.svc.todayCart(at);
      expect(await e.svc.whyNotBuyCart(day, 0, at), ShopBlock.notEnoughCoins);
      await expectLater(e.svc.buyCartSlot(day, 0, at), _blocked(ShopBlock.notEnoughCoins));
      expect((await e.svc.todayCart(at)).slots.first.sold, isFalse);
      await e.give(5000);
      // 시트를 연 사이 새벽 5시가 지났다
      expect(await e.svc.whyNotBuyCart(day, 0, _kst(addDays(day, 1), 5)), ShopBlock.soldOut);
    });

    test('물감 통: 그날 색 3통을 물감 보관에 더하고(길에서 줍는 통과 같은 양), 30 럭, 그 칸은 팔림', () async {
      final e = await _env();
      await e.give(100);
      final day = await _dayWith(e, tube: true);
      final at = _kst(day, 12);
      final tube = (await e.svc.todayCart(at)).slots.firstWhere((s) => s.item.id == 'paint_tube');
      await e.svc.buyCartSlot(day, tube.slot, at);
      expect(await e.svc.coinBalance(), 70);
      final stock = await (e.db.select(e.db.paintStock)..where((t) => t.colorId.equals(tube.tubeColor!))).getSingle();
      expect((stock.tubes, stock.seen), (3, false));
      final rows = await e.db.select(e.db.paintTubes).get();
      expect(rows, hasLength(3));
      expect(rows.every((r) => r.trailId == -1 && r.colorId == tube.tubeColor), isTrue);
      expect(rows.map((r) => r.amountM).every((m) => m >= 770 && m <= 1540), isTrue);
      expect(stock.remainM, rows.fold(0.0, (a, r) => a + r.amountM));
      // 배낭 물감 탭도 같은 통 수를 본다
      final shelf = await PaintService(e.db, rules).shelf();
      expect(shelf.colors.firstWhere((c) => c.colorId == tube.tubeColor).tubes, 3);
      expect((await e.svc.todayCart(at)).slots.firstWhere((s) => s.slot == tube.slot).sold, isTrue);
    });

    test('쉼터 물품·무늬·배도 사면 그 표에 들어간다 (무늬는 거리 보상이 아니다)', () async {
      final e = await _env();
      await e.give(100000);
      await e.walked('2026-11-17', 1000);
      // 다른 것을 다 가지면 그날 수레에 남은 셋만 나온다
      await e.ownEverything(except: {'decor_bench', 'trail_02', 'boat_pirate'});
      final day = await _dayWith(e, tube: false);
      final at = _kst(day, 12);
      final cart = await e.svc.todayCart(at);
      expect({for (final s in cart.slots) s.item.id}, {'decor_bench', 'trail_02', 'boat_pirate'});
      for (final s in cart.slots) {
        await e.svc.buyCartSlot(day, s.slot, at);
      }
      expect((await (e.db.select(e.db.decorOwned)..where((t) => t.decorId.equals('decor_bench'))).getSingle()).gotUtc,
          at.millisecondsSinceEpoch);
      final pattern = await (e.db.select(e.db.patternsOwned)..where((t) => t.patternId.equals('trail_02'))).getSingle();
      expect((pattern.rewardKm, pattern.seen), (null, false));
      expect(await e.svc.ownedBoatIds(), contains('boat_pirate'));
      expect((await e.svc.todayCart(at)).slots.every((s) => s.sold), isTrue);
    });
  });

  group('새 상품 점', () {
    test('설치한 날은 없고, 다음 날 처음 나온 상품이 있으면 켜지고, 상점을 보면 그날은 꺼진다', () async {
      final e = await _env();
      expect((await e.svc.todayCart(_kst('2026-11-18', 12))).news, isFalse);
      final day2 = await e.svc.todayCart(_kst('2026-11-19', 6));
      expect(day2.slots.any((s) => s.fresh), isTrue);
      expect(day2.news, isTrue);
      await e.svc.markShopSeen(_kst('2026-11-19', 7));
      expect((await e.svc.todayCart(_kst('2026-11-19', 8))).news, isFalse);
      // 다음 날 새 상품이 있으면 다시
      expect((await e.svc.todayCart(_kst('2026-11-20', 6))).news, isTrue);
    });

    test('처음 나온 상품이 없는 날(다 나와 본 상품뿐)은 점이 없다', () async {
      final e = await _env();
      // 처음 묶음 하나만 남기면 그 상품은 첫날 나오고, 다음 날부터는 처음 나온 게 아니다
      await e.ownEverything(except: {'cloth_05'});
      expect(await e.ids(_kst('2026-11-18', 12)), contains('cloth_05'));
      var day = '2026-11-19';
      while ((await e.ids(_kst(day, 12))).contains('paint_tube')) {
        day = addDays(day, 1);
      }
      final cart = await e.svc.todayCart(_kst(day, 12));
      expect([for (final s in cart.slots) (s.item.id, s.fresh)], [('cloth_05', false)]);
      expect(cart.news, isFalse);
    });
  });
}
