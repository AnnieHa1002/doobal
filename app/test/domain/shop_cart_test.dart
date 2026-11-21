import 'package:doobal/domain/color_props.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/domain/shop_cart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 오늘의 수레 순수 규칙 (16장 11/19·11/20, M2~M6 AC·AF, 개발인계_20261120 3장). 값은 실제 config·shop·props

final _cart = rules.shopCart;

/// 수레에 올릴 수 있는 모든 상품 (shop.json + 색 소품)
final _items = [...shopCatalog.items, ...colorShopItems(props)];

/// 처음부터 가진 기본 소품 (베레모·여행복·갈색 신발 등)
final _initial = havePropIds(props, const {});

List<String> _plan({
  double km = 0,
  Set<String> owned = const {},
  Map<String, int> shown = const {},
  String seed = 'install-a',
  String day = '2026-11-21',
}) {
  final have = {..._initial, ...owned};
  return planCart(
    rules: _cart,
    items: _items,
    owned: (i) => have.contains(i.propId ?? i.boatId ?? i.decorId ?? i.trailId),
    haveBase: have.contains,
    totalKm: km,
    timesShown: shown,
    seed: seed,
    day: day,
  );
}

String _kind(String id) => cartKindOf(_items.firstWhere((i) => i.id == id));

/// 물감 통이 나오는 날과 안 나오는 날 (씨앗 install-a, 11월에서 찾는다)
String _dayWith({required bool tube}) {
  for (var d = 1; d <= 30; d++) {
    final day = '2026-11-${d.toString().padLeft(2, '0')}';
    if (_plan(day: day).contains('paint_tube') == tube) return day;
  }
  throw StateError('그런 날이 없다');
}

