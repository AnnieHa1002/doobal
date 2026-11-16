import 'package:doobal/domain/color_props.dart';
import 'package:doobal/domain/shop_news.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('본 시각 뒤에 얻은 기본 소품의 색 소품 3개가 새 상품 (16장 11/13 수레 점)', () {
    final news = newShopItems(props, const {'hat_02': 500}, 400);
    expect(news, hasLength(3));
    final hatColors = {for (final i in colorShopItems(props)) if (i.requires == 'hat_02') i.id};
    expect(news, hatColors);
  });

  test('본 시각 전·같은 때에 얻은 것은 새 상품이 아니다 (상점을 연 뒤)', () {
    expect(newShopItems(props, const {'hat_02': 400}, 400), isEmpty);
    expect(newShopItems(props, const {'hat_02': 300}, 400), isEmpty);
  });

  test('처음부터 가진 기본 소품(베레모·여행복·갈색 신발)의 색 소품은 새 상품이 아니다 (첫날 점 없음)', () {
    final initial = {
      for (final p in props)
        if (p.kind.name == 'initial') p.id: 1000,
    };
    expect(initial, isNotEmpty);
    expect(newShopItems(props, initial, 0), isEmpty);
  });

  test('색 소품이 없는 소품이나 본 시각이 없으면 없다', () {
    expect(newShopItems(props, const {'hat_02': 500}, null), isEmpty);
    final noColors = props.firstWhere(
        (p) => p.kind.name != 'initial' && !colorShopItems(props).any((i) => i.requires == p.id));
    expect(newShopItems(props, {noColors.id: 500}, 400), isEmpty);
  });
}
