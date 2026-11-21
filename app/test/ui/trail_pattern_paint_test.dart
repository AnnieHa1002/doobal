import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/domain/trail_layout.dart';
import 'package:doobal/ui/common/trail_pattern_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 물감 길 무늬 그리기 (개발인계_20261120 5장, config mapTrail.patterns): 밤 여부에 따른 윤곽 색·굵기, 무늬 그림 묶음,
// 끝과 반복 무늬 사이 여백, 무늬가 바뀌는 곳 여백 8pt. 실제로 그린 그림의 픽셀을 본다

const _w = 1200;
const _h = 120;

/// 그린 그림 한 장의 픽셀
class _Pixels {
  _Pixels(this.bytes);

  final ByteData bytes;

  Color at(double x, double y) {
    final i = (y.round() * _w + x.round()) * 4;
    return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
  }
}

Future<_Pixels> _draw(void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(_w, _h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  image.dispose();
  return _Pixels(bytes!);
}

/// 흰 불투명 그림 한 장 (무늬 그림 대신: RGB × 구간 색이면 구간 색이 그대로 보인다)
Future<ui.Image> _white(int w, int h) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.white);
  return recorder.endRecording().toImage(w, h);
}

const _k = 4.0;
const _y = 60.0;
const _red = Color(0xFFFF0000);

TrailPiece _piece(double fromPt, double toPt, String pattern, {double k = _k}) =>
    TrailPiece([(fromPt * k, _y), (toPt * k, _y)], colorId: 'red', patternId: pattern);

TrailRunLayout _layout(List<TrailPiece> pieces, {double k = _k}) =>
    layoutTrailRun(pieces, trailLayoutRules(rules.mapTrail, rules.paintPattern), k: k);

Color _colorOf(String _) => _red;

void main() {
  test('윤곽 값: 낮은 잉크 25% 1pt, 밤 지도는 #D9E4EF 1.2pt', () {
    final day = trailPaintStyle(rules.mapTrail, rules.paintPattern, k: 1, night: false);
    expect(day.outlineColor, const Color(0xFF3E2C22).withValues(alpha: 0.25));
    expect(day.outlinePt, 1);
    final night = trailPaintStyle(rules.mapTrail, rules.paintPattern, k: 1, night: true);
    expect(night.outlineColor, const Color(0xFFD9E4EF));
    expect(night.outlinePt, 1.2);
    expect((night.heightPt, night.capPt, night.chunkPx), (10, 12, 64));
  });

  testWidgets('밤 여부에 따라 윤곽 색·굵기가 다르다 (짧은 구간의 끝 1개를 그려 본다)', (tester) async {
    await tester.runAsync(() async {
      // 20pt 구간 = 끝(지름 12pt) 1개만 가운데 (10pt 자리). 가장자리 번짐을 피하려고 크게(1pt = 20px)
      const k = 20.0;
      final layout = _layout([_piece(0, 20, 'drops', k: k)], k: k);
      expect(layout.caps, hasLength(1));
      const art = TrailArt.none('drops');
      Future<_Pixels> draw(bool night) => _draw((c) => paintTrailRun(
          c, layout, art, trailPaintStyle(rules.mapTrail, rules.paintPattern, k: k, night: night), _colorOf));
      final day = await draw(false);
      final night = await draw(true);
      // 끝 반지름 6pt. 6.5pt는 두 윤곽 다 안, 7.1pt는 밤(6 + 1.2pt)만, 7.3pt는 둘 다 밖
      const cx = 10 * k;
      final dayRing = day.at(cx + 6.5 * k, _y);
      expect(dayRing.a, closeTo(0.25, 0.02));
      expect((dayRing.r * 255).round(), closeTo(0x3E, 3));
      expect(night.at(cx + 6.5 * k, _y), const Color(0xFFD9E4EF));
      expect(day.at(cx + 7.1 * k, _y).a, 0);
      expect(night.at(cx + 7.1 * k, _y), const Color(0xFFD9E4EF));
      expect(night.at(cx + 7.3 * k, _y).a, 0);
    });
  });

  testWidgets('무늬 그림이 있으면 묶음마다 RGB × 구간 색, 끝과 반복 무늬 사이·무늬가 바뀌는 곳은 비운다', (tester) async {
    await tester.runAsync(() async {
      final art = TrailArt(defaultId: 'drops', images: {
        'trail_01': TrailPatternImages(tile: await _white(512, 64), cap: await _white(64, 64)),
      });
      expect(art.drawn('trail_01'), 'trail_01');
      // 그림이 없는 무늬는 기본 방울로 (missingArt drawAsDefault)
      expect(art.drawn('trail_02'), 'drops');
      expect(art.drawn(null), 'drops');
      // 방울 100pt → 발자국 100pt
      final layout = _layout([_piece(0, 100, 'drops'), _piece(100, 200, 'trail_01')]);
      final px = await _draw((c) => paintTrailRun(
          c, layout, art, trailPaintStyle(rules.mapTrail, rules.paintPattern, k: _k, night: false), _colorOf));
      double x(double pt) => pt * _k;
      // 발자국 반복 무늬(108~182pt) 가운데는 구간 색 그대로
      expect(px.at(x(150), _y), _red);
      // 바뀌는 곳: 방울 끝(88~100pt, 윤곽 101pt까지) 뒤 여백 8pt → 104pt는 비어 있고 108pt 뒤는 칠함
      expect(px.at(x(97), _y).a, greaterThan(0.5));
      expect(px.at(x(104), _y).a, 0);
      expect(px.at(x(109), _y), _red);
      // 발자국 끝(188~200pt) 앞 여백: 182pt 뒤 ~ 끝 윤곽 187pt 전은 비어 있다
      expect(px.at(x(184.5), _y).a, 0);
      expect(px.at(x(194), _y), _red);
      // 높이 10pt: 줄에서 4pt 위는 칠하고 6pt 위는 윤곽(1pt)도 지난다
      expect(px.at(x(150), _y - 4 * _k), _red);
      expect(px.at(x(150), _y - 6.5 * _k).a, 0);
    });
  });
}