void main() {
  group('config shop.cart', () {
    test('새벽 5시, 칸 0·50·150·300km → 3·4·5·6, 여행 효과 고정, 물감 통·여행 효과는 가져도 판다', () {
      expect(_cart.refreshHour, 5);
      expect([for (final s in _cart.slotsByKm) (s.km, s.slots)], [(0, 3), (50, 4), (150, 5), (300, 6)]);
      expect(_cart.fixedKinds, {'travel'});
      expect(_cart.ownedStillSold, {'paintTube', 'travel'});
      expect(_cart.consumableKinds, {'paintTube'});
      expect((_cart.excludeOwned, _cart.neverShownFirst, _cart.showFewer, _cart.removeOnBuy), (true, true, true, true));
      expect(_cart.newDotOnNeverShown, isTrue);
    });

    test('SOLD 도장 값 (v33: 56pt·#A4502F·2.5/7/1pt·SOLD 13pt 자간 1·700·−12°·88%·누를 수 없음)', () {
      final m = _cart.soldMark!;
      expect((m.diameterPt, m.argb, m.outerPt, m.innerInsetPt, m.innerPt), (56, 0xFFA4502F, 2.5, 7, 1));
      expect((m.text, m.textPt, m.letterSpacingPt, m.textWeight), ('SOLD', 13, 1, 700));
      expect((m.rotateDeg, m.opacity, m.tappable), (-12, 0.88, false));
    });

    test('모르는 값은 멈춘다 (시간대·거리 기준·산 칸·도장 그리기)', () {
      Map<String, dynamic> base() => {
            'refreshHour': 5,
            'refreshTz': 'Asia/Seoul',
            'distanceBasis': 'actualAll',
            'slotsByKm': [
              {'km': 0, 'slots': 3},
            ],
            'kindsByKm': const [],
            'prefer': 'neverShownFirst',
            'boughtToday': 'removeOnBuy',
            'fewerThanSlots': 'showFewer',
            'colorVariants': 'followBase',
          };
      expect(CartRules.fromJson(base()).slotsAt(0), 3);
      expect(() => CartRules.fromJson({...base(), 'refreshTz': 'UTC'}), throwsFormatException);
      expect(() => CartRules.fromJson({...base(), 'distanceBasis': 'travel'}), throwsFormatException);
      expect(() => CartRules.fromJson({...base(), 'boughtToday': 'refill'}), throwsFormatException);
      expect(() => CartRules.fromJson({...base(), 'slotsByKm': const []}), throwsFormatException);
      expect(
        () => CartRules.fromJson({...base(), 'soldMark': {'draw': 'image', 'until': 'nextRefresh'}}),
        throwsFormatException,
      );
      // 수레가 없는 config면 고정 칸만
      expect(CartRules.fromJson(null).slotsAt(1000), 0);
    });
  });

  group('칸 수·종류는 누적 실제 거리로', () {
    test('칸: 50km 전 3, 50km부터 4, 150km 5, 300km 6', () {
      expect(<double>[0, 49.9, 50, 149.9, 150, 299.9, 300, 1000].map(_cart.slotsAt), [3, 3, 4, 4, 5, 5, 6, 6]);
    });

    test('종류: 처음 옷·모자·신발·물감 통 → 5km 무늬 → 25km 미니 친구 → 75km 액세서리 → 150km 쉼터 물품·꾸밈 효과 → 300km 배',
        () {
      expect(_cart.kindsAt(0), {'cloth', 'hat', 'shoe', 'paintTube'});
      expect(_cart.kindsAt(4.9).contains('trail'), isFalse);
      expect(_cart.kindsAt(5).contains('trail'), isTrue);
      expect(_cart.kindsAt(24.9).contains('pet'), isFalse);
      expect(_cart.kindsAt(25).contains('pet'), isTrue);
      expect(_cart.kindsAt(75).containsAll(['face', 'hand', 'float']), isTrue);
      expect(_cart.kindsAt(149).contains('effect'), isFalse);
      expect(_cart.kindsAt(150).containsAll(['decor', 'effect']), isTrue);
      expect(_cart.kindsAt(299).contains('boat'), isFalse);
      expect(_cart.kindsAt(300).contains('boat'), isTrue);
    });

    test('상품 종류는 소품 칸, 없으면 분류 (색 소품은 기본 소품 칸)', () {
      expect(['fx_shortcut', 'cloth_05', 'pet_06', 'trail_01', 'paint_tube', 'decor_pond', 'boat_cruise', 'hat_01_c1']
          .map(_kind), ['travel', 'cloth', 'pet', 'trail', 'paintTube', 'decor', 'boat', 'hat']);
    });

    test('안 열린 칸 자리: 칸이 늘어나는 거리마다 하나씩', () {
      expect(lockedSlotKms(_cart, 0), [50, 150, 300]);
      expect(lockedSlotKms(_cart, 50), [150, 300]);
      expect(lockedSlotKms(_cart, 299), [300]);
      expect(lockedSlotKms(_cart, 300), isEmpty);
    });

    test('다음 종류 단계: 0km면 5km 무늬, 5km면 25km, 300km면 없음', () {
      expect(nextKindStep(_cart, 0)!.km, 5);
      expect(nextKindStep(_cart, 5)!.km, 25);
      expect(nextKindStep(_cart, 160)!.kinds, {'boat'});
      expect(nextKindStep(_cart, 300), isNull);
    });
  });

  group('수레 날', () {
    test('한국 시간 새벽 5시에 바뀐다 (4:59는 전날)', () {
      // KST 11/21 04:59 = UTC 11/20 19:59
      expect(_cart.dayOf(DateTime.utc(2026, 11, 20, 19, 59)), '2026-11-20');
      expect(_cart.dayOf(DateTime.utc(2026, 11, 20, 20, 0)), '2026-11-21');
      expect(_cart.dayOf(DateTime.utc(2026, 11, 21, 14, 59)), '2026-11-21');
      expect(_cart.dayStartUtc('2026-11-21'), DateTime.utc(2026, 11, 20, 20));
    });
  });

  group('그날 줄 정하기', () {
    test('같은 날·같은 씨앗이면 같은 줄, 날이나 씨앗이 다르면 섞임이 다르다', () {
      final a = _plan(day: '2026-11-21');
      expect(a, hasLength(3));
      expect(_plan(day: '2026-11-21'), a);
      final others = {
        for (var d = 22; d <= 28; d++) _plan(day: '2026-11-$d').join(','),
        for (final s in ['b', 'c', 'd']) _plan(seed: s).join(','),
      };
      expect(others.length, greaterThan(1));
      expect(others, isNot(contains(a.join(','))));
    });

    test('여행 효과는 수레 칸에 안 나온다 (고정 칸)', () {
      for (var d = 1; d <= 30; d++) {
        final line = _plan(km: 500, day: '2026-11-${d.toString().padLeft(2, '0')}');
        expect(line.where((id) => _kind(id) == 'travel'), isEmpty);
      }
    });

    test('가진 물품은 안 나온다', () {
      final day = _dayWith(tube: false);
      final first = _plan(day: day);
      final again = _plan(day: day, owned: first.toSet());
      expect(again.toSet().intersection(first.toSet()), isEmpty);
    });

    test('물감 통은 가져도(소모품) 나오고, 하루 한 칸까지, 칸 수 안에서', () {
      final day = _dayWith(tube: true);
      final line = _plan(day: day, owned: {'paint_tube'});
      expect(line.where((id) => id == 'paint_tube'), hasLength(1));
      expect(line, hasLength(3));
      expect(_plan(day: _dayWith(tube: false)).contains('paint_tube'), isFalse);
    });

    test('물감 통은 나온 횟수와 상관없이 그날 확률로만 (안 나온 것 먼저에서 빠짐)', () {
      final day = _dayWith(tube: true);
      expect(_plan(day: day, shown: {'paint_tube': 99}), contains('paint_tube'));
    });

    test('한 번도 안 나온 것 먼저, 그다음 덜 나온 것', () {
      // 처음 묶음의 일반 상품 (물감 통 빼고)
      final pool = [
        for (final i in _items)
          if ({'cloth', 'hat', 'shoe'}.contains(cartKindOf(i)) &&
              (i.requires == null || _initial.contains(i.requires)) &&
              !_initial.contains(i.propId))
            i.id,
      ];
      expect(pool.length, greaterThan(3));
      final day = _dayWith(tube: false);
      // 하나 빼고 다 한 번 나왔다 → 안 나온 하나가 꼭 들어간다
      final never = pool.last;
      final line = _plan(day: day, shown: {for (final id in pool) if (id != never) id: 1});
      expect(line, contains(never));
      // 셋만 한 번, 나머지는 두 번 → 그 셋이 나온다
      final once = pool.take(3).toSet();
      expect(_plan(day: day, shown: {for (final id in pool) id: once.contains(id) ? 1 : 2}).toSet(), once);
    });

    test('고를 상품이 칸보다 적으면 칸을 줄인다, 모두 가지면 빈 줄 (여행 효과 칸만 남는다)', () {
      final all = {for (final i in _items) ?(i.propId ?? i.boatId ?? i.decorId ?? i.trailId)};
      final day = _dayWith(tube: false);
      expect(_plan(km: 1000, day: day, owned: all), isEmpty);
      final leaveOne = all.difference({'cloth_05'});
      expect(_plan(km: 1000, day: day, owned: leaveOne), ['cloth_05']);
    });

    test('25km 전에는 미니 친구가 없고, 25km부터 나온다', () {
      final lower = {
        for (final i in _items)
          if ({'cloth', 'hat', 'shoe', 'trail'}.contains(cartKindOf(i))) ?(i.propId ?? i.trailId),
      };
      for (var d = 1; d <= 30; d++) {
        final day = '2026-11-${d.toString().padLeft(2, '0')}';
        expect(_plan(km: 24.9, day: day).where((id) => _kind(id) == 'pet'), isEmpty);
      }
      final day = _dayWith(tube: false);
      expect(_plan(km: 24.9, day: day, owned: lower), isEmpty);
      expect(_plan(km: 25, day: day, owned: lower).map(_kind).toSet(), {'pet'});
    });

    test('색 소품은 기본 소품을 가진 뒤에만 (여행 모자 색은 여행 모자를 얻은 뒤)', () {
      bool hasHat02Color(List<String> line) => line.any((id) => id.startsWith('hat_02_c'));
      final everythingElse = {
        for (final i in _items)
          if (!i.id.startsWith('hat_02_c')) ?(i.propId ?? i.boatId ?? i.decorId ?? i.trailId),
      };
      final day = _dayWith(tube: false);
      expect(hasHat02Color(_plan(day: day, owned: everythingElse.difference({'hat_02'}))), isFalse);
      expect(_plan(day: day, owned: everythingElse).every((id) => id.startsWith('hat_02_c')), isTrue);
    });

    test('물감 통 색은 그날 계절 16색 중 하나, 양은 길에서 줍는 통과 같은 범위', () {
      final season = seasonOf('2026-11-21', rules);
      final colors = rules.paintColor.seasonIds(season);
      expect(colors, hasLength(16));
      final c = cartTubeColor(colors, 'install-a', '2026-11-21');
      expect(colors, contains(c));
      expect(cartTubeColor(colors, 'install-a', '2026-11-21'), c);
      for (var n = 0; n < 20; n++) {
        final m = cartTubeAmountM(770, 1540, 'install-a', '2026-11-21', n);
        expect(m, inInclusiveRange(770, 1540));
      }
    });

    test('씨앗 수는 0 이상 1 미만이고 기기와 상관없이 같다', () {
      final v = cartRandom('install-a', '2026-11-21', 'pick|cloth_05');
      expect(v, inInclusiveRange(0, 0.9999999));
      expect(cartRandom('install-a', '2026-11-21', 'pick|cloth_05'), v);
    });
  });

  test('물감 통·무늬·쉼터 물품도 사면 생기는 것이 있는 상품이다', () {
    for (final id in ['paint_tube', 'trail_01', 'decor_bench', 'boat_cruise', 'pet_06', 'fx_shortcut']) {
      expect(isSellable(shopCatalog.byId(id)!), isTrue, reason: id);
    }
    expect(isSellable(const ShopItem(id: 'x', category: ShopCategory.prop, name: 'x', price: 1, order: 1)), isFalse);
  });
}
