import 'dart:ui';

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/map/map_geometry.dart';
import 'package:doobal/ui/map/map_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

final _geometry = MapGeometry(projection: mapProjection, regions: mapRegions, landmarks: landmarks);

double _pathLength(Path p) => p.computeMetrics().fold(0.0, (sum, m) => sum + m.length);

void main() {
  group('MapGeometry', () {
    test('시도마다 경로가 있고 even-odd, 경복궁은 서울 경로 안 · 부산 경로 밖', () {
      expect(_geometry.regionPaths, hasLength(18));
      expect(_geometry.regionPaths.every((p) => p.fillType == PathFillType.evenOdd), isTrue);
      final seoul = mapRegions.indexWhere((r) => r.id == 'seoul');
      final busan = mapRegions.indexWhere((r) => r.id == 'busan');
      final p = _geometry.landmarkPoints['kr001']!;
      expect(_geometry.regionPaths[seoul].contains(p), isTrue);
      expect(_geometry.regionPaths[busan].contains(p), isFalse);
    });

    test('명소 101곳의 좌표는 투영과 같고, byId로 찾는다', () {
      expect(_geometry.landmarkPoints, hasLength(101));
      final k = landmarks.first;
      final want = mapProjection.project(k.latLng);
      expect(_geometry.landmarkPoints[k.id], Offset(want.x, want.y));
      expect(_geometry.byId[k.id], same(k));
    });

    test('권역 경계 상자와 전체 상자, 화면 너비에 맞춘 배율', () {
      expect(_geometry.boundsOfRegion('jeju').height, lessThan(_geometry.bounds.height));
      expect(_geometry.boundsOfRegion('ulleung').width, lessThan(60));
      expect(_geometry.baseScale(390), 390 / 2048);
      expect(_geometry.baseScale(2048), 1);
    });

    test('명소의 지형·권역은 라벨 표에 모두 있다', () {
      for (final l in landmarks) {
        expect(terrainLabels.keys, contains(l.terrain), reason: l.name);
        expect(regionLabels.keys, contains(l.region), reason: l.name);
      }
    });
  });

  group('nearestLandmark', () {
    final points = {'a': const Offset(100, 100), 'b': const Offset(130, 100)};

    test('가장 가까운 명소', () {
      expect(nearestLandmark(const Offset(110, 100), points, base: 1, zoom: 1), 'a');
      expect(nearestLandmark(const Offset(120, 100), points, base: 1, zoom: 1), 'b');
    });

    test('화면 24pt 밖이면 null, 경계 24pt는 포함', () {
      expect(nearestLandmark(const Offset(100, 124), points, base: 1, zoom: 1), 'a');
      expect(nearestLandmark(const Offset(100, 125), points, base: 1, zoom: 1), isNull);
    });

    test('확대하면 같은 child 거리가 화면에서 더 멀다 (24pt는 화면 기준)', () {
      const tap = Offset(100, 112);
      expect(nearestLandmark(tap, points, base: 1, zoom: 1), 'a');
      expect(nearestLandmark(tap, points, base: 1, zoom: 2), 'a');
      expect(nearestLandmark(tap, points, base: 1, zoom: 3), isNull);
      // 줄이면(작은 zoom) 더 넓게 잡힌다
      expect(nearestLandmark(const Offset(100, 140), points, base: 1, zoom: 0.5), 'a');
    });

    test('base: 캔버스 px를 child pt로 줄여서 잰다', () {
      // 캔버스 (1000, 1000)은 base 0.5에서 child (500, 500)
      final p = {'x': const Offset(1000, 1000)};
      expect(nearestLandmark(const Offset(510, 500), p, base: 0.5, zoom: 1), 'x');
      expect(nearestLandmark(const Offset(540, 500), p, base: 0.5, zoom: 1), isNull);
    });

    test('실제 명소: 경복궁 근처 12pt는 경복궁, 서해 바다는 null', () {
      const base = 390 / 2048;
      final k = _geometry.landmarkPoints['kr001']!;
      expect(
        nearestLandmark(k * base + const Offset(8, 8), _geometry.landmarkPoints,
            base: base, zoom: 1),
        'kr001',
      );
      expect(
        nearestLandmark(const Offset(100, 1000) * base, _geometry.landmarkPoints,
            base: base, zoom: 1),
        isNull,
      );
    });
  });

  group('dashedPath', () {
    test('곧은 선: 선 10 · 빈 10이면 100 길이에 선이 50', () {
      final p = dashedPath(const [Offset(0, 0), Offset(100, 0)], 10, 10);
      expect(_pathLength(p), closeTo(50, 1e-6));
      expect(p.computeMetrics().length, 5);
    });

    test('꺾인 선도 조각이 이어서 센다 (총 길이 100, 선 10 · 빈 5 → 선 70)', () {
      final p = dashedPath(const [Offset(0, 0), Offset(60, 0), Offset(60, 40)], 10, 5);
      // 15 단위 주기마다 선 10: 100 = 6주기(90) + 10 → 선 60 + 10
      expect(_pathLength(p), closeTo(70, 1e-6));
    });

    test('점이 하나 이하이거나 길이 0이면 빈 경로', () {
      expect(_pathLength(dashedPath(const [Offset(1, 1)], 10, 5)), 0);
      expect(_pathLength(dashedPath(const [Offset(1, 1), Offset(1, 1)], 10, 5)), 0);
      expect(_pathLength(dashedPath(const [], 10, 5)), 0);
    });
  });

  group('MapPainter', () {
    final data = MapData(
      visited: const {'kr001': Frame.gold, 'kr003': Frame.wood},
      paths: const [
        [LatLng(37.5665, 126.978), LatLng(36.37, 127.38)],
      ],
      destId: 'kr002',
      position: const LatLng(37.0, 127.0),
      fundKm: 0,
    );

    MapPainter painter({String? selected = 'kr001', double zoom = 1, MapData? d, MapGeometry? g}) =>
        MapPainter(geometry: g ?? _geometry, data: d ?? data, selectedId: selected, zoom: zoom);

    test('여러 확대 배율과 선택 상태로 그려도 오류가 없다', () {
      for (final zoom in [1.0, 2.5, 6.0]) {
        for (final selected in [null, 'kr001', 'kr002', 'kr003', 'kr050']) {
          final recorder = PictureRecorder();
          painter(selected: selected, zoom: zoom).paint(Canvas(recorder), const Size(390, 487.5));
          recorder.endRecording().dispose();
        }
      }
      // 위치가 없고 목적지도 없는 상태
      final recorder = PictureRecorder();
      painter(
        d: const MapData(visited: {}, paths: [], destId: null, position: null, fundKm: 0),
      ).paint(Canvas(recorder), const Size(390, 487.5));
      recorder.endRecording().dispose();
    });

    test('shouldRepaint: 확대·선택·데이터가 바뀔 때만', () {
      final base = painter();
      expect(base.shouldRepaint(painter()), isFalse);
      expect(base.shouldRepaint(painter(zoom: 1.5)), isTrue);
      expect(base.shouldRepaint(painter(selected: 'kr002')), isTrue);
      expect(base.shouldRepaint(painter(selected: null)), isTrue);
      expect(
        base.shouldRepaint(painter(
          d: const MapData(visited: {}, paths: [], destId: null, position: null, fundKm: 0),
        )),
        isTrue,
      );
      expect(
        base.shouldRepaint(painter(
          g: MapGeometry(projection: mapProjection, regions: mapRegions, landmarks: landmarks),
        )),
        isTrue,
      );
    });
  });
}
