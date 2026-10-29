import 'package:doobal/domain/sky.dart';
import 'package:doobal/domain/sun.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 한국 2026-11-18, 일출 06:12 · 일몰 18:40
final _day = kstDayStartUtc('2026-11-18');
final _sun = SunTimes(
  _day.add(const Duration(hours: 6, minutes: 12)),
  _day.add(const Duration(hours: 18, minutes: 40)),
);

double _ref(int h, int m) => skyRefHour(_day.add(Duration(hours: h, minutes: m)), _sun);
double _bandX(double ref) => skyBandX(ref, rules.skyBandWidthPx);

void main() {
  group('기준 시각 환산', () {
    test('일출 06:12 → 6시, x 2048', () {
      expect(_ref(6, 12), closeTo(6.0, 1e-9));
      expect(_bandX(_ref(6, 12)), closeTo(2048, 1e-6));
    });

    test('일몰 18:40 → 18시, x 6144', () {
      expect(_ref(18, 40), closeTo(18.0, 1e-9));
      expect(_bandX(_ref(18, 40)), closeTo(6144, 1e-6));
    });

    test('03:06 → 3시, x 1024 (밤 앞쪽 절반)', () {
      expect(_ref(3, 6), closeTo(3.0, 1e-9));
      expect(_bandX(_ref(3, 6)), closeTo(1024, 1e-6));
    });

    test('정오 12:00 → 11.58289', () {
      expect(_ref(12, 0), closeTo(11.58289, 1e-4));
    });

    test('21:20 → 21시, x 7168', () {
      expect(_ref(21, 20), closeTo(21.0, 1e-9));
      expect(_bandX(_ref(21, 20)), closeTo(7168, 1e-6));
    });

    test('00:00 → 0, 24시 직전은 24 미만', () {
      expect(_ref(0, 0), 0);
      expect(_ref(23, 59), lessThan(24));
      expect(_ref(23, 59), greaterThan(23.9));
    });

    test('한국 시계로 본다 (UTC 15:00 = 한국 00:00)', () {
      expect(skyRefHour(DateTime.utc(2026, 11, 17, 15), _sun), 0);
    });
  });

  group('5단계 경계 (잠정값 새벽 5 · 아침 6.5 · 낮 9 · 노을 17 · 밤 19)', () {
    SkyPhase at(double h) => skyPhaseAt(h, rules);

    test('시작 시각은 그 단계에 속한다', () {
      expect(at(5), SkyPhase.dawn);
      expect(at(6.5), SkyPhase.morning);
      expect(at(9), SkyPhase.day);
      expect(at(17), SkyPhase.sunset);
      expect(at(19), SkyPhase.night);
    });

    test('경계 직전은 앞 단계', () {
      expect(at(4.999), SkyPhase.night);
      expect(at(6.499), SkyPhase.dawn);
      expect(at(8.999), SkyPhase.morning);
      expect(at(16.999), SkyPhase.day);
      expect(at(18.999), SkyPhase.sunset);
    });

    test('밤은 자정을 넘어 이어진다', () {
      expect(at(0), SkyPhase.night);
      expect(at(23.99), SkyPhase.night);
    });
  });
}
