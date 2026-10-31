import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/tint.dart';
import 'package:doobal/ui/common/figure_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

/// [paint]가 그린 그림 한 장의 RGBA 바이트 (실제 엔진으로 그린다)
Future<({Uint8List bytes, int width})> _render(
  WidgetTester tester,
  Size size,
  void Function(Canvas canvas, Size size) paint,
) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  });
  return (bytes: bytes!, width: size.width.toInt());
}

/// (x, y) 한 점의 불투명 RGB
(int, int, int) _pixel(({Uint8List bytes, int width}) img, int x, int y) {
  final i = (y * img.width + x) * 4;
  return (img.bytes[i], img.bytes[i + 1], img.bytes[i + 2]);
}

(int, int, int) _rgb(int argb) => ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

Matcher _near((int, int, int) want, [int tolerance = 1]) => predicate<(int, int, int)>(
      (got) =>
          (got.$1 - want.$1).abs() <= tolerance &&
          (got.$2 - want.$2).abs() <= tolerance &&
          (got.$3 - want.$3).abs() <= tolerance,
      '$want ±$tolerance',
    );

void main() {
  group('tintMatrix를 실제 ColorFilter.matrix로 그리면', () {
    Future<(int, int, int)> tinted(WidgetTester tester, int swatch, int base, int gray) async {
      final img = await _render(tester, const Size(8, 8), (canvas, size) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = Color.fromARGB(255, gray, gray, gray)
            ..colorFilter = ColorFilter.matrix(tintMatrix(swatch, base)),
        );
      });
      return _pixel(img, 4, 4);
    }

    testWidgets('머리 회색 182는 견본색 그대로 (견본 10개)', (tester) async {
      for (final s in lookPalette.hair.swatches) {
        expect(await tinted(tester, s.color, lookPalette.hair.base, 182), _near(_rgb(s.color)),
            reason: s.name);
      }
    });

    testWidgets('피부 회색 196은 견본색 그대로 (견본 7개)', (tester) async {
      for (final s in lookPalette.skin.swatches) {
        expect(await tinted(tester, s.color, lookPalette.skin.base, 196), _near(_rgb(s.color)),
            reason: s.name);
      }
    });

    testWidgets('어두운 회색은 견본보다 어둡고, 도메인 계산(applyColorMatrix)과 같다', (tester) async {
      const swatch = 0xFF8C3E2A;
      for (final gray in [0, 60, 91, 150, 182, 220, 255]) {
        final got = await tinted(tester, swatch, 182, gray);
        final want = applyColorMatrix(
            tintMatrix(swatch, 182), 0xFF000000 | gray << 16 | gray << 8 | gray);
        expect(got, _near(_rgb(want)), reason: 'gray $gray');
      }
    });
  });

  group('FigurePainter 자리표시 색', () {
    const size = Size(200, 200);
    // 얼굴 가운데 (c = 100,100, 반지름 52): 피부색만 칠해진 자리
    const faceX = 100;
    const faceY = 112;

    testWidgets('피부색을 얼굴에 칠한다 (기본은 피부 견본 1)', (tester) async {
      var img = await _render(
          tester, size, (c, s) => const FigurePainter(1, Color(0xFF2B2522)).paint(c, s));
      expect(_pixel(img, faceX, faceY), _near(_rgb(0xFFF6E1D3), 0));
      img = await _render(tester, size,
          (c, s) => const FigurePainter(1, Color(0xFF2B2522), skin: Color(0xFF966242)).paint(c, s));
      expect(_pixel(img, faceX, faceY), _near(_rgb(0xFF966242), 0));
    });

    testWidgets('머리색을 앞머리에 칠한다', (tester) async {
      final img = await _render(tester, size,
          (c, s) => const FigurePainter(1, Color(0xFFE39AB0)).paint(c, s));
      // 앞머리: 얼굴 위쪽 반원 (c.dy - r 근처)
      expect(_pixel(img, 100, 100 - 52), _near(_rgb(0xFFE39AB0), 0));
    });

    testWidgets('그러데이션: 뿌리 쪽은 뿌리색, 끝 쪽은 끝색, 사이는 섞인다', (tester) async {
      // 긴 머리(3): 머리카락 위아래 범위는 앞머리 위 끝(약 y 40)부터 뒷머리 아래 끝(약 y 209)
      const root = Color(0xFF2B2522);
      const tip = Color(0xFFE39AB0);
      final img = await _render(
        tester,
        size,
        (c, s) => const FigurePainter(
          3,
          root,
          hairGradient: HairGradient(tip: tip, rootUntil: 0.3, tipFrom: 0.85),
        ).paint(c, s),
      );
      // 뒷머리 긴 판(얼굴 옆)에서 위에서 아래로 본다 (x = 100 - 52 * 1.15 → 얼굴 밖, 판 안)
      const x = 100 - 60;
      final top = _pixel(img, x, 70); // 범위의 약 18% (뿌리색)
      final bottom = _pixel(img, x, 190); // 약 89% (끝색)
      final middle = _pixel(img, x, 128); // 약 52% (섞임)
      expect(top, _near(_rgb(0xFF2B2522), 2));
      expect(bottom, _near(_rgb(0xFFE39AB0), 2));
      // 중간은 두 색 사이 (채널마다 뿌리와 끝 사이)
      for (final (m, a, b) in [
        (middle.$1, 0x2B, 0xE3),
        (middle.$2, 0x25, 0x9A),
        (middle.$3, 0x22, 0xB0),
      ]) {
        expect(m, inInclusiveRange(a, b));
        expect(m, isNot(a));
        expect(m, isNot(b));
      }
    });

    testWidgets('그러데이션이 아니면 머리 전체가 한 색', (tester) async {
      final img = await _render(tester, size,
          (c, s) => const FigurePainter(3, Color(0xFF2B2522)).paint(c, s));
      expect(_pixel(img, 40, 70), _near(_rgb(0xFF2B2522), 0));
      expect(_pixel(img, 40, 190), _near(_rgb(0xFF2B2522), 0));
    });

    test('figureOf: 팔레트에서 머리색·그러데이션·피부색을 읽는다', () {
      final plain = figureOf(
        const Look(hair: 4, hairColor: SwatchHairColor(6), skin: SwatchSkinColor(5)),
        lookPalette,
      );
      expect(plain.hair, 4);
      expect(plain.hairColor, const Color(0xFFD6B26E));
      expect(plain.skin, const Color(0xFFCF9A72));
      expect(plain.hairGradient, isNull);

      final grad = figureOf(
        const Look(
          hair: 2,
          hairColor: GradientHairColor('#102030', '#A0B0C0'),
          skin: CustomSkinColor('#C08060'),
        ),
        lookPalette,
      );
      expect(grad.hairColor, const Color(0xFF102030));
      expect(grad.hairGradient,
          const HairGradient(tip: Color(0xFFA0B0C0), rootUntil: 0.3, tipFrom: 0.85));
      expect(grad.skin, const Color(0xFFC08060));
    });

    test('shouldRepaint: 피부·그러데이션이 달라져도 다시 그린다', () {
      const base = FigurePainter(1, Color(0xFF000000));
      expect(base.shouldRepaint(const FigurePainter(1, Color(0xFF000000))), isFalse);
      expect(base.shouldRepaint(const FigurePainter(1, Color(0xFF000000), skin: Color(0xFF966242))),
          isTrue);
      expect(
          base.shouldRepaint(const FigurePainter(1, Color(0xFF000000),
              hairGradient: HairGradient(tip: Color(0xFFFFFFFF), rootUntil: 0.3, tipFrom: 0.85))),
          isTrue);
      expect(base.shouldRepaint(const FigurePainter(2, Color(0xFF000000))), isTrue);
    });
  });
}
