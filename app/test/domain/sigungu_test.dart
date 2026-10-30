import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/sigungu.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

List<String> _labels(List<Sigungu> l) => [for (final s in l) s.label];

void main() {
  group('parseSigungu', () {
    test('sigungu.json 전체를 파일 순서대로 읽는다', () {
      expect(sigungu, hasLength(230));
      final first = sigungu.first;
      expect((first.id, first.sido, first.name, first.label), ('11110', '서울', '종로구', '서울 종로구'));
      expect(first.lat, closeTo(37.57477, 1e-9));
      expect(first.lng, closeTo(126.97961, 1e-9));
      expect(first.latLng, const LatLng(37.57477, 126.97961));
      expect(first.island, Island.mainland);
    });

    test('id는 하나뿐이고 label도 하나뿐이다 (같은 이름의 구는 시·도로 가린다)', () {
      expect({for (final s in sigungu) s.id}, hasLength(sigungu.length));
      expect({for (final s in sigungu) s.label}, hasLength(sigungu.length));
      expect(_labels(sigungu), containsAll(['서울 중구', '부산 중구', '대구 중구']));
    });

    test('섬은 island로 읽는다 (제주 둘, 울릉 하나)', () {
      final islands = {for (final s in sigungu) if (s.island != Island.mainland) s.label: s.island};
      expect(islands, {
        '제주 제주시': Island.jeju,
        '제주 서귀포시': Island.jeju,
        '경북 울릉군': Island.ulleung,
      });
    });

    test('세종은 시·군·구가 하나라 label이 "세종"이다', () {
      final s = sigungu.singleWhere((s) => s.sido == '세종');
      expect((s.name, s.label), ('세종시', '세종'));
    });

    test('작은 JSON도 읽고, 모르는 섬 이름은 ArgumentError', () {
      final one = parseSigungu({
        'items': [
          {
            'id': 'x1',
            'sido': '가',
            'name': '나시',
            'label': '가 나시',
            'lat': 36,
            'lng': 127.5,
            'island': 'jeju',
          },
        ],
      });
      expect(one.single.lat, 36.0);
      expect(one.single.island, Island.jeju);
      expect(
        () => parseSigungu({
          'items': [
            {
              'id': 'x2',
              'sido': '가',
              'name': '나시',
              'label': '가 나시',
              'lat': 36,
              'lng': 127,
              'island': 'moon',
            },
          ],
        }),
        throwsArgumentError,
      );
    });
  });

  group('sidoList', () {
    test('시·도 16개가 파일에 처음 나오는 순서로, 중복 없이', () {
      final sido = sidoList(sigungu);
      expect(sido, hasLength(16));
      expect(sido.toSet(), hasLength(16));
      expect(sido.take(3), ['서울', '전남광주', '부산']);
      expect(sido.last, '전북');
      expect(sido, containsAll(['세종', '경기', '제주', '강원']));
    });

    test('빈 목록이면 빈 목록', () => expect(sidoList(const []), isEmpty));
  });

  group('inSido', () {
    test('그 시·도의 시·군·구만 파일 순서로', () {
      final seoul = inSido(sigungu, '서울');
      expect(seoul, hasLength(25));
      expect(seoul.first.name, '종로구');
      expect(seoul.every((s) => s.sido == '서울'), isTrue);
      expect(inSido(sigungu, '세종').map((s) => s.name), ['세종시']);
      expect(inSido(sigungu, '없는시도'), isEmpty);
    });

    test('시·도 16개의 시·군·구를 모으면 전체와 같다', () {
      final all = [for (final d in sidoList(sigungu)) ...inSido(sigungu, d)];
      expect(all.map((s) => s.id).toSet(), sigungu.map((s) => s.id).toSet());
      expect(all, hasLength(sigungu.length));
    });
  });

  group('searchSigungu', () {
    test('"수원" → 경기 수원시', () {
      expect(_labels(searchSigungu(sigungu, '수원')), ['경기 수원시']);
    });

    test('"서울중구"처럼 공백 없이 붙여도, 사이에 공백이 있어도 같다', () {
      expect(_labels(searchSigungu(sigungu, '서울중구')), ['서울 중구']);
      expect(_labels(searchSigungu(sigungu, '서울 중구')), ['서울 중구']);
      expect(_labels(searchSigungu(sigungu, ' 서울   중 구 ')), ['서울 중구']);
    });

    test('같은 이름의 구는 시·도가 달라도 모두 나오고, 파일 순서다', () {
      final labels = _labels(searchSigungu(sigungu, '중구'));
      expect(labels.take(3), ['서울 중구', '부산 중구', '대구 중구']);
      expect(labels, everyElement(contains('중구')));
      expect(labels.toSet(), hasLength(labels.length));
    });

    test('시·도 이름으로도 찾는다 (label 기준)', () {
      final labels = _labels(searchSigungu(sigungu, '제주'));
      expect(labels, ['제주 제주시', '제주 서귀포시']);
      expect(_labels(searchSigungu(sigungu, '세종')), ['세종']);
    });

    test('빈 검색어와 공백뿐인 검색어는 빈 목록', () {
      expect(searchSigungu(sigungu, ''), isEmpty);
      expect(searchSigungu(sigungu, '   '), isEmpty);
      expect(searchSigungu(sigungu, '\t\n'), isEmpty);
    });

    test('없는 동네는 빈 목록', () {
      expect(searchSigungu(sigungu, '없는동네'), isEmpty);
    });

    test('빈 목록에서 찾으면 빈 목록', () {
      expect(searchSigungu(const [], '수원'), isEmpty);
    });
  });
}
