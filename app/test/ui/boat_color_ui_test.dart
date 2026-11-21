import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/app/boat_providers.dart';
import 'package:doobal/app/shop_providers.dart';
import 'package:doobal/app/sync_service.dart' show ShopSync;
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/ui/boat/boat_art_loader.dart';
import 'package:doobal/ui/scene/scene_art.dart';
import 'package:doobal/ui/shop/shop_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:doobal/ui/common/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart' show boatCatalog, landmarks, rules, spiritPalette;
import 'ui_env.dart';

// 상점 배 색 (T4c): 색 입힌 배 판 읽기(장면·미리보기 같이 씀), 장면과 미리보기 색이 같은가, 색 시트·저장.
// 배 그림은 아직 리포에 없어(Drive 허락 전) 작은 가짜 그림(96×48, 배 캔버스 3072×1536과 같은 2:1)을 번들로 넣는다

final _captureDir = Platform.environment['DOOBAL_BOAT_CAPTURE_DIR'];

const _w = 96;
const _h = 48;
const _terracotta = Color(0xFFC9775A);
const _navy = Color(0xFF7F8DB3);

/// 배 그림을 흉내 내는 번들: [files]에 있는 경로는 그 PNG, 나머지는 앱 번들
class _FakeBoats extends CachingAssetBundle {
  _FakeBoats(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<ByteData> load(String key) async {
    if (files[key] case final f?) return ByteData.sublistView(f);
    return rootBundle.load(key);
  }
}

/// [_w]×[_h] PNG에 [rects](자리, 색)를 칠한다
Future<Uint8List> _png(List<(Rect, Color)> rects) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  for (final (r, color) in rects) {
    c.drawRect(r, Paint()..color = color);
  }
  final image = await rec.endRecording().toImage(_w, _h);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}

/// 그림의 (x, y) 곧은 색
Future<Color> _at(ui.Image image, double fx, double fy) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  final x = (fx * image.width).floor();
  final y = (fy * image.height).floor();
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

bool _near(Color a, Color b, [int tol = 3]) =>
    (a.a * 255 - b.a * 255).abs() <= tol &&
    (a.r * 255 - b.r * 255).abs() <= tol &&
    (a.g * 255 - b.g * 255).abs() <= tol &&
    (a.b * 255 - b.b * 255).abs() <= tol;

const _body = Rect.fromLTWH(0, 24, 96, 24);
const _left = Rect.fromLTWH(0, 24, 48, 24);
const _right = Rect.fromLTWH(48, 24, 48, 24);
const _frontBody = Rect.fromLTWH(0, 36, 96, 12);
const _stripe = Rect.fromLTWH(0, 24, 8, 24);
const _gray192 = Color(0xFFC0C0C0);
const _gray125 = Color(0xFF7D7D7D);

/// 차양 보트(premium_01, materialIds) 그림 묶음: 뒤판 몸 (40,60,80), 앞판 띠 (200,200,200), 뒤판 왼쪽 8px 고정 층(검정),
/// 뒤판 선체 shading = 왼쪽 반, 지붕 = 오른쪽 반, 앞판 선체 shading = 띠 전체 (회색 192)
Future<Map<String, Uint8List>> _canopyFiles() async {
  final boat = boatCatalog.byId('boat_canopy')!;
  final dir = boatCatalog.assetPath(boat.recolor!.dir);
  const clear = <(Rect, Color)>[];
  return {
    boatCatalog.assetPath(boat.layers.rear): await _png([(_body, const Color(0xFF283C50))]),
    boatCatalog.assetPath(boat.layers.front): await _png([(_frontBody, const Color(0xFFC8C8C8))]),
    '${dir}rear_fixed.png': await _png([(_stripe, const Color(0xFF141414))]),
    '${dir}front_fixed.png': await _png(clear),
    '${dir}rear_hull_shading.png': await _png([(_left, _gray192)]),
    '${dir}rear_upper_shading.png': await _png([(_right, _gray192)]),
    '${dir}rear_accent_shading.png': await _png(clear),
    '${dir}front_hull_shading.png': await _png([(_frontBody, _gray192)]),
    '${dir}front_upper_shading.png': await _png(clear),
    '${dir}front_accent_shading.png': await _png(clear),
  };
}

