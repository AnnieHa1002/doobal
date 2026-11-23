import 'package:doobal/app/providers.dart';
import 'package:doobal/app/shop_providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/asset_index.dart';
import 'package:doobal/domain/color_props.dart';
import 'package:doobal/domain/shop_cart.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:doobal/ui/shop/cart_widgets.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/ui/common/item_cell.dart';
import 'package:doobal/ui/common/paint_art.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/rest/rest_slots.dart';
import 'package:doobal/ui/shop/shop_art.dart';
import 'package:doobal/ui/shop/shop_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

// 오늘의 수레 (캔버스 8-1, 16장 11/19·11/20): 여행 효과 고정 칸, 그날 수레 칸·SOLD 도장·잠긴 칸, 구매 시트, 막힘,
// 구매 뒤 갱신, 쉼터에서 들어가기·수레 위 물건. 설치 KST 11/18 09:00, 화면은 10:00 (수레 날 11/18)

const _day = '2026-11-18';

Finder _key(String k) => find.byKey(ValueKey(k));
Finder _item(String id) => _key('shop-item-$id');
Finder _slot(int n) => _key('cart-slot-$n');

/// 처음 여는 날(빈 기록)의 수레 줄: 앱과 같은 규칙으로 미리 계산한다 (설치 번호 0×32, 누적 0km)
List<String> _firstLine(String day, {double km = 0}) {
  final have = havePropIds(props, const {});
  return planCart(
    rules: rules.shopCart,
    items: [...shopCatalog.items, ...colorShopItems(props)],
    owned: (i) => have.contains(i.propId),
    haveBase: have.contains,
    totalKm: km,
    timesShown: const {},
    seed: '0' * 32,
    day: day,
  );
}

/// 11/18부터 처음 줄에 물감 통이 [tube]대로 나오는 날
String _dayWith({required bool tube}) {
  for (var n = 0; n < 40; n++) {
    final day = addDays(_day, n);
    if (_firstLine(day).contains('paint_tube') == tube) return day;
  }
  throw StateError('그런 날이 없다');
}

/// 한국 시간 [day] 정오
DateTime _noon(String day) => kstDayStartUtc(day).add(const Duration(hours: 12));

Future<void> _giveCoins(UiEnv e, int n) => e.db
    .into(e.db.coinLedger)
    .insert(CoinLedgerCompanion.insert(day: _day, kind: CoinKind.gift, amount: n));

Future<void> _open(WidgetTester tester, UiEnv e) async {
  await openOnTop(tester, e, const ShopScreen(),
      ready: () => _item('fx_shortcut').evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 4);
}

/// 칸을 누르고 시트가 다 올라올 때까지. 막혀서 시트가 안 뜨면 토스트가 뜬다
Future<void> _press(WidgetTester tester, String id) => _tapCell(tester, _item(id));

Future<void> _tapCell(WidgetTester tester, Finder cell) async {
  await tester.ensureVisible(cell);
  await tester.pump();
  await tester.tap(cell);
  await settle(tester, () => false, tries: 6);
  await tester.pump(const Duration(milliseconds: 400));
}

/// 구매·취소 시트 버튼을 누르고 끝날 때까지
Future<void> _answer(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settle(tester, () => false, tries: 8);
  await tester.pump(const Duration(milliseconds: 400));
  await settle(tester, () => false, tries: 4);
}

/// 칸의 꼬리표 상태 글자
Finder _state(String id, String text) =>
    find.descendant(of: _item(id), matching: find.text(text));

Finder _inSlot(int n, Finder f) => find.descendant(of: _slot(n), matching: f);

String _balance(WidgetTester tester) =>
    tester.widget<Text>(_key('shop-balance')).data!;

T _read<T>(WidgetTester tester, ProviderListenable<T> p) =>
    ProviderScope.containerOf(tester.element(find.byType(ShopScreen)), listen: false).read(p);

/// 앱이 쓰는 서비스 (UiEnv.svc에는 상점 데이터가 없다). [body]를 실제 비동기로 돌린다
Future<R> _withSvc<R>(WidgetTester tester, Future<R> Function(SyncService svc) body) async =>
    (await tester.runAsync(() async => body(await _read(tester, syncServiceProvider.future))))
        as R;

