import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/color_props.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/domain/shop_cart.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/ui/common/item_cell.dart';
import 'package:doobal/ui/shop/cart_widgets.dart';
import 'package:doobal/ui/shop/shop_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

// 연출 ③ 수레 칸 (T19, 16장 11/20 Q008, config ui.motion.cartSlot, 캔버스 8-1 메모): 지난번 상점을 본 뒤 새로
// 열린 칸은 자물쇠가 풀리며 물건이 톡, 그 뒤 팔린 칸은 물건이 떠올라 사라지고 SOLD 도장이 찍힌다. 칸마다 한 번.
// 설치 KST 11/18 09:00 (shop_screen_test와 같은 날·같은 줄)

const _day = '2026-11-18';
final _m = rules.motion.cartSlot!;

Finder _key(String k) => find.byKey(ValueKey(k));
Finder _slot(int n) => _key('cart-slot-$n');
Finder _inSlot(int n, Finder f) => find.descendant(of: _slot(n), matching: f);

DateTime _noon(String day) => kstDayStartUtc(day).add(const Duration(hours: 12));

/// 처음 여는 날(빈 기록)의 수레 줄 (shop_screen_test와 같은 계산)
List<String> _firstLine(String day) {
  final have = havePropIds(props, const {});
  return planCart(
    rules: rules.shopCart,
    items: [...shopCatalog.items, ...colorShopItems(props)],
    owned: (i) => have.contains(i.propId),
    haveBase: have.contains,
    totalKm: 0,
    timesShown: const {},
    seed: '0' * 32,
    day: day,
  );
}

/// 11/18부터 처음 줄에 물감 통이 없는 날 (칸이 모두 소품·물품)
String _plainDay() {
  for (var n = 0; n < 40; n++) {
    final day = addDays(_day, n);
    if (!_firstLine(day).contains('paint_tube')) return day;
  }
  throw StateError('그런 날이 없다');
}

ShopItem _itemOf(String id) => shopCatalog.byId(id) ?? colorShopItem(props, id)!;

Future<void> _giveCoins(UiEnv e, int n) => e.db
    .into(e.db.coinLedger)
    .insert(CoinLedgerCompanion.insert(day: _day, kind: CoinKind.gift, amount: n));

/// 상점을 연다 (첫 화면 ‘열기’ 위로). 시계는 그대로라 연출이 시작만 한 상태
Future<void> _open(WidgetTester tester, UiEnv e) async {
  await openOnTop(tester, e, const ShopScreen(), ready: () => _key('cart-slot-0').evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 4);
}

/// 상점을 닫았다 다시 연다 (같은 앱)
Future<void> _reopen(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(ShopScreen))).pop();
  await transition(tester);
  await tester.tap(find.text('열기'));
  await tester.pump();
  await settle(tester, () => _key('cart-slot-0').evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 4);
}

/// [n]번 칸을 사고 팔린 칸이 그려질 때까지 (시계는 0초에 멈춰 둔다)
Future<void> _buy(WidgetTester tester, int n) async {
  await tester.ensureVisible(_slot(n));
  await tester.pump();
  await tester.tap(_slot(n));
  await settle(tester, () => find.text('구매').evaluate().isNotEmpty);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('구매'));
  await settle(tester, () => _key('cart-sold-$n').evaluate().isNotEmpty);
}

double _scaleOf(Finder f) => (f.evaluate().single.widget as Transform).transform.getMaxScaleOnAxis();

