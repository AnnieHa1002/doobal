import 'package:doobal/domain/map_first_view.dart';
import 'package:doobal/domain/map_projection.dart';
import 'package:doobal/domain/map_regions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 실제 명소 101곳의 캔버스 px
final _points = [for (final l in landmarks) mapProjection.project(l.latLng)];

/// 지도 전체 경계 (시도 경계 상자의 합)
final _bounds = boundsOf(mapRegions);

// 390×844 폰 기준: 영역 가로 358pt, 세로 약 470pt ÷ 기본 배율(390/2048)
const _base = 390 / 2048;
const _viewW = 358 / _base;
const _viewH = 470 / _base;

MapFirstView _view(MapPoint at, {List<MapPoint>? lms}) => mapFirstView(
      current: at,
      landmarks: lms ?? _points,
      bounds: _bounds,
      viewW: _viewW,
      viewH: _viewH,
      minCount: rules.mapFirstViewMinLandmarks,
      margin: rules.mapFirstViewMargin,
    );

MapRect _visible(MapFirstView v) => MapRect(
      v.center.x - _viewW / v.zoom / 2,
      v.center.y - _viewH / v.zoom / 2,
      v.center.x + _viewW / v.zoom / 2,
      v.center.y + _viewH / v.zoom / 2,
    );

void main() {
  group('지도 첫 보기', () {
    test('실제 명소 101곳: 어느 명소에서 시작해도 3곳 이상 보이고 현재 위치가 화면 안', () {
      for (final l in landmarks) {
        final at = mapProjection.project(l.latLng);
        final v = _view(at);
        final seen = _points.where(_visible(v).contains).length;
        expect(seen, greaterThanOrEqualTo(3), reason: l.name);
        expect(_visible(v).contains(at), isTrue, reason: l.name);
        expect(v.zoom, inInclusiveRange(1, 6), reason: l.name);
      }
    });

    test('섬·끝 위치(제주, 울릉도 등)에서도 보이는 범위가 지도 경계 밖으로 안 나간다', () {
      for (final l in landmarks) {
        final v = _view(mapProjection.project(l.latLng));
        final r = _visible(v);
        // 범위가 경계보다 작을 때만 안쪽에 있어야 한다 (크면 가운데)
        if (r.width <= _bounds.width) {
          expect(r.left, greaterThanOrEqualTo(_bounds.left - 1e-6), reason: l.name);
          expect(r.right, lessThanOrEqualTo(_bounds.right + 1e-6), reason: l.name);
        }
        if (r.height <= _bounds.height) {
          expect(r.top, greaterThanOrEqualTo(_bounds.top - 1e-6), reason: l.name);
          expect(r.bottom, lessThanOrEqualTo(_bounds.bottom + 1e-6), reason: l.name);
        }
      }
    });

    test('명소가 촘촘한 곳은 더 확대하고, 드문 곳은 덜 확대한다', () {
      final seoul = mapProjection.project(landmarks.firstWhere((l) => l.id == 'kr001').latLng);
      final jeju = mapProjection.project(landmarks.firstWhere((l) => l.region == 'jeju').latLng);
      expect(_view(seoul).zoom, greaterThan(_view(jeju).zoom));
    });

    test('명소가 하나도 없으면 배율 1', () {
      final v = _view(const MapPoint(1000, 1200), lms: const []);
      expect(v.zoom, 1);
    });

    test('명소가 2곳뿐이면 2곳이 보이면 된다', () {
      const at = MapPoint(1000, 1200);
      final v = _view(at, lms: const [MapPoint(1010, 1210), MapPoint(1100, 1300)]);
      expect(_visible(v).contains(const MapPoint(1100, 1300)), isTrue);
    });

    test('같은 입력은 같은 결과', () {
      final at = mapProjection.project(landmarks[10].latLng);
      final a = _view(at);
      final b = _view(at);
      expect(a.zoom, b.zoom);
      expect(a.center, b.center);
    });
  });
}
