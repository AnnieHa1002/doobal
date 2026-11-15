import 'package:doobal/domain/shop_news.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('상점에 보이는 상품: 탭 상품 전부 + 처음부터 가진 기본 소품의 색 소품 9개', () {
    final shown = shownShopItemIds(shopCatalog, props, const {});
    for (final i in shopCatalog.items) {
      expect(shown, contains(i.id));
    }
    expect(shown.length, shopCatalog.items.length + 9);
  });

  test('기본 소품을 얻으면 그 색 소품 3개가 새 상품이 된다 (16장 11/13 수레 점)', () {
    final before = shownShopItemIds(shopCatalog, props, const {});
    final after = shownShopItemIds(shopCatalog, props, const {'hat_02'});
    final news = newShopItems(after, before);
    expect(news, hasLength(3));
    for (final id in news) {
      expect(id, startsWith('hat_02_'));
    }
    // 이미 본 것만 있으면 없다
    expect(newShopItems(after, after), isEmpty);
  });

  test('처음(본 목록 없음)에는 새 상품이 없다 (첫날 수레 점 없음)', () {
    expect(newShopItems(shownShopItemIds(shopCatalog, props, const {'hat_02'}), null), isEmpty);
  });
}
