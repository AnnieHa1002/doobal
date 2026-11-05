import 'package:doobal/domain/rest_camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final g = RestGeometry(campTheme, rules.rest, 390, 844);

  group('밀기 경계', () {
    test('처음 배율의 오른쪽 끝은 화면 폭 − 장면 폭', () {
      expect(g.minX(1), -195);
    });

    test('왼쪽 끝을 넘으면 0, 오른쪽 끝을 넘으면 끝에 멈춘다', () {
      const start = RestCamera();
      expect(g.gesture(start, fromX: 100, toX: 300).x, 0);
      expect(g.gesture(start, fromX: 300, toX: 200).x, -100);
      expect(g.gesture(start, fromX: 390, toX: -500).x, -195);
    });

    test('손을 떼면 가까운 끝으로 붙는다 (config rest.drag.snapToEnds)', () {
      expect(g.settle(const RestCamera(x: -90)).x, 0);
      expect(g.settle(const RestCamera(x: -100)).x, -195);
      expect(g.settle(const RestCamera(x: -195)).x, -195);
      expect(g.settle(const RestCamera()).x, 0);
    });

    test('원경은 0.45배로 움직인다 (config rest.drag.farParallax)', () {
      expect(rules.rest.farParallax, 0.45);
      expect(g.farX(const RestCamera(x: -195)), closeTo(-87.75, 1e-9));
      expect(g.farX(const RestCamera()), 0);
    });

    test('원경 층 폭은 처음 배율 오른쪽 끝에서 화면 끝까지 덮는다', () {
      expect(g.farWidth, closeTo(390 + 195 * 0.45, 1e-9));
      // 어느 배율·어느 끝에서도 화면 오른쪽 끝은 원경 층 안이다
      for (final zoom in [1.0, 1.2, 1.5]) {
        final c = RestCamera(x: g.minX(zoom), zoom: zoom);
        final right = (g.width - g.farX(c)) / zoom;
        expect(right, lessThanOrEqualTo(g.farWidth + 1e-9), reason: '$zoom');
      }
    });
  });

  group('확대 경계', () {
    test('값은 config rest.zoom', () {
      expect(rules.rest.zoomMin, 1);
      expect(rules.rest.zoomMax, 1.5);
      expect(rules.rest.snapEdgesWhenZoomed, isFalse);
    });

    test('1~1.5배로 막힌다', () {
      const start = RestCamera();
      expect(g.gesture(start, scale: 3, fromX: 100, toX: 100).zoom, 1.5);
      expect(g.gesture(start, scale: 0.2, fromX: 100, toX: 100).zoom, 1);
      expect(g.gesture(start, scale: 1.2, fromX: 100, toX: 100).zoom, 1.2);
    });

    test('확대하면 오른쪽 끝이 늘어난다', () {
      expect(g.minX(1.5), 390 - 585 * 1.5);
      expect(g.clamp(const RestCamera(x: -1000, zoom: 1.5)).x, 390 - 585 * 1.5);
      expect(g.clamp(const RestCamera(x: 50, zoom: 1.5)).x, 0);
    });

    test('초점 아래의 장면 지점이 그대로 있다', () {
      const start = RestCamera(x: -100);
      final at = g.gesture(start, scale: 1.25, fromX: 200, toX: 200);
      // 초점(화면 200)이 가리키던 장면 지점 300이 그대로 화면 200에 온다
      expect(at.x + (200 - start.x) * at.zoom, closeTo(200, 1e-9));
    });

    test('확대 중에는 손을 떼도 끝에 안 붙는다', () {
      const c = RestCamera(x: -130, zoom: 1.3);
      expect(g.settle(c), c);
    });

    test('1배로 돌아오면 다시 끝에 붙는다', () {
      expect(g.settle(const RestCamera(x: -60, zoom: 1.0005)), const RestCamera());
      expect(g.settle(const RestCamera(x: -150, zoom: 1.0005)), const RestCamera(x: -195));
    });

    test('장면은 아래 기준: 확대해도 화면 아래 끝은 그대로', () {
      for (final zoom in [1.0, 1.25, 1.5]) {
        final c = RestCamera(zoom: zoom);
        expect(g.toScreen(c, 0, 844).y, closeTo(844, 1e-9));
      }
      // 정령 발(y 725)은 아래에서 119 × 배율
      expect(g.toScreen(const RestCamera(zoom: 1.5), 0, 725).y, closeTo(844 - 119 * 1.5, 1e-9));
    });

    test('확대 중 끌기는 그 배율의 끝까지 간다', () {
      const start = RestCamera(zoom: 1.5);
      expect(g.gesture(start, fromX: 300, toX: -700).x, g.minX(1.5));
      expect(g.gesture(start, fromX: 300, toX: -700).zoom, 1.5);
    });
  });
}
