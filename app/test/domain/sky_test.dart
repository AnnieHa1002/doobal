import 'package:doobal/domain/geo.dart';
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

DateTime _at(int h, int m) => _day.add(Duration(hours: h, minutes: m));
SkyMix _mix(int h, int m) => skyMixAt(_at(h, m), _sun, rules);
SkyLook _look(int h, int m) => skyLookOf(_mix(h, m), rules);
Celestial _body(int h, int m) => celestialAt(_at(h, m), _sun, rules);

void main() {
  group('skyKeys: 일출 372분 · 일몰 1120분 기준 7개', () {
    test('분: 밤 끝 302 · 새벽 352 · 아침 432 · 낮 522~1000 · 노을 1120 · 밤 1180', () {
      final keys = skyKeys(_sun, rules);
      expect(keys.map((k) => k.minute), [302, 352, 432, 522, 1000, 1120, 1180]);
      expect(keys.map((k) => k.phase), [
        SkyPhase.night,
        SkyPhase.dawn,
        SkyPhase.morning,
        SkyPhase.day,
        SkyPhase.day,
        SkyPhase.sunset,
        SkyPhase.night,
      ]);
    });

    test('한국 어디서든 1년 내내 순서가 맞다 (서울 · 남쪽 끝 · 북쪽 끝 위도)', () {
      const places = [LatLng(37.5776, 126.9769), LatLng(33.1, 126.27), LatLng(38.6, 128.4)];
      for (final p in places) {
        var key = '2026-01-01';
        for (var i = 0; i < 365; i++, key = addDays(key, 1)) {
          final sun = sunTimes(p, key, rules.sunZenithDeg);
          expect(skyKeys(sun, rules), hasLength(7), reason: '$key ${p.lat}');
        }
      }
    });

    test('순서가 뒤집히면 StateError (낮이 너무 짧은 가짜 해)', () {
      final short = SunTimes(_at(12, 0), _at(12, 10));
      expect(() => skyKeys(short, rules), throwsStateError);
    });
  });

  group('skyMixAt', () {
    test('03:00 → 밤에 머문다', () {
      expect(_mix(3, 0), const SkyMix(SkyPhase.night, SkyPhase.night, 0));
    });

    test('05:27 → 밤→새벽 0.5', () {
      final m = _mix(5, 27);
      expect((m.from, m.to), (SkyPhase.night, SkyPhase.dawn));
      expect(m.t, closeTo(0.5, 1e-9));
    });

    test('06:52 → 새벽→아침 0.75', () {
      final m = _mix(6, 52);
      expect((m.from, m.to), (SkyPhase.dawn, SkyPhase.morning));
      expect(m.t, closeTo(0.75, 1e-9));
    });

    test('12:00 → 낮에 머문다 (from == to, t 0)', () {
      expect(_mix(12, 0), const SkyMix(SkyPhase.day, SkyPhase.day, 0));
    });

    test('17:40 → 낮→노을 0.5', () {
      final m = _mix(17, 40);
      expect((m.from, m.to), (SkyPhase.day, SkyPhase.sunset));
      expect(m.t, closeTo(0.5, 1e-9));
    });

    test('19:10 → 노을→밤 0.5', () {
      final m = _mix(19, 10);
      expect((m.from, m.to), (SkyPhase.sunset, SkyPhase.night));
      expect(m.t, closeTo(0.5, 1e-9));
    });

    test('23:00은 밤, 기준점 시각에는 그 단계에서 시작한다', () {
      expect(_mix(23, 0), const SkyMix(SkyPhase.night, SkyPhase.night, 0));
      // 새벽 기준점 05:52 = 새벽→아침 t 0, 마지막 기준점 19:40 = 밤에 머문다
      expect(_mix(5, 52), const SkyMix(SkyPhase.dawn, SkyPhase.morning, 0));
      expect(_mix(19, 40), const SkyMix(SkyPhase.night, SkyPhase.night, 0));
    });

    test('한국 시계로 본다 (UTC 2026-11-17 15:00 = 한국 00:00 → 밤)', () {
      expect(skyMixAt(DateTime.utc(2026, 11, 17, 15), _sun, rules),
          const SkyMix(SkyPhase.night, SkyPhase.night, 0));
    });

    test('dominant: 가까운 쪽, 딱 중간은 to', () {
      expect(const SkyMix(SkyPhase.night, SkyPhase.dawn, 0.49).dominant, SkyPhase.night);
      expect(const SkyMix(SkyPhase.night, SkyPhase.dawn, 0.5).dominant, SkyPhase.dawn);
      expect(const SkyMix(SkyPhase.day, SkyPhase.day, 0).dominant, SkyPhase.day);
    });

    test('값이 같으면 같다', () {
      expect(const SkyMix(SkyPhase.day, SkyPhase.sunset, 0.25),
          const SkyMix(SkyPhase.day, SkyPhase.sunset, 0.25));
      expect(const SkyMix(SkyPhase.day, SkyPhase.sunset, 0.25).hashCode,
          const SkyMix(SkyPhase.day, SkyPhase.sunset, 0.25).hashCode);
      expect(const SkyMix(SkyPhase.day, SkyPhase.sunset, 0.25),
          isNot(const SkyMix(SkyPhase.day, SkyPhase.sunset, 0.5)));
    });
  });

  group('skyLookOf', () {
    test('config의 키는 하늘 5단계 전부다', () {
      expect(rules.skyKeys.keys.toSet(), SkyPhase.values.map((p) => p.name).toSet());
    });

    test('새벽 기준점(05:52)은 새벽 키 색 그대로', () {
      expect(
        _look(5, 52),
        const SkyLook(
          top: 0xFF3E4468,
          mid: 0xFF7C7499,
          horizon: 0xFFD9AFB2,
          glow: 0xFFF2C9A0,
          glowStrength: 0.35,
          stars: 0.4,
        ),
      );
    });

    test('05:27: 밤↔새벽 한가운데. 위쪽 색 채널 반올림, 별 0.7', () {
      final l = _look(5, 27);
      // R (24+62)/2=43 · G (33+68)/2=50.5→51 · B (58+104)/2=81
      expect(l.top, 0xFF2B3351);
      expect(l.stars, closeTo(0.7, 1e-9));
    });

    test('낮은 낮 키 색, 별 없음', () {
      final l = _look(12, 0);
      expect(l.top, 0xFF7FA8C8);
      expect(l.horizon, 0xFFE6E4D4);
      expect(l.stars, 0);
    });

    test('17:40: 낮 0.15 ↔ 노을 0.45 한가운데 빛무리 0.30', () {
      expect(_look(17, 40).glowStrength, closeTo(0.30, 1e-9));
    });

    test('밤은 별 1.0, 결과 색은 항상 불투명', () {
      expect(_look(3, 0).stars, 1.0);
      for (var h = 0; h < 24; h++) {
        final l = _look(h, 30);
        for (final c in [l.top, l.mid, l.horizon, l.glow]) {
          expect(c >> 24, 0xFF);
        }
      }
    });
  });

  group('celestialAt', () {
    test('일출 06:12: 해가 왼쪽 끝에서 뜬다', () {
      final c = _body(6, 12);
      expect(c.body, SkyBody.sun);
      expect(c.progress, closeTo(0, 1e-9));
    });

    test('12:26 (일출·일몰 한가운데): 해 0.5', () {
      final c = _body(12, 26);
      expect(c.body, SkyBody.sun);
      expect(c.progress, closeTo(0.5, 1e-9));
    });

    test('일몰 18:40부터 밤 시작 19:40 전까지는 해도 달도 없고, 빛무리는 진 자리(1)', () {
      for (final (h, m) in [(18, 40), (19, 10), (19, 39)]) {
        final c = _body(h, m);
        expect(c.body, SkyBody.none, reason: '$h:$m');
        expect(c.progress, 1, reason: '$h:$m');
      }
    });

    test('밤 시작 19:40: 달이 왼쪽 끝에서 뜬다', () {
      final c = _body(19, 40);
      expect(c.body, SkyBody.moon);
      expect(c.progress, closeTo(0, 1e-9));
    });

    test('00:00: 달 260/562 (밤 시작~다음 날 밤 끝 562분 중 260분 지남)', () {
      final c = _body(0, 0);
      expect(c.body, SkyBody.moon);
      expect(c.progress, closeTo(260 / 562, 1e-9));
    });

    test('밤 끝 05:02 직전은 달이 거의 다 졌다', () {
      final c = _body(5, 1);
      expect(c.body, SkyBody.moon);
      expect(c.progress, closeTo(561 / 562, 1e-9));
    });

    test('밤 끝 05:02부터 일출 전까지는 해도 달도 없고, 빛무리는 뜰 자리(0)', () {
      for (final (h, m) in [(5, 2), (5, 30), (6, 11)]) {
        final c = _body(h, m);
        expect(c.body, SkyBody.none, reason: '$h:$m');
        expect(c.progress, 0, reason: '$h:$m');
      }
    });

    test('값이 같으면 같다', () {
      expect(const Celestial(SkyBody.sun, 0.5), const Celestial(SkyBody.sun, 0.5));
      expect(const Celestial(SkyBody.sun, 0.5), isNot(const Celestial(SkyBody.moon, 0.5)));
    });
  });
}
