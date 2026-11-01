import 'dart:async';

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/ui/scene/scene_art.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

void main() {
  testWidgets('느린 계절 로드 중 이전 완성 장면을 유지한 뒤 한 번에 전환한다', (tester) async {
    final bundle = _DelayedSceneBundle();
    Widget scene(int month, String name) {
      final look = sceneLook(
        DateTime.utc(2026, month, 15, 3),
        const LatLng(37.5776, 126.9769),
        false,
        landmarks,
        rules,
      );
      return MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: SceneArtHost(
            look: look,
            mode: SceneMode.walking,
            size: const Size(390, 844),
            builder: (_, art, elapsed) => Text(art == null ? 'loading' : name),
          ),
        ),
      );
    }

    Future<void> ready(String label) async {
      for (var i = 0; i < 600 && find.text(label).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      expect(find.text(label), findsOneWidget);
    }

    await tester.pumpWidget(scene(4, 'spring'));
    await ready('spring');
    await tester.pumpWidget(scene(7, 'summer'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('spring'), findsOneWidget);
    expect(find.text('summer'), findsNothing);
    bundle.gate.complete();
    await ready('summer');
    await tester.pumpWidget(const SizedBox());
  });
}

class _DelayedSceneBundle extends AssetBundle {
  int reads = 0;
  final gate = Completer<void>();
  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/data/scene_art.json' && ++reads > 1) await gate.future;
    return rootBundle.load(key);
  }
}
