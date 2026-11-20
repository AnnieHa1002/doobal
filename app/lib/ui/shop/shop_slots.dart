import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shop_providers.dart';
import '../../domain/camp_theme.dart';
import '../rest/rest_slots.dart';
import 'cart_widgets.dart';
import 'shop_art.dart';
import 'shop_screen.dart';

/// 쉼터에서 상점으로 (수레·보석·옆 상점 버튼, 캔버스 2-2)
void openShop(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShopScreen()));

/// 쉼터 수레 자리: 수레 그림 위에 그날 수레 물건 (16장 11/19 ④, camp_wide v5 itemsOn).
/// 알림 점(옆 상점 버튼)은 그날 수레에 처음 나온 상품이 있고 그날 아직 상점을 안 봤을 때 (config ui.newDot cart·
/// cartWhen newShopItem, shop.cart.newDot cartHasNeverShown, DB 19 shop_seen_utc로 껐다 켜도 남음)
final shopCartSlotProvider = Provider.autoDispose<RestObjectSlot>((ref) {
  final onNew = ref.watch(rulesProvider).value?.screen.cartDotOnNewItem ?? false;
  return RestObjectSlot(
    art: (_) => const CartWithItemsArt(),
    onTap: openShop,
    label: '상점',
    notice: onNew && (ref.watch(todayCartProvider).value?.news ?? false),
  );
});

/// 쉼터 럭 보석 자리
final shopGemSlot = RestGemSlot(art: (_) => const LuckGemArt(), onTap: openShop);

/// 쉼터 수레 그림 + 그날 수레의 팔리지 않은 물건 아이콘. 받은 상자(테마의 artW×artH × 장면 배율)를 채운다
class CartWithItemsArt extends ConsumerWidget {
  const CartWithItemsArt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(campThemeProvider).value?.objectOrNull(campCartId);
    final slots = ref.watch(todayCartProvider).value?.slots ?? const [];
    if (cart == null || cart.itemsOnMax <= 0 || slots.isEmpty) return const ShopCartArt();
    return LayoutBuilder(builder: (context, box) {
      final k = cart.artW > 0 ? box.maxWidth / cart.artW : 1.0;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          const ShopCartArt(),
          CartItemsOnTop(slots: slots, max: cart.itemsOnMax, iconPt: cart.itemsOnIconPt * k),
        ],
      );
    });
  }
}
