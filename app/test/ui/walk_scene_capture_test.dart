import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/ui/scene/scene_art_painter.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import '../domain/helpers.dart';

/// 걷는 장면을 눈으로 볼 때만 도는 시험 (T13: 뒤쪽 줄 나무 발·키 큰 조각 투명 없음).
/// 그림을 [DOOBAL_WALK_SCENE_CAPTURE_DIR]에 PNG로 남긴다. 360×880은 Z 플립6 논리 크기
void main() {
  final dir = Platform.environment['DOOBAL_WALK_SCENE_CAPTURE_DIR'];

  testWidgets('걷는 장면 찍기', skip: dir == null, (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    for (final (name, size) in [
      ('360x880', const Size(360, 880)),
      ('390x844', const Size(390, 844)),
      ('880x360', const Size(880, 360)),
    ]) {
      tester.view.physicalSize = size;
      for (final (season, month) in [('autumn', 10), ('summer', 7)]) {
        for (final m in [120.0, 301.0, 640.0, 980.0]) {
          await tester.pumpWidget(MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: SceneView(
                mode: SceneMode.walking,
                distanceM: m,
                nowUtc: DateTime.utc(2026, month, 15, 3),
                position: const LatLng(37.5776, 126.9769),
                onSea: false,
                rules: rules,
                landmarks: landmarks,
                sceneSeed: 'capture-t13',
              ),
            ),
          ));
          bool ready() =>
              find
                  .byWidgetPredicate((w) =>
                      w is CustomPaint &&
                      w.painter is SceneArtPainter &&
                      (w.painter! as SceneArtPainter).art.images.isNotEmpty)
                  .evaluate()
                  .isNotEmpty &&
              find.byType(rive.RiveWidget).evaluate().isNotEmpty;
          for (var i = 0; i < 400 && !ready(); i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
            await tester.pump();
          }
          await tester.pump(const Duration(milliseconds: 300));
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            await File('$dir/walk_${name}_${season}_${m.round()}m.png')
                .writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
