import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/parallax.dart';
import 'package:doobal/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('config의 장면 규격', () {
    test('땅 4096px = 100m → px/m = 40.96', () {
      expect(rules.groundWidthPx, 4096);
      expect(rules.groundMeters, 100);
      expect(rules.groundPxPerM, closeTo(40.96, 1e-9));
    });

    test('레이어 속도: 하늘 0.03 · 후경 0.05 · 능선 0.10 · 숲 0.30 · 풀밭 0.50 · 땅 1.0 · 전경 1.0', () {
      expect({for (final e in rules.layers.entries) e.key: e.value.speed}, {
        SceneLayerId.sky: 0.03,
        SceneLayerId.backdrop: 0.05,
        SceneLayerId.ridge: 0.10,
        SceneLayerId.grove: 0.30,
        SceneLayerId.meadow: 0.50,
        SceneLayerId.ground: 1.0,
        SceneLayerId.foreground: 1.0,
      });
    });

    test('레이어마다 규격이 있다: 크기·위 y, 띠는 그 이미지 안에 들어간다', () {
      for (final id in SceneLayerId.values) {
        final l = rules.layers[id]!;
        if (id == SceneLayerId.sky) continue;
        expect(l.widthPx, isNotNull, reason: id.name);
        expect(l.heightPx, isNotNull, reason: id.name);
        expect(l.topY, isNotNull, reason: id.name);
        if (l.bandTop == null) continue;
        expect(l.bandTop!, greaterThanOrEqualTo(l.topY!), reason: id.name);
        expect(l.bandBottom!, greaterThan(l.bandTop!), reason: id.name);
        expect(l.bandBottom!, lessThanOrEqualTo(l.topY! + l.heightPx!), reason: id.name);
      }
      final backdrop = rules.layers[SceneLayerId.backdrop]!;
      expect((backdrop.widthPx, backdrop.heightPx, backdrop.topY), (1764, 662, 912));
      expect((backdrop.bandTop, backdrop.bandBottom), (1050, 1200));
      final ground = rules.layers[SceneLayerId.ground]!;
      expect((ground.widthPx, ground.heightPx, ground.topY), (4096, 640, 1892));
      expect(ground.bandTop, isNull);
    });

    test('바다에서는 능선·숲·풀밭·전경을 숨긴다 (하늘·후경·땅은 남는다)', () {
      expect(rules.seaHiddenLayers, {
        SceneLayerId.ridge,
        SceneLayerId.grove,
        SceneLayerId.meadow,
        SceneLayerId.foreground,
      });
    });

    test('기준 화면 2532px: 지평선 1580 · 길 2171 · 캐릭터 키 820', () {
      expect(rules.screenHeightPx, 2532);
      expect(rules.horizonY, 1580);
      expect(rules.pathY, 2171);
      expect(rules.characterHeightPx, 820);
    });

    test('잘못된 레이어 이름은 받아들이지 않는다', () {
      Map<String, dynamic> config() => jsonDecode(
          File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
      final bad = config();
      ((bad['scene'] as Map)['layers'] as Map)['cloud'] = {'speed': 0.02};
      expect(() => Rules.fromJson(bad), throwsFormatException);
      final badHidden = config();
      ((badHidden['scene'] as Map)['seaHiddenLayers'] as List).add('wave');
      expect(() => Rules.fromJson(badHidden), throwsFormatException);
      final missing = config();
      ((missing['scene'] as Map)['layers'] as Map).remove('meadow');
      expect(() => Rules.fromJson(missing), throwsFormatException);
    });
  });

  group('layerOffsetPx', () {
    final pxPerM = rules.groundPxPerM;
    double offset(SceneLayerId id, double distanceM) {
      final l = rules.layers[id]!;
      return layerOffsetPx(distanceM, l.speed, pxPerM, l.widthPx!);
    }

    test('땅 50m → 이미지 반 장, 100m → 한 바퀴', () {
      expect(offset(SceneLayerId.ground, 50), closeTo(2048, 1e-6));
      // 한 바퀴는 0이거나 (부동소수 오차로) 4096 바로 아래
      expect(offset(SceneLayerId.ground, 100), anyOf(closeTo(0, 1e-6), closeTo(4096, 1e-6)));
    });

    test('전경도 땅과 같은 속도', () {
      expect(offset(SceneLayerId.foreground, 37), offset(SceneLayerId.ground, 37));
    });

    test('풀밭 150m × 0.5 → 3072', () {
      expect(offset(SceneLayerId.meadow, 150), closeTo(3072, 1e-6));
    });

    test('숲 100m × 0.3 → 1228.8', () {
      expect(offset(SceneLayerId.grove, 100), closeTo(1228.8, 1e-6));
    });

    test('능선 500m × 0.10 = 2048 (가로 2400), 1000m → 4096 - 2400 = 1696', () {
      expect(offset(SceneLayerId.ridge, 500), closeTo(2048, 1e-6));
      expect(offset(SceneLayerId.ridge, 1000), closeTo(1696, 1e-6));
    });

    test('후경 250m × 0.05 → 512 (가로 1764), 1000m → 2048 - 1764 = 284', () {
      expect(offset(SceneLayerId.backdrop, 250), closeTo(512, 1e-6));
      expect(offset(SceneLayerId.backdrop, 1000), closeTo(284, 1e-6));
    });

    test('거리 0 → 0, 음수 거리도 0 이상', () {
      expect(layerOffsetPx(0, 1.0, pxPerM, 4096), 0);
      final r = layerOffsetPx(-50, 1.0, pxPerM, 4096);
      expect(r, closeTo(2048, 1e-6));
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

    test('왼쪽이 음수여도 이어 붙는다', () {
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
