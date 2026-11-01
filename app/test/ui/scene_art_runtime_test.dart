import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/ui/scene/doobal_character.dart';
import 'package:doobal/ui/scene/scene_art.dart';
import 'package:doobal/ui/scene/scene_art_painter.dart';
import 'package:doobal/ui/scene/scene_painter.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import '../domain/helpers.dart';

void main() {
  test('작은 폰·태블릿·가로에서 길과 배의 발 위치가 화면 안에 있다', () {
    final data = jsonDecode(
      File('assets/data/scene_art.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final art = SceneArt(data, {});
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(844, 390),
    ]) {
      final land = SceneArtLayout(art, size, SceneMode.walking, false, null);
      final sea = SceneArtLayout(art, size, SceneMode.walking, true, null);
      expect(land.foot.dy, lessThan(size.height));
      expect(land.foot.dy, greaterThan(land.figureHeight));
      expect(sea.foot.dy, lessThan(land.foot.dy));
      expect(sea.foot.dy, greaterThan(sea.figureHeight));
    }
    expect(sceneArtHash('journey-a', 4), sceneArtHash('journey-a', 4));
    expect(sceneArtHash('journey-a', 4), isNot(sceneArtHash('journey-a', 5)));
    expect(sceneArtHash('journey-a', 4), isNot(sceneArtHash('journey-b', 4)));
  });

  testWidgets('실제 PNG의 지역·계절·바다별 로드와 낮밤 그리기', (tester) async {
    final seen = <Map<String, dynamic>>[];
    for (final region in [
      'capital',
      'gangwon',
      'chungcheong',
      'jeolla',
      'gyeongsang',
      'jeju',
      'sea',
    ]) {
      final look = sceneLook(
        DateTime.utc(2026, 7, 15, 3),
        const LatLng(37.5776, 126.9769),
        region == 'sea',
        landmarks,
        rules,
      );
      final actual = SceneLook(
        look.mix,
        look.sky,
        look.celestial,
        region,
        look.season,
      );
      final art = (await tester.runAsync(
        () => SceneArt.load(rootBundle, actual, false, 1 / 3, 3),
      ))!;
      try {
        expect((art.data['far'][region] as List).length, 3);
        if (region == 'sea') {
          expect(art.images.containsKey('bg_path_v11_clean.png'), isFalse);
          expect(
            art.images.containsKey('bg_front_summer_v11_clean.png'),
            isFalse,
          );
          expect(art.images.containsKey('bg_near_water_v11_clean.png'), isTrue);
        }
        final recorder = ui.PictureRecorder();
        SceneArtPainter(
          art: art,
          look: actual,
          mode: SceneMode.walking,
          distanceM: 123456,
          rules: rules,
          onSea: region == 'sea',
          pass: ScenePass.background,
          elapsed: 4,
        ).paint(Canvas(recorder), const Size(390, 844));
        final picture = recorder.endRecording();
        final image = (await tester.runAsync(() => picture.toImage(390, 844)))!;
        final bytes = (await tester.runAsync(() => image.toByteData()))!;
        expect(bytes.lengthInBytes, 390 * 844 * 4);
        for (final p in [0, (400 * 390 + 10) * 4, (843 * 390 + 10) * 4]) {
          expect(bytes.getUint8(p + 3), 255, reason: '$region 화면 빈칸');
        }
        image.dispose();
        picture.dispose();
        seen.add({
          'region': region,
          'decodedImages': art.images.length,
          'decodedBytes': art.images.values.fold<int>(
            0,
            (n, i) => n + i.width * i.height * 4,
          ),
        });
      } finally {
        art.dispose();
      }
    }
    final directory = Platform.environment['DOOBAL_BACKGROUND_CAPTURE_DIR'];
    if (directory != null) {
      await tester.runAsync(() => File('$directory/decode_report.json').writeAsString(jsonEncode(seen)));
    }
  });

  testWidgets('실제 Rive 앞뒤에 새 배경·앞풀·배·캠프를 연결한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    for (final state in [
      ('walk', false, false, false, 4, 12, const Size(390, 844)),
      ('run', false, false, true, 4, 12, const Size(390, 844)),
      ('night', false, false, false, 7, 2, const Size(390, 844)),
      ('autumn_landscape', false, false, false, 10, 12, const Size(844, 390)),
      ('boat', false, true, false, 7, 12, const Size(844, 390)),
      ('camp', true, false, false, 4, 12, const Size(390, 844)),
      ('camp_landscape', true, false, false, 4, 12, const Size(844, 390)),
      ('winter', false, false, false, 1, 12, const Size(320, 568)),
    ]) {
      tester.view.physicalSize = state.$7;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: SceneView(
              mode: state.$2 ? SceneMode.rest : SceneMode.walking,
              distanceM: 301,
              nowUtc: DateTime.utc(2026, state.$5, 15, state.$6 - 9),
              position: const LatLng(37.5776, 126.9769),
              onSea: state.$3,
              rules: rules,
              landmarks: landmarks,
              camp: state.$2 ? campTheme : null,
              running: state.$4,
              sceneSeed: 'runtime-test',
            ),
          ),
        ),
      );
      final expected = state.$2
          ? 'bg_rest_camp_back_v11_clean.png'
          : state.$3
          ? 'bg_near_water_v11_clean.png'
          : 'bg_front_${seasonOf('2026-${state.$5.toString().padLeft(2, '0')}-15', rules).name}_v11_clean.png';
      bool ready() =>
          find
              .byWidgetPredicate(
                (w) =>
                    w is CustomPaint &&
                    w.painter is SceneArtPainter &&
                    (w.painter! as SceneArtPainter).art.images.containsKey(
                      expected,
                    ),
              )
              .evaluate()
              .isNotEmpty &&
          find.byType(rive.RiveWidget).evaluate().isNotEmpty;
      for (var i = 0; i < 400 && !ready(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      expect(ready(), isTrue, reason: state.$1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: state.$1);
      expect(
        tester.widget<DoobalCharacter>(find.byType(DoobalCharacter)).speed,
        state.$2 || state.$3
            ? 0
            : state.$4
            ? 2
            : 1,
      );
      final directory = Platform.environment['DOOBAL_BACKGROUND_CAPTURE_DIR'];
      if (directory != null) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('$directory/${state.$1}.png').writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