double _opacityOf(Finder f) => (f.evaluate().single.widget as Opacity).opacity;

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('산 칸: 물건 빠짐 + SOLD 도장', () {
    testWidgets('물건이 16pt 떠오르며 0.25초에 사라지고, 이어 도장이 1.3배에서 0.2초에 1배. 도는 중·뒤 모두 누를 수 없다',
        (tester) async {
      final day = _plainDay();
      final item = _itemOf(_firstLine(day).first);
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester, () => _giveCoins(e, 1000));
      await _open(tester, e);
      await _buy(tester, 0);

      // 0초: 물건 그림이 그대로, 도장은 아직
      await tester.pump();
      expect(_inSlot(0, _key('cart-sold-item')), findsOneWidget);
      expect(_opacityOf(_key('cart-sold-item')), closeTo(1, 0.05));
      expect(_inSlot(0, _key('cart-sold-stamp-scale')), findsNothing);
      // 도는 중에도 누를 수 없다 (닫히는 구매 시트가 아직 내려가는 중이라 누르기는 끝난 뒤에 본다)
      expect(tester.widget<ItemCell>(_slot(0)).onTap, isNull);
      expect(tester.getSemantics(_slot(0)).flagsCollection.isButton, isFalse);
      // 0.125초: 반쯤 흐려지며 떠오름
      await tester.pump(const Duration(milliseconds: 125));
      expect(_opacityOf(_key('cart-sold-item')), closeTo(0.5, 0.1));
      final up = tester.widget<Transform>(
          find.descendant(of: _key('cart-sold-item'), matching: find.byType(Transform)).first);
      expect(up.transform.getTranslation().y, inInclusiveRange(-16, -8));
      // 0.25초: 물건은 없고 도장이 1.3배로
      await tester.pump(const Duration(milliseconds: 130));
      expect(_key('cart-sold-item'), findsNothing);
      expect(_scaleOf(_key('cart-sold-stamp-scale')), closeTo(_m.soldStampScaleFrom, 0.05));
      expect(_inSlot(0, find.byType(SoldStamp)), findsOneWidget);
      // 0.45초: 도장 1배
      await tester.pump(const Duration(milliseconds: 200));
      expect(_scaleOf(_key('cart-sold-stamp-scale')), 1);
      expect(_inSlot(0, find.text(item.name)), findsNothing);
      // 끝난 뒤에도 누를 수 없다
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(_slot(0), warnIfMissed: false);
      await settle(tester, () => false, tries: 6);
      expect(find.text('구매하시겠습니까?'), findsNothing);
      expect(tester.getSemantics(_slot(0)).flagsCollection.isButton, isFalse);
      await end(tester, e);
    });

    testWidgets('다시 열면 도장만 (한 번만 돈다)', (tester) async {
      final day = _plainDay();
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester, () => _giveCoins(e, 1000));
      await _open(tester, e);
      await _buy(tester, 0);
      await tester.pump(const Duration(seconds: 1));
      e.now = e.now.add(const Duration(minutes: 3));
      await _reopen(tester);
      expect(_key('cart-sold-item'), findsNothing);
      expect(_scaleOf(_key('cart-sold-stamp-scale')), 1);
      await end(tester, e);
    });

    testWidgets('상점을 닫은 사이 걸어서 얻은 칸은 다음에 열 때 빠짐 + 도장, 그다음엔 도장만', (tester) async {
      final day = _plainDay();
      final line = _firstLine(day);
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester);
      await _open(tester, e);
      expect(_key('cart-sold-1'), findsNothing);
      // 닫고 10분 뒤 다른 길로 그 물건을 얻었다
      Navigator.of(tester.element(find.byType(ShopScreen))).pop();
      await transition(tester);
      e.now = e.now.add(const Duration(minutes: 10));
      await tester.runAsync(() => e.db.into(e.db.propsOwned).insert(
          PropsOwnedCompanion.insert(propId: _itemOf(line[1]).propId!, unlockedUtc: e.now.millisecondsSinceEpoch)));
      ProviderScope.containerOf(tester.element(find.text('열기'))).invalidate(snapshotProvider);
      await tester.tap(find.text('열기'));
      await tester.pump();
      await settle(tester, () => _key('cart-sold-1').evaluate().isNotEmpty);
      expect(_key('cart-sold-item'), findsOneWidget, reason: '처음 보는 팔림이라 돈다');
      await tester.pump(const Duration(seconds: 1));
      e.now = e.now.add(const Duration(minutes: 1));
      await _reopen(tester);
      expect(_key('cart-sold-item'), findsNothing);
      expect(_scaleOf(_key('cart-sold-stamp-scale')), 1);
      await end(tester, e);
    });

    testWidgets('움직임 줄이기면 끝 상태만: 바로 도장 1배', (tester) async {
      _reduceMotion(tester);
      final day = _plainDay();
      final e = UiEnv();
      e.now = _noon(day);
      await e.seed(tester, () => _giveCoins(e, 1000));
      await _open(tester, e);
      await _buy(tester, 0);
      await tester.pump();
      expect(_key('cart-sold-item'), findsNothing);
      expect(_scaleOf(_key('cart-sold-stamp-scale')), 1);
      expect(_inSlot(0, find.byType(SoldStamp)), findsOneWidget);
      await end(tester, e);
    });
  });

  group('새 칸 열림', () {
    Future<UiEnv> unlocked(WidgetTester tester) async {
      // 11/19에 52km → 11/20 수레는 4칸, 지난번 본 때(설치 11/18)는 3칸
      final e = UiEnv();
      e.now = _noon('2026-11-20');
      await e.seed(tester, () => e.db.into(e.db.daySummaries).insert(DaySummariesCompanion.insert(
          day: '2026-11-19', steps: 70000, distanceM: 52000, countedSessions: 1)));
      return e;
    }

    testWidgets('지난번 본 뒤 열린 4번째 칸: 자물쇠 0.2초 흐려짐 → 물건이 12pt 위·1.1배에서 0.25초에 톡, 다른 칸은 그대로',
        (tester) async {
      final e = await unlocked(tester);
      await _open(tester, e);
      await settle(tester, () => _key('cart-slot-3').evaluate().isNotEmpty);
      await tester.pump();
      expect(_inSlot(3, _key('cart-unlock-lock')), findsOneWidget);
      expect(_opacityOf(_key('cart-unlock-lock')), closeTo(1, 0.05));
      final item = find.descendant(of: _key('cart-unlock-3'), matching: find.byType(Visibility)).first;
      expect((item.evaluate().single.widget as Visibility).visible, isFalse);
      // 앞 세 칸은 그대로 (자물쇠 없음, 물건 그대로)
      for (var n = 0; n < 3; n++) {
        expect(_inSlot(n, _key('cart-unlock-lock')), findsNothing);
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacityOf(_key('cart-unlock-lock')), closeTo(0.5, 0.1));
      await tester.pump(const Duration(milliseconds: 110));
      expect(_key('cart-unlock-lock'), findsNothing);
      expect((item.evaluate().single.widget as Visibility).visible, isTrue);
      final drop = tester.widget<Transform>(
          find.descendant(of: _key('cart-unlock-3'), matching: find.byKey(const ValueKey('cart-unlock-item'))));
      expect(drop.transform.getTranslation().y, inInclusiveRange(-_m.dropPt, -_m.dropPt * 0.8));
      await tester.pump(const Duration(milliseconds: 260));
      final landed = tester.widget<Transform>(
          find.descendant(of: _key('cart-unlock-3'), matching: find.byKey(const ValueKey('cart-unlock-item'))));
      expect(landed.transform.getTranslation().y, 0);
      // 다시 열면 그대로 (열릴 때 한 번)
      e.now = e.now.add(const Duration(minutes: 1));
      await _reopen(tester);
      expect(_key('cart-unlock-lock'), findsNothing);
      await end(tester, e);
    });

    testWidgets('움직임 줄이기면 자물쇠 없이 물건만', (tester) async {
      _reduceMotion(tester);
      final e = await unlocked(tester);
      await _open(tester, e);
      await settle(tester, () => _key('cart-slot-3').evaluate().isNotEmpty);
      await tester.pump();
      expect(_key('cart-unlock-lock'), findsNothing);
      expect(find.byType(LockedCartSlot), findsNWidgets(2));
      await end(tester, e);
    });
  });
}
