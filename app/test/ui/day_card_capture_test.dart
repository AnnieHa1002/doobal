import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/app/providers.dart';
import 'package:doobal/domain/day_card.dart';
import 'package:doobal/domain/journey.dart' show Frame;
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/common/app_text.dart';
import 'package:doobal/ui/day_card/day_card_view.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart' as h;
import 'ui_env.dart';

/// 하루 카드 엽서(2-3)·공유 엽서(2-4)를 눈으로 볼 때만 도는 시험 (T10b). 그림을 [DOOBAL_DAYCARD_CAPTURE_DIR]에 PNG로 남긴다
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final dir = Platform.environment['DOOBAL_DAYCARD_CAPTURE_DIR'];

  testWidgets('하루 카드 찍기', skip: dir == null, (tester) async {
    await tester.runAsync(() async {
      Future<ByteData> font(String name) async =>
          ByteData.sublistView(await File('assets/fonts/$name.ttf').readAsBytes());
      await (FontLoader(bodyFont)
            ..addFont(font('NotoSansKR-Regular'))
            ..addFont(font('NotoSansKR-SemiBold'))
            ..addFont(font('NotoSansKR-Bold')))
          .load();
    });
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final e = UiEnv();
    await e.seed(tester);
    final rules = h.rules;
    final now = DateTime.utc(2026, 11, 19, 0);
    e.now = now;

    DayCard cardOf(DayRange range, {int steps = 7912, double trailM = 3750, CardStory story = CardStory.empty}) =>
        buildDayCard(
          range,
          {
            for (final d in range.dayKeys)
              d: DayTotals(day: d, steps: steps, actualM: steps * 0.7, trailM: trailM, coins: 37),
            '2026-11-16': const DayTotals(day: '2026-11-16', steps: 8350, coins: 40),
            '2026-11-17': const DayTotals(day: '2026-11-17', steps: 3104, coins: 20),
          },
          rules: rules,
          story: story,
        );
    const toward = CardJourney(destId: 'kr001', destName: '경복궁', totalKm: 24, beforeKm: 6, endKm: 11.6);
    const strokes = [
      PaintStroke('autumn.morning', 1200),
      PaintStroke('autumn.day', 1300),
      PaintStroke('autumn.sunset', 1250),
    ];
    final states = <String, (DayCard, List<String>)>{
      'walked': (cardOf(const DayRange.single('2026-11-18'), story: const CardStory(journey: toward, strokes: strokes)), const []),
      'rest': (cardOf(const DayRange.single('2026-11-18'), steps: 0, trailM: 0, story: const CardStory(journey: toward)), const []),
      'arrived': (
        cardOf(const DayRange.single('2026-11-18'),
            story: const CardStory(
                journey: CardJourney(
                    destId: 'kr001', destName: '경복궁', totalKm: 24, beforeKm: 20, endKm: 24,
                    arrived: true, frame: Frame.silver, visitNo: 1))),
        const ['kr001'],
      ),
      'multi': (cardOf(const DayRange('2026-11-16', '2026-11-18'), story: const CardStory(strokes: strokes)), const []),
    };

    Future<void> wait([int n = 12]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        image.dispose();
      });
    }

    for (final MapEntry(key: name, value: (card0, paintings)) in states.entries) {
      final card = paintings.isEmpty
          ? card0
          : DayCard(
              range: card0.range,
              steps: card0.steps,
              actualM: card0.actualM,
              trailM: card0.trailM,
              drops: card0.drops,
              best: card0.best,
              week: card0.week,
              paintings: paintings,
              coins: card0.coins,
              story: card0.story,
            );
      for (final share in [false, true]) {
        tester.view.physicalSize = (share ? const Size(360, 450) : const Size(390, 640)) * 2;
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: e.overrides,
            child: MaterialApp(
              theme: ThemeData(fontFamily: bodyFont, scaffoldBackgroundColor: const Color(0xFF6B6359)),
              home: Scaffold(
                body: Consumer(builder: (context, ref, _) {
                  final landmarks = ref.watch(landmarksProvider).value ?? const [];
                  final painting = cardPainting(card, {for (final l in landmarks) l.id: l});
                  if (share) {
                    return DayCardShareImage(card: card, now: now, painting: painting, spirit: SpiritLook.base);
                  }
                  return Center(
                    child: SizedBox(
                      width: 342,
                      child: DayCardPanel(
                        card: card,
                        now: now,
                        rules: rules,
                        painting: painting,
                        spirit: SpiritLook.base,
                        onShare: () {},
                        onDetail: () {},
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ));
        await wait(160);
        await shot('daycard_${name}_${share ? 'share' : 'card'}');
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await end(tester, e);
  });
}
