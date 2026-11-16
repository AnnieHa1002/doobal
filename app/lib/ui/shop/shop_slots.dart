import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/screen_providers.dart';
import '../rest/rest_slots.dart';
import 'shop_art.dart';
import 'shop_screen.dart';

/// 쉼터에서 상점으로 (수레·보석 모두, 캔버스 2-2)
void openShop(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShopScreen()));

/// 쉼터 수레 자리. 알림 점은 상점에 새 상품이 들어왔을 때만 (16장 11/13, config ui.newDot cart·cartWhen)
final shopCartSlotProvider = Provider.autoDispose<RestObjectSlot>((ref) {
  final onNew = ref.watch(rulesProvider).value?.screen.cartDotOnNewItem ?? false;
  return RestObjectSlot(
    art: (_) => const ShopCartArt(),
    onTap: openShop,
    label: '상점',
    notice: onNew && (ref.watch(shopNewsProvider).value?.isNotEmpty ?? false),
  );
});

/// 쉼터 럭 보석 자리
final shopGemSlot = RestGemSlot(art: (_) => const LuckGemArt(), onTap: openShop);
