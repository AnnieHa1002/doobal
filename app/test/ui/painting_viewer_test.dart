import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/data/painting_saver.dart';
import 'package:doobal/ui/album/painting_viewer.dart';
import 'package:doobal/ui/common/framed_painting.dart';
import 'package:doobal/ui/album/painting_share.dart';
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

BigPainting _big(String id, {Frame frame = Frame.wood}) =>
    BigPainting(landmark: landmarks.firstWhere((l) => l.id == id), frame: frame);

const _firstPack = BigPainting(landmark: firstPackLandmark, frame: Frame.wood, isFirstPack: true);

Finder _key(String k) => find.byKey(ValueKey(k));

/// 크게 보기를 앱 첫 화면 위에 열고 그림이 보일 때까지
Future<void> _open(WidgetTester tester, UiEnv e, List<BigPainting> items, {int index = 0}) async {
  await openOnTop(tester, e, PaintingViewer(items: items, initialIndex: index),
      ready: () => _key('viewer-painting-${items[index].landmark.id}').evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 6);
}

/// 이미지를 뜨는 것(toImage)은 실제 시간이 걸려서 실제 비동기를 기다리며 화면을 갱신한다
Future<void> _waitFor(WidgetTester tester, bool Function() done) =>
    settle(tester, done, tries: 80);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('공유 글·파일 이름 (저장 이름은 확장자 없이 같은 이름)', () {
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

  group('그림 크게 보기 (16장 11/10, 캔버스 6-1·3-2)', () {
    testWidgets('검은 바탕에 액자 그림만, 화면 글 없음. 위 왼쪽 저장·오른쪽 닫기 (44pt)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, [_big('kr001', frame: Frame.gold)]);

      expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, const Color(0xFF1E1611));
      final framed = tester.widget<FramedPainting>(
          find.descendant(of: _key('viewer-painting-kr001'), matching: find.byType(FramedPainting)));
      expect((framed.landmark!.id, framed.frame, framed.thickness, framed.fullSize), ('kr001', Frame.gold, 12, true));
      final viewer = find.byType(PaintingViewer);
      expect(find.descendant(of: viewer, matching: find.byType(Text)), findsNothing);
      final save = tester.getRect(_key('viewer-save'));
      final close = tester.getRect(_key('viewer-close'));
      expect(save.left, lessThan(close.left));
      expect(save.top, close.top);
      expect((save.width >= 44, save.height >= 44, close.width >= 44), (true, true, true));
      expect(find.byTooltip('이미지로 저장'), findsOneWidget);
      expect(find.byTooltip('닫기'), findsOneWidget);
      // 그림은 화면 폭에 맞춘 4:3 (양옆 12)
      final rect = tester.getRect(_key('viewer-painting-kr001'));
      expect((rect.width, rect.height), (366, 274.5));
      await end(tester, e);
    });

    testWidgets('저장: 액자 그림을 원본 폭(1536)에 맞춘 PNG로 떠서 명소 이름으로 저장하고 ‘저장했어요’ 1.5초', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, [_big('kr001')]);

      await tester.tap(_key('viewer-save'));
      await _waitFor(tester, () => _key('viewer-toast').evaluate().isNotEmpty);
      final c = e.saver.calls.single;
      expect(c.name, '경복궁');
      final (w, h) = _pngSize(c.png)!;
      expect((w - 1536).abs() <= 1, isTrue, reason: '$w');
      expect((h - 1152).abs() <= 1, isTrue, reason: '$h');
      // 모서리는 액자 잉크선, 가운데는 그림 자리
      expect(await _pixel(tester, c.png, 1, 1), Palette.ink);
      final center = await _pixel(tester, c.png, w ~/ 2, h ~/ 2);
      expect(center, isNot(Palette.ink));
      expect(find.text('저장했어요'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('저장했어요'), findsNothing);
      await end(tester, e);
    });

    testWidgets('첫 그림은 `첫 그림`으로 저장한다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await _open(tester, e, [_firstPack]);
      await tester.tap(_key('viewer-save'));
      await _waitFor(tester, () => e.saver.calls.isNotEmpty);
      expect(e.saver.calls.single.name, '첫 그림');
      await end(tester, e);
    });

    testWidgets('사진 권한이 없거나 저장에 실패하면 알리고 그대로 남는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, [_big('kr001')]);

      e.saver.outcome = SaveOutcome.denied;
      await tester.tap(_key('viewer-save'));
      await _waitFor(tester, () => find.text('사진 권한이 없어 저장하지 못했어요').evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 1600));

      e.saver.outcome = SaveOutcome.failed;
      await tester.tap(_key('viewer-save'));
      await _waitFor(tester, () => find.text('저장하지 못했어요').evaluate().isNotEmpty);
      expect(e.saver.calls, hasLength(2));
      expect(find.byType(PaintingViewer), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('좌우로 밀면 다음·이전 그림, 저장은 지금 보이는 그림', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, [_big('kr001'), _big('kr002'), _firstPack], index: 1);

      expect(_key('viewer-painting-kr002'), findsOneWidget);
      await tester.fling(_key('viewer-pages'), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(_key('viewer-painting-$sketchId'), findsOneWidget);
      // 마지막 장에서 더 밀어도 그대로
      await tester.fling(_key('viewer-pages'), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(_key('viewer-painting-$sketchId'), findsOneWidget);
      await tester.fling(_key('viewer-pages'), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      await tester.fling(_key('viewer-pages'), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(_key('viewer-painting-kr001'), findsOneWidget);

      await tester.tap(_key('viewer-save'));
      await _waitFor(tester, () => e.saver.calls.isNotEmpty);
      expect(e.saver.calls.single.name, '경복궁');
      await end(tester, e);
    });

    testWidgets('두 손가락으로 펴면 2배까지 커지고, 커진 동안에는 넘기지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, [_big('kr001'), _big('kr002')]);

      final center = tester.getCenter(_key('viewer-painting-kr001'));
      final a = await tester.startGesture(center - const Offset(20, 0));
      final b = await tester.startGesture(center + const Offset(20, 0), pointer: 2);
      for (var i = 1; i <= 10; i++) {
        await a.moveTo(center - Offset(20.0 + i * 20, 0));
        await b.moveTo(center + Offset(20.0 + i * 20, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      // 4배로 폈어도 2배에서 멈춘다 (config ui.bigView.maxZoom)
      final zoom = tester.widget<Transform>(_key('viewer-zoom-0'));
      expect(zoom.transform.getMaxScaleOnAxis(), closeTo(2, 0.05));
      // 확대한 그림은 화면 밖으로 비지 않는다: 그림이 화면보다 커져도 왼쪽 위가 화면 안쪽으로 들어오지 않는다
      final rect = tester.getRect(_key('viewer-painting-kr001'));
      expect(rect.width, closeTo(366 * 2, 2));
      await tester.fling(_key('viewer-pages'), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(_key('viewer-painting-kr002'), findsNothing);
      await end(tester, e);
    });

    testWidgets('닫기, 아래로 밀기, 뒤로 가기로 닫힌다. 조금만 끌면 그대로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, [_big('kr001')]);
      await tester.tap(_key('viewer-close'));
      await tester.pumpAndSettle();
      expect(find.byType(PaintingViewer), findsNothing);

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      await tester.drag(_key('viewer-drag'), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(find.byType(PaintingViewer), findsOneWidget);
      await tester.drag(_key('viewer-drag'), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byType(PaintingViewer), findsNothing);

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      await nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(PaintingViewer), findsNothing);
      await end(tester, e);
    });
  });
}
