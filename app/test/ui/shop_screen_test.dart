import 'dart:ui' show Tristate;

import 'package:doobal/app/providers.dart';
import 'package:doobal/app/shop_providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/asset_index.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/ui/common/item_cell.dart';
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

// 행상 수레 (캔버스 8-1): 탭별 상품, 구매 시트, 막힘, 구매 뒤 갱신, 쉼터에서 들어가기

const _day = '2026-11-18';

Finder _key(String k) => find.byKey(ValueKey(k));
Finder _item(String id) => _key('shop-item-$id');
Finder _tab(ShopTab t) => _key('shop-tab-${t.name}');

Future<void> _giveCoins(UiEnv e, int n) => e.db
    .into(e.db.coinLedger)
    .insert(CoinLedgerCompanion.insert(day: _day, kind: CoinKind.gift, amount: n));

Future<void> _open(WidgetTester tester, UiEnv e) async {
  await openOnTop(tester, e, const ShopScreen(),
      ready: () => _item('fx_shortcut').evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 4);
}

Future<void> _goTab(WidgetTester tester, ShopTab t) async {
  await tester.tap(_tab(t));
  await tester.pump();
}

/// 칸을 누르고 시트가 다 올라올 때까지. 막혀서 시트가 안 뜨면 토스트가 뜬다
Future<void> _press(WidgetTester tester, String id) async {
  await tester.ensureVisible(_item(id));
  await tester.pump();
  await tester.tap(_item(id));
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
    testWidgets('제목·잔액, 탭 4는 shop.json 이름, 처음 탭은 여행 효과', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 1240));
      await _open(tester, e);

      expect(find.text('행상 수레'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      await settle(tester, () => _balance(tester) == '1,240');
      expect(_balance(tester), '1,240');
      for (final t in ShopTab.values) {
        expect(
          find.descendant(of: _tab(t), matching: find.text(shopCatalog.tabLabels[t]!)),
          findsOneWidget,
        );
      }
      expect(tester.getSemantics(_tab(ShopTab.travel)).flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSemantics(_tab(ShopTab.prop)).flagsCollection.isSelected, Tristate.isFalse);
      expect(_item('fx_shortcut'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('탭마다 그 탭 상품만 order 순서로, 값은 천 단위 쉼표 + 럭', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      for (final t in [ShopTab.travel, ShopTab.prop, ShopTab.effect]) {
        await _goTab(tester, t);
        final items = shopCatalog.inTab(t);
        expect(items, isNotEmpty);
        expect(find.byType(ItemCell), findsNWidgets(items.length), reason: t.name);
        var last = -1.0;
        for (final item in items) {
          await tester.ensureVisible(_item(item.id));
          await tester.pump();
          expect(_state(item.id, '${item.price} 럭'), findsOneWidget, reason: item.id);
          final y = tester.getTopLeft(_item(item.id)).dy;
          expect(y, greaterThanOrEqualTo(last - 400), reason: item.id);
          last = y;
        }
      }
      await end(tester, e);
    });

    testWidgets('배 탭: 맨 앞은 처음부터 가진 뗏목, 뒤로 상점 배 6척', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, ShopTab.boat);

      expect(find.byType(ItemCell), findsNWidgets(7));
      expect(_state('boat_raft', '가짐'), findsOneWidget);
      expect(_state('boat_cruise', '5,000 럭'), findsOneWidget);
      expect(_state('boat_canopy', '8,000 럭'), findsOneWidget);
      await tester.ensureVisible(_item('boat_starlight'));
      await tester.pump();
      expect(_state('boat_starlight', '12,000 럭'), findsOneWidget);
      // 보상 배는 상점에 없다
      expect(_item('boat_skiff'), findsNothing);
      expect(_item('boat_voyage'), findsNothing);
      await end(tester, e);
    });

    testWidgets('그림 없는 칸은 점선 + 이름, 파일을 넣으면 그 그림', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(
        find.descendant(of: _item('fx_shortcut'), matching: find.byType(ItemPlaceholder)),
        findsOneWidget,
      );
      expect(find.descendant(of: _item('fx_shortcut'), matching: find.text('지름길')), findsNWidgets(2));
      await end(tester, e);

      final f = UiEnv(
        assets: AssetIndex([
          'assets/items/icons/ui_shop_fx_shortcut_v01_clean.png',
          'assets/ui/ui_gem_sky_v01_clean.png',
        ]),
      );
      await f.seed(tester);
      await _open(tester, f);
      await settle(tester, () => false, tries: 4);
      expect(find.descendant(of: _item('fx_shortcut'), matching: find.byType(Image)), findsOneWidget);
      expect(find.descendant(of: _item('fx_tailwind'), matching: find.byType(Image)), findsNothing);
      expect(find.descendant(of: find.byType(LuckGemArt), matching: find.byType(Image)), findsOneWidget);
      await end(tester, f);
    });

    testWidgets('배 칸: 뒤판·앞판 파일이 있으면 겹쳐 그린다', (tester) async {
      final e = UiEnv(
        assets: AssetIndex([
          'assets/boats/v01fix/prop_boat_theme_01_rear_v02_clean.png',
          'assets/boats/v01fix/prop_boat_theme_01_front_v02_clean.png',
          // 뒤판만 있는 배는 점선
          'assets/boats/v01fix/prop_boat_theme_02_rear_v02_clean.png',
        ]),
      );
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, ShopTab.boat);
      await settle(tester, () => false, tries: 4);
      expect(find.descendant(of: _item('boat_cruise'), matching: find.byType(Image)), findsNWidgets(2));
      expect(tester.getSize(find.descendant(of: _item('boat_cruise'), matching: find.byType(BoatShelfArt))),
          boatArtSize);
      expect(find.descendant(of: _item('boat_speed'), matching: find.byType(Image)), findsNothing);
      expect(find.descendant(of: _item('boat_speed'), matching: find.byType(ItemPlaceholder)), findsOneWidget);
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
      expect(find.text('지름길을 50 럭에 구매할까요?'), findsOneWidget);
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
      expect(find.text('순풍을 40 럭에 구매할까요?'), findsOneWidget);
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

    testWidgets('소품: 받침에 맞는 조사, 사면 가짐으로 바뀌고 얻은 소품·새 표시에 들어간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 700));
      await _open(tester, e);
      await _goTab(tester, ShopTab.prop);

      await _press(tester, 'face_02');
      expect(find.text('귀마개를 300 럭에 구매할까요?'), findsOneWidget);
      await _answer(tester, '구매');
      expect(find.text('귀마개를 구매했어요'), findsOneWidget);
      await settle(tester, () => _state('face_02', '가짐').evaluate().isNotEmpty);
      expect(_state('face_02', '가짐'), findsOneWidget);
      expect(tester.getSemantics(_item('face_02')).label, '귀마개, 가짐');

      expect(await _withSvc(tester, (s) => s.ownedPropIds()), contains('face_02'));
      final row = await tester.runAsync(() => (e.db.select(e.db.propsOwned)
            ..where((t) => t.propId.equals('face_02')))
          .getSingle());
      expect(row!.seen, isFalse);
      expect(await tester.runAsync(() => _read(tester, ownedPropIdsProvider.future)), contains('face_02'));

      // 가진 칸은 눌러도 시트가 없다
      await _press(tester, 'face_02');
      expect(find.textContaining('구매할까요'), findsNothing);
      await end(tester, e);
    });

    testWidgets('꾸밈 효과도 소품처럼 산다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 200));
      await _open(tester, e);
      await _goTab(tester, ShopTab.effect);

      await _press(tester, 'effect_01');
      expect(find.text('나뭇잎을 200 럭에 구매할까요?'), findsOneWidget);
      expect(find.text('남는 럭 0'), findsOneWidget);
      await _answer(tester, '구매');
      await settle(tester, () => _state('effect_01', '가짐').evaluate().isNotEmpty);
      expect(_state('effect_01', '가짐'), findsOneWidget);
      expect(await _withSvc(tester, (s) => s.ownedPropIds()), contains('effect_01'));
      await end(tester, e);
    });

    testWidgets('배: 사면 가짐으로, 자동으로 갈아타지 않는다. 뗏목은 눌러도 시트가 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _giveCoins(e, 5000));
      await _open(tester, e);
      await _goTab(tester, ShopTab.boat);

      await _press(tester, 'boat_raft');
      expect(find.textContaining('구매할까요'), findsNothing);

      await _press(tester, 'boat_cruise');
      expect(find.text('유람선을 5,000 럭에 구매할까요?'), findsOneWidget);
      await _answer(tester, '구매');
      await settle(tester, () => _state('boat_cruise', '가짐').evaluate().isNotEmpty);
      expect(_state('boat_cruise', '가짐'), findsOneWidget);
      expect(await _withSvc(tester, (s) => s.ownedBoatIds()), contains('boat_cruise'));
      expect((await _withSvc(tester, (s) => s.selectedBoat()))!.id, 'boat_raft');
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
      expect(find.textContaining('구매할까요'), findsNothing);
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
      expect(find.textContaining('구매할까요'), findsNothing);
      expect(await _withSvc(tester, (s) => s.coinBalance()), 1000);
      // 다른 효과는 살 수 있다
      await tester.pump(const Duration(seconds: 3));
      await _press(tester, 'fx_tailwind');
      expect(find.textContaining('구매할까요'), findsOneWidget);
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
      expect(find.text('지름길을 50 럭에 구매할까요?'), findsOneWidget);
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
      expect(find.text('상점'), findsOneWidget);
      expect(tester.getRect(_key('cart-placeholder')), const Rect.fromLTWH(440, 530, 120, 109));

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

    testWidgets('상품이 없으면 입구를 숨긴다 (스키마 13장)', (tester) async {
      final c = ProviderContainer(overrides: [
        shopCatalogProvider.overrideWith(
          (ref) => ShopCatalog(tabLabels: const {}, defaultBoat: 'boat_raft', items: const []),
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
