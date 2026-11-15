import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/shop_news.dart';
import 'providers.dart';

/// 화면 세부(T11)·쉼터 정령 자세(T5)가 쓰는 무작위. 시험은 고정 값으로 바꿔 끼운다

/// [count]개 중 하나(0부터)를 고른다
typedef PickOne = int Function(int count);

/// 정령 만들기에서 처음 골라져 있는 여행복 시작 색(props cloth_02.startColors 4색 중 무작위, 16장 11/15 A안)
final startClothPickProvider = Provider<PickOne>((ref) {
  final random = Random();
  return random.nextInt;
});

/// 쉼터 정령 자세 바꾸기(config character.rive.restSwap)의 무작위: 다음 자세·간격
final restSwapRandomProvider = Provider<Random>((ref) => Random());

/// 상점에서 본 상품 id. 이 실행 동안만 기억한다 (DB 18에 둘 자리가 없어 저장하지 않음, 인계 노트 T11).
/// 처음 상품 목록을 읽을 때 그때 보이는 것을 다 본 것으로 둔다 (첫날 수레 점 없음, 캔버스 2-2)
class ShopSeen {
  Set<String>? ids;
}

final shopSeenProvider = Provider<ShopSeen>((ref) => ShopSeen());

/// 아직 안 본 새 상품 id (수레 알림 점, config ui.newDot.cartWhen newShopItem). 기본 소품을 얻어 색 소품이
/// 새로 보이게 되면 생기고, 상점을 열면 없어진다 ([markShopSeen])
final shopNewsProvider = Provider.autoDispose<Set<String>>((ref) {
  final shop = ref.watch(shopCatalogProvider).value;
  final props = ref.watch(propsProvider).value;
  final owned = ref.watch(ownedPropIdsProvider).value;
  if (shop == null || props == null || owned == null) return const {};
  final shown = shownShopItemIds(shop, props, owned);
  final seen = ref.watch(shopSeenProvider);
  final news = newShopItems(shown, seen.ids);
  seen.ids ??= shown;
  return news;
});

/// 상점에 보이는 새 상품을 본 것으로 (상점 화면이 열려 있는 동안)
void markShopSeen(WidgetRef ref) {
  final news = ref.read(shopNewsProvider);
  if (news.isEmpty) return;
  final seen = ref.read(shopSeenProvider);
  seen.ids = {...?seen.ids, ...news};
  ref.invalidate(shopNewsProvider);
}
