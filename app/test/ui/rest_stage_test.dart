import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/rest/rest_slots.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 쉼터 장면 (캔버스 2-2, camp_wide v5): 장면은 화면 폭 1.5배를 좌우로 밀고 두 손가락으로 1~1.5배.
// v5 장면에 서는 물건은 수레뿐이라 수레(자리 440,530 / 그림 120×109)로 장면 움직임을 본다.
// 고정 HUD = 럭 보석·쉬는 중 알약·오른쪽 옆 버튼 (16장 11/18)

final _cartArt = find.byKey(const ValueKey('cart-art'));
final _cartBox = find.byKey(const ValueKey('camp-object-cart'));
final _gem = find.byKey(const ValueKey('rest-gem'));
final _pill = find.textContaining('쉬는 중');
final _mapButton = find.byKey(const ValueKey('rest-side-map'));

/// 수레 자리에 색 상자를 끼운다 (누르면 [onTap])
Override _cart({VoidCallback? onTap, bool notice = false}) => restSlotsProvider.overrideWithValue(RestSlots(
      cart: RestObjectSlot(
        art: (_) => const ColoredBox(key: ValueKey('cart-art'), color: Colors.brown),
        label: '상점',
        notice: notice,
        onTap: (_) => onTap?.call(),
      ),
    ));

Future<void> _open(WidgetTester tester, UiEnv e, {List<Override> more = const []}) async {
  phone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...e.overrides,
      restWiggleProvider.overrideWithValue(const WiggleSpec.off()),
      ...more,
    ],
    child: const MaterialApp(home: RestScreen()),
  ));
  await settle(tester, () => _pill.evaluate().isNotEmpty);
  await tester.pump();
}

