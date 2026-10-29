import 'package:doobal/domain/parallax.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('config의 땅 규격에서 px/m = 20.48이 나온다', () {
    expect(rules.groundPxPerM, closeTo(20.48, 1e-9));
    expect(rules.parallaxBackdrop, 0.3);
    expect(rules.parallaxGround, 1.0);
    expect(rules.parallaxForeground, 1.3);
    expect(rules.skyBandWidthPx / rules.skyTileWidthPx, 8);
    expect(rules.groundWidthPx / rules.groundTileWidthPx, 2);
  });

  group('layerOffsetPx', () {
    final pxPerM = rules.groundPxPerM;

    test('땅 100m → 이미지 반 장', () {
      expect(layerOffsetPx(100, 1.0, pxPerM, 4096), closeTo(2048, 1e-6));
    });

    test('땅 200m → 한 바퀴 돌아 0', () {
      expect(layerOffsetPx(200, 1.0, pxPerM, 4096), closeTo(0, 1e-6));
    });

    test('후경 250m × 0.3, 가로 2048 → 1536', () {
      expect(layerOffsetPx(250, 0.3, pxPerM, 2048), closeTo(1536, 1e-6));
    });

    test('거리 0 → 0, 음수 거리도 0 이상', () {
      expect(layerOffsetPx(0, 1.0, pxPerM, 4096), 0);
      final r = layerOffsetPx(-50, 1.0, pxPerM, 4096);
      expect(r, closeTo(3072, 1e-6));
      expect(r, inInclusiveRange(0, 4096));
    });

    test('아주 작은 음수도 가로 이상이 되지 않는다', () {
      expect(layerOffsetPx(-1e-20, 1.0, 1.0, 4096), lessThan(4096));
    });
  });

  group('visibleTiles', () {
    test('1170px 화면이 조각 3장에 걸친다', () {
      expect(visibleTiles(1000, 1170, 1024, 8), [0, 1, 2]);
    });

    test('띠 끝을 넘으면 처음으로 이어진다', () {
      expect(visibleTiles(7800, 1170, 1024, 8), [7, 0]);
    });

    test('조각 경계에 딱 맞으면 한 장', () {
      expect(visibleTiles(0, 1024, 1024, 8), [0]);
    });

    test('왼쪽이 음수여도 이어 붙는다 (하늘 띠 앞쪽)', () {
      expect(visibleTiles(-100, 1170, 1024, 8), [7, 0, 1]);
    });

    test('화면이 띠보다 커도 조각 수를 넘지 않는다', () {
      expect(visibleTiles(0, 5000, 1024, 2), [0, 1]);
    });

    test('땅 조각 2장짜리: 화면 오른쪽 끝이 넘어가면 두 장', () {
      expect(visibleTiles(3000, 1170, 2048, 2), [1, 0]);
    });

    test('빈 화면은 조각 없음', () {
      expect(visibleTiles(100, 0, 1024, 8), isEmpty);
    });
  });
}
