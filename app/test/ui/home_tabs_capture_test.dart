import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/app/paint_trail_controller.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/tabs/home_tabs.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import 'ui_env.dart';

/// 3탭(쉼터·걷기·나)을 눈으로 볼 때만 도는 시험. 그림을 [DOOBAL_TABS_CAPTURE_DIR]에 PNG로 남긴다
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final dir = Platform.environment['DOOBAL_TABS_CAPTURE_DIR'];

  testWidgets('3탭 찍기', skip: dir == null, (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final e = UiEnv();
    await e.seed(tester, () => e.insertSketchJourney(0.6));

    Future<void> shot(String name) async {
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        image.dispose();
      });
    }

    tester.view.physicalSize = const Size(390, 844) * 2;
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [...e.overrides, restWiggleProvider.overrideWithValue(const WiggleSpec.off())],
        child: const DoobalApp(),
      ),
    ));
    bool ready() => find.byType(rive.RiveWidget).evaluate().isNotEmpty;
    for (var i = 0; i < 400 && !ready(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    await shot('tabs_rest');

    await openTab(tester, 'walk');
    await shot('tabs_walk_idle');

    final c = ProviderScope.containerOf(tester.element(find.byType(HomeTabs)));
    for (var i = 0; i < 80 && !c.read(paintTrailProvider).active; i++) {
      await tester.runAsync(() => c.read(paintTrailProvider.notifier).startNow());
      await tester.pump();
    }
    await shot('tabs_walk_walking');

    await openTab(tester, 'me');
    await shot('tabs_me');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await end(tester, e);
  });
}
