import 'dart:convert';
import 'dart:io';

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

    test('실제 앱 파일: props.json icon이 있는 소품은 아이콘 폴더 v01 그림, 그 밖의 상품은 없다 (11/23 기준)', () {
      final raw = (jsonDecode(File('assets/data/props.json').readAsStringSync()) as Map<String, dynamic>)['props']
          as List<dynamic>;
      final withIcon = {
        for (final p in raw.cast<Map<String, dynamic>>())
          if (p['icon'] != null) p['id'] as String,
      };
      // 물빛 구슬(ui_icon_float_04_v01)은 11/23 받은 묶음(소품 v01·미니 친구 v01)에 없다
      const notYet = {'float_04'};
      expect(withIcon.length, 67);
      for (final id in withIcon.difference(notYet)) {
        // 옛 기본 소품 6개(basic_v02)도 아이콘 폴더가 먼저다
        expect(assetIndex.itemIcon(id), 'assets/items/icons/item_${id}_icon_v01_clean.webp', reason: id);
      }
      for (final id in notYet) {
        expect(assetIndex.itemIcon(id), isNull, reason: id);
      }
      // 아이콘 폴더의 파일은 모두 icon이 있는 소품의 것 (이름 규칙 item_<id>_icon_v01_clean.webp)
      final files = [
        for (final f in Directory(AssetIndex.iconDir).listSync())
          if (!f.uri.pathSegments.last.startsWith('.')) f.uri.pathSegments.last,
      ];
      expect(files.toSet(), {for (final id in withIcon.difference(notYet)) 'item_${id}_icon_v01_clean.webp'});
      // 소품이 아닌 상품(여행 효과·무늬·물감 통·쉼터 물품·배)과 효과 소품은 아직 칸 그림이 없다
      for (final item in shopCatalog.items) {
        if (withIcon.contains(item.propId)) continue;
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

  group('물감 길 그림 (config paintDrop.pickup.sprites, assets/ui/)', () {
    test('config 이름의 버전·_clean이 달라도 찾고, 새 버전·WebP가 먼저, 없으면 null', () {
      final index = AssetIndex([
        'assets/ui/ui_paint_pickup_a_v01.png',
        'assets/ui/ui_paint_pickup_a_v02_clean.webp',
        'assets/ui/ui_paint_pickup_b_v01_clean.png',
        'assets/ui/fx_paint_splash_v01_clean.png',
        'assets/items/icons/ui_paint_pickup_c_v02.png',
      ]);
      expect(index.sprite('ui_paint_pickup_a_v01'), 'assets/ui/ui_paint_pickup_a_v02_clean.webp');
      expect(index.sprite('ui_paint_pickup_b_v01'), 'assets/ui/ui_paint_pickup_b_v01_clean.png');
      expect(index.sprite('fx_paint_splash_v01'), 'assets/ui/fx_paint_splash_v01_clean.png');
      // 다른 폴더·다른 이름은 안 된다
      expect(index.sprite('ui_paint_pickup_c_v02'), isNull);
      expect(AssetIndex(['assets/ui/ui_paint_pickup_ab_v01.png']).sprite('ui_paint_pickup_a_v01'),
          isNull);
    });

    test('실제 앱 파일: 방울 줍기 그림은 아직 없다 (납품 전, 코드로 그린 임시)', () {
      final p = rules.paintPickup;
      for (final name in [...p.dropSprites, p.pressedSprite, p.splashSprite]) {
        expect(assetIndex.sprite(name), isNull, reason: name);
      }
    });
  });
}
