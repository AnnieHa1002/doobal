import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/domain/scene_plan.dart';
import 'package:doobal/ui/scene/scene_art.dart';
import 'package:doobal/ui/scene/scene_art_painter.dart';
import 'package:doobal/ui/scene/scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 16장 11/19 Annie: 장면 물체는 어떤 경우에도 투명하게 하지 않는다 (④), 뒤쪽 줄 나무 발은 들판 선에 (⑤)

/// 그린 그림·자리·칠의 불투명도를 적는 캔버스
class _Canvas implements Canvas {
  final drawn = <({ui.Image image, Rect at, double alpha})>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      drawn.add((image: image, at: dst, alpha: paint.color.a));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final _scene = _json('assets/data/scene.json');
final _plan = ScenePlan.fromJson(_scene);

/// 가을 서울 (키 큰 은행나무·단풍나무가 선다)
final _autumn = sceneLook(DateTime.utc(2026, 10, 15, 3), const LatLng(37.5776, 126.9769), false, landmarks, rules);

void main() {
  test('scene.json: 흐리기 키가 없고, 뒤쪽 줄 발은 들판 선(meadow.portraitY)', () {
    final roadside = (_scene['layout'] as Map)['roadside'] as Map;
    expect(roadside.containsKey('tallNearCharacterOpacity'), isFalse);
    expect(roadside.containsKey('tallFadePx'), isFalse);
    final meadowY = ((_scene['meadow'] as Map)['portraitY'] as num).toDouble();
    expect(meadowY, 1880);
    expect(_plan.back.feetY, meadowY);
    // scene_art.json의 세로 들판 윗선도 같은 값
    expect((_json('assets/data/scene_art.json')['portrait'] as Map)['meadowY'], meadowY);
  });

  group('줄 발 자리 (SceneArtLayout.rowFeetY)', () {
    final art = SceneArt(_json('assets/data/scene_art.json'), {}, plan: _plan);
    for (final size in [const Size(360, 880), const Size(390, 844), const Size(880, 360), const Size(844, 390)]) {
      test('$size: 뒤쪽 줄은 들판 윗선, 군락·앞쪽 줄은 땅 기준 (가로는 땅 그림을 줄인 만큼)', () {
        final layout = SceneArtLayout(art, size, SceneMode.walking, false, null);
        expect(layout.rowFeetY(SceneRow.back, _plan.back.feetY), closeTo(layout.y(layout.n('meadowY')), 1e-9));
        final groundP = (art.data['portrait'] as Map)['groundY'] as num;
        for (final row in [SceneRow.grove, SceneRow.front]) {
          final feet = _plan.spec(row).feetY;
          expect(
            layout.rowFeetY(row, feet),
            closeTo(layout.y(layout.n('groundY') + (feet - groundP) * layout.groundScale), 1e-9),
          );
        }
        // 뒤쪽 줄 발은 앞쪽 줄 발보다 위(먼 곳), 땅(길)보다 위
        expect(layout.rowFeetY(SceneRow.back, _plan.back.feetY), lessThan(layout.rowFeetY(SceneRow.front, _plan.front.feetY)));
      });
    }
  });

  testWidgets('키 큰 조각이 정령 뒤를 지날 때도 모든 조각을 불투명하게 그린다 (세로·가로)', (tester) async {
    await tester.runAsync(() async {
      final data = _json('assets/data/scene_art.json');
      final keys = <String>{};
      for (final row in SceneRow.values) {
        for (final p in _plan.eligible(row, _autumn.backdrop, _autumn.season.name)) {
          final key = SceneArt(data, {}, plan: _plan).assetKeyOf(p.file);
          if (key != null) keys.add(key);
        }
      }
      final images = {for (final k in keys) k: await createTestImage(width: 16, height: 16)};
      final tallImages = {
        for (final p in _plan.roadsidePieces)
          if (p.tall && images[SceneArt(data, {}, plan: _plan).assetKeyOf(p.file)] != null)
            images[SceneArt(data, {}, plan: _plan).assetKeyOf(p.file)]!,
      };
      expect(tallImages, isNotEmpty);
      final art = SceneArt(data, images, plan: _plan);
      for (final size in [const Size(360, 880), const Size(880, 360)]) {
        final layout = SceneArtLayout(art, size, SceneMode.walking, false, null);
        final zone = Rect.fromCenter(center: layout.foot, width: layout.figureHeight * 0.5, height: layout.figureHeight);
        final feetYs = {
          for (final row in SceneRow.values) layout.rowFeetY(row, _plan.spec(row).feetY).toStringAsFixed(3),
        };
        var tallBehind = 0;
        for (var m = 0.0; m <= 3000; m += 25) {
          final canvas = _Canvas();
          SceneArtPainter(
            art: art,
            look: _autumn,
            mode: SceneMode.walking,
            distanceM: m,
            rules: rules,
            onSea: false,
            pass: ScenePass.background,
            elapsed: 0,
            seed: 'rows-test',
          ).paint(canvas, size);
          for (final d in canvas.drawn) {
            if (!images.values.contains(d.image)) continue;
            expect(d.alpha, 1.0, reason: '$size ${m}m');
            expect(feetYs, contains(d.at.bottom.toStringAsFixed(3)), reason: '$size ${m}m: 줄 발 자리');
            if (tallImages.contains(d.image) && d.at.overlaps(zone)) tallBehind++;
          }
        }
        // 키 큰 조각이 정령 상자 뒤를 지나는 장면을 실제로 거쳤다
        expect(tallBehind, greaterThan(0), reason: '$size');
      }
      art.dispose();
    });
  });
}
