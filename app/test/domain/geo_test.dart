import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('#14 kstDayKey는 한국 자정 기준', () {
    expect(kstDayKey(DateTime.utc(2026, 11, 17, 15)), '2026-11-18');
    expect(kstDayKey(DateTime.utc(2026, 11, 17, 14, 59)), '2026-11-17');
  });

  test('kstDate는 한국 날짜를 UTC 0시로 나타낸다 (자정 직전·직후)', () {
    expect(kstDate(DateTime.utc(2026, 11, 17, 14, 59)), DateTime.utc(2026, 11, 17));
    // UTC 15:00 = 한국 다음 날 00:00
    expect(kstDate(DateTime.utc(2026, 11, 17, 15)), DateTime.utc(2026, 11, 18));
    expect(kstDate(DateTime.utc(2026, 12, 31, 20)), DateTime.utc(2027, 1, 1));
  });

  test('#15 경복궁 → 독립기념관 90.93km', () {
    const gyeongbok = LatLng(37.57761, 126.9769);
    const independence = LatLng(36.78367, 127.22281);
    expect(haversineKm(gyeongbok, independence, rules.earthRadiusKm), closeTo(90.93, 0.01));
  });

  test('#19 항구의 섬 판정', () {
    expect(islandOf(rules.ports['jeju']!, rules.islands), Island.jeju);
    expect(islandOf(rules.ports['dodong']!, rules.islands), Island.ulleung);
    expect(islandOf(rules.ports['wando']!, rules.islands), Island.mainland);
  });
}
