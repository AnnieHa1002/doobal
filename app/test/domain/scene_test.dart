import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('계절', () {
    test('3월 1일 봄, 2월 28일 겨울', () {
      expect(seasonOf('2026-03-01', rules), Season.spring);
      expect(seasonOf('2026-02-28', rules), Season.winter);
    });

    test('12월 1일 겨울, 11월 30일 가을', () {
      expect(seasonOf('2026-12-01', rules), Season.winter);
      expect(seasonOf('2026-11-30', rules), Season.autumn);
    });

    test('여름·1월', () {
      expect(seasonOf('2026-06-01', rules), Season.summer);
      expect(seasonOf('2027-01-15', rules), Season.winter);
    });
  });

  group('후경', () {
    // 경복궁 근처
    const nearGyeongbok = LatLng(37.5776, 126.9769);

    test('경복궁 옆 → 가장 가까운 명소 경복궁, 후경 capital', () {
      final l = nearestLandmark(nearGyeongbok, landmarks, rules.earthRadiusKm);
      expect(l.id, 'kr001');
      expect(backdropAt(const RoutePosition(nearGyeongbok, 0, false), landmarks, rules),
          'capital');
    });

    test('배 구간이면 어디든 sea', () {
      expect(backdropAt(const RoutePosition(nearGyeongbok, 0, true), landmarks, rules),
          'sea');
      expect(backdropAt(RoutePosition(rules.ports['wando']!, 1, true), landmarks, rules),
          'sea');
    });

    test('울릉도 명소 옆은 명소 데이터대로 sea', () {
      final ulleung = landmarks.firstWhere((l) => l.backdrop == seaBackdrop);
      expect(backdropAt(RoutePosition(ulleung.latLng, 0, false), landmarks, rules), 'sea');
    });

    test('명소가 없으면 StateError', () {
      expect(() => nearestLandmark(nearGyeongbok, const [], rules.earthRadiusKm),
          throwsStateError);
    });
  });
}
