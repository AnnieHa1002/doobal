import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/map_land.dart';
import 'package:doobal/domain/map_projection.dart';
import 'package:doobal/domain/map_regions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

bool _on(LatLng p, Island island) => onIsland(p, island, mapProjection, mapRegions);

void main() {
  group('실제 지도', () {
    test('서울시청은 본토 땅이고 제주·울릉은 아니다', () {
      expect(_on(testHome, Island.mainland), isTrue);
      expect(_on(testHome, Island.jeju), isFalse);
      expect(_on(testHome, Island.ulleung), isFalse);
    });

    test('서해 (37.0, 125.0)와 동해 바다는 어느 섬도 아니다', () {
      for (final island in Island.values) {
        expect(_on(const LatLng(37.0, 125.0), island), isFalse, reason: '서해 $island');
        expect(_on(const LatLng(37.5, 131.5), island), isFalse, reason: '동해 $island');
        // 제주와 완도 사이 바다
        expect(_on(const LatLng(33.9, 126.6), island), isFalse, reason: '제주 해협 $island');
      }
    });

    test('제주시는 제주 땅이고 본토는 아니다', () {
      const jeju = LatLng(33.49953, 126.53117);
      expect(_on(jeju, Island.jeju), isTrue);
      expect(_on(jeju, Island.mainland), isFalse);
    });

    test('울릉군은 울릉 땅', () {
      const ulleung = LatLng(37.48444, 130.90571);
      expect(_on(ulleung, Island.ulleung), isTrue);
      expect(_on(ulleung, Island.mainland), isFalse);
      expect(_on(ulleung, Island.jeju), isFalse);
    });

    test('명소는 거의 다 자기 섬의 땅이다 (지도가 간략본이라 해안 명소 몇 곳은 해안선 밖)', () {
      final off = [for (final l in landmarks) if (!_on(l.latLng, l.island)) l.name];
      expect(landmarks.length - off.length, greaterThanOrEqualTo(90), reason: '$off');
      // 안쪽 명소는 틀림없이 땅
      for (final id in ['kr001', 'kr010']) {
        final l = landmarks.firstWhere((l) => l.id == id);
        expect(_on(l.latLng, l.island), isTrue, reason: l.name);
      }
    });

    test('시·군·구 대표 좌표도 모두 자기 섬의 땅이다', () {
      for (final s in sigungu) {
        expect(_on(s.latLng, s.island), isTrue, reason: s.label);
      }
    });
  });

  group('even-odd', () {
    // 투영을 1:1로 두고 (lng, lat)을 그대로 (x, y)처럼 쓰는 가짜 지도
    const proj = MapProjection(
      width: 100,
      height: 100,
      lonOffset: 0,
      pxPerDegLon: 1,
      top: 0,
      latOffset: 100,
      pxPerDegLat: 1,
    );
    MapPoint pt(double x, double y) => MapPoint(x, y);
    // 큰 정사각형(0~100) 안에 구멍(40~60)이 있는 본토 하나, 구멍 안에 섬 고리(45~55)가 또 있다
    final regions = [
      MapRegion(
        id: 'a',
        region: 'capital',
        name: 'a',
        fill: 0xFF000000,
        rings: [
          [pt(0, 0), pt(100, 0), pt(100, 100), pt(0, 100)],
          [pt(40, 40), pt(60, 40), pt(60, 60), pt(40, 60)],
          [pt(45, 45), pt(55, 45), pt(55, 55), pt(45, 55)],
        ],
      ),
    ];
    // y = 100 - lat 이라 (lat, lng) = (100 - y, x)
    LatLng at(double x, double y) => LatLng(100 - y, x);

    test('바깥 고리 안은 땅, 구멍 안은 아님, 구멍 안의 섬 고리는 다시 땅', () {
      expect(onIsland(at(10, 10), Island.mainland, proj, regions), isTrue);
      expect(onIsland(at(50, 42), Island.mainland, proj, regions), isFalse);
      expect(onIsland(at(50, 50), Island.mainland, proj, regions), isTrue);
      expect(onIsland(at(150, 50), Island.mainland, proj, regions), isFalse);
    });

    test('권역이 다르면 섬도 다르다 (jeju는 제주, ulleung은 울릉)', () {
      final sq = [pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10)];
      final rs = [
        MapRegion(id: 'j', region: 'jeju', name: 'j', fill: 0xFF000000, rings: [sq]),
        MapRegion(id: 'u', region: 'ulleung', name: 'u', fill: 0xFF000000, rings: [sq]),
      ];
      final p = at(5, 5);
      expect(onIsland(p, Island.jeju, proj, rs), isTrue);
      expect(onIsland(p, Island.ulleung, proj, rs), isTrue);
      expect(onIsland(p, Island.mainland, proj, rs), isFalse);
      expect(onIsland(p, Island.jeju, proj, [rs[1]]), isFalse);
    });

    test('경계가 없으면 어디도 땅이 아니다', () {
      expect(onIsland(at(5, 5), Island.mainland, proj, const []), isFalse);
    });
  });
}
