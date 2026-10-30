import 'dart:convert';

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

String _id(int i) => i.toRadixString(16).padLeft(32, '0');

double _km(LatLng a, LatLng b) => haversineKm(a, b, rules.earthRadiusKm);

LatLng _dest(String installId, {bool Function(LatLng)? ok, LatLng home = testHome}) =>
    sketchDestination(
      home: home,
      installId: installId,
      minKm: rules.firstSketchMinKm,
      maxKm: rules.firstSketchMaxKm,
      earthRadiusKm: rules.earthRadiusKm,
      ok: ok ?? (_) => true,
    );

void main() {
  test('config의 범위는 2~3km', () {
    expect((rules.firstSketchMinKm, rules.firstSketchMaxKm), (2, 3));
  });

  group('sketchDestination', () {
    test('같은 설치 번호면 늘 같은 점', () {
      expect(_dest(_id(7)), _dest(_id(7)));
      // 다른 설치는 (거의 틀림없이) 다른 점
      expect(_dest(_id(7)), isNot(_dest(_id(8))));
    });

    test('출발 동네에서 2~3km 안, 설치 번호가 달라도', () {
      final distances = [for (var i = 0; i < 300; i++) _km(testHome, _dest(_id(i)))];
      for (final d in distances) {
        expect(d, inInclusiveRange(2 - 1e-6, 3 + 1e-6));
      }
      // 범위 전체에 퍼진다 (한쪽에 몰려 있지 않다)
      expect(distances.reduce((a, b) => a < b ? a : b), lessThan(2.2));
      expect(distances.reduce((a, b) => a > b ? a : b), greaterThan(2.8));
    });

    test('방향도 사방으로 퍼진다', () {
      final quadrants = <int>{};
      for (var i = 0; i < 100; i++) {
        final p = _dest(_id(i));
        quadrants.add((p.lat >= testHome.lat ? 1 : 0) + (p.lng >= testHome.lng ? 2 : 0));
      }
      expect(quadrants, {0, 1, 2, 3});
    });

    test('ok가 첫 방향을 거절하면 90° 돌린 점 (같은 거리)', () {
      final first = _dest(_id(3));
      final turned = _dest(_id(3), ok: (p) => p != first);
      expect(turned, isNot(first));
      final d = _km(testHome, first);
      expect(_km(testHome, turned), closeTo(d, 1e-6));
      // 같은 거리에서 90° 벌어진 두 점 사이는 약 d × √2
      expect(_km(first, turned), closeTo(d * 1.41421, 0.01));
    });

    test('둘째·셋째까지 거절하면 180°, 270°를 차례로', () {
      final seen = <LatLng>[];
      _dest(_id(3), ok: (p) {
        seen.add(p);
        return seen.length == 4;
      });
      expect(seen, hasLength(4));
      final d = _km(testHome, seen[0]);
      expect(_km(seen[0], seen[1]), closeTo(d * 1.41421, 0.01));
      // 맞은편은 2d
      expect(_km(seen[0], seen[2]), closeTo(2 * d, 0.01));
      expect(_km(seen[1], seen[3]), closeTo(2 * d, 0.01));
      expect(_dest(_id(3), ok: (p) => p == seen[3]), seen[3]);
    });

    test('넷 다 거절하면 첫 후보', () {
      final first = _dest(_id(3));
      var calls = 0;
      final p = _dest(_id(3), ok: (_) {
        calls++;
        return false;
      });
      expect(p, first);
      expect(calls, 4);
    });

    test('범위가 한 값이면 그 거리', () {
      final p = sketchDestination(
        home: testHome,
        installId: _id(1),
        minKm: 2.5,
        maxKm: 2.5,
        earthRadiusKm: rules.earthRadiusKm,
        ok: (_) => true,
      );
      expect(_km(testHome, p), closeTo(2.5, 1e-6));
    });
  });

  group('destinationPoint', () {
    test('북쪽 1도는 약 111.2km, 방위가 90°면 위도가 거의 그대로', () {
      final north = destinationPoint(testHome, 0, 111.195, rules.earthRadiusKm);
      expect(north.lat, closeTo(testHome.lat + 1, 0.001));
      expect(north.lng, closeTo(testHome.lng, 1e-9));
      final east = destinationPoint(testHome, 90, 2, rules.earthRadiusKm);
      expect(east.lat, closeTo(testHome.lat, 0.001));
      expect(east.lng, greaterThan(testHome.lng));
      expect(_km(testHome, east), closeTo(2, 1e-9));
    });
  });

  group('sketchLandmark', () {
    test('가장 가까운 명소의 지역 값을 가져오고 명소 목록 필드는 비운다', () {
      final nearest = landmarks.firstWhere((l) => l.id == 'kr001');
      const point = LatLng(37.58, 126.99);
      final l = sketchLandmark(point, nearest);
      expect((l.id, l.name), (sketchId, '내 동네 스케치'));
      expect((l.sido, l.sigungu, l.region), (nearest.sido, nearest.sigungu, nearest.region));
      expect((l.backdrop, l.terrain, l.island),
          (nearest.backdrop, nearest.terrain, nearest.island));
      expect(l.types, isEmpty);
      expect(l.painting, '');
      expect(l.latLng, point);
    });

    test('id는 명소 id와 겹치지 않는다', () {
      expect(landmarks.map((l) => l.id), isNot(contains(sketchId)));
    });
  });

  group('sketchSteps', () {
    test('남은 거리를 보폭으로 걸음 수로 바꿔 100보 단위로 반올림', () {
      // 2.5km ÷ 0.7m = 3,571보 → 3,600
      expect(sketchSteps(2.5, rules), 3600);
      // 2.0km → 2,857보 → 2,900, 3.0km → 4,286보 → 4,300
      expect(sketchSteps(2.0, rules), 2900);
      expect(sketchSteps(3.0, rules), 4300);
      expect(sketchSteps(0, rules), 0);
    });
  });

  group('Sketch', () {
    final sketch = Sketch(
      point: const LatLng(37.58, 126.99),
      arrivedAt: DateTime.utc(2026, 11, 18, 3, 20),
      backdrop: 'capital',
      look: const Look(hair: 3, hairColor: SwatchHairColor(5)),
    );

    test('JSON은 lat·lng·arrivedUtc·backdrop·look', () {
      expect(sketch.toJson(), {
        'lat': 37.58,
        'lng': 126.99,
        'arrivedUtc': DateTime.utc(2026, 11, 18, 3, 20).millisecondsSinceEpoch,
        'backdrop': 'capital',
        'look': {'hair': 3, 'hairColor': {'kind': 'swatch', 'i': 5}},
      });
    });

    test('글자로 바꿨다 되돌려도 같다', () {
      expect(Sketch.decode(sketch.encode()), sketch);
      expect(jsonDecode(sketch.encode()), sketch.toJson());
    });

    test('깨진 값은 FormatException', () {
      const bad = '{"lat":1,"lng":2,"arrivedUtc":3,"backdrop":"x","look":{"hair":9}}';
      expect(() => Sketch.decode(bad), throwsFormatException);
    });
  });
}
