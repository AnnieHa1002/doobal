import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/map_projection.dart';
import 'package:doobal/domain/map_regions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('투영 JSON에서 캔버스 크기와 계수를 읽는다', () {
    expect(mapProjection.width, 2048);
    expect(mapProjection.height, 2560);
    expect(mapProjection.lonOffset, 124.5);
    expect(mapProjection.pxPerDegLon, 315.0769);
    expect(mapProjection.top, 170.05);
    expect(mapProjection.latOffset, 38.7);
    expect(mapProjection.pxPerDegLat, 389.4565);
  });

  test('경복궁 (37.57761, 126.9769) → 약 (780.42, 607.17)', () {
    final p = mapProjection.project(const LatLng(37.57761, 126.9769));
    expect(p.x, closeTo(780.42, 0.01));
    expect(p.y, closeTo(607.17, 0.01));
  });

  test('왼쪽 위 끝 (38.7, 124.5)은 (0, 170.05), 위도가 내려가면 y가 커지고 경도가 커지면 x가 커진다', () {
    final origin = mapProjection.project(const LatLng(38.7, 124.5));
    expect(origin, const MapPoint(0, 170.05));
    final south = mapProjection.project(const LatLng(37.7, 124.5));
    expect(south.x, 0);
    expect(south.y, closeTo(170.05 + 389.4565, 1e-9));
    final east = mapProjection.project(const LatLng(38.7, 125.5));
    expect(east.x, closeTo(315.0769, 1e-9));
    expect(east.y, 170.05);
  });

  test('MapPoint는 값이 같으면 같다', () {
    expect(const MapPoint(1, 2), const MapPoint(1, 2));
    expect(const MapPoint(1, 2).hashCode, const MapPoint(1, 2).hashCode);
    expect(const MapPoint(1, 2), isNot(const MapPoint(1, 3)));
  });

  test('명소 101곳이 모두 캔버스 안에 들어가고, 자기 권역 경계 상자 안에 있다', () {
    expect(landmarks, hasLength(101));
    for (final l in landmarks) {
      final p = mapProjection.project(l.latLng);
      expect(p.x, inInclusiveRange(0, mapProjection.width), reason: l.name);
      expect(p.y, inInclusiveRange(0, mapProjection.height), reason: l.name);
      final box = boundsOf(mapRegions.where((r) => r.region == l.region));
      expect(box.contains(p), isTrue, reason: '${l.name} ${l.region} $p');
    }
  });
}
