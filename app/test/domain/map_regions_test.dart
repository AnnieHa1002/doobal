import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/map_projection.dart';
import 'package:doobal/domain/map_regions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

String _svg(String attrs, String d) => '<svg><g><path $attrs d="$d"/></g></svg>';

const _attrs = 'id="a" data-region="capital" data-name="가" fill="#E8DAC0"';

void main() {
  group('실제 SVG', () {
    test('경계 18개 (17 시도 + 울릉도)', () {
      expect(mapRegions, hasLength(18));
      expect(mapRegions.map((r) => r.id), containsAll(['seoul', 'ulleung', 'jeju', 'busan']));
      expect({for (final r in mapRegions) r.id}, hasLength(18));
    });

    test('권역 값은 7개 키뿐', () {
      expect({for (final r in mapRegions) r.region},
          {'capital', 'gangwon', 'chungcheong', 'jeolla', 'gyeongsang', 'jeju', 'ulleung'});
      final byRegion = <String, List<String>>{};
      for (final r in mapRegions) {
        byRegion.putIfAbsent(r.region, () => []).add(r.id);
      }
      expect(byRegion['capital'], unorderedEquals(['gyeonggi', 'incheon', 'seoul']));
      expect(byRegion['chungcheong'],
          unorderedEquals(['chungbuk', 'chungnam', 'daejeon', 'sejong']));
      expect(byRegion['gyeongsang'],
          unorderedEquals(['busan', 'daegu', 'gyeongbuk', 'gyeongnam', 'ulsan']));
    });

    test('이름·색·고리를 읽는다', () {
      final busan = mapRegions.singleWhere((r) => r.id == 'busan');
      expect(busan.name, '부산광역시');
      expect(busan.fill, 0xFFE8DAC0);
      expect(busan.rings, hasLength(1));
      // 전남은 섬이 많아서 고리가 여러 개
      expect(mapRegions.singleWhere((r) => r.id == 'jeonnam').rings.length, greaterThan(10));
      for (final r in mapRegions) {
        expect(r.rings, isNotEmpty, reason: r.id);
        for (final ring in r.rings) {
          expect(ring.length, greaterThanOrEqualTo(3), reason: r.id);
        }
      }
    });

    test('경복궁의 투영점은 서울 경계 상자 안', () {
      final seoul = boundsOf(mapRegions.where((r) => r.id == 'seoul'));
      final p = mapProjection.project(landmarks.firstWhere((l) => l.name == '경복궁').latLng);
      expect(seoul.contains(p), isTrue);
    });

    test('울릉도 경계 상자는 x 1983~2023 / y 619~654', () {
      final b = boundsOf(mapRegions.where((r) => r.region == 'ulleung'));
      expect(b.left, closeTo(1983, 1));
      expect(b.right, closeTo(2023, 1));
      expect(b.top, closeTo(619, 1));
      expect(b.bottom, closeTo(654, 1));
    });

    test('전체 경계 상자는 캔버스 안, 권역 상자는 전체 안', () {
      final all = boundsOf(mapRegions);
      expect(all.left, greaterThanOrEqualTo(0));
      expect(all.top, greaterThanOrEqualTo(0));
      expect(all.right, lessThanOrEqualTo(mapProjection.width));
      expect(all.bottom, lessThanOrEqualTo(mapProjection.height));
      for (final key in ['capital', 'gangwon', 'chungcheong', 'jeolla', 'gyeongsang', 'jeju']) {
        final b = boundsOf(mapRegions.where((r) => r.region == key));
        expect(b.left, greaterThanOrEqualTo(all.left), reason: key);
        expect(b.right, lessThanOrEqualTo(all.right), reason: key);
        expect(b.top, greaterThanOrEqualTo(all.top), reason: key);
        expect(b.bottom, lessThanOrEqualTo(all.bottom), reason: key);
      }
    });
  });

  group('parseMapRegions', () {
    test('쉼표·공백, M 뒤의 좌표 쌍(암묵 L), 여러 부분 경로', () {
      final r =
          parseMapRegions(_svg(_attrs, 'M0,0 L10 0 L10,10Z M20 20 30 20 30 30 20 30Z')).single;
      expect(r.rings, hasLength(2));
      expect(r.rings[0], [const MapPoint(0, 0), const MapPoint(10, 0), const MapPoint(10, 10)]);
      // M 뒤 둘째 쌍부터는 L로 이어진다
      expect(r.rings[1], [
        const MapPoint(20, 20),
        const MapPoint(30, 20),
        const MapPoint(30, 30),
        const MapPoint(20, 30),
      ]);
    });

    test('닫지 않은 경로도 다음 M이나 끝에서 고리가 된다', () {
      final r = parseMapRegions(_svg(_attrs, 'M0 0L5 5L9 1M20 20L25 25L29 21')).single;
      expect(r.rings, hasLength(2));
      expect(r.rings[1].first, const MapPoint(20, 20));
    });

    test('소수와 음수를 읽는다', () {
      final r = parseMapRegions(_svg(_attrs, 'M1.5-2.25L-3 4.5Z')).single;
      expect(r.rings.single, [const MapPoint(1.5, -2.25), const MapPoint(-3, 4.5)]);
    });

    test('path가 여러 개면 순서대로, path가 없으면 빈 목록', () {
      final svg =
          '<svg><path id="a" data-region="capital" data-name="가" fill="#000001" d="M0 0L1 1Z"/>'
          '<path id="b" data-region="jeju" data-name="나" fill="#FFFFFF" d="M2 2L3 3Z"/></svg>';
      final rs = parseMapRegions(svg);
      expect(rs.map((r) => r.id), ['a', 'b']);
      expect(rs[0].fill, 0xFF000001);
      expect(rs[1].fill, 0xFFFFFFFF);
      expect(parseMapRegions('<svg></svg>'), isEmpty);
    });

    test('M·L·Z 말고 다른 명령은 FormatException', () {
      const bad = ['M0 0C1 1 2 2 3 3Z', 'M0 0H5Z', 'M0 0l5 5Z', 'm0 0L5 5Z', 'M0 0A1 1 0 0 1 2 2Z'];
      for (final d in bad) {
        expect(() => parseMapRegions(_svg(_attrs, d)), throwsFormatException, reason: d);
      }
    });

    test('좌표가 맞지 않거나 M 없이 시작하면 FormatException', () {
      for (final d in ['M0 0L5Z', 'M0L5 5Z', 'L0 0L5 5Z', '0 0L5 5Z', 'M0 0Z 3 3', 'M']) {
        expect(() => parseMapRegions(_svg(_attrs, d)), throwsFormatException, reason: d);
      }
    });

    test('속성이 빠졌거나 색 형식이 다르면 FormatException', () {
      expect(() => parseMapRegions('<path id="a" data-region="x" fill="#000000" d="M0 0Z"/>'),
          throwsFormatException);
      expect(
          () => parseMapRegions(
              '<path id="a" data-region="x" data-name="n" fill="red" d="M0 0L1 1Z"/>'),
          throwsFormatException);
      expect(
          () => parseMapRegions('<path id="a" data-region="x" data-name="n" fill="#000000"/>'),
          throwsFormatException);
    });

    test('boundsOf: 모든 고리의 점을 담고, 비어 있으면 StateError', () {
      final rs = parseMapRegions(_svg(_attrs, 'M0 5L10 0L10 10ZM-4 2L3 3L2 20Z'));
      final b = boundsOf(rs);
      expect((b.left, b.top, b.right, b.bottom), (-4.0, 0.0, 10.0, 20.0));
      expect(b.width, 14);
      expect(b.height, 20);
      expect(b.center, const MapPoint(3, 10));
      expect(() => boundsOf(const []), throwsStateError);
    });
  });

  group('regionProgress', () {
    test('권역별 명소 수: 수도권 12·강원 17·충청 17·전라 21·경상 31·제주 2·울릉 1', () {
      final p = regionProgress({}, landmarks);
      expect({for (final e in p.entries) e.key: e.value.total}, {
        'capital': 12,
        'gangwon': 17,
        'chungcheong': 17,
        'jeolla': 21,
        'gyeongsang': 31,
        'jeju': 2,
        'ulleung': 1,
      });
      expect(p.values.every((v) => v.visited == 0), isTrue);
    });

    test('다녀온 곳만 센다', () {
      final gyeongsang = landmarks.where((l) => l.region == 'gyeongsang').toList();
      final visited = {
        ...gyeongsang.take(4).map((l) => l.id),
        landmarks.firstWhere((l) => l.region == 'ulleung').id,
        'kr-없는-곳',
      };
      final p = regionProgress(visited, landmarks);
      expect(p['gyeongsang'], (visited: 4, total: 31));
      expect(p['ulleung'], (visited: 1, total: 1));
      expect(p['capital'], (visited: 0, total: 12));
    });

    test('명소가 없는 권역은 항목이 없다', () {
      expect(regionProgress({}, const []), isEmpty);
    });
  });
}
