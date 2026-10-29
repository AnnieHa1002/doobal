import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/sun.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _seoul = LatLng(37.5665, 126.978);

/// 한국 시계 시:분의 그날 0시부터 분
double _kstMinutes(DateTime utc) =>
    utc.difference(kstDayStartUtc(kstDayKey(utc))).inSeconds / 60;

void _expectKst(DateTime actual, String key, int h, int m) {
  expect(kstDayKey(actual), key);
  // KASI 값과 ±2분
  expect(_kstMinutes(actual), closeTo(h * 60 + m, 2));
}

void main() {
  test('서울 하지 2026-06-21: 일출 05:11, 일몰 19:57 (KASI)', () {
    final s = sunTimes(_seoul, '2026-06-21', rules.sunZenithDeg);
    _expectKst(s.sunrise, '2026-06-21', 5, 11);
    _expectKst(s.sunset, '2026-06-21', 19, 57);
  });

  test('서울 동지 2026-12-22: 일출 07:43, 일몰 17:17 (KASI)', () {
    final s = sunTimes(_seoul, '2026-12-22', rules.sunZenithDeg);
    _expectKst(s.sunrise, '2026-12-22', 7, 43);
    _expectKst(s.sunset, '2026-12-22', 17, 17);
  });

  test('일출은 전날 UTC로 나오지만 한국 날짜는 입력과 같다', () {
    final s = sunTimes(_seoul, '2026-06-21', rules.sunZenithDeg);
    expect(s.sunrise.isUtc, isTrue);
    expect(s.sunrise.day, 20);
    expect(kstDayKey(s.sunrise), '2026-06-21');
    expect(s.sunrise.isBefore(s.sunset), isTrue);
  });

  test('극야·백야 위도는 StateError', () {
    expect(() => sunTimes(const LatLng(80, 0), '2026-06-21', rules.sunZenithDeg),
        throwsStateError);
  });
}
