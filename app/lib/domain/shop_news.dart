import 'color_props.dart';
import 'prop.dart';

/// 상점의 새 상품 (16장 11/13 수레 점, 11/16 Annie ‘저장’): 기본 소품을 [seenUtc] 뒤에 얻어 상점에 새로 보이게 된
/// 그 색 소품 id. [ownedAt]은 얻은 소품 id → 얻은 시각(PropsOwned.unlockedUtc, 동기화가 알아챈 시각).
/// 처음부터 가진 기본 소품(베레모·여행복·갈색 신발)의 색 소품은 처음부터 보여서 새 상품이 아니다.
/// [seenUtc]가 없으면 없다
Set<String> newShopItems(List<Prop> props, Map<String, int> ownedAt, int? seenUtc) {
  if (seenUtc == null) return const {};
  final byId = {for (final p in props) p.id: p};
  return {
    for (final item in colorShopItems(props))
      if (byId[item.requires] case final base?
          when base.kind != PropUnlockKind.initial && (ownedAt[base.id] ?? -1) > seenUtc)
        item.id,
  };
}
