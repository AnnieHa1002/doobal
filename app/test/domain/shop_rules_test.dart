import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/domain/sky.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 럭·상점·배의 순수 규칙 (M4.5). 값은 실제 shop.json·boats.json·config.json

ShopItem _item(String id) => shopCatalog.byId(id)!;

ShopBlock? _buy(
  String id, {
  int balance = 100000,
  int held = 0,
  bool owned = false,
}) =>
    buyBlock(
      _item(id),
      balance: balance,
      held: held,
      maxHold: rules.shopMaxHoldPerItem,
      owned: owned,
    );

ShopBlock? _use(
  String id, {
  int held = 1,
  bool hasJourney = true,
  bool inWalk = true,
  int usedToday = 0,
  double usedKmToday = 0,
}) =>
    useBlock(
      _item(id),
      held: held,
      hasJourney: hasJourney,
      inWalk: inWalk,
      usedToday: usedToday,
      usedKmToday: usedKmToday,
      capKm: rules.shopDailyEffectCapKm,
    );

void main() {
  group('잔액', () {
    test('들어온 럭 − 쓴 럭이고 음수가 되지 않는다', () {
      expect(coinBalanceOf(credited: 150, spent: 50), 100);
      expect(coinBalanceOf(credited: 50, spent: 50), 0);
      expect(coinBalanceOf(credited: 10, spent: 50), 0);
    });
  });

  group('구매 막기', () {
    test('값만큼 있으면 산다, 1럭 모자라면 막는다', () {
      final price = _item('fx_shortcut').price;
      expect(_buy('fx_shortcut', balance: price), isNull);
      expect(_buy('fx_shortcut', balance: price - 1), ShopBlock.notEnoughCoins);
    });

    test('여행 효과는 종류마다 보관 한도까지 (10번째 구매 막기)', () {
      final max = rules.shopMaxHoldPerItem;
      expect(max, 9);
      expect(_buy('fx_tailwind', held: max - 1), isNull);
      expect(_buy('fx_tailwind', held: max), ShopBlock.holdFull);
    });

    test('소품·꾸밈 효과·배는 한 번만 산다', () {
      for (final tab in [ShopTab.prop, ShopTab.effect, ShopTab.boat]) {
        final id = shopCatalog.inTab(tab).first.id;
        expect(_buy(id), isNull, reason: id);
        expect(_buy(id, owned: true), ShopBlock.owned, reason: id);
      }
    });

    test('줄 것이 없는 상품은 막는다', () {
      const empty = ShopItem(id: 'x', tab: ShopTab.prop, name: 'x', price: 1, order: 1);
      expect(buyBlock(empty, balance: 9, held: 0, maxHold: 9, owned: false), ShopBlock.unknownItem);
    });
  });

  group('사용 막기', () {
    test('가지고 있지 않으면, 여정이 없으면 막는다', () {
      expect(_use('fx_shortcut'), isNull);
      expect(_use('fx_shortcut', held: 0), ShopBlock.notOwned);
      expect(_use('fx_shortcut', hasJourney: false), ShopBlock.noJourney);
      expect(ShopBlock.noJourney.message, '여정 중에만 쓸 수 있어요');
    });

    test('지름길은 걷는 중이 아니어도 되고, 순풍은 걷는 중에만', () {
      expect(_use('fx_shortcut', inWalk: false), isNull);
      expect(_use('fx_tailwind', inWalk: false), ShopBlock.noWalk);
    });

    test('하루 횟수: 지름길 2장, 순풍 1번', () {
      expect(_use('fx_shortcut', usedToday: 1), isNull);
      expect(_use('fx_shortcut', usedToday: 2), ShopBlock.dailyLimit);
      expect(_use('fx_tailwind', usedToday: 1), ShopBlock.dailyLimit);
    });

    test('오늘 상한이 다 찼으면 효과를 버리지 않게 막는다', () {
      final cap = rules.shopDailyEffectCapKm;
      expect(_use('fx_shortcut', usedKmToday: cap - 0.1), isNull);
      expect(_use('fx_shortcut', usedKmToday: cap), ShopBlock.dailyCap);
      expect(_use('fx_tailwind', usedKmToday: cap), ShopBlock.dailyCap);
    });

    test('여행 효과가 아니면 막는다', () {
      expect(_use(shopCatalog.inTab(ShopTab.prop).first.id), ShopBlock.unknownItem);
    });
  });

  group('하루 상한', () {
    final cap = rules.shopDailyEffectCapKm;

    test('넘는 만큼 버린다 (지름길 2 + 순풍 5km 걷기 → 2 + 1 = 3)', () {
      expect(clipEffectKm(1, usedKm: 0, capKm: cap), 1);
      expect(clipEffectKm(1, usedKm: 2.5, capKm: cap), 0.5);
      expect(clipEffectKm(5 * 0.2, usedKm: 2, capKm: cap), 1);
      expect(clipEffectKm(10 * 0.2, usedKm: 2, capKm: cap), 1);
      expect(clipEffectKm(1, usedKm: cap, capKm: cap), 0);
      expect(clipEffectKm(-1, usedKm: 0, capKm: cap), 0);
    });
  });

  group('순풍이 보는 실제 거리', () {
    GaitMinute walk(int minute, int steps) => GaitMinute(minute, steps, Gait.walk);
    const minuteMs = Duration.millisecondsPerMinute;

    test('분 시작이 창 안인 분만, 걸음 × 보폭으로 센다', () {
      final minutes = [walk(10, 100), walk(11, 100), walk(12, 100)];
      expect(walkedMBetween(minutes, 11 * minuteMs, 12 * minuteMs, rules), closeTo(70, 1e-9));
      expect(walkedMBetween(minutes, 10 * minuteMs + 1, 13 * minuteMs, rules), closeTo(140, 1e-9));
      expect(walkedMBetween(minutes, 12 * minuteMs, 12 * minuteMs, rules), 0);
    });

    test('뛴 분은 뛰기 보폭으로 센다', () {
      final m = [GaitMinute(5, 100, Gait.run)];
      expect(walkedMBetween(m, 5 * minuteMs, 6 * minuteMs, rules), closeTo(100, 1e-9));
    });
  });

  group('보상 배', () {
    List<String> earned(Set<String> islands) =>
        [for (final b in earnedRewardBoats(boatCatalog, islands)) b.id];

    test('섬에 안 갔으면 없다', () => expect(earned({}), isEmpty));

    test('제주나 울릉 하나면 조각배, 둘 다면 돛단배까지', () {
      expect(earned({'jeju'}), ['boat_skiff']);
      expect(earned({'ulleung'}), ['boat_skiff']);
      expect(earned({'jeju', 'ulleung'}), ['boat_skiff', 'boat_voyage']);
    });

    test('육지는 치지 않는다', () => expect(earned({'mainland'}), isEmpty));
  });

  group('탈 배', () {
    test('안 골랐거나 데이터에 없으면 기본 배', () {
      expect(boatOf(boatCatalog, null, shopCatalog.defaultBoat)!.id, 'boat_raft');
      expect(boatOf(boatCatalog, 'gone', shopCatalog.defaultBoat)!.id, 'boat_raft');
      expect(boatOf(boatCatalog, 'boat_cruise', shopCatalog.defaultBoat)!.id, 'boat_cruise');
    });
  });

  group('배 그림', () {
    final cruise = boatCatalog.artOf(boatCatalog.byId('boat_cruise')!);

    test('경로는 assetDir 아래이고, 창 불빛은 있는 배만', () {
      expect(cruise.rear, startsWith('assets/boats/v01fix/'));
      expect(cruise.front, startsWith('assets/boats/v01fix/'));
      expect(cruise.nightOverlay, startsWith('assets/boats/v01fix/'));
      expect(boatCatalog.artOf(boatCatalog.byId('boat_raft')!).nightOverlay, isNull);
    });

    test('정령 발이 mainFoot에 닿고, 동행 발은 같은 원점에서 companionFoot', () {
      const scale = 0.5;
      final at = placeBoat(cruise, footX: 100, footY: 200, scale: scale);
      expect(at.left + cruise.mainFoot.x * scale, closeTo(100, 1e-9));
      expect(at.top + cruise.mainFoot.y * scale, closeTo(200, 1e-9));
      expect(at.width, boatCatalog.canvasWidth * scale);
      expect(at.height, boatCatalog.canvasHeight * scale);
      expect(at.companionFoot.x, closeTo(at.left + cruise.companionFoot.x * scale, 1e-9));
      expect(at.companionFoot.y, closeTo(200, 1e-9));
    });

    test('창 불빛은 밤·새벽에만', () {
      expect(
        [for (final p in SkyPhase.values) if (boatLightOn(p)) p],
        unorderedEquals([SkyPhase.night, SkyPhase.dawn]),
      );
    });
  });

  group('토스트', () {
    test('한 척이면 이름만, 여럿이면 외 n척', () {
      final skiff = boatCatalog.byId('boat_skiff')!;
      final voyage = boatCatalog.byId('boat_voyage')!;
      expect(newBoatToast([skiff]), '새 배를 얻었어요 · ${skiff.name}');
      expect(newBoatToast([skiff, voyage]), '새 배를 얻었어요 · ${skiff.name} 외 1척');
    });
  });
}
