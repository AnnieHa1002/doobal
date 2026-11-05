import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

final _backpack = find.byKey(const ValueKey('camp-object-backpack'));

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
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
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
    testWidgets('처음 화면: 물건은 캔버스 자리, 왼쪽 끝', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(tester.getRect(_backpack), const Rect.fromLTWH(268, 510, 64, 80));
      expect(tester.getTopLeft(find.byKey(const ValueKey('camp-object-note'))), const Offset(184, 572));
      expect(tester.getTopLeft(find.byKey(const ValueKey('camp-object-map'))), const Offset(318, 596));
      await end(tester, e);
    });

    testWidgets('끌면 장면이 같이 움직이고 고정 HUD는 그대로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      final profile = tester.getRect(find.byTooltip('나의 정보'));
      final settings = tester.getRect(find.byTooltip('설정'));
      final depart = tester.getRect(find.byTooltip('출발하기'));
      final pill = tester.getRect(find.textContaining('쉬는 중'));

      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      final moved = tester.getTopLeft(_backpack).dx;
      // 터치 기울기(slop)만큼 덜 움직일 수 있다
      expect(moved, lessThan(268 - 40));
      expect(moved, greaterThanOrEqualTo(268 - 80));
      expect(tester.getRect(find.byTooltip('나의 정보')), profile);
      expect(tester.getRect(find.byTooltip('설정')), settings);
      expect(tester.getRect(find.byTooltip('출발하기')), depart);
      expect(tester.getRect(find.textContaining('쉬는 중')), pill);
      await gesture.up();
      await _settleSnap(tester);
      await end(tester, e);
    });

    testWidgets('놓으면 가까운 끝으로 붙는다: 오른쪽 끝은 −195, 다시 밀면 처음으로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await tester.dragFrom(const Offset(300, 300), const Offset(-150, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_backpack).dx, closeTo(268 - 195, 0.01));

      await tester.dragFrom(const Offset(100, 300), const Offset(30, 0));
      await _settleSnap(tester);
      // 끝에서 조금만 밀면 도로 끝으로
      expect(tester.getTopLeft(_backpack).dx, closeTo(268 - 195, 0.01));

      await tester.dragFrom(const Offset(100, 300), const Offset(150, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_backpack).dx, closeTo(268, 0.01));
      await end(tester, e);
    });

    testWidgets('끝을 넘어 끌어도 그 끝에서 멈춘다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await tester.dragFrom(const Offset(100, 300), const Offset(200, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_backpack).dx, closeTo(268, 0.01));
      await tester.dragFrom(const Offset(380, 300), const Offset(-370, 0));
      await _settleSnap(tester);
      expect(tester.getTopLeft(_backpack).dx, closeTo(268 - 195, 0.01));
      await end(tester, e);
    });

    testWidgets('밀어 놓은 뒤에도 물건을 누르면 그 화면으로 간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await tester.dragFrom(const Offset(300, 300), const Offset(-150, 0));
      await _settleSnap(tester);
      await tester.tap(find.byKey(const ValueKey('camp-object-map')));
      await settle(tester, () => find.byType(MapScreen).evaluate().isNotEmpty);
      expect(find.byType(MapScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('물건 위에서 시작해도 끌면 눌리지 않고 밀린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await tester.dragFrom(tester.getCenter(_backpack), const Offset(-150, 0));
      await _settleSnap(tester);
      expect(find.byType(AlbumScreen), findsNothing);
      expect(tester.getTopLeft(_backpack).dx, closeTo(268 - 195, 0.01));
      await end(tester, e);
    });

    testWidgets('작은 폰(375×667): 물건 자리는 폭 비율, 아래 기준', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      tester.view.physicalSize = const Size(375, 667);
      await tester.pump();
      const k = 375 / 390;
      final at = tester.getTopLeft(_backpack);
      expect(at.dx, closeTo(268 * k, 0.01));
      expect(at.dy, closeTo(667 - (844 - 510) * k, 0.01));
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
      await _open(tester, e);
      final depart = tester.getRect(find.byTooltip('출발하기'));
      final fingers = await pinch(tester, 50);
      // 손가락 사이 100 → 150 = 1.5배 (config max)
      final rect = tester.getRect(_backpack);
      expect(rect.width, closeTo(64 * 1.5, 0.5));
      // 아래 기준: 물건의 y는 화면 아래에서 (844 − 510) × 배율
      expect(rect.top, closeTo(844 - (844 - 510) * 1.5, 0.5));
      expect(tester.getRect(find.byTooltip('출발하기')), depart);
      for (final f in fingers) {
        await f.up();
      }
      await _settleSnap(tester);
      await end(tester, e);
    });

    testWidgets('1.5배를 넘게 벌려도 1.5배, 오므려도 1배 아래로 안 간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      var fingers = await pinch(tester, 200);
      expect(tester.getRect(_backpack).width, closeTo(96, 0.5));
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
      expect(tester.getRect(_backpack).width, closeTo(64, 0.01));
      final x = tester.getTopLeft(_backpack).dx;
      expect(x == 268 || (x - (268 - 195)).abs() < 0.01, isTrue, reason: '$x');
      await end(tester, e);
    });

    testWidgets('확대 중 끌기는 놓아도 끝에 안 붙는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      final fingers = await pinch(tester, 25);
      for (final f in fingers) {
        await f.up();
      }
      await _settleSnap(tester);
      expect(tester.getRect(_backpack).width, closeTo(64 * 1.25, 0.5));

      await tester.dragFrom(const Offset(300, 300), const Offset(-120, 0));
      await tester.pump();
      final moved = tester.getTopLeft(_backpack).dx;
      expect(moved, lessThan(268 * 1.25));
      await _settleSnap(tester);
      // 처음 자리도 오른쪽 끝도 아닌 그 자리에 그대로
      expect(tester.getTopLeft(_backpack).dx, closeTo(moved, 0.01));
      await end(tester, e);
    });

    testWidgets('확대 중에도 물건을 누르면 그 화면으로 간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      final fingers = await pinch(tester, 25);
      for (final f in fingers) {
        await f.up();
      }
      await _settleSnap(tester);
      await tester.tap(_backpack);
      await settle(tester, () => find.byType(AlbumScreen).evaluate().isNotEmpty);
      expect(find.byType(AlbumScreen), findsOneWidget);
      await end(tester, e);
    });
  });
}
