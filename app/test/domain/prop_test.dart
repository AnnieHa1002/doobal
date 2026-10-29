import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/prop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Set<String> _earned({double km = 0, int steps = 0, Set<String> regions = const {}}) =>
    earnedPropIds(props, km, steps, regions);

Set<String> _idsOf(PropUnlockKind kind) => {
      for (final p in props)
        if (p.kind == kind) p.id,
    };

Set<String> _regionIds(String region) => {
      for (final l in landmarks)
        if (l.region == region) l.id,
    };

void main() {
  group('props.json 읽기', () {
    test('전체 39개 중 mvp 27개만 읽는다 (pending 이벤트 소품 12개는 뺀다)', () {
      final json =
          jsonDecode(File('assets/data/props.json').readAsStringSync()) as Map<String, dynamic>;
      expect((json['props'] as List), hasLength(39));
      expect(props, hasLength(27));
      expect(props.map((p) => p.id).toSet(), hasLength(27));
    });

    test('해금 조건 개수: 기본 6 · 거리 10 · 권역 7 · 걸음 1 · 동료 3', () {
      expect(_idsOf(PropUnlockKind.initial), hasLength(6));
      expect(_idsOf(PropUnlockKind.distance), hasLength(10));
      expect(_idsOf(PropUnlockKind.region), hasLength(7));
      expect(_idsOf(PropUnlockKind.steps), hasLength(1));
      expect(_idsOf(PropUnlockKind.companion), hasLength(3));
    });

    test('동료 소품 3개: 달 핀 · 꾹꾹이 장갑 · 동그란 안경 (동료 id는 아직 없다)', () {
      final companion = props.where((p) => p.kind == PropUnlockKind.companion).toList();
      expect({for (final p in companion) p.id: p.name},
          {'hat_10': '달 핀', 'hat_11': '동그란 안경', 'hand_09': '꾹꾹이 장갑'});
      expect(companion.every((p) => p.companion == null), isTrue);
    });

    test('전체 슬롯 개수: 모자 11 · 손 9 · 반려 8 · 가방 4 · 신발 3 · 옷 4 (pending 포함)', () {
      final json =
          jsonDecode(File('assets/data/props.json').readAsStringSync()) as Map<String, dynamic>;
      final slots = <String, int>{};
      for (final p in json['props'] as List) {
        slots.update((p as Map<String, dynamic>)['slot'] as String, (n) => n + 1,
            ifAbsent: () => 1);
      }
      expect(slots, {'hat': 11, 'hand': 9, 'pet': 8, 'bag': 4, 'shoe': 3, 'cloth': 4});
    });

    test('동료 id가 들어 있으면 읽는다', () {
      final p = Prop.fromJson({
        'id': 'hat_10',
        'slot': 'hat',
        'name': '달 핀',
        'unlock': {'kind': 'companion', 'companion': 'pei'},
      });
      expect(p.kind, PropUnlockKind.companion);
      expect(p.companion, 'pei');
    });

    test('모르는 해금 조건은 받아들이지 않는다', () {
      expect(
          () => Prop.fromJson({
                'id': 'x_01',
                'slot': 'hat',
                'name': 'x',
                'unlock': {'kind': 'event'},
              }),
          throwsFormatException);
    });
  });

  group('earnedPropIds', () {
    test('아무것도 안 했어도 기본 6개: 첫 동기화부터 가진다', () {
      expect(_earned(), {'hat_01', 'hand_01', 'pet_01', 'bag_01', 'shoe_01', 'cloth_01'});
    });

    test('거리 경계: 10km 미만이면 hand_02 없음, 10km면 있음', () {
      expect(_earned(km: 9.999), isNot(contains('hand_02')));
      expect(_earned(km: 10), contains('hand_02'));
      expect(_earned(km: 10), isNot(contains('hat_02')));
      expect(_earned(km: 25), containsAll(['hand_02', 'hat_02']));
    });

    test('거리 소품 10개: 기준 km마다 하나씩 늘어난다', () {
      final distance = props.where((p) => p.kind == PropUnlockKind.distance).toList();
      expect(distance.map((p) => p.km).toSet(),
          {10.0, 25.0, 50.0, 100.0, 150.0, 200.0, 300.0, 500.0, 700.0, 1000.0});
      for (final p in distance) {
        expect(_earned(km: p.km! - 0.001), isNot(contains(p.id)), reason: p.id);
        expect(_earned(km: p.km!), contains(p.id), reason: p.id);
      }
      expect(_earned(km: 1000), hasLength(6 + 10));
    });

    test('권역 소품 7개: 그 권역을 완료해야 얻는다', () {
      const byRegion = {
        'capital': 'pet_02',
        'gangwon': 'pet_03',
        'chungcheong': 'hand_05',
        'jeolla': 'hat_04',
        'gyeongsang': 'hat_05',
        'jeju': 'pet_04',
        'ulleung': 'pet_05',
      };
      for (final e in byRegion.entries) {
        expect(_earned(regions: {e.key}), contains(e.value));
        // 다른 권역만 완료하면 이 소품은 없다
        expect(_earned(regions: byRegion.keys.toSet()..remove(e.key)), isNot(contains(e.value)));
      }
      expect(_earned(regions: byRegion.keys.toSet()), hasLength(6 + 7));
    });

    test('걸음 1,000,000: cloth_04. 999,999는 아니다', () {
      expect(_earned(steps: 999999), isNot(contains('cloth_04')));
      expect(_earned(steps: 1000000), contains('cloth_04'));
    });

    test('동료 소품은 어떤 조건을 채워도 여기서 얻지 않는다 (이야기를 마칠 때 준다, M4)', () {
      final regions = landmarks.map((l) => l.region).toSet();
      final all = _earned(km: 1e9, steps: 1 << 40, regions: regions);
      expect(all.intersection(_idsOf(PropUnlockKind.companion)), isEmpty);
    });

    test('거리·권역·걸음 전부 채우면 24개 (MVP 27개 - 동료 3개)', () {
      final regions = landmarks.map((l) => l.region).toSet();
      final all = _earned(km: 1000, steps: 1000000, regions: regions);
      expect(all, hasLength(24));
      expect(all, props.map((p) => p.id).toSet().difference(_idsOf(PropUnlockKind.companion)));
    });
  });

  group('completedRegions', () {
    test('권역별 명소 수: 수도권 12·강원 17·충청 17·전라 21·경상 31·제주 2·울릉 1', () {
      for (final e in const {
        'capital': 12,
        'gangwon': 17,
        'chungcheong': 17,
        'jeolla': 21,
        'gyeongsang': 31,
        'jeju': 2,
        'ulleung': 1,
      }.entries) {
        expect(_regionIds(e.key), hasLength(e.value), reason: e.key);
      }
    });

    test('한 곳도 안 갔으면 없다', () {
      expect(completedRegions({}, landmarks), isEmpty);
    });

    test('수도권 12곳 중 11곳은 미완료, 12곳이면 완료', () {
      final capital = _regionIds('capital').toList();
      expect(completedRegions(capital.take(11).toSet(), landmarks), isEmpty);
      expect(completedRegions(capital.toSet(), landmarks), {'capital'});
    });

    test('울릉도는 한 곳이라 그곳만 가도 완료, 제주는 둘 다 가야 한다', () {
      expect(completedRegions(_regionIds('ulleung'), landmarks), {'ulleung'});
      final jeju = _regionIds('jeju').toList();
      expect(completedRegions({jeju.first}, landmarks), isEmpty);
      expect(completedRegions(jeju.toSet(), landmarks), {'jeju'});
    });

    test('모르는 id는 무시하고, 전부 가면 7권역', () {
      expect(completedRegions({'zz999'}, landmarks), isEmpty);
      expect(completedRegions({for (final l in landmarks) l.id}, landmarks), hasLength(7));
    });
  });
}
