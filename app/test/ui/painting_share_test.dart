import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/ui/album/painting_detail_screen.dart';
import 'package:doobal/ui/album/painting_share.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

OwnedPaintingView _view(String id, {bool first = false}) => OwnedPaintingView(
      landmark: first ? firstPackLandmark : landmarks.firstWhere((l) => l.id == id),
      visits: 1,
      frame: Frame.wood,
      bestKm: 1,
      firstArrivedAt: t1,
      lastArrivedAt: t1,
      isFirstPack: first,
    );

final _share = find.widgetWithText(GameButton, '공유');

/// PNG 머리말의 가로·세로(IHDR). PNG가 아니면 null
(int, int)? _pngSize(Uint8List b) {
  const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length < 24) return null;
  for (var i = 0; i < magic.length; i++) {
    if (b[i] != magic[i]) return null;
  }
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

/// PNG를 풀어 (x, y) 픽셀의 색(불투명 RGB)을 돌려준다
Future<Color> _pixel(WidgetTester tester, Uint8List png, int x, int y) async {
  final bytes = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final w = image.width;
    image.dispose();
    codec.dispose();
    return (data, w);
  });
  final (data, w) = bytes!;
  final i = (y * w + x) * 4;
  return Color.fromARGB(
      data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

/// 그림 상세를 앱 첫 화면 위에 열고 그림이 보일 때까지
Future<void> _open(WidgetTester tester, UiEnv e, String id, String paintingKey) async {
  await openOnTop(tester, e, PaintingDetailScreen(landmarkId: id),
      ready: () => find.byKey(ValueKey(paintingKey)).evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 6);
}

/// 이미지를 뜨는 것(toImage)은 실제 시간이 걸려서 실제 비동기를 기다리며 화면을 갱신한다
Future<void> _waitFor(WidgetTester tester, bool Function() done) =>
    settle(tester, done, tries: 80);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('공유 글·파일 이름', () {
    test('명소 그림: 이름이 들어간 글과 `<명소 이름>.png`', () {
      final p = _view('kr001');
      expect(paintingShareText(p), '두발에서 걸어서 얻은 그림: 경복궁');
      expect(paintingShareFileName(p), '경복궁.png');
    });

    test('첫 그림: `두발 첫 그림: 첫 여행 짐 꾸러미`와 `첫 그림.png`', () {
      final p = _view(sketchId, first: true);
      expect(paintingShareText(p), '두발 첫 그림: 첫 여행 짐 꾸러미');
      expect(paintingShareFileName(p), '첫 그림.png');
    });

    test('명소 101곳 모두 파일 이름에 못 쓰는 글자가 없다 (·와 공백은 그대로)', () {
      expect(landmarks, hasLength(101));
      for (final l in landmarks) {
        final name = paintingShareFileName(_view(l.id));
        expect(name, '${l.name}.png');
        expect(name, isNot(matches(RegExp(r'[\\/:*?"<>|]'))), reason: l.name);
      }
      expect(paintingShareFileName(_view('kr002')), '인천 차이나타운·월미도.png');
    });
  });

  group('그림 상세의 공유 버튼', () {
    Future<UiEnv> seeded(WidgetTester tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.insertArrival('j1', 'kr001', DateTime.utc(2026, 11, 17, 16), km: 12.34);
      });
      return e;
    }

    testWidgets('보조 버튼 "공유"가 그림·방문 기록 아래 맨 끝에 있다', (tester) async {
      final e = await seeded(tester);
      await _open(tester, e, 'kr001', 'detail-painting');

      expect(_share, findsOneWidget);
      expect(tester.widget<GameButton>(_share).kind, GameButtonKind.secondary);
      expect(tester.widget<GameButton>(_share).onPressed, isNotNull);
      final visits = find.text('1번째 방문 · 12.3 km · 11월 18일');
      expect(tester.getTopLeft(_share).dy, greaterThan(tester.getBottomLeft(visits).dy));
      // 아직 누르지 않았으니 공유한 것이 없다
      expect(e.sharer.calls, isEmpty);
      await end(tester, e);
    });

    testWidgets('누르면 액자 낀 그림을 PNG로 떠서 파일 이름·글과 함께 공유한다', (tester) async {
      final e = await seeded(tester);
      await _open(tester, e, 'kr001', 'detail-painting');

      await tester.tap(_share);
      await _waitFor(tester, () => e.sharer.calls.isNotEmpty);

      expect(e.sharer.calls, hasLength(1));
      final c = e.sharer.calls.single;
      expect(c.png, isNotEmpty);
      // 액자 300×225에 종이색 여백 8을 두른 316×241을 3배로 그린다
      expect(_pngSize(c.png), (948, 723));
      expect(c.fileName, '경복궁.png');
      expect(c.text, '두발에서 걸어서 얻은 그림: 경복궁');
      // iPad용 자리: 누른 버튼의 화면 좌표
      expect(c.origin, tester.getRect(_share));
      await end(tester, e);
    });

    testWidgets('뜬 이미지는 비어 있지 않다: 모서리는 종이색 여백, 여백 안쪽은 액자 잉크선이다', (tester) async {
      final e = await seeded(tester);
      await _open(tester, e, 'kr001', 'detail-painting');
      await tester.tap(_share);
      await _waitFor(tester, () => e.sharer.calls.isNotEmpty);
      final png = e.sharer.calls.single.png;

      // 3배: 여백 8 → 24px, 액자 바깥 잉크선(2)은 그 안쪽 6px
      final corner = await _pixel(tester, png, 2, 2);
      expect(corner, Palette.paper);
      final line = await _pixel(tester, png, 474, 24 + 3);
      expect(line, Palette.ink);
      // 한가운데는 그림 자리(종이도 잉크도 아닌 색)
      final center = await _pixel(tester, png, 474, 361);
      expect(center, isNot(Palette.paper));
      expect(center, isNot(Palette.ink));
      await end(tester, e);
    });

    testWidgets('첫 그림 상세에도 같은 버튼이 있고 첫 그림 글·이름으로 공유한다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await _open(tester, e, sketchId, 'detail-first-pack');

      expect(_share, findsOneWidget);
      await tester.tap(_share);
      await _waitFor(tester, () => e.sharer.calls.isNotEmpty);

      final c = e.sharer.calls.single;
      expect(_pngSize(c.png), (948, 723));
      expect(c.fileName, '첫 그림.png');
      expect(c.text, '두발 첫 그림: 첫 여행 짐 꾸러미');
      expect(c.origin, tester.getRect(_share));
      await end(tester, e);
    });

    testWidgets('이미지를 뜨는 동안 또 눌러도 한 번만 공유하고, 끝나면 다시 누를 수 있다', (tester) async {
      final e = await seeded(tester);
      await _open(tester, e, 'kr001', 'detail-painting');

      await tester.tap(_share);
      await tester.pump();
      // 공유가 끝나기 전에는 버튼이 꺼져 있다
      expect(tester.widget<GameButton>(_share).onPressed, isNull);
      await tester.tap(_share, warnIfMissed: false);
      await _waitFor(tester, () => e.sharer.calls.isNotEmpty);
      await settle(tester, () => false, tries: 6);

      expect(e.sharer.calls, hasLength(1));
      expect(tester.widget<GameButton>(_share).onPressed, isNotNull);
      await tester.tap(_share);
      await _waitFor(tester, () => e.sharer.calls.length == 2);
      expect(e.sharer.calls, hasLength(2));
      await end(tester, e);
    });

    testWidgets('공유 시트를 열지 못하면 토스트로 알리고 화면은 그대로다', (tester) async {
      final e = await seeded(tester);
      e.sharer.fail = true;
      await _open(tester, e, 'kr001', 'detail-painting');

      await tester.tap(_share);
      await _waitFor(tester, () => find.text('그림을 공유하지 못했어요').evaluate().isNotEmpty);

      expect(find.text('그림을 공유하지 못했어요'), findsOneWidget);
      expect(find.byType(PaintingDetailScreen), findsOneWidget);
      expect(e.sharer.calls, hasLength(1));
      expect(tester.widget<GameButton>(_share).onPressed, isNotNull);
      await end(tester, e);
    });
  });
}
