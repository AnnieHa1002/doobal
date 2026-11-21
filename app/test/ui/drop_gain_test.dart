import 'package:doobal/app/catalog_providers.dart';
import 'package:doobal/domain/asset_index.dart';
import 'package:doobal/domain/paint_color.dart';
import 'package:doobal/domain/paint_trail.dart' show paintDrops;
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:doobal/ui/walking/paint_drop_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 연출 ④ 물감 방울 줍기 럭 숫자 (T19, 16장 11/20 Q008, config ui.motion.dropPickup, 캔버스 3-1 메모 가안):
// 떠오르는 ‘+n 럭’의 숫자가 0.3초 동안 1씩 오르며 1.15배로 튀고, 통 아이콘은 0.1초 뒤. 떠오름·흐려짐은 그대로.
// 한 방울이면 ‘+1 럭’이 튀기만, 화면이 꺼졌다 켜져 여러 방울을 한꺼번에 주우면 +1 → +n으로 오른다.

final _d = rules.motion.dropPickup!;

SceneCompanionSpot _spot() => const SceneCompanionSpot(
      size: Size(390, 844),
      spiritFoot: Offset(200, 600),
      figureHeight: 180,
      groundPtPerM: 2,
      tint: 0xFFFFFFFF,
    );

Future<void> _pump(WidgetTester tester, double shownM, {bool still = false, int? trailId}) => tester.pumpWidget(ProviderScope(
      overrides: [assetIndexProvider.overrideWith((ref) => AssetIndex(const []))],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(390, 844), disableAnimations: still),
          child: Stack(children: [
            Positioned.fill(
              child: PaintDropLayer(spot: _spot(), shownM: shownM, rules: rules, color: 0xFF74C6EA, trailId: trailId),
            ),
          ]),
        ),
      ),
    ));

Finder _key(String k) => find.byKey(ValueKey(k));

String _text(WidgetTester tester) => tester.widget<Text>(_key('paint-drop-gain')).data!;

double _scale(WidgetTester tester) =>
    tester.widget<Transform>(_key('paint-drop-gain-scale')).transform.getMaxScaleOnAxis();

bool _tubeShown(WidgetTester tester) => tester
    .widget<Visibility>(find.ancestor(of: _key('paint-drop-gain-tube'), matching: find.byType(Visibility)).first)
    .visible;

Duration _ms(int ms) => Duration(milliseconds: ms);

/// 물감 길 1에서 통이 나오는 첫 방울 번호
final _tubeDrop = [for (var i = 1; i < 60; i++) if (rollDrop(1, i, rules.paintColor).tube) i].first;

void main() {
  testWidgets('한 방울: ‘+1 럭’이 0.3초 동안 1 → 1.15 → 1배로 튄다 (숫자는 그대로)', (tester) async {
    await _pump(tester, 95);
    await _pump(tester, 100);
    expect(_text(tester), '+${rules.paintDropCoinsPerDrop} 럭');
    expect(_scale(tester), 1);
    await tester.pump();
    await tester.pump(_ms(150));
    expect(_scale(tester), closeTo(_d.luxBounceScale, 0.01));
    expect(_text(tester), '+1 럭');
    await tester.pump(_ms(150));
    expect(_scale(tester), 1);
    // 떠오름·흐려짐은 그대로 (1.2초 뒤 없어짐)
    await tester.pump(_ms(1000));
    expect(_key('paint-drop-gain'), findsNothing);
  });

  testWidgets('여러 방울을 한꺼번에(화면이 꺼졌다 켜짐): +1에서 +5까지 0.3초 동안 1씩', (tester) async {
    await _pump(tester, 95);
    await _pump(tester, 520);
    expect(_text(tester), '+1 럭');
    await tester.pump();
    await tester.pump(_ms(100));
    expect(_text(tester), '+2 럭');
    await tester.pump(_ms(100));
    expect(_text(tester), '+3 럭');
    await tester.pump(_ms(90));
    expect(_text(tester), '+4 럭');
    await tester.pump(_ms(20));
    expect(_text(tester), '+5 럭');
    expect(_scale(tester), 1);
    await tester.pump(_ms(1200));
  });

  testWidgets('통 방울: 통 아이콘은 0.1초 뒤에 나타난다 (자리는 처음부터)', (tester) async {
    await _pump(tester, _tubeDrop * 100.0 - 5, trailId: 1);
    await _pump(tester, _tubeDrop * 100.0, trailId: 1);
    expect(_tubeShown(tester), isFalse);
    expect(tester.getSize(_key('paint-drop-gain-tube')), const Size(24, 24));
    await tester.pump();
    await tester.pump(_ms(90));
    expect(_tubeShown(tester), isFalse);
    await tester.pump(_ms(20));
    expect(_tubeShown(tester), isTrue);
    await tester.pump(_ms(1200));
  });

  testWidgets('움직임 줄이기면 끝 상태만: 다 오른 숫자·1배·통 바로', (tester) async {
    final from = _tubeDrop * 100.0 - 205;
    final to = _tubeDrop * 100.0;
    await _pump(tester, from, still: true, trailId: 1);
    await _pump(tester, to, still: true, trailId: 1);
    final n = (paintDrops(to, rules) - paintDrops(from, rules)) * rules.paintDropCoinsPerDrop;
    expect(n, greaterThan(1));
    expect(_text(tester), '+$n 럭');
    expect(_scale(tester), 1);
    expect(_tubeShown(tester), isTrue);
    await tester.pump();
    await tester.pump(_ms(150));
    expect(_scale(tester), 1);
    await tester.pump(_ms(1200));
  });
}
