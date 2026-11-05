import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/domain/sky.dart';
import 'package:doobal/ui/scene/scene_art.dart';
import 'package:doobal/ui/scene/scene_art_painter.dart';
import 'package:doobal/ui/scene/scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 배 구간 그림 (M4.5): 뒤판 → 창 불빛 → (정령·동행) → 앞판 → 물결. 판은 모두 같은 자리에 그린다

const _size = Size(390, 844);
const _seoul = LatLng(37.5776, 126.9769);

/// 그린 그림과 자리, 시간대 보정이 칠에 입혀졌는지를 적는 캔버스
class _Canvas implements Canvas {
  final drawn = <({ui.Image image, Rect at, bool tinted})>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      drawn.add((image: image, at: dst, tinted: paint.colorFilter != null));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> _data() =>
    jsonDecode(File('assets/data/scene_art.json').readAsStringSync()) as Map<String, dynamic>;

SceneLook _lookAt(DateTime utc) => sceneLook(utc, _seoul, true, landmarks, rules);

final _noon = _lookAt(DateTime.utc(2026, 7, 15, 3));
final _midnight = _lookAt(DateTime.utc(2026, 7, 15, 15));

_Canvas _paint(SceneArt art, SceneLook look, ScenePass pass, {double elapsed = 0}) {
  final canvas = _Canvas();
  SceneArtPainter(
    art: art,
    look: look,
    mode: SceneMode.walking,
    distanceM: 0,
    rules: rules,
    onSea: true,
    pass: pass,
    elapsed: elapsed,
  ).paint(canvas, _size);
  return canvas;
}

void main() {
  final cruise = boatCatalog.artOf(boatCatalog.byId('boat_cruise')!);

  test('밤낮 표본이 시험하려는 하늘 단계다', () {
    expect(_noon.phase, SkyPhase.day);
    expect(_midnight.phase, SkyPhase.night);
  });

  testWidgets('판 순서와 자리', (tester) async {
    await tester.runAsync(() async {
      final rear = await createTestImage(width: 8, height: 4);
      final front = await createTestImage(width: 8, height: 4);
      final night = await createTestImage(width: 8, height: 4);
      final art = SceneArt(_data(), {}, boat: BoatImages(cruise, rear, front, night));

      // 낮: 뒤판만, 앞판은 정령 위 패스에
      final day = _paint(art, _noon, ScenePass.background);
      expect(day.drawn.map((d) => d.image), [rear]);
      final dayFront = _paint(art, _noon, ScenePass.foreground);
      expect(dayFront.drawn.map((d) => d.image), [front]);

      // 밤: 뒤판 → 창 불빛. 창 불빛은 시간대 보정 밖이다
      final dark = _paint(art, _midnight, ScenePass.background);
      expect(dark.drawn.map((d) => d.image), [rear, night]);
      expect(dark.drawn[0].tinted, isTrue);
      expect(dark.drawn[1].tinted, isFalse);
      final darkFront = _paint(art, _midnight, ScenePass.foreground);
      expect(darkFront.drawn.map((d) => d.image), [front]);
      expect(darkFront.drawn[0].tinted, isTrue);

      // 판은 모두 같은 자리이고, 정령 발이 mainFoot에 닿는다
      final at = dark.drawn[0].at;
      expect(dark.drawn[1].at, at);
      expect(darkFront.drawn[0].at, at);
      final layout = SceneArtLayout(art, _size, SceneMode.walking, true, null);
      final scale = layout.figureHeight / rules.characterCanvasHeightPx;
      expect(at.left + cruise.mainFoot.x * scale, closeTo(layout.foot.dx, 1e-6));
      expect(at.top + cruise.mainFoot.y * scale, closeTo(layout.foot.dy, 1e-6));
      expect(at.width / at.height, closeTo(boatCatalog.canvasWidth / boatCatalog.canvasHeight, 1e-9));
    });
  });

  testWidgets('창 불빛이 없는 배는 밤에도 뒤판만', (tester) async {
    await tester.runAsync(() async {
      final rear = await createTestImage(width: 8, height: 4);
      final front = await createTestImage(width: 8, height: 4);
      final raft = boatCatalog.artOf(boatCatalog.byId('boat_raft')!);
      final art = SceneArt(_data(), {}, boat: BoatImages(raft, rear, front, null));
      expect(_paint(art, _midnight, ScenePass.background).drawn.map((d) => d.image), [rear]);
    });
  });

  testWidgets('판 그림이 없으면 옛 배 한 장을 뒤에 그리고 앞판은 없다', (tester) async {
    await tester.runAsync(() async {
      final legacy = await createTestImage(width: 8, height: 4);
      final art = SceneArt(_data(), {'prop_boat_01_v11_clean.png': legacy});
      expect(_paint(art, _midnight, ScenePass.background).drawn.map((d) => d.image), [legacy]);
      expect(_paint(art, _midnight, ScenePass.foreground).drawn, isEmpty);
    });
  });

  testWidgets('흔들림은 판마다 같고, 값이 없으면 흔들리지 않는다', (tester) async {
    await tester.runAsync(() async {
      final rear = await createTestImage(width: 8, height: 4);
      final front = await createTestImage(width: 8, height: 4);
      final night = await createTestImage(width: 8, height: 4);
      final layers = BoatImages(cruise, rear, front, night);

      final still = SceneArt(_data(), {}, boat: layers);
      expect(
        SceneArtLayout(still, _size, SceneMode.walking, true, null).boatSwayY(1),
        0,
      );

      final data = _data();
      (data['boat'] as Map)
        ..['swayPx'] = 6
        ..['swaySec'] = 4;
      final art = SceneArt(data, {}, boat: layers);
      final layout = SceneArtLayout(art, _size, SceneMode.walking, true, null);
      // 4초 주기의 1초 = 가장 많이 흔들린 때
      final sway = layout.boatSwayY(1);
      expect(sway, closeTo(6 * layout.scale, 1e-9));
      expect(SceneArtLayout(art, _size, SceneMode.walking, false, null).boatSwayY(1), 0);

      final calm = _paint(still, _midnight, ScenePass.background).drawn;
      final back = _paint(art, _midnight, ScenePass.background, elapsed: 1).drawn;
      final fore = _paint(art, _midnight, ScenePass.foreground, elapsed: 1).drawn;
      final moved = calm[0].at.translate(0, sway);
      expect(back[0].at, moved);
      expect(back[1].at, moved);
      expect(fore[0].at, moved);
    });
  });

  group('읽기', () {
    testWidgets('고른 배 파일이 아직 없으면 옛 배로 되돌아간다', (tester) async {
      final art = (await tester.runAsync(
        () => SceneArt.load(rootBundle, _noon, false, 1 / 3, 3, onSea: true, boat: cruise),
      ))!;
      addTearDown(art.dispose);
      expect(art.boat, isNull);
      expect(art.images.containsKey('prop_boat_01_v11_clean.png'), isTrue);
    });

    testWidgets('파일이 있으면 assetPath로 읽고 옛 배는 읽지 않는다', (tester) async {
      final bundle = await tester.runAsync(_BoatBundle.make);
      final art = (await tester.runAsync(
        () => SceneArt.load(bundle!, _noon, false, 1 / 3, 3, onSea: true, boat: cruise),
      ))!;
      addTearDown(art.dispose);
      expect(art.boat, isNotNull);
      expect(art.boat!.art.id, 'boat_cruise');
      expect(art.boat!.night, isNotNull);
      expect(art.images.containsKey('prop_boat_01_v11_clean.png'), isFalse);
      expect(bundle!.asked, containsAll([cruise.rear, cruise.front, cruise.nightOverlay]));
    });

    testWidgets('땅 위와 쉼터에서는 배를 읽지 않는다', (tester) async {
      final bundle = await tester.runAsync(_BoatBundle.make);
      final land = (await tester.runAsync(
        () => SceneArt.load(bundle!, _noon, false, 1 / 3, 3, boat: cruise),
      ))!;
      addTearDown(land.dispose);
      expect(land.boat, isNull);
      expect(bundle!.asked, isNot(contains(cruise.rear)));
      expect(land.images.containsKey('prop_boat_01_v11_clean.png'), isFalse);
    });
  });
}

/// 배 경로에는 작은 PNG를 돌려주고 나머지는 실제 에셋
class _BoatBundle extends AssetBundle {
  _BoatBundle(this.png);

  final ByteData png;
  final asked = <String>{};

  static Future<_BoatBundle> make() async {
    final image = await createTestImage(width: 8, height: 4);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return _BoatBundle(bytes!);
  }

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    return key.startsWith('assets/boats/') ? png : rootBundle.load(key);
  }
}
