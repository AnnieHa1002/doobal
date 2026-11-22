import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/app/sync_service.dart' show MapData;
import 'package:doobal/domain/geo.dart';
import 'package:doobal/ui/common/trail_pattern_paint.dart';
import 'package:doobal/ui/map/map_geometry.dart';
import 'package:doobal/ui/map/map_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

/// 지도 물감 길 무늬 그림(발자국·꽃잎·별가루, 11/22 그림 넣기)을 눈으로 볼 때만 도는 시험.
/// 그림을 [DOOBAL_MAP_TRAIL_CAPTURE_DIR]에 PNG로 남긴다 (지도 화면 390×487.5pt, 2배)
void main() {
  final dir = Platform.environment['DOOBAL_MAP_TRAIL_CAPTURE_DIR'];

  testWidgets('지도 무늬 찍기', skip: dir == null, (tester) async {
    await tester.runAsync(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // 앱과 같은 길: AssetIndex.sprite로 assets/ui/의 tile·cap을 찾아 읽는다
      final art = await container.read(trailArtProvider.future);
      expect(art.images.keys, containsAll(['trail_01', 'trail_02', 'trail_03']));

      final geometry = MapGeometry(projection: mapProjection, regions: mapRegions, landmarks: landmarks);
      const view = Size(390, 487.5);

      // 따로 된 네 줄(무늬마다 한 줄, 가운데 굽이) + 이어진 한 줄(무늬가 바뀌는 곳, 급한 굽이)
      List<LatLng> row(double lat) =>
          [LatLng(lat, 126.85), LatLng(lat + 0.06, 127.2), LatLng(lat - 0.04, 127.55), LatLng(lat, 127.85)];
      final rows = [for (final lat in [37.98, 37.82, 37.66, 37.50]) row(lat)];
      const zig = [
        [LatLng(37.05, 126.85), LatLng(37.30, 127.05)],
        [LatLng(37.30, 127.05), LatLng(37.08, 127.30)],
        [LatLng(37.08, 127.30), LatLng(37.30, 127.55)],
        [LatLng(37.30, 127.55), LatLng(37.08, 127.85)],
      ];
      final data = MapData(
        visited: const {},
        paths: [...rows, [for (final s in zig) ...s]],
        destId: null,
        position: null,
        fundKm: 0,
        paintLines: [...rows, ...zig],
        paintLineColors: const ['basic', 'sunset', 'morning', 'night', 'basic', 'sunset', 'dawn', 'rain'],
        paintLinePatterns: const [null, 'trail_01', 'trail_02', 'trail_03', null, 'trail_01', 'trail_02', 'trail_03'],
        paintLineJoined: const [false, false, false, false, false, true, true, true],
      );

      Future<void> shot(String name, double zoom, LatLng focus) async {
        final painter = MapPainter(
          geometry: geometry,
          data: data,
          selectedId: null,
          zoom: zoom,
          trail: rules.mapTrail,
          palette: rules.paintColor,
          style: rules.mapAlbum.map,
          patterns: rules.paintPattern,
          patternArt: art,
        );
        const ratio = 2.0;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..scale(ratio)
          ..drawRect(Offset.zero & view, Paint()..color = const Color(0xFFF3E9D2))
          ..clipRect(Offset.zero & view);
        // 뷰어처럼: [focus]를 화면 가운데에 두고 zoom배
        final base = geometry.baseScale(view.width);
        final p = mapProjection.project(focus);
        canvas
          ..translate(view.width / 2 - p.x * base * zoom, view.height / 2 - p.y * base * zoom)
          ..scale(zoom);
        painter.paint(canvas, view);
        final image = await recorder.endRecording().toImage(
              (view.width * ratio).round(),
              (view.height * ratio).round(),
            );
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        image.dispose();
      }

      await shot('map_trail_zoom5', 5, const LatLng(37.52, 127.35));
      await shot('map_trail_zoom2', 2, const LatLng(37.5, 127.4));
    });
  });
}
