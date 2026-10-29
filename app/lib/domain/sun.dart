import 'dart:math' as math;

import 'geo.dart';
import 'time_kst.dart';

/// 그날의 일출·일몰 (UTC)
class SunTimes {
  const SunTimes(this.sunrise, this.sunset);

  final DateTime sunrise;
  final DateTime sunset;
}

/// 한국 날짜(kstDayKey) 하루의 일출·일몰. NOAA "General Solar Position Calculations".
/// 분은 그 날짜의 UTC 0시 기준이라 한국의 일출은 음수(전날 UTC)로 나오는데 맞는 값이다.
/// 한국에는 극야·백야가 없어서 범위를 벗어나면 StateError
SunTimes sunTimes(LatLng p, String kstDayKey, double zenithDeg) {
  final day = dayFromKey(kstDayKey);
  final dayOfYear = day.difference(DateTime.utc(day.year, 1, 1)).inDays + 1;
  final daysInYear = DateTime.utc(day.year + 1, 1, 1).difference(DateTime.utc(day.year, 1, 1)).inDays;
  // 정오 기준 분수 연도(rad). 윤년은 366
  final g = 2 * math.pi / daysInYear * (dayOfYear - 1);

  // 균시차(분)와 태양 적위(rad)
  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(g) -
          0.032077 * math.sin(g) -
          0.014615 * math.cos(2 * g) -
          0.040849 * math.sin(2 * g));
  final decl = 0.006918 -
      0.399912 * math.cos(g) +
      0.070257 * math.sin(g) -
      0.006758 * math.cos(2 * g) +
      0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) +
      0.00148 * math.sin(3 * g);

  final lat = _rad(p.lat);
  final cosHa = math.cos(_rad(zenithDeg)) / (math.cos(lat) * math.cos(decl)) -
      math.tan(lat) * math.tan(decl);
  if (cosHa < -1 || cosHa > 1) {
    throw StateError('해가 뜨고 지지 않는 날: ${p.lat}, $kstDayKey');
  }
  final haDeg = math.acos(cosHa) * 180 / math.pi;

  DateTime at(double minutes) =>
      day.add(Duration(microseconds: (minutes * Duration.microsecondsPerMinute).round()));
  return SunTimes(
    at(720 - 4 * (p.lng + haDeg) - eqTime),
    at(720 - 4 * (p.lng - haDeg) - eqTime),
  );
}

double _rad(double deg) => deg * math.pi / 180;