/// 쓸 때 막힌 까닭을 돌려준다 (안 막히면 실패)
Future<ShopBlocked> _useBlocked(WidgetTester tester, UiEnv e, String id) =>
    _withSvc(tester, (svc) async {
      try {
        await svc.useTravelEffect(id, e.now);
      } on ShopBlocked catch (blocked) {
        return blocked;
      }
      throw StateError('막히지 않았다');
    });

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('진열', () {
    testWidgets('제목·잔액, 여행 효과 고정 칸 2(설명 한 줄), 오늘의 수레 3칸, 잠긴 칸 3, 다음 종류 한 줄', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 1240));
      await _open(tester, e);

      expect(find.text('오늘의 수레'), findsNWidgets(2)); // 제목 + 수레 묶음 머리
      expect(find.text('여행 효과'), findsOneWidget);
      expect(find.text('늘 있어요'), findsOneWidget);
      expect(find.text('새벽 5시에 바뀌어요'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      await settle(tester, () => _balance(tester) == '1,240');
      expect(find.descendant(of: _item('fx_shortcut'), matching: find.text('목적지와의 거리가 1km 줄어요')),
          findsOneWidget);
      expect(find.descendant(of: _item('fx_tailwind'), matching: find.text('이번 물감 길에서 20% 더 멀리 가요')),
          findsOneWidget);
      expect(_state('fx_shortcut', '50 럭'), findsOneWidget);
      expect(_state('fx_tailwind', '40 럭'), findsOneWidget);

      final line = _firstLine(_day);
      expect(find.byType(ItemCell), findsNWidgets(line.length));
      for (final (i, id) in line.indexed) {
        final item = shopCatalog.byId(id) ?? colorShopItem(props, id)!;
        expect(_inSlot(i, find.text(coinAmountText(item.price, rules))), findsOneWidget, reason: id);
      }
      // 칸이 늘어나는 누적 거리 (캔버스 8-1 자물쇠 칸)
      for (final (i, km) in ['50km', '150km', '300km'].indexed) {
        expect(find.descendant(of: _key('cart-locked-$i'), matching: find.text(km)), findsOneWidget);
      }
      expect(tester.getSemantics(_key('cart-locked-0')).label, '4번째 칸, 누적 50km에 열림');
      expect(find.text('누적 5km를 걸으면 물감 길 무늬도 수레에 실려요'), findsOneWidget);
      // 가진 상점 배가 없으면 배 줄도 없다
      expect(find.text('가진 배 · 색 바꾸기'), findsNothing);
      await end(tester, e);
    });

    testWidgets('50km를 넘긴 다음 날은 4칸, 자물쇠는 150·300km 둘', (tester) async {
      final e = UiEnv();
      e.now = _noon('2026-11-20');
      await e.seed(tester, () => e.db.into(e.db.daySummaries).insert(DaySummariesCompanion.insert(
          day: '2026-11-19', steps: 70000, distanceM: 52000, countedSessions: 1)));
      await _open(tester, e);
      await settle(tester, () => find.byType(ItemCell).evaluate().length == 4);
      expect(find.byType(ItemCell), findsNWidgets(4));
      expect(find.byType(LockedCartSlot), findsNWidgets(2));
      expect(find.text('누적 75km를 걸으면 액세서리도 수레에 실려요'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('그림 없는 칸은 점선 + 이름, 아이콘 파일을 넣으면 그 그림', (tester) async {
      final day = _dayWith(tube: false);
      final first = _firstLine(day).first;
      // 11/23부터 소품 칸 그림이 있다. 그림 없는 칸을 보려고 첫 칸 소품 그림만 뺀 파일 목록을 쓴다
      final e = UiEnv(assets: assetIndexWithout(['item_${first}_icon']));
      e.now = _noon(day);
      await e.seed(tester);
      await _open(tester, e);
      final item = shopCatalog.byId(first) ?? colorShopItem(props, first)!;
      // 색 소품은 그림이 없으면 색 상자 (11/6 규칙)
      final none = item.requires == null ? ItemPlaceholder : ItemSwatch;
      expect(_inSlot(0, find.byType(none)), findsOneWidget);
      await end(tester, e);

      final f = UiEnv(assets: AssetIndex(['assets/items/icons/item_${first}_icon_v01_clean.webp']));
      f.now = _noon(day);
      await f.seed(tester);
      await _open(tester, f);
      await settle(tester, () => _inSlot(0, find.byType(Image)).evaluate().isNotEmpty, tries: 8);
      expect(_inSlot(0, find.byType(Image)), findsOneWidget);
      await end(tester, f);
    });

    testWidgets('가진 상점 배는 수레에 안 나오고 ‘가진 배’ 줄에 (색 시트는 T4c)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.db.into(e.db.boatsOwned).insert(
          BoatsOwnedCompanion.insert(boatId: 'boat_cruise', atUtc: 1)));
      await _open(tester, e);
      await tester.ensureVisible(_key('owned-boat-boat_cruise'));
      await tester.pump();
      expect(find.text('가진 배 · 색 바꾸기'), findsOneWidget);
      expect(find.descendant(of: _key('owned-boat-boat_cruise'), matching: find.text('유람선')), findsOneWidget);
      // 뗏목·보상 배는 상점 배가 아니라 없다
      expect(_key('owned-boat-boat_raft'), findsNothing);
      await end(tester, e);
    });
  });

  group('수레 칸 사기 (SOLD)', () {
    testWidgets('사면 그 칸은 SOLD 도장만(그림·꼬리표 지움), 다른 칸 그대로, 도장 칸은 눌러도 아무 일 없다', (tester) async {
      final day = _dayWith(tube: false);
      final line = _firstLine(day);
      final item = shopCatalog.byId(line.first) ?? colorShopItem(props, line.first)!;
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester, () => _giveCoins(e, 1000));
      await _open(tester, e);

      await _tapCell(tester, _slot(0));
      expect(find.text('구매하시겠습니까?'), findsOneWidget);
      expect(find.text(coinsLeftText(1000 - item.price)), findsOneWidget);
      await _answer(tester, '구매');
      expect(find.text(boughtText(item.name)), findsOneWidget);
      await settle(tester, () => _inSlot(0, find.byType(SoldStamp)).evaluate().isNotEmpty);

      expect(_inSlot(0, find.byType(SoldStamp)), findsOneWidget);
      expect(_inSlot(0, find.text('SOLD')), findsOneWidget);
      expect(_inSlot(0, find.text(item.name)), findsNothing);
      expect(_inSlot(0, find.text(coinAmountText(item.price, rules))), findsNothing);
      expect(tester.getSemantics(_slot(0)).label, '${item.name}, SOLD');
      expect(tester.getSemantics(_slot(0)).flagsCollection.isButton, isFalse);
      // 칸 수·다른 칸은 그대로 (다시 채우지 않는다)
      expect(find.byType(ItemCell), findsNWidgets(line.length));
      expect(_inSlot(1, find.byType(SoldStamp)), findsNothing);
      // 도장: 지름 56, 상자 왼쪽 위 14pt, −12°
      expect(tester.getSize(find.byKey(const ValueKey('sold-stamp'))), const Size(56, 56));
      // 가운데는 그림 상자(84) 왼쪽 위 14 + 반지름 28 = 42 (돌려도 가운데는 그대로)
      final center = tester.getCenter(find.byKey(const ValueKey('sold-stamp')));
      final cell = tester.getRect(_slot(0));
      expect(center.dy - cell.top, closeTo(42, 0.5));
      final rotate = tester.widget<Transform>(
          find.ancestor(of: find.byKey(const ValueKey('sold-stamp')), matching: find.byType(Transform)).first);
      expect(rotate.transform.getRotation().entry(1, 0), closeTo(-0.2079, 0.001)); // sin(−12°)
      expect(await _withSvc(tester, (s) => s.ownedPropIds()), contains(item.propId));

      // 도장 칸을 눌러도 시트가 없다
      await tester.pump(const Duration(seconds: 3));
      await _tapCell(tester, _slot(0));
      expect(find.text('구매하시겠습니까?'), findsNothing);
      expect(await _withSvc(tester, (s) => s.coinBalance()), 1000 - item.price);
      await end(tester, e);
    });

    testWidgets('걸어서(다른 길로) 얻어도 그 칸이 SOLD', (tester) async {
      final day = _dayWith(tube: false);
      final line = _firstLine(day);
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester);
      await _open(tester, e);
      final id = (shopCatalog.byId(line[1]) ?? colorShopItem(props, line[1])!).propId!;
      await tester.runAsync(() => e.db.into(e.db.propsOwned).insert(
          PropsOwnedCompanion.insert(propId: id, unlockedUtc: e.now.millisecondsSinceEpoch)));
      ProviderScope.containerOf(tester.element(find.byType(ShopScreen))).invalidate(snapshotProvider);
      // 연 동안 팔린 칸은 물건이 떠오른 뒤 도장이 찍힌다 (T19 연출 ③, 0.25초 + 0.2초)
      await settle(tester, () => _key('cart-sold-1').evaluate().isNotEmpty);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_inSlot(1, find.byType(SoldStamp)), findsOneWidget);
      expect(_inSlot(0, find.byType(SoldStamp)), findsNothing);
      await end(tester, e);
    });

    testWidgets('물감 통 칸: 그날 색 통 그림·색 이름, 사면 그 색 3통이 물감 보관에', (tester) async {
      final day = _dayWith(tube: true);
      final slot = _firstLine(day).indexOf('paint_tube');
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester, () => _giveCoins(e, 30));
      await _open(tester, e);
      final cart = await _withSvc(tester, (s) => s.todayCart(e.now));
      final color = cart.slots[slot].tubeColor!;
      expect(_inSlot(slot, find.byType(PaintTubeArt)), findsOneWidget);
      expect(_inSlot(slot, find.text(rules.paintColor.nameOf(color))), findsOneWidget);
      expect(_inSlot(slot, find.text('30 럭')), findsOneWidget);

      await _tapCell(tester, _slot(slot));
      await _answer(tester, '구매');
      expect(find.text('물감 통을 구매했어요'), findsOneWidget);
      await settle(tester, () => _inSlot(slot, find.byType(SoldStamp)).evaluate().isNotEmpty);
      final stock = await tester.runAsync(
          () => (e.db.select(e.db.paintStock)..where((t) => t.colorId.equals(color))).getSingle());
      expect(stock!.tubes, 3);
      expect(await _withSvc(tester, (s) => s.coinBalance()), 0);
      await end(tester, e);
    });

    testWidgets('럭이 모자라면 시트 없이 까닭만', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tapCell(tester, _slot(0));
      expect(find.text(ShopBlock.notEnoughCoins.message), findsOneWidget);
      expect(find.textContaining('구매하시겠습니까'), findsNothing);
      expect(_inSlot(0, find.byType(SoldStamp)), findsNothing);
      await end(tester, e);
    });

    testWidgets('새벽 5시가 지나면 열린 화면도 새 수레 (SOLD가 풀린다)', (tester) async {
      final day = _dayWith(tube: false);
      final e = UiEnv();
      e.now = kstDayStartUtc(day).add(const Duration(hours: 23));
      await e.seed(tester, () => _giveCoins(e, 1000));
      await _open(tester, e);
      await _tapCell(tester, _slot(0));
      await _answer(tester, '구매');
      await settle(tester, () => _inSlot(0, find.byType(SoldStamp)).evaluate().isNotEmpty);
      // 다음 날 05:00 (분 시계가 새 시각을 낸다)
      e.now = kstDayStartUtc(addDays(day, 1)).add(const Duration(hours: 5));
      await tester.pump(const Duration(minutes: 1));
      await settle(tester, () => find.byType(SoldStamp).evaluate().isEmpty);
      expect(find.byType(SoldStamp), findsNothing);
      expect(await _withSvc(tester, (s) async => (await s.todayCart(e.now)).day), addDays(day, 1));
      await end(tester, e);
    });
  });

  group('구매', () {
    testWidgets('여행 효과: 시트에 값과 남는 럭, 사면 잔액·보관함이 바뀌고 토스트', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 1240));
      await _open(tester, e);
      await settle(tester, () => _balance(tester) == '1,240');

      await _press(tester, 'fx_shortcut');
      expect(find.text('구매하시겠습니까?'), findsOneWidget);
      expect(find.text('남는 럭 1,190'), findsOneWidget);
      expect(find.text('구매'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);

      await _answer(tester, '구매');
      expect(find.text('지름길을 구매했어요'), findsOneWidget);
      await settle(tester, () => _balance(tester) == '1,190');
      expect(_balance(tester), '1,190');
      expect(await _withSvc(tester, (s) => s.coinBalance()), 1190);
      expect(await _withSvc(tester, (s) => s.shopHeld()), {'fx_shortcut': 1});
      // 화면이 보는 프로바이더도 따라온다
      expect(await tester.runAsync(() => _read(tester, shopHeldProvider.future)), {'fx_shortcut': 1});
      // 소모품은 여전히 값이 보이고 또 살 수 있다
      expect(_state('fx_shortcut', '50 럭'), findsOneWidget);
      await _press(tester, 'fx_shortcut');
      expect(find.text('남는 럭 1,140'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('취소·시트 밖 누르기는 아무것도 바꾸지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 100));
      await _open(tester, e);

      await _press(tester, 'fx_tailwind');
      expect(find.text('구매하시겠습니까?'), findsOneWidget);
      await _answer(tester, '취소');
      await _press(tester, 'fx_tailwind');
      await tester.tapAt(const Offset(195, 40));
      await settle(tester, () => false, tries: 4);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('순풍을 구매했어요'), findsNothing);
      expect(await _withSvc(tester, (s) => s.coinBalance()), 100);
      expect(await _withSvc(tester, (s) => s.shopHeld()), isEmpty);
      await end(tester, e);
    });
  });

  group('막힘', () {
    testWidgets('잔액 부족: 시트 없이 까닭만, 아무것도 안 바뀐다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 49));
      await _open(tester, e);

      await _press(tester, 'fx_shortcut');
      expect(find.text(ShopBlock.notEnoughCoins.message), findsOneWidget);
      expect(find.textContaining('구매하시겠습니까'), findsNothing);
      expect(await _withSvc(tester, (s) => s.coinBalance()), 49);
      expect(await _withSvc(tester, (s) => s.shopHeld()), isEmpty);
      await end(tester, e);
    });

    testWidgets('보관 한도: 9개면 10번째를 못 산다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _giveCoins(e, 1000);
        await e.db
            .into(e.db.shopInventory)
            .insert(ShopInventoryCompanion.insert(itemId: 'fx_shortcut', count: rules.shopMaxHoldPerItem));
      });
      await _open(tester, e);

      await _press(tester, 'fx_shortcut');
      expect(find.text(ShopBlock.holdFull.message), findsOneWidget);
      expect(find.textContaining('구매하시겠습니까'), findsNothing);
      expect(await _withSvc(tester, (s) => s.coinBalance()), 1000);
      // 다른 효과는 살 수 있다
      await tester.pump(const Duration(seconds: 3));
      await _press(tester, 'fx_tailwind');
      expect(find.textContaining('구매하시겠습니까'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('시트를 연 사이 럭이 줄면 사지 않고 까닭을 보여 준다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 50));
      await _open(tester, e);

      await _press(tester, 'fx_shortcut');
      await _withSvc(tester, (s) => s.buyItem('fx_tailwind', e.now));
      await _answer(tester, '구매');
      expect(find.text(ShopBlock.notEnoughCoins.message), findsOneWidget);
      expect(find.text('지름길을 구매했어요'), findsNothing);
      expect(await _withSvc(tester, (s) => s.shopHeld()), {'fx_tailwind': 1});
      await end(tester, e);
    });

    // 쓰는 자리가 캔버스에 없어(docs/트랙/상점_T4b.md) 사는 곳만 있다. 여정·하루 한도는 쓸 때의 막힘이다
    testWidgets('여정이 없어도 살 수 있고, 쓸 때 여정 중에만 쓸 수 있다고 막는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 100));
      await _open(tester, e);

      await _press(tester, 'fx_shortcut');
      await _answer(tester, '구매');
      expect(find.text('지름길을 구매했어요'), findsOneWidget);

      final blocked = await _useBlocked(tester, e, 'fx_shortcut');
      expect(blocked.block, ShopBlock.noJourney);
      expect(blocked.message, '여정 중에만 쓸 수 있어요');
      expect(await _withSvc(tester, (s) => s.shopHeld()), {'fx_shortcut': 1});
      await end(tester, e);
    });

    testWidgets('하루 한도는 살 때 막지 않고 쓸 때 막는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _giveCoins(e, 200);
        await e.svc.startJourney('kr003', t1);
      });
      await _open(tester, e);
      await _withSvc(tester, (s) async {
        for (var i = 0; i < 2; i++) {
          await s.buyItem('fx_shortcut', e.now);
          await s.useTravelEffect('fx_shortcut', e.now);
        }
      });

      // 오늘 2장을 다 썼어도 더 사서 보관할 수 있다
      await _press(tester, 'fx_shortcut');
      expect(find.text('구매하시겠습니까?'), findsOneWidget);
      await _answer(tester, '구매');
      expect(await _withSvc(tester, (s) => s.shopHeld()), {'fx_shortcut': 1});

      final blocked = await _useBlocked(tester, e, 'fx_shortcut');
      expect(blocked.block, ShopBlock.dailyLimit);
      expect(blocked.message, ShopBlock.dailyLimit.message);
      await end(tester, e);
    });
  });

  group('쉼터에서', () {
    Future<void> openRest(WidgetTester tester, UiEnv e, {List<Override> extra = const []}) async {
      phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...e.overrides,
          restWiggleProvider.overrideWithValue(const WiggleSpec.off()),
          ...extra,
        ],
        child: const MaterialApp(home: RestScreen()),
      ));
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.pump();
    }

    testWidgets('럭 보석을 누르면 상점, 사고 돌아오면 쉼터 숫자도 바뀐다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 300));
      await openRest(tester, e);
      final gem = _key('rest-gem');
      await settle(tester, () => tester.widget<Text>(_key('luck-number')).data == '300');
      expect(tester.getSemantics(gem).flagsCollection.isButton, isTrue);
      expect(find.descendant(of: gem, matching: find.byType(LuckGemArt)), findsOneWidget);

      await tester.tap(gem);
      await transition(tester);
      await settle(tester, () => _item('fx_shortcut').evaluate().isNotEmpty);
      expect(find.byType(ShopScreen), findsOneWidget);

      await _press(tester, 'fx_shortcut');
      await _answer(tester, '구매');
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(ShopScreen), findsNothing);
      await settle(tester, () => tester.widget<Text>(_key('luck-number')).data == '250');
      expect(tester.widget<Text>(_key('luck-number')).data, '250');
      await end(tester, e);
    });

    testWidgets('수레는 테마 자리에 서고, 밀어서 누르면 상점. 그림이 없으면 자리표시', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openRest(tester, e);
      final cart = _key('camp-object-cart');
      expect(cart, findsOneWidget);
      // 이름 ‘상점’은 옆 상점 버튼에 (수레는 이름표 없음, 16장 11/18). 수레 그림 자리표시는 옆 버튼 아이콘에도 있다
      expect(find.text('상점'), findsOneWidget);
      expect(tester.getRect(_key('cart-placeholder').first), const Rect.fromLTWH(440, 530, 120, 109));

      await tester.dragFrom(const Offset(380, 300), const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(cart);
      await transition(tester);
      await settle(tester, () => _item('fx_shortcut').evaluate().isNotEmpty);
      expect(find.byType(ShopScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('수레 그림 파일이 있으면 읽고, 랜턴은 밤에만 얹는다', (tester) async {
      const dir = 'assets/backgrounds/v11';
      final files = AssetIndex([
        '$dir/obj_rest_cart_v01_clean.webp',
        '$dir/obj_rest_cart_lantern_v01_clean.png',
      ]);
      Future<int> imagesAt(DateTime now) async {
        final e = UiEnv(assets: files);
        e.now = now;
        await e.seed(tester);
        phone(tester);
        await tester.pumpWidget(ProviderScope(
          overrides: e.overrides,
          child: const MaterialApp(
            home: Center(child: SizedBox(width: 120, height: 109, child: ShopCartArt())),
          ),
        ));
        await settle(tester, () => false, tries: 8);
        // 시험에는 그림 파일이 없어 못 읽으면 자리표시로 돌아가지만, 읽으려는 층 수는 같다
        final n = find.byType(Image).evaluate().length;
        await end(tester, e);
        return n;
      }

      // 한국 시간 낮 12시, 밤 11시
      expect(await imagesAt(DateTime.utc(2026, 11, 18, 3)), 1);
      expect(await imagesAt(DateTime.utc(2026, 11, 18, 14)), 2);
    });

    testWidgets('쉼터 수레 위에 그날 수레 물건이 얹힌다 (팔린 칸은 빠짐, 그림 없으면 짐 상자)', (tester) async {
      final day = _dayWith(tube: false);
      // 11/23부터 소품 칸 그림이 있다. 짐 상자를 보려고 칸 그림 폴더를 뺀 파일 목록을 쓴다
      final e = UiEnv(assets: assetIndexWithout([AssetIndex.iconDir]));
      e.now = _noon(day);
      await e.seed(tester, () => _giveCoins(e, 1000));
      await openRest(tester, e);
      await settle(tester, () => find.byKey(const ValueKey('cart-top-parcel')).evaluate().length == 3);
      expect(find.byKey(const ValueKey('cart-top-parcel')), findsNWidgets(3));
      // 아이콘(28pt)은 수레 그림 상자(440, 530, 120×109) 위쪽에
      final icon = tester.getRect(_key('cart-top-0'));
      expect(icon.width, 28);
      expect(icon.top, greaterThanOrEqualTo(530 - 28));
      expect(icon.bottom, lessThan(530 + 109 / 2));
      await tester.runAsync(() async {
        final svc = await ProviderScope.containerOf(tester.element(find.byType(RestScreen)))
            .read(syncServiceProvider.future);
        await svc.buyCartSlot(day, 0, e.now);
      });
      ProviderScope.containerOf(tester.element(find.byType(RestScreen))).invalidate(snapshotProvider);
      await settle(tester, () => find.byKey(const ValueKey('cart-top-parcel')).evaluate().length == 2);
      expect(find.byKey(const ValueKey('cart-top-parcel')), findsNWidgets(2));
      expect(_key('cart-top-0'), findsNothing);
      await end(tester, e);
    });

    testWidgets('쉼터 수레 위 소품 상품은 짐 상자 대신 칸 그림 (11/23 소품 아이콘)', (tester) async {
      final day = _dayWith(tube: false);
      final line = _firstLine(day);
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester);
      await openRest(tester, e);
      Finder imageAt(int slot) => find.descendant(of: _key('cart-top-$slot'), matching: find.byType(Image));
      await settle(tester, () => imageAt(line.length - 1).evaluate().isNotEmpty);
      for (final (slot, id) in line.indexed) {
        final image = tester.widget<Image>(imageAt(slot)).image as AssetImage;
        expect(image.assetName, 'assets/items/icons/item_${id}_icon_v01_clean.webp', reason: id);
      }
      // 그림 파일을 실제로 풀어도 짐 상자로 돌아가지 않는다
      await settle(tester, () => false, tries: 12);
      expect(find.byKey(const ValueKey('cart-top-parcel')), findsNothing);
      await end(tester, e);
    });

    testWidgets('상품이 없으면 입구를 숨긴다 (스키마 13장)', (tester) async {
      final c = ProviderContainer(overrides: [
        shopCatalogProvider.overrideWith(
          (ref) => ShopCatalog(defaultBoat: 'boat_raft', items: const []),
        ),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(restSlotsProvider, (_, _) {});
      await tester.runAsync(() => c.read(shopCatalogProvider.future));
      expect(c.read(restSlotsProvider).cart, isNull);
      expect(c.read(restSlotsProvider).gem.onTap, isNull);
      sub.close();
    });
  });
}