/// 끝에 붙는 애니메이션까지 (0.25초)
Future<void> _settleSnap(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('쉼터 넓히기', () {
    testWidgets('처음 화면: 수레는 캔버스 자리(장면 x 440, 처음 화면 밖), 왼쪽 끝', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      expect(tester.getRect(_cartArt), const Rect.fromLTWH(440, 530, 120, 109));
      await end(tester, e);
    });

    testWidgets('끌면 장면이 같이 움직이고 고정 HUD(럭 보석·알약·옆 버튼)는 그대로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      final gem = tester.getRect(_gem);
      final pill = tester.getRect(_pill);
      final map = tester.getRect(_mapButton);

      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      final moved = tester.getTopLeft(_cartArt).dx;
      // 터치 기울기(slop)만큼 덜 움직일 수 있다
      expect(moved, lessThan(440 - 40));
      expect(moved, greaterThanOrEqualTo(440 - 80));
      expect(tester.getRect(_gem), gem);
      expect(tester.getRect(_pill), pill);
      expect(tester.getRect(_mapButton), map);
      await gesture.up();
      await _settleSnap(tester);
      await end(tester, e);
    });

    testWidgets('놓으면 가까운 끝으로 붙는다: 오른쪽 끝은 −195, 다시 밀면 처음으로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      await tester.dragFrom(const Offset(300, 300), const Offset(-150, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_cartArt).dx, closeTo(440 - 195, 0.01));

      await tester.dragFrom(const Offset(100, 300), const Offset(30, 0));
      await _settleSnap(tester);
      // 끝에서 조금만 밀면 도로 끝으로
      expect(tester.getTopLeft(_cartArt).dx, closeTo(440 - 195, 0.01));

      await tester.dragFrom(const Offset(100, 300), const Offset(150, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_cartArt).dx, closeTo(440, 0.01));
      await end(tester, e);
    });

    testWidgets('끝을 넘어 끌어도 그 끝에서 멈춘다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      await tester.dragFrom(const Offset(100, 300), const Offset(200, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_cartArt).dx, closeTo(440, 0.01));
      await tester.dragFrom(const Offset(380, 300), const Offset(-370, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_cartArt).dx, closeTo(440 - 195, 0.01));
      await end(tester, e);
    });

    testWidgets('밀어 놓은 뒤 수레를 누르면 눌리고, 옆 버튼은 언제나 눌린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      var taps = 0;
      await _open(tester, e, more: [_cart(onTap: () => taps++)]);
      await tester.dragFrom(const Offset(300, 300), const Offset(-150, 0));
      await _settleSnap(tester);
      await tester.tap(_cartBox);
      await tester.pump();
      expect(taps, 1);
      await tester.tap(_mapButton);
      await settle(tester, () => find.byType(MapScreen).evaluate().isNotEmpty);
      expect(find.byType(MapScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('수레 위에서 시작해도 끌면 눌리지 않고 밀린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      var taps = 0;
      await _open(tester, e, more: [_cart(onTap: () => taps++)]);
      await tester.dragFrom(const Offset(380, 300), const Offset(-300, 0));
      await _settleSnap(tester);
      await tester.dragFrom(tester.getCenter(_cartArt), const Offset(150, 0));
      await _settleSnap(tester);
      expect(taps, 0);
      expect(tester.getTopLeft(_cartArt).dx, closeTo(440, 0.01));
      await end(tester, e);
    });

    testWidgets('화면 크기가 달라도 수레가 장면 아래 안에 있고 끝까지 밀면 화면 안에 들어온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      for (final size in const [Size(320, 568), Size(411, 1005), Size(768, 1024), Size(1024, 768)]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size');
        await tester.dragFrom(Offset(size.width - 10, size.height / 3), Offset(-size.width, 0));
        await _settleSnap(tester);
        final rect = tester.getRect(_cartArt);
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$size');
        expect(rect.right, lessThanOrEqualTo(size.width + 0.01), reason: '$size');
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$size');
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$size');
      }
      await end(tester, e);
    });

    testWidgets('작은 폰(375×667): 물건 자리는 폭 비율, 아래 기준', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      tester.view.physicalSize = const Size(375, 667);
      await tester.pump();
      const k = 375 / 390;
      final at = tester.getTopLeft(_cartArt);
      expect(at.dx, closeTo(440 * k, 0.01));
      expect(at.dy, closeTo(667 - (844 - 530) * k, 0.01));
      await end(tester, e);
    });
  });

  group('두 손가락 확대', () {
    /// 두 손가락을 [spread]만큼 벌린다 (가운데 고정). 손가락은 댄 채로 돌려준다
    Future<List<TestGesture>> pinch(WidgetTester tester, double spread) async {
      final a = await tester.startGesture(const Offset(150, 300), pointer: 1);
      final b = await tester.startGesture(const Offset(250, 300), pointer: 2);
      await a.moveBy(Offset(-spread / 2, 0));
      await b.moveBy(Offset(spread / 2, 0));
      await tester.pump();
      return [a, b];
    }

    testWidgets('벌리면 커지고 장면은 아래 기준, HUD는 고정', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      final gem = tester.getRect(_gem);
      final map = tester.getRect(_mapButton);
      final fingers = await pinch(tester, 50);
      // 손가락 사이 100 → 150 = 1.5배 (config max)
      final rect = tester.getRect(_cartArt);
      expect(rect.width, closeTo(120 * 1.5, 0.5));
      // 아래 기준: 물건의 y는 화면 아래에서 (844 − 530) × 배율
      expect(rect.top, closeTo(844 - (844 - 530) * 1.5, 0.5));
      expect(tester.getRect(_gem), gem);
      expect(tester.getRect(_mapButton), map);
      for (final f in fingers) {
        await f.up();
      }
      await _settleSnap(tester);
      await end(tester, e);
    });

    testWidgets('1.5배를 넘게 벌려도 1.5배, 오므려도 1배 아래로 안 간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart()]);
      var fingers = await pinch(tester, 200);
      expect(tester.getRect(_cartArt).width, closeTo(180, 0.5));
      for (final f in fingers) {
        await f.up();
      }
      await _settleSnap(tester);
      fingers = await pinch(tester, -90);
      for (final f in fingers) {
        await f.up();
      }
      await _settleSnap(tester);
      // 100 → 10 = 0.1배, 1.5 × 0.1은 1로 막힌다. 1배로 돌아오면 끝에 붙는다
      expect(tester.getRect(_cartArt).width, closeTo(120, 0.01));
      final x = tester.getTopLeft(_cartArt).dx;
      expect((x - 440).abs() < 0.01 || (x - (440 - 195)).abs() < 0.01, isTrue, reason: '$x');
      await end(tester, e);
    });

    testWidgets('확대 중 끌기는 놓아도 끝에 안 붙고, 확대 중에도 수레는 눌린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      var taps = 0;
      await _open(tester, e, more: [_cart(onTap: () => taps++)]);
      final fingers = await pinch(tester, 25);
      for (final f in fingers) {
        await f.up();
      }
      await _settleSnap(tester);
      expect(tester.getRect(_cartArt).width, closeTo(120 * 1.25, 0.5));

      await tester.dragFrom(const Offset(300, 300), const Offset(-120, 0));
      await tester.pump();
      final moved = tester.getTopLeft(_cartArt).dx;
      await _settleSnap(tester);
      // 처음 자리도 오른쪽 끝도 아닌 그 자리에 그대로
      expect(tester.getTopLeft(_cartArt).dx, closeTo(moved, 0.01));
      // 끝까지 밀면 수레가 화면 안에 들어와 눌린다
      await tester.dragFrom(const Offset(380, 300), const Offset(-370, 0));
      await _settleSnap(tester);
      expect(tester.getRect(_cartBox).left, lessThan(390));
      await tester.tap(_cartBox);
      await tester.pump();
      expect(taps, 1);
      await end(tester, e);
    });
  });

  group('자리 열기', () {
    testWidgets('상품이 없어 수레를 안 끼우면 수레도 상점 옆 버튼도 없다 (스키마 13장)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [restSlotsProvider.overrideWithValue(const RestSlots())]);
      expect(_cartBox, findsNothing);
      expect(find.byKey(const ValueKey('rest-side-shop')), findsNothing);
      expect(find.byKey(const ValueKey('rest-side-map')), findsOneWidget);
      expect(find.byKey(const ValueKey('rest-side-backpack')), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('수레는 이름표 없이 서고 새 상품 점은 상점 옆 버튼에 붙는다. v5에는 배낭·노트·지도·동행·표지판 물건이 없다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, more: [_cart(notice: true)]);
      expect(find.text('상점'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('rest-side-shop')), matching: find.text('상점')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('rest-side-shop-dot')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-dot')), findsNothing);
      for (final id in ['backpack', 'note', 'map', 'companion', 'guestbookSign']) {
        expect(find.byKey(ValueKey('camp-object-$id')), findsNothing, reason: id);
      }
      await end(tester, e);
    });

    testWidgets('럭 보석은 첫날도 0으로 보이고 위 왼쪽(14pt)에 쉬는 중 알약과 한 줄로 고정, 콜백이 있으면 눌린다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertSketchJourney(0.6));
      var taps = 0;
      await _open(tester, e, more: [
        restSlotsProvider.overrideWithValue(RestSlots(gem: RestGemSlot(onTap: (_) => taps++))),
      ]);
      await settle(tester, () => _gem.evaluate().isNotEmpty);
      expect(
        find.descendant(of: _gem, matching: find.byKey(const ValueKey('luck-number'))),
        findsOneWidget,
      );
      expect(tester.widget<Text>(find.byKey(const ValueKey('luck-number'))).data, '0');
      final at = tester.getRect(_gem);
      expect(at.left, 14);
      // 알약과 같은 줄 (가운데 높이가 같다)
      expect(tester.getCenter(_pill).dy, closeTo(at.center.dy, 12));
      await tester.dragFrom(const Offset(300, 300), const Offset(-150, 0));
      await _settleSnap(tester);
      expect(tester.getRect(_gem), at);
      await tester.tap(_gem);
      await tester.pump();
      expect(taps, 1);
      await end(tester, e);
    });

    testWidgets('첫날: 이정표 글과 아래 말풍선이 함께 선다 (걸으면 함께 사라진다는 조건이 같다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertSketchJourney(0.6));
      await _open(tester, e);
      expect(find.text('첫 스케치 →'), findsOneWidget);
      expect(find.byKey(const ValueKey('first-sketch-bubble')), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('첫날이 아니면 이정표 글이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(find.text('첫 스케치 →'), findsNothing);
      await end(tester, e);
    });

    testWidgets('출발하기 버튼은 없다 (16장 11/13: 걸으면 물감 길이 열린다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(find.byTooltip('출발하기'), findsNothing);
      expect(find.text('출발하기'), findsNothing);
      await end(tester, e);
    });
  });
}
