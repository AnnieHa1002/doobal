import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/route.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 기대값은 항구 대략값(config.json) 기준. 항구 좌표를 보정하면 #16·#18을 다시 계산한다
const _gyeongbok = LatLng(37.57761, 126.9769);
const _seongsan = LatLng(33.45913, 126.94054);
const _hallasan = LatLng(33.36232, 126.53333);
const _seonginbong = LatLng(37.49799, 130.86706);

void _expectLegs(TravelRoute r, List<(LegKind, double, double)> want) {
  expect(r.legs.map((l) => l.kind).toList(), want.map((w) => w.$1).toList());
  for (var i = 0; i < want.length; i++) {
    expect(r.legs[i].rawKm, closeTo(want[i].$2, 0.01), reason: 'leg $i raw');
    expect(r.legs[i].effectiveKm, closeTo(want[i].$3, 0.01), reason: 'leg $i effective');
  }
}

void main() {
  test('#16 경복궁 → 성산일출봉: 완도·제주항 경유', () {
    final r = buildRoute(_gyeongbok, _seongsan, rules);
    _expectLegs(r, [
      (LegKind.land, 363.34, 363.34),
      (LegKind.sea, 89.72, 29.91),
      (LegKind.land, 37.64, 37.64),
    ]);
    expect(r.totalEffectiveKm, closeTo(430.88, 0.01));
  });

  test('반대 방향이면 순서가 뒤집힌다', () {
    final r = buildRoute(_seongsan, _gyeongbok, rules);
    expect(r.legs.map((l) => l.kind).toList(), [LegKind.land, LegKind.sea, LegKind.land]);
    expect(r.totalEffectiveKm, closeTo(430.88, 0.01));
  });

  test('#17 섬 안: 성산일출봉 → 한라산 백록담', () {
    final r = buildRoute(_seongsan, _hallasan, rules);
    _expectLegs(r, [(LegKind.land, 39.30, 39.30)]);
  });

  test('#18 경복궁 → 성인봉: 포항·도동항 경유', () {
    final r = buildRoute(_gyeongbok, _seonginbong, rules);
    _expectLegs(r, [
      (LegKind.land, 273.85, 273.85),
      (LegKind.sea, 211.09, 70.36),
      (LegKind.land, 3.77, 3.77),
    ]);
    expect(r.totalEffectiveKm, closeTo(347.99, 0.01));
  });

  test('제주 → 울릉: 배 두 번', () {
    final r = buildRoute(_hallasan, _seonginbong, rules);
    expect(r.legs.map((l) => l.kind).toList(),
        [LegKind.land, LegKind.sea, LegKind.land, LegKind.sea, LegKind.land]);
  });

  test('positionAt: 시작·배 위·끝', () {
    final r = buildRoute(_gyeongbok, _seongsan, rules);
    expect(positionAt(r, 0).latLng, _gyeongbok);
    final onBoat = positionAt(r, r.legs[0].effectiveKm + 10);
    expect(onBoat.legIndex, 1);
    expect(onBoat.onSea, isTrue);
    expect(positionAt(r, r.totalEffectiveKm + 5).latLng, _seongsan);
  });
}
