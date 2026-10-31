import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/map_land.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 땅 판정 결과 집계 (실제 지도·시·군·구·config 범위로)
class _Tally {
  var total = 0;

  /// 첫 후보가 땅이라 돌리지 않은 것
  var first = 0;

  /// 90°씩 돌려서(2~4번째 후보) 땅을 찾은 것
  var rotated = 0;

  /// 네 방향이 모두 바다·다른 섬이라 첫 후보로 돌아간 것 (바다에 떨어진다)
  final allSea = <String>[];
}

/// 시·군·구 230곳 × 설치 번호 [installs]개로 앱과 같은 땅 판정(SyncService.startSketch의 ok)을 돌린다.
/// 거리는 [minKm]~[maxKm]
_Tally _tally(double minKm, double maxKm, {int installs = 60}) {
  final t = _Tally();
  for (final s in sigungu) {
    for (var i = 0; i < installs; i++) {
      final tried = <bool>[];
      sketchDestination(
        home: s.latLng,
        installId: i.toRadixString(16).padLeft(32, '0'),
        minKm: minKm,
        maxKm: maxKm,
        earthRadiusKm: rules.earthRadiusKm,
        ok: (p) {
          final land = islandOf(p, rules.islands) == s.island &&
              onIsland(p, s.island, mapProjection, mapRegions);
          tried.add(land);
          return land;
        },
      );
      t.total++;
      if (tried.first) {
        t.first++;
      } else if (tried.last) {
        t.rotated++;
      } else {
        t.allSea.add('${s.label}#$i');
      }
    }
  }
  return t;
}

void main() {
  // 지도 SVG는 1px ≈ 0.29km로 거칠다. 첫 여정이 0.5km까지 짧아져도 바다에 떨어지지 않는지 본다
  group('첫 여정 목적지의 바다 회피 (시·군·구 × 설치 번호)', () {
    test('config 범위(0.5~0.8km): 네 방향이 모두 바다인 경우가 없다', () {
      final t = _tally(rules.firstSketchMinKm, rules.firstSketchMaxKm);
      expect(t.total, sigungu.length * 60);
      expect(t.allSea, isEmpty);
      expect(t.first + t.rotated, t.total);
      // 거의 다 첫 방향 그대로 땅이고, 돌리는 건 해안·섬 가장자리 동네의 소수다
      expect(t.first / t.total, greaterThan(0.98));
    });

    test('가장 짧은 0.5km와 가장 긴 0.8km에서도 마찬가지다', () {
      for (final km in [rules.firstSketchMinKm, rules.firstSketchMaxKm]) {
        final t = _tally(km, km, installs: 30);
        expect(t.allSea, isEmpty, reason: '$km km');
        expect(t.first / t.total, greaterThan(0.98), reason: '$km km');
      }
    });
  });
}