/// 유람선(theme_01, meanLuminance) 그림 묶음 (가안 이름): 뒤판·앞판 원래 그림, 판 공통 중립(회색 125)·구역 마스크
/// (선체 = 왼쪽 반, 지붕 = 오른쪽 반, 흰 마스크)
Future<Map<String, Uint8List>> _cruiseFiles() async {
  final boat = boatCatalog.byId('boat_cruise')!;
  final dir = boatCatalog.assetPath(boat.recolor!.dir);
  return {
    boatCatalog.assetPath(boat.layers.rear): await _png([(_body, const Color(0xFF688D83))]),
    boatCatalog.assetPath(boat.layers.front): await _png([(_frontBody, const Color(0xFF61877E))]),
    '${dir}neutral.png': await _png([(_body, _gray125)]),
    '${dir}hull_mask.png': await _png([(_left, const Color(0xFFFFFFFF))]),
    '${dir}upper_mask.png': await _png([(_right, const Color(0xFFFFFFFF))]),
    '${dir}accent_mask.png': await _png(const []),
  };
}

BoatArt _art(String id, BoatColors colors) => boatCatalog.artOf(
      boatCatalog.byId(id)!,
      colors: colors,
      argb: boatZoneArgb(colors, spiritPalette.body.argbOf),
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(clearBoatLayerCache);

  group('색 입힌 배 판 읽기 (loadBoatLayers)', () {
    testWidgets('premium(materialIds): 고른 구역만 색, 고르지 않은 구역·고정 층은 원래 그림', (tester) async {
      await tester.runAsync(() async {
        final bundle = _FakeBoats(await _canopyFiles());
        const colors = BoatColors({BoatZone.hull: SwatchBodyColor(9)});
        final l = (await loadBoatLayers(bundle, _art('boat_canopy', colors), _w))!;
        expect((l.rear.width, l.rear.height), (_w, _h));
        expect(_near(await _at(l.rear, .25, .75), _terracotta), isTrue, reason: '${await _at(l.rear, .25, .75)}');
        expect(_near(await _at(l.rear, .75, .75), const Color(0xFF283C50)), isTrue);
        expect(_near(await _at(l.rear, .02, .75), const Color(0xFF141414)), isTrue);
        expect((await _at(l.rear, .5, .2)).a, 0);
        expect(_near(await _at(l.front, .5, .9), _terracotta), isTrue);
        l.rear.dispose();
        l.front.dispose();
      });
    });

    testWidgets('theme(meanLuminance): 중립 = 구역 평균 밝기인 곳은 고른 색 그대로, 마스크 밖은 원래 그림', (tester) async {
      await tester.runAsync(() async {
        final bundle = _FakeBoats(await _cruiseFiles());
        const colors = BoatColors({BoatZone.upper: SwatchBodyColor(10)});
        final l = (await loadBoatLayers(bundle, _art('boat_cruise', colors), _w))!;
        expect(_near(await _at(l.rear, .75, .75), _navy), isTrue, reason: '${await _at(l.rear, .75, .75)}');
        expect(_near(await _at(l.rear, .25, .75), const Color(0xFF688D83)), isTrue);
        // 앞판은 판 공통 마스크를 같이 쓴다 (오른쪽 반 지붕)
        expect(_near(await _at(l.front, .75, .9), _navy), isTrue);
        expect(_near(await _at(l.front, .25, .9), const Color(0xFF61877E)), isTrue);
        expect(l.night, isNull);
        l.rear.dispose();
        l.front.dispose();
      });
    });

    testWidgets('고른 색이 없거나 색 층 그림이 없으면 원래 그림 그대로, 배 그림이 없으면 null', (tester) async {
      await tester.runAsync(() async {
        final files = await _canopyFiles();
        final plain = (await loadBoatLayers(_FakeBoats(files), _art('boat_canopy', BoatColors.none), _w))!;
        expect(_near(await _at(plain.rear, .25, .75), const Color(0xFF283C50)), isTrue);
        // 색 층 하나가 빠지면 (받기 전) 원래 그림
        files.removeWhere((k, _) => k.endsWith('rear_upper_shading.png'));
        const colors = BoatColors({BoatZone.hull: SwatchBodyColor(9)});
        final missing = (await loadBoatLayers(_FakeBoats(files), _art('boat_canopy', colors), _w))!;
        expect(_near(await _at(missing.rear, .25, .75), const Color(0xFF283C50)), isTrue);
        // 지금 리포처럼 배 그림이 아예 없으면 null (장면은 옛 배 한 장, 미리보기는 점선 칸)
        expect(await loadBoatLayers(rootBundle, _art('boat_canopy', colors), _w), isNull);
        for (final i in [plain.rear, plain.front, missing.rear, missing.front]) {
          i.dispose();
        }
      });
    });
  });

  testWidgets('장면(배 구간)과 색 시트 미리보기가 같은 색: 같은 읽기를 크기만 달리해 쓴다', (tester) async {
    await tester.runAsync(() async {
      final bundle = _FakeBoats(await _canopyFiles());
      const colors = BoatColors({BoatZone.hull: SwatchBodyColor(9), BoatZone.upper: CustomBodyColor('#335577')});
      final art = _art('boat_canopy', colors);
      final look = sceneLook(DateTime.utc(2026, 7, 15, 3), const LatLng(33.5, 126.5), true, landmarks, rules);
      final scene = await SceneArt.load(bundle, look, false, 844 / 2532, 1, onSea: true, boat: art);
      final preview = (await loadBoatLayers(bundle, art, 450))!;
      try {
        final sceneRear = scene.boat!.rear;
        for (final (fx, fy) in [(.25, .75), (.75, .75), (.02, .75)]) {
          final a = await _at(sceneRear, fx, fy);
          final b = await _at(preview.rear, fx, fy);
          expect(_near(a, b), isTrue, reason: '($fx, $fy) 장면 $a / 미리보기 $b');
        }
        expect(_near(await _at(sceneRear, .25, .75), _terracotta), isTrue);
        expect(_near(await _at(sceneRear, .75, .75), const Color(0xFF335577)), isTrue);
        expect(_near(await _at(scene.boat!.front, .5, .9), await _at(preview.front, .5, .9)), isTrue);
      } finally {
        scene.dispose();
        preview.rear.dispose();
        preview.front.dispose();
      }
    });
  });

  group('색 시트 (캔버스 8-1 가진 배 · 색 바꾸기)', () {
    Future<UiEnv> seeded(WidgetTester tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.db.into(e.db.boatsOwned).insert(BoatsOwnedCompanion.insert(boatId: 'boat_cruise', atUtc: 1));
      });
      return e;
    }

    Future<void> openShop(WidgetTester tester, UiEnv e, Map<String, Uint8List> files) async {
      phone(tester);
      await tester.pumpWidget(DefaultAssetBundle(
        bundle: _FakeBoats(files),
        child: ProviderScope(
          overrides: e.overrides,
          child: const MaterialApp(home: ShopScreen()),
        ),
      ));
      await settle(tester, () => find.byKey(const ValueKey('owned-boat-boat_cruise')).evaluate().isNotEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('owned-boat-boat_cruise')));
      await tester.pump();
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('owned-boat-boat_cruise')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('owned-boat-boat_cruise')));
      await settle(tester, () => find.byKey(const ValueKey('boat-swatch-9')).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('boat-swatch-9')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<String?> saved(WidgetTester tester, UiEnv e) async => (await tester.runAsync(() =>
            (e.db.select(e.db.boatsOwned)..where((t) => t.boatId.equals('boat_cruise'))).getSingle()))!
        .colors;

    testWidgets('알약을 누르면 시트: 미리보기·고른 색 점·구역 탭·견본 12(기본 + 10 + 직접), 처음은 모두 기본', (tester) async {
      final e = await seeded(tester);
      await openShop(tester, e, await tester.runAsync(_cruiseFiles) ?? {});
      await openSheet(tester);

      expect(find.text('유람선 색'), findsOneWidget);
      for (final z in ['선체', '지붕·좌석', '장식 천']) {
        expect(find.text('$z 기본'), findsOneWidget, reason: z);
      }
      expect(find.byKey(const ValueKey('boat-swatch-original')), findsOneWidget);
      for (var i = 1; i <= 10; i++) {
        expect(find.byKey(ValueKey('boat-swatch-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('boat-swatch-custom')), findsOneWidget);
      expect(find.byKey(const ValueKey('boat-zone-hull')), findsOneWidget);
      // 원래 색이면 되돌리기 단추가 없다
      expect(find.byKey(const ValueKey('boat-color-reset')), findsNothing);
      // 미리보기는 가짜 그림으로 그린다 (점선 칸이 아님)
      await settle(tester, () => find.bySemanticsLabel('유람선 미리보기').evaluate().isNotEmpty);
      expect(find.bySemanticsLabel('유람선 미리보기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('견본·직접 고르기 → 저장하면 BoatsOwned.colors, 토스트, 장면 배에 그 색', (tester) async {
      final e = await seeded(tester);
      await tester.runAsync(() => e.svc.chooseBoat('boat_cruise'));
      await openShop(tester, e, await tester.runAsync(_cruiseFiles) ?? {});
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('boat-swatch-9')));
      await tester.pump();
      expect(find.text('선체 테라코타'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('boat-zone-upper')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('boat-swatch-custom')));
      await tester.tap(find.byKey(const ValueKey('boat-swatch-custom')));
      await tester.pump();
      expect(find.text('지붕·좌석 직접'), findsOneWidget);
      expect(find.text('직접 고른 색 #C9775A'), findsOneWidget);
      expect(find.byKey(const ValueKey('boat-color-reset')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('boat-color-save')));
      await tester.tap(find.byKey(const ValueKey('boat-color-save')));
      await settle(tester, () => find.text('유람선 색을 바꿨어요').evaluate().isNotEmpty);
      expect(find.text('유람선 색을 바꿨어요'), findsOneWidget);
      expect(await saved(tester, e),
          '{"hull":{"kind":"swatch","i":9},"upper":{"kind":"custom","hex":"#C9775A"}}');
      // 걷는 중 배 구간이 읽는 배에 고른 색
      final c = ProviderScope.containerOf(tester.element(find.byType(ShopScreen)));
      final scene = c.listen(sceneBoatProvider, (_, _) {});
      final stored = c.listen(boatColorsProvider('boat_cruise'), (_, _) {});
      await settle(tester, () => scene.read().value?.colors.isNotEmpty ?? false);
      final art = scene.read().value!;
      expect(art.id, 'boat_cruise');
      expect(art.colors, {BoatZone.hull: 0xFFC9775A, BoatZone.upper: 0xFFC9775A});
      await settle(tester, () => stored.read().hasValue);
      expect(stored.read().value!.encode(), await saved(tester, e));
      scene.close();
      stored.close();
      await end(tester, e);
    });

    testWidgets('원래 색으로 되돌리기 → 저장하면 null, 취소하면 아무것도 안 바뀐다', (tester) async {
      final e = await seeded(tester);
      await tester.runAsync(() => (e.db.update(e.db.boatsOwned)..where((t) => t.boatId.equals('boat_cruise')))
          .write(const BoatsOwnedCompanion(colors: Value('{"accent":{"kind":"swatch","i":2}}'))));
      await openShop(tester, e, await tester.runAsync(_cruiseFiles) ?? {});
      await openSheet(tester);
      expect(find.text('장식 천 살구'), findsOneWidget);

      // 취소: 바꾼 것을 버린다
      await tester.tap(find.byKey(const ValueKey('boat-swatch-5')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('boat-color-cancel')));
      await tester.tap(find.byKey(const ValueKey('boat-color-cancel')));
      await settle(tester, () => find.text('유람선 색').evaluate().isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(await saved(tester, e), '{"accent":{"kind":"swatch","i":2}}');

      await openSheet(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('boat-color-reset')));
      await tester.tap(find.byKey(const ValueKey('boat-color-reset')));
      await tester.pump();
      expect(find.text('장식 천 기본'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('boat-color-save')));
      await tester.tap(find.byKey(const ValueKey('boat-color-save')));
      await settle(tester, () => find.text('유람선 색을 바꿨어요').evaluate().isNotEmpty);
      expect(await saved(tester, e), isNull);
      await end(tester, e);
    });

    testWidgets('배 그림이 아직 없으면 미리보기는 점선 칸 + 이름, 고른 색 점은 그대로', (tester) async {
      final e = await seeded(tester);
      await openShop(tester, e, const {});
      await openSheet(tester);
      await settle(tester, () => find.byKey(const ValueKey('item-placeholder')).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('item-placeholder')), findsOneWidget);
      expect(find.text('선체 기본'), findsOneWidget);
      await end(tester, e);
    });
  });

  testWidgets('색 시트 찍기 (DOOBAL_BOAT_CAPTURE_DIR가 있을 때만)', skip: _captureDir == null, (tester) async {
    await tester.runAsync(() async {
      Future<ByteData> font(String name) async =>
          ByteData.sublistView(await File('assets/fonts/$name.ttf').readAsBytes());
      await (FontLoader(bodyFont)
            ..addFont(font('NotoSansKR-Regular'))
            ..addFont(font('NotoSansKR-SemiBold'))
            ..addFont(font('NotoSansKR-Bold')))
          .load();
    });
    final e = UiEnv();
    await e.seed(tester, () async {
      await e.db.into(e.db.boatsOwned).insert(BoatsOwnedCompanion.insert(boatId: 'boat_cruise', atUtc: 1));
    });
    final files = await tester.runAsync(_cruiseFiles) ?? {};
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: DefaultAssetBundle(
        bundle: _FakeBoats(files),
        child: ProviderScope(
          overrides: e.overrides,
          child: MaterialApp(theme: ThemeData(fontFamily: bodyFont), home: const ShopScreen()),
        ),
      ),
    ));
    await settle(tester, () => find.byKey(const ValueKey('owned-boat-boat_cruise')).evaluate().isNotEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('owned-boat-boat_cruise')));
    await tester.pump();
    Future<void> shot(String name) async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$_captureDir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.byKey(const ValueKey('owned-boat-boat_cruise')));
    await settle(tester, () => find.byKey(const ValueKey('boat-swatch-9')).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    await shot('boat_sheet_original');
    await tester.tap(find.byKey(const ValueKey('boat-swatch-9')));
    await tester.tap(find.byKey(const ValueKey('boat-zone-upper')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('boat-swatch-custom')));
    await tester.pump();
    await shot('boat_sheet_picked');
    await end(tester, e);
  });
}
