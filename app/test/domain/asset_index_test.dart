import 'package:doobal/domain/asset_index.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('칸 그림 찾기', () {
    test('아이콘 폴더에서는 이름에 id가 있으면 찾는다', () {
      final index = AssetIndex([
        'assets/items/icons/item_hat_02_icon_v01_clean.png',
        'assets/items/icons/ui_shop_fx_shortcut_v01_clean.png',
        'assets/items/icons/face_01.webp',
      ]);
      expect(index.itemIcon('hat_02'), 'assets/items/icons/item_hat_02_icon_v01_clean.png');
      expect(index.itemIcon('fx_shortcut'), 'assets/items/icons/ui_shop_fx_shortcut_v01_clean.png');
      expect(index.itemIcon('face_01'), 'assets/items/icons/face_01.webp');
      expect(index.itemIcon('hat_03'), isNull);
    });

    test('id가 다른 파일과 섞이지 않는다', () {
      final index = AssetIndex([
        'assets/items/icons/item_hat_01_c1_icon_v01_clean.png',
        'assets/items/icons/item_chat_01_icon_v01_clean.png',
      ]);
      expect(index.itemIcon('hat_01'), isNull);
      expect(index.itemIcon('hat_01_c1'), 'assets/items/icons/item_hat_01_c1_icon_v01_clean.png');
    });

    test('다른 소품 묶음은 _icon 파일만 아이콘이다 (입는 조각이 섞여 있다)', () {
      final index = AssetIndex([
        'assets/items/basic_v02/item_hat_01_v02_clean.png',
        'assets/items/basic_v02/item_shoe_01_l_v02_clean.png',
      ]);
      expect(index.itemIcon('hat_01'), isNull);
      expect(index.itemIcon('shoe_01'), isNull);
      expect(
        AssetIndex(['assets/items/basic_v02/item_hat_01_icon_v02.png']).itemIcon('hat_01'),
        'assets/items/basic_v02/item_hat_01_icon_v02.png',
      );
    });

    test('아이콘 폴더 > 옛 묶음, WebP > PNG, 새 버전 > 옛 버전', () {
      final index = AssetIndex([
        'assets/items/basic_v02/item_hat_01_icon_v02.png',
        'assets/items/icons/item_hat_01_icon_v01_clean.png',
        'assets/items/icons/item_hat_01_icon_v02_clean.png',
        'assets/items/icons/item_bag_01_icon_v09_clean.png',
        'assets/items/icons/item_bag_01_icon_v01_clean.webp',
      ]);
      expect(index.itemIcon('hat_01'), 'assets/items/icons/item_hat_01_icon_v02_clean.png');
      expect(index.itemIcon('bag_01'), 'assets/items/icons/item_bag_01_icon_v01_clean.webp');
    });

    test('실제 앱 파일: 옛 기본 소품 6개는 그림이 있고 상점 소품은 없다 (11/6 기준)', () {
      for (final id in ['hat_01', 'hand_01', 'pet_01', 'bag_01', 'cloth_01', 'shoe_01']) {
        expect(assetIndex.itemIcon(id), 'assets/items/basic_v02/item_${id}_icon_v02.png', reason: id);
      }
      expect(assetIndex.itemIcon('hat_02'), isNull);
      for (final item in shopCatalog.items) {
        expect(assetIndex.itemIcon(item.id), isNull, reason: item.id);
      }
    });
  });

  test('럭 보석: 버전이 올라도 찾고 다른 보석 그림과 섞이지 않는다', () {
    expect(
      AssetIndex([
        'assets/ui/ui_gem_pile_sky_v01_clean.png',
        'assets/ui/ui_gem_small_sky_v01_clean.png',
      ]).gem,
      isNull,
    );
    expect(AssetIndex(['assets/ui/ui_gem_sky_v01_clean.png']).gem, 'assets/ui/ui_gem_sky_v01_clean.png');
    expect(
      AssetIndex(['assets/ui/ui_gem_sky_v01_clean.png', 'assets/ui/ui_gem_sky_v02_clean.png']).gem,
      'assets/ui/ui_gem_sky_v02_clean.png',
    );
  });

  test('이름 하나로 찾기: WebP를 먼저 본다', () {
    const dir = 'assets/backgrounds/v11';
    expect(AssetIndex(const []).file(dir, 'obj_rest_cart_v01_clean.png'), isNull);
    expect(
      AssetIndex(['$dir/obj_rest_cart_v01_clean.png']).file(dir, 'obj_rest_cart_v01_clean.png'),
      '$dir/obj_rest_cart_v01_clean.png',
    );
    expect(
      AssetIndex(['$dir/obj_rest_cart_v01_clean.png', '$dir/obj_rest_cart_v01_clean.webp'])
          .file(dir, 'obj_rest_cart_v01_clean.png'),
      '$dir/obj_rest_cart_v01_clean.webp',
    );
  });
}
