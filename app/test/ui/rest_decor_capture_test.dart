import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:doobal/app/decor_providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/decor_place.dart';
import 'package:doobal/domain/journey.dart' show Frame;
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 쉼터 꾸미기를 눈으로 볼 때만 도는 시험 (T15). 그림을 [DOOBAL_DECOR_CAPTURE_DIR]에 PNG로 남긴다
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final dir = Platform.environment['DOOBAL_DECOR_CAPTURE_DIR'];
  final stage = DecorStage.of(campTheme, rules.decor.place, screenHeightPx: rules.screenHeightPx)!;

  testWidgets('쉼터 꾸미기 찍기 (낮·밤·서랍)', skip: dir == null, (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final e = UiEnv();
    await e.seed(tester, () async {
      final items = {
        'decor_easel': (const ScenePoint(300, 700), false),
        'decor_clothesline': (const ScenePoint(330, 795), false),
        'decor_lantern': (const ScenePoint(250, 690), false),
        'decor_stone_lantern': (const ScenePoint(560, 760), true),
        'decor_bench': (const ScenePoint(480, 800), false),
        'decor_flower_pot': (const ScenePoint(20, 790), false),
      };
      await e.db.batch((b) {
        b.insertAll(e.db.decorOwned, [
          for (final (i, id) in [...items.keys, 'decor_pond', 'decor_stump'].indexed)
            DecorOwnedCompanion.insert(decorId: id, gotUtc: i),
        ]);
        for (final i in items.entries) {
          final r = stage.toRatio(i.value.$1);
          b.insert(e.db.decorPlaced, DecorPlacedCompanion.insert(
            decorId: i.key, xRatio: r.x, yRatio: r.y, flipped: Value(i.value.$2), placedUtc: 1));
        }
        b.insertAll(e.db.decorPaintings, [
          DecorPaintingsCompanion.insert(decorId: 'decor_easel', slot: 0, paintingKey: 'sketch'),
          DecorPaintingsCompanion.insert(decorId: 'decor_clothesline', slot: 0, paintingKey: 'kr001'),
          DecorPaintingsCompanion.insert(decorId: 'decor_clothesline', slot: 2, paintingKey: 'kr002'),
        ]);
        b.insert(e.db.companions, CompanionsCompanion.insert(
          companionId: 'bright', metUtc: 1, chapter: Value(rules.companionChapters),
          readChapter: Value(rules.companionChapters)));
      });
      await e.ownPaintings({'sketch': Frame.wood, 'kr001': Frame.gold, 'kr002': Frame.silver});
    });

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

    Future<void> open(DateTime now) async {
      e.now = now;
      tester.view.physicalSize = const Size(390, 844) * 2;
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            ...e.overrides,
            restWiggleProvider.overrideWithValue(const WiggleSpec.off()),
            finaleRoamRandomProvider.overrideWithValue(Random(3)),
          ],
          child: const MaterialApp(home: RestScreen()),
        ),
      ));
      bool ready() => find.byType(rive.RiveWidget).evaluate().isNotEmpty;
      for (var i = 0; i < 400 && !ready(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // 낮 (한국 11/18 10시), 처음 화면과 오른쪽 끝
    await open(DateTime.utc(2026, 11, 18, 1));
    await shot('decor_day_first');
    await tester.drag(find.byType(RestScreen), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('decor_day_end');
    await tester.drag(find.byType(RestScreen), const Offset(300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    // 서랍 열기 + 이젤 고르기
    await tester.tap(find.byKey(const ValueKey('rest-side-decorate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('decor-decor_easel')));
    await tester.pump();
    await shot('decor_day_drawer');
    // 밤 (한국 11/18 23시)
    await tester.pumpWidget(const SizedBox());
    await open(DateTime.utc(2026, 11, 18, 14));
    await shot('decor_night_first');
    await tester.drag(find.byType(RestScreen), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('decor_night_end');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await end(tester, e);
  });
}
