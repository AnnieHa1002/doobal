import 'package:doobal/domain/eta.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/route.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Journey _journey({required double totalKm, double fundKm = 0}) {
  const a = LatLng(37, 127);
  const b = LatLng(37, 128);
  return Journey(
    id: 'j1',
    origin: a,
    destId: 'kr001',
    startAt: DateTime.utc(2026, 11, 18),
    fundKm: fundKm,
    route: TravelRoute(a, b, [Leg(a, b, LegKind.land, totalKm, totalKm)]),
  );
}

void main() {
  test('#20 frameFor 경계값', () {
    expect([19.99, 20.0, 49.99, 50.0].map((km) => frameFor(km, rules)).toList(),
        [Frame.wood, Frame.silver, Frame.silver, Frame.gold]);
  });

  test('#21 sketchStage', () {
    expect([0.249, 0.25, 0.75, 0.99].map((r) => sketchStage(r, rules)).toList(),
        [0, 1, 3, 3]);
  });

  test('#22 도착·넘침: 총 10km, 경비 0, 걸은 12km', () {
    final p = progress(_journey(totalKm: 10), 12, rules);
    expect(p.arrived, isTrue);
    expect(p.overflowKm, closeTo(2, 1e-9));
    expect(p.remainingKm, 0);
    expect(p.ratio, 1);
  });

  test('경비는 진행 거리에 더해진다', () {
    final p = progress(_journey(totalKm: 10, fundKm: 3), 2, rules);
    expect(p.progressKm, 5);
    expect(p.remainingKm, 5);
    expect(p.arrived, isFalse);
    expect(p.sketchStage, 2);
  });

  test('#23 경비 상한: 14km + 3km → 15km', () {
    expect(addToFund(14, 3, rules), 15);
  });

  test('#24 etaDate 첫날: 남은 49km, 기록 없음 → 4.9km/일, 10일 뒤', () {
    expect(etaDate(49, const {}, '2026-11-18', '2026-11-18', rules), DateTime.utc(2026, 11, 28));
  });

  test('#25 etaDate 기록 5일: 합 35km → 평균 7km, 7일 뒤', () {
    final daily = {
      '2026-11-13': 5.0,
      '2026-11-14': 6.0,
      '2026-11-15': 7.0,
      '2026-11-16': 8.0,
      '2026-11-17': 9.0,
      '2026-11-18': 20.0, // 오늘은 아직 끝나지 않아 빼고 센다
    };
    expect(etaDate(49, daily, '2026-11-18', '2026-11-13', rules), DateTime.utc(2026, 11, 25));
  });

  test('etaDate: 기록 없는 날은 0km로 세고, 남은 거리 0이면 오늘', () {
    // 첫 기록일부터 어제까지 4일 중 기록은 하루(14km) → 평균 3.5km
    expect(etaDate(7, const {'2026-11-15': 14.0}, '2026-11-18', '2026-11-14', rules),
        DateTime.utc(2026, 11, 20));
    expect(etaDate(0, const {}, '2026-11-18', '2026-11-18', rules), DateTime.utc(2026, 11, 18));
  });
}
