import 'dart:math' as math;

import 'package:doobal/domain/trail_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 물감 길 무늬 놓기 (개발인계_20261120 5장, config mapTrail.patterns): 짧은 구간 끝 1개, 양끝 + 여백 18pt,
// 무늬 바뀜 끝 1개 + 여백 8pt, 색만 바뀌면 이어 그림, 굽이 64px 묶음 각도

final _rules = TrailLayoutRules(
  capPt: rules.mapTrail.paintCapPt,
  shortUnderPt: rules.paintPattern.shortUnderPt,
  shortGapPt: rules.paintPattern.shortGapPt,
  switchGapPt: rules.paintPattern.switchGapPt,
);

/// 오른쪽으로 [from]~[to] pt 곧은 구간
TrailPiece _line(double from, double to, {String color = 'basic', String pattern = 'drops', double k = 1}) =>
    TrailPiece([(from * k, 0), (to * k, 0)], colorId: color, patternId: pattern);

void main() {
  test('config 값 그대로 (끝 12pt, 36pt, 18pt, 8pt)', () {
    expect((_rules.capPt, _rules.shortUnderPt, _rules.shortGapPt, _rules.switchGapPt), (12, 36, 18, 8));
  });

  group('짧은 구간 (shortSegment)', () {
    test('화면 35pt 구간은 반복 없이 끝 1개만 가운데에', () {
      final l = layoutTrailRun([_line(0, 35, pattern: 'trail_01')], _rules, k: 1);
      expect(l.spans, isEmpty);
      expect(l.caps, hasLength(1));
      expect(l.caps.single.d, closeTo(17.5, 1e-9));
      expect(l.caps.single.start, isFalse);
    });

    test('36pt부터는 양끝 끝 모양, 반복 무늬는 앞뒤 여백 18pt 안쪽만 (36pt는 반복할 자리가 없다)', () {
      var l = layoutTrailRun([_line(0, 36)], _rules, k: 1);
      expect(l.caps.map((c) => (c.d, c.start)), [(6.0, true), (30.0, false)]);
      expect(l.spans, isEmpty);
      l = layoutTrailRun([_line(0, 100)], _rules, k: 1);
      expect(l.caps.map((c) => (c.d, c.start)), [(6.0, true), (94.0, false)]);
      expect(l.spans.single.from, closeTo(18, 1e-9));
      expect(l.spans.single.to, closeTo(82, 1e-9));
    });

    test('길이는 화면 pt: 확대(k = 2)해도 36pt 기준은 화면 그대로', () {
      // k = 2 (화면 1pt = 2px): 35pt = 70px는 짧은 구간, 50pt = 100px는 양끝 + 여백 18pt = 36px
      final short = layoutTrailRun([_line(0, 35, k: 2)], _rules, k: 2);
      expect(short.caps, hasLength(1));
      final long = layoutTrailRun([_line(0, 50, k: 2)], _rules, k: 2);
      expect(long.caps, hasLength(2));
      expect(long.spans.single.from, closeTo(36, 1e-9));
    });
  });

  group('무늬가 바뀌는 곳 (switch)', () {
    test('앞 무늬 끝 1개 + 여백 8pt 뒤 새 무늬 첫 도형 (새 무늬 시작 끝은 없다)', () {
      final l = layoutTrailRun([_line(0, 100), _line(100, 200, pattern: 'trail_01')], _rules, k: 1);
      expect(l.caps.map((c) => (c.d, c.patternId, c.start)), [
        (6.0, 'drops', true),
        (94.0, 'drops', false), // 앞 무늬 끝: 바깥 가장자리 = 바뀌는 자리 100
        (194.0, 'trail_01', false),
      ]);
      expect(l.spans.map((s) => (s.from, s.to, s.patternId)), [
        (18.0, 82.0, 'drops'),
        (108.0, 182.0, 'trail_01'), // 100 + 8pt
      ]);
      expect(l.groups.map((g) => g.afterSwitch), [false, true]);
    });

    test('색만 바뀌면 끝 모양 없이 이어 그린다 (한 덩어리, 색은 자리마다)', () {
      final l = layoutTrailRun(
        [_line(0, 100, color: 'sunset'), _line(100, 160, color: 'autumn.rain')],
        _rules,
        k: 1,
      );
      expect(l.caps.map((c) => c.d), [6.0, 154.0]);
      expect(l.spans.single.from, closeTo(18, 1e-9));
      expect(l.spans.single.to, closeTo(142, 1e-9));
      expect(l.colorAt(50), 'sunset');
      expect(l.colorAt(130), 'autumn.rain');
      expect(l.caps.last.colorId, 'autumn.rain');
    });

    test('바뀐 뒤 짧은 덩어리는 끝 1개만', () {
      final l = layoutTrailRun([_line(0, 100), _line(100, 120, pattern: 'trail_02')], _rules, k: 1);
      expect(l.caps.map((c) => (c.d, c.patternId)), [(6.0, 'drops'), (94.0, 'drops'), (110.0, 'trail_02')]);
      expect(l.spans.map((s) => s.patternId), ['drops']);
    });
  });

  group('급한 굽이 (curve chunkPx perChunk)', () {
    test('반복 무늬를 묶음마다 나누고, 묶음 가운데 자리의 방향으로 돌린다', () {
      // 오른쪽 100pt → 아래로 100pt (직각 굽이)
      final l = layoutTrailRun(
        [TrailPiece(const [(0, 0), (100, 0), (100, 100)], colorId: 'basic', patternId: 'trail_01')],
        _rules,
        k: 1,
      );
      final span = l.spans.single;
      expect((span.from, span.to), (18.0, 182.0));
      // 그림 64px = 높이 10pt → 묶음 10pt
      final chunk = rules.paintPattern.curveChunkPx * rules.mapTrail.paintHeightPt / 64;
      final chunks = TrailRunLayout.chunks(span, chunk);
      expect(chunks, hasLength(17)); // 164pt ÷ 10 = 16묶음 + 남은 4pt
      expect(chunks.last.length, closeTo(4, 1e-9));
      expect(chunks.map((c) => c.index), List.generate(17, (i) => i));
      for (final c in chunks) {
        final mid = c.from + c.length / 2;
        final angle = l.line.at(mid).angle;
        expect(angle, closeTo(mid < 100 ? 0 : math.pi / 2, 1e-9), reason: '$mid');
      }
    });
  });

  test('줄 위 자리·방향 (TrailPolyline)', () {
    final line = TrailPolyline(const [(0, 0), (3, 4), (3, 4), (3, 10)]);
    expect(line.length, 11);
    final p = line.at(2.5);
    expect((p.x, p.y), (1.5, 2.0));
    expect(line.at(8).angle, closeTo(math.pi / 2, 1e-12));
    expect(line.at(99).y, 10);
  });
}
