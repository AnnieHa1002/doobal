import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import 'ui_env.dart';

/// 쉼터를 눈으로 볼 때만 도는 시험. 그림을 [DOOBAL_REST_CAPTURE_DIR]에 PNG로 남긴다
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final dir = Platform.environment['DOOBAL_REST_CAPTURE_DIR'];

  testWidgets('쉼터 장면 찍기', skip: dir == null, (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final e = UiEnv();
    await e.seed(tester, () => e.insertSketchJourney(0.6));

    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        image.dispose();
      });
    }

    for (final (name, size) in [('390', const Size(390, 844)), ('375', const Size(375, 667))]) {
      tester.view.physicalSize = size * 2;
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [...e.overrides, restWiggleProvider.overrideWithValue(const WiggleSpec.off())],
          child: const MaterialApp(home: RestScreen()),
        ),
      ));
      bool ready() => find.byType(rive.RiveWidget).evaluate().isNotEmpty;
      for (var i = 0; i < 400 && !ready(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
      // 물건 그림까지 풀리게 몇 번 더
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await shot('rest_${name}_first');
      await tester.drag(find.byType(RestScreen), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await shot('rest_${name}_end');
      await tester.drag(find.byType(RestScreen), const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    await end(tester, e);
  });
}
