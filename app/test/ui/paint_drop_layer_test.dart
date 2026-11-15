import 'package:doobal/app/catalog_providers.dart';
import 'package:doobal/domain/asset_index.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:doobal/ui/walking/paint_drop_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 물감 방울 줍기 연출 (config paintDrop.pickup, 디자인기획/물감길_개발인계 2장): 방울이 정령 가운데에 닿으면
// 눌린 방울 0.12초 → 튐 0.6초(0.6→1.2배), 닿은 순간부터 `+1 럭` 1.2초. 동작 줄이기면 `+1 럭`만, 밤에는 정령과 같은 보정.

const _foot = Offset(200, 600);

/// 땅 1m = 2pt (방울 사이 100m = 200pt), 정령 키 180pt
SceneCompanionSpot _spot({int tint = 0xFFFFFFFF}) => SceneCompanionSpot(
      size: const Size(390, 844),
      spiritFoot: _foot,
      figureHeight: 180,
      groundPtPerM: 2,
      tint: tint,
    );

Future<void> _pump(WidgetTester tester, double shownM, {bool still = false, int? tint}) =>
    tester.pumpWidget(ProviderScope(
      overrides: [assetIndexProvider.overrideWith((ref) => AssetIndex(const []))],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(390, 844), disableAnimations: still),
          child: Stack(children: [
            Positioned.fill(
              child: PaintDropLayer(
                spot: tint == null ? _spot() : _spot(tint: tint),
                shownM: shownM,
                rules: rules,
              ),
            ),
          ]),
        ),
      ),
    ));

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('땅 위 방울: 다음 방울이 오른쪽에서 흘러오고 정령을 지나면 사라진다 (지름 config sizePt)',
      (tester) async {
    await _pump(tester, 50);
    // 방울 1(100m)은 50m 앞 = 100pt 오른쪽, 방울 2(200m)는 화면 밖(300pt + 반지름)
    expect(_key('paint-drop-1'), findsOneWidget);
    expect(tester.getRect(_key('paint-drop-1')),
        Rect.fromLTWH(_foot.dx + 100 - 14, _foot.dy - 28, 28, 28));
    expect(_key('paint-drop-2'), findsNothing);
    expect(_key('paint-drop-pressed'), findsNothing);
    expect(_key('paint-drop-gain'), findsNothing);
  });

  testWidgets('닿으면 눌린 방울 0.12초 → 튐 0.6초(0.6→1.2배로 퍼지며 사라짐), +1 럭은 닿은 순간부터 1.2초',
      (tester) async {
    await _pump(tester, 90);
    await _pump(tester, 100);
    expect(_key('paint-drop-1'), findsNothing);
    expect(_key('paint-drop-pressed'), findsOneWidget);
    expect(_key('paint-drop-splash'), findsNothing);
    expect(find.text('+1 럭'), findsOneWidget);
    final gainTop = tester.getTopLeft(_key('paint-drop-gain')).dy;

    await tester.pump(const Duration(milliseconds: 130));
    expect(_key('paint-drop-pressed'), findsNothing);
    expect(_key('paint-drop-splash'), findsOneWidget);
    // 튐 시작: 0.6배 근처 (0.01초 지남)
    Transform scale() => tester.widget<Transform>(
        find.descendant(of: _key('paint-drop-splash'), matching: find.byType(Transform)));
    expect(scale().transform.entry(0, 0), closeTo(0.6 + 0.6 * 0.01 / 0.6, 0.01));
    // +1 럭은 머리 위로 떠오른다
    expect(tester.getTopLeft(_key('paint-drop-gain')).dy, lessThan(gainTop));

    await tester.pump(const Duration(milliseconds: 300));
    expect(scale().transform.entry(0, 0), closeTo(0.6 + 0.6 * 0.31 / 0.6, 0.01));

    // 0.72초 뒤 튐은 끝났고 +1 럭은 아직 (1.2초까지)
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('paint-drop-splash'), findsNothing);
    expect(_key('paint-drop-gain'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_key('paint-drop-gain'), findsNothing);
  });

  testWidgets('동작 줄이기: 눌린 방울·튐 없이 지우고 +1 럭만 제자리에서 흐려진다', (tester) async {
    await _pump(tester, 90, still: true);
    await _pump(tester, 100, still: true);
    expect(_key('paint-drop-1'), findsNothing);
    expect(_key('paint-drop-pressed'), findsNothing);
    expect(find.text('+1 럭'), findsOneWidget);
    final top = tester.getTopLeft(_key('paint-drop-gain')).dy;
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('paint-drop-splash'), findsNothing);
    expect(tester.getTopLeft(_key('paint-drop-gain')).dy, top);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_key('paint-drop-gain'), findsNothing);
  });

  testWidgets('처음 열 때 이미 지난 방울은 줍는 연출 없이, 밤에는 방울에 정령과 같은 시간대 보정', (tester) async {
    await _pump(tester, 250, tint: 0xFF8090C0);
    expect(_key('paint-drop-gain'), findsNothing);
    expect(_key('paint-drop-3'), findsOneWidget);
    final filter = tester.widget<ColorFiltered>(
        find.ancestor(of: _key('paint-drop-3'), matching: find.byType(ColorFiltered)));
    expect(filter.colorFilter, const ColorFilter.mode(Color(0xFF8090C0), BlendMode.modulate));
    // 글자(+1 럭)는 보정 밖이다
    await _pump(tester, 300, tint: 0xFF8090C0);
    expect(find.ancestor(of: _key('paint-drop-gain'), matching: find.byType(ColorFiltered)),
        findsNothing);
  });
}
