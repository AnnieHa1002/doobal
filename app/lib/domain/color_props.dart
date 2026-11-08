import 'prop.dart';
import 'shop.dart';

// 색 소품 (16장 11/4, 명세 M4.5 D, shop.json colorVariantItems): 사용자가 색을 고르지 않고 색마다 따로 된
// 상점 소품을 산다. props.json의 variantOf 소품이고 값은 props unlock.price 하나다.
// 기본 소품을 얻기 전에는 상점·꾸미기에 안 보이고, 기본 소품 바로 뒤에 뜬다

/// 가진 소품 id: 얻은 기록([owned]) + 처음부터 가진 기본 소품 (첫 동기화 전에는 기록이 없다)
Set<String> havePropIds(List<Prop> props, Set<String> owned) => {
      ...owned,
      for (final p in props)
        if (p.kind == PropUnlockKind.initial) p.id,
    };

/// 색 소품 id → 기본 소품 id (spiritLookOf가 색 소품을 기본 소품 그림으로 보이게 쓴다)
Map<String, String> variantBases(Iterable<Prop> props) => {
      for (final p in props) p.id: ?p.variantOf,
    };

/// 보여도 되는 소품인가: 색 소품은 기본 소품을 가졌을 때만 ([have]는 [havePropIds])
bool baseHeld(Prop p, Set<String> have) => p.variantOf == null || have.contains(p.variantOf);

/// 색 소품을 저마다 기본 소품 바로 뒤로 옮긴 순서 (나머지는 props.json 순서 그대로).
/// 기본 소품이 목록에 없는 색 소품은 맨 뒤에 둔다
List<Prop> variantsAfterBase(List<Prop> props) {
  final bases = {for (final p in props) if (!p.isColorVariant) p.id};
  final byBase = <String, List<Prop>>{};
  final orphans = <Prop>[];
  for (final p in props) {
    final base = p.variantOf;
    if (base == null) continue;
    if (bases.contains(base)) {
      (byBase[base] ??= []).add(p);
    } else {
      orphans.add(p);
    }
  }
  return [
    for (final p in props)
      if (!p.isColorVariant) ...[p, ...?byBase[p.id]],
    ...orphans,
  ];
}

/// 색 소품을 상품으로 (상점 소품 탭 아래 '색 소품' 묶음, 캔버스 8-1). order는 기본 소품 순서다
List<ShopItem> colorShopItems(List<Prop> props) => [
      for (final (i, p) in variantsAfterBase(props)
          .where((p) => p.isColorVariant && p.kind == PropUnlockKind.shop && p.price != null)
          .indexed)
        ShopItem(
          id: p.id,
          tab: ShopTab.prop,
          name: p.name,
          price: p.price!,
          order: i + 1,
          propId: p.id,
          requires: p.requires ?? p.variantOf,
        ),
    ];

/// 색 소품 [id]의 상품. 색 소품이 아니면 null
ShopItem? colorShopItem(List<Prop> props, String id) {
  for (final item in colorShopItems(props)) {
    if (item.id == id) return item;
  }
  return null;
}

/// 상점에 띄울 색 소품: 기본 소품을 가진 것만 ([have]는 [havePropIds])
List<ShopItem> shownColorItems(List<Prop> props, Set<String> have) => [
      for (final item in colorShopItems(props))
        if (have.contains(item.requires)) item,
    ];
