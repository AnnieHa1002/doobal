import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/domain/sky.dart';
import 'package:doobal/domain/sun.dart';
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
  group('sceneLook: 시각·위치 → 하늘 단계·후경·계절', () {
    const seoul = LatLng(37.5776, 126.9769);
    // 한국 시각 → UTC
    DateTime kst(int y, int mo, int d, int h, [int mi = 0]) =>
        DateTime.utc(y, mo, d, h - 9, mi);

    test('서울 11월 한낮 → 낮·capital·가을', () {
      final look = sceneLook(kst(2026, 11, 18, 12), seoul, false, landmarks, rules);
      expect(look.phase, SkyPhase.day);
      expect(look.backdrop, 'capital');
      expect(look.season, Season.autumn);
    });

    test('한밤은 밤, 자정 직전도 밤', () {
      expect(sceneLook(kst(2026, 11, 18, 2), seoul, false, landmarks, rules).phase,
          SkyPhase.night);
      expect(sceneLook(kst(2026, 11, 18, 23, 30), seoul, false, landmarks, rules).phase,
          SkyPhase.night);
    });

    test('일몰 직후는 노을, 일출 직후는 새벽', () {
      final sun = sunTimes(seoul, '2026-11-18', rules.sunZenithDeg);
      final afterSunset = sun.sunset.add(const Duration(minutes: 20));
      expect(sceneLook(afterSunset, seoul, false, landmarks, rules).phase, SkyPhase.sunset);
      final afterRise = sun.sunrise.add(const Duration(minutes: 20));
      expect(sceneLook(afterRise, seoul, false, landmarks, rules).phase, SkyPhase.dawn);
    });

    test('배 구간이면 후경 sea', () {
      final look = sceneLook(kst(2026, 11, 18, 12), seoul, true, landmarks, rules);
      expect(look.backdrop, 'sea');
    });

    test('계절은 한국 날짜 기준 (UTC 2/28 15:30 = 한국 3/1 → 봄, UTC 5/31 14:00 = 한국 5/31 → 봄)', () {
      expect(sceneLook(DateTime.utc(2026, 2, 28, 15, 30), seoul, false, landmarks, rules).season,
          Season.spring);
      expect(sceneLook(DateTime.utc(2026, 5, 31, 14), seoul, false, landmarks, rules).season,
          Season.spring);
      expect(sceneLook(DateTime.utc(2026, 5, 31, 15, 30), seoul, false, landmarks, rules).season,
          Season.summer);
    });

    test('기본 출발지(양구)도 계산된다', () {
      final look = sceneLook(kst(2026, 6, 10, 12), rules.fallbackOrigin, false, landmarks, rules);
      expect(look.phase, SkyPhase.day);
      expect(look.backdrop, 'gangwon');
    });
  });
}
