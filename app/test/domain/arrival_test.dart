import 'package:doobal/domain/arrival.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/prop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _t = DateTime.utc(2026, 11, 18);

Set<String> _ids(String region) => {
      for (final l in landmarks)
        if (l.region == region) l.id,
    };

Set<String> _allBut(String region, int skip) => _ids(region).skip(skip).toSet();

void main() {
  group('previousBestKm', () {
    test('먼저 도착한 여정이 없으면 null (첫 방문)', () {
      expect(previousBestKm(const [], _t), isNull);
      // 자기 자신(같은 시각)이나 나중 여정은 먼저가 아니다
      expect(previousBestKm([ArrivedTrip(_t, 30)], _t), isNull);
      expect(previousBestKm([ArrivedTrip(_t.add(const Duration(days: 1)), 30)], _t), isNull);
    });

    test('먼저 도착한 여정 중 가장 먼 거리를 고른다 (가장 최근이 아니다)', () {
      final trips = [
        ArrivedTrip(_t.subtract(const Duration(days: 3)), 12.5),
        ArrivedTrip(_t.subtract(const Duration(days: 2)), 32.4),
        ArrivedTrip(_t.subtract(const Duration(days: 1)), 8),
      ];
      expect(previousBestKm(trips, _t), 32.4);
    });

    test('나중에 도착한 더 먼 여정은 빼고, 순서가 섞여 있어도 같다', () {
      final trips = [
        ArrivedTrip(_t.add(const Duration(days: 1)), 99),
        ArrivedTrip(_t.subtract(const Duration(days: 1)), 8),
        ArrivedTrip(_t, 70),
        ArrivedTrip(_t.subtract(const Duration(days: 5)), 21),
      ];
      expect(previousBestKm(trips, _t), 21);
    });
  });

  group('regionPropOnArrival', () {
    const region = 'jeju';

    Prop? prop(String region, {int visitNo = 1, required Set<String> visited}) =>
        regionPropOnArrival(
          visitNo: visitNo,
          region: region,
          visitedIds: visited,
          landmarks: landmarks,
          props: props,
        );

    test('울릉(명소 1곳): 첫 방문이 곧 완성이라 괭이갈매기', () {
      expect(prop('ulleung', visited: _ids('ulleung'))?.id, 'pet_05');
    });

    test('제주(2곳): 둘 다 갔을 때만 돌하르방, 하나면 null', () {
      expect(prop(region, visited: _ids(region))?.id, 'pet_04');
      expect(prop(region, visited: {_ids(region).first}), isNull);
    });

    test('재방문이면 이미 채운 권역이어도 null', () {
      expect(prop(region, visitNo: 2, visited: _ids(region)), isNull);
    });

    test('권역마다 자기 소품: 수도권 해치·전라 대나무 삿갓·경상 신라 금관', () {
      expect(prop('capital', visited: _ids('capital'))?.name, '해치');
      expect(prop('jeolla', visited: _ids('jeolla'))?.name, '대나무 삿갓');
      expect(prop('gyeongsang', visited: _ids('gyeongsang'))?.name, '신라 금관');
    });

    test('한 곳이 모자란 권역은 null', () {
      expect(prop('capital', visited: _allBut('capital', 1)), isNull);
    });

    test('권역에 소품이 없으면 null (소품 목록에 그 권역 조건이 없을 때)', () {
      final out = regionPropOnArrival(
        visitNo: 1,
        region: 'ulleung',
        visitedIds: _ids('ulleung'),
        landmarks: landmarks,
        props: [for (final p in props) if (p.region != 'ulleung') p],
      );
      expect(out, isNull);
    });
  });

  group('revisitKind', () {
    test('첫 방문 (이전 액자 없음)', () {
      expect(revisitKind(1, null, Frame.gold), RevisitKind.first);
    });

    test('재방문: 올랐으면 frameUp, 같으면 unchanged', () {
      expect(revisitKind(2, Frame.wood, Frame.silver), RevisitKind.frameUp);
      expect(revisitKind(3, Frame.wood, Frame.gold), RevisitKind.frameUp);
      expect(revisitKind(2, Frame.silver, Frame.silver), RevisitKind.unchanged);
      expect(revisitKind(2, Frame.gold, Frame.gold), RevisitKind.unchanged);
    });

    test('내려간 경우는 없지만 들어오면 unchanged로 본다', () {
      expect(revisitKind(2, Frame.gold, Frame.wood), RevisitKind.unchanged);
    });

    test('방문 번호가 2 이상인데 이전 액자가 없는 이상한 값도 first', () {
      expect(revisitKind(2, null, Frame.wood), RevisitKind.first);
    });
  });
}
