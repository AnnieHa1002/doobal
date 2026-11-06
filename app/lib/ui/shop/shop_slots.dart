import 'package:flutter/material.dart';

import '../rest/rest_slots.dart';
import 'shop_art.dart';
import 'shop_screen.dart';

/// 쉼터에서 상점으로 (수레·보석 모두, 캔버스 2-2)
void openShop(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShopScreen()));

/// 쉼터 수레 자리. 알림 점은 규칙이 정해지면 켠다 (캔버스 ‘새 상품 있음’, 조건 없음)
final shopCartSlot = RestObjectSlot(
  art: (_) => const ShopCartArt(),
  onTap: openShop,
  label: '상점',
);

/// 쉼터 럭 보석 자리
final shopGemSlot = RestGemSlot(art: (_) => const LuckGemArt(), onTap: openShop);
