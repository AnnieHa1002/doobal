import 'color_props.dart';
import 'prop.dart';
import 'shop.dart';

/// 상점에 보이는 상품 id: 탭 상품 전부(산 것도 ‘가짐’으로 보인다) + 기본 소품을 가진 색 소품
/// ([owned]는 얻은 소품 id, 처음부터 가진 소품은 여기서 더한다)
Set<String> shownShopItemIds(ShopCatalog shop, List<Prop> props, Set<String> owned) => {
      for (final i in shop.items) i.id,
      for (final i in shownColorItems(props, havePropIds(props, owned))) i.id,
    };

/// 새 상품 = 보이는데 아직 안 본 것 (16장 11/13 수레 점). [seen]이 없으면(처음) 지금 보이는 것을 다 본 것으로 친다
Set<String> newShopItems(Set<String> shown, Set<String>? seen) =>
    seen == null ? const {} : shown.difference(seen);
