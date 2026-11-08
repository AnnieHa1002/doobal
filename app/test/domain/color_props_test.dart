import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/color.dart';
import 'package:doobal/domain/color_props.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/shop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 색 소품 (16장 11/4, 명세 M4.5 D, shop.json colorVariantItems)

final _json =
    jsonDecode(File('assets/data/props.json').readAsStringSync()) as Map<String, dynamic>;

/// props.json의 variantOf 소품 원문
final _raw = [
  for (final p in _json['props'] as List)
    if ((p as Map<String, dynamic>).containsKey('variantOf')) p,
];

final _bases = [for (final b in (_json['colorVariants'] as Map)['bases'] as List) b as String];

List<String> _ids(Iterable<Object> xs) => [
      for (final x in xs)
        switch (x) {
          Prop(:final id) => id,
          ShopItem(:final id) => id,
          _ => throw ArgumentError(x),
        },
    ];

void main() {
  group('props.json 읽기', () {
    test('variantOf 소품 21개: 기본 소품·requires·값·색 이름·hex를 읽는다', () {
      final variants = props.where((p) => p.isColorVariant).toList();
      expect(_raw, hasLength(21));
      expect(variants, hasLength(21));
      final byId = {for (final p in variants) p.id: p};
      for (final r in _raw) {
        final p = byId[r['id']]!;
        final unlock = r['unlock'] as Map<String, dynamic>;
        expect(p.kind, PropUnlockKind.shop, reason: p.id);
        expect(p.variantOf, r['variantOf'], reason: p.id);
        expect(p.requires, unlock['requires'], reason: p.id);
        expect(p.price, unlock['price'], reason: p.id);
        expect(p.colorName, r['color'], reason: p.id);
        expect(p.materialArgb, argbFromHex((r['material'] as Map)['hex'] as String), reason: p.id);
        expect(p.slot, props.firstWhere((b) => b.id == p.variantOf).slot, reason: p.id);
      }
    });

    test('기본 소품은 색 소품이 아니고 material 색을 가진다', () {
      final beret = props.firstWhere((p) => p.id == 'hat_01');
      expect(beret.isColorVariant, isFalse);
      expect(beret.variantOf, isNull);
      expect(beret.materialArgb, 0xFFA4502F);
    });

    test('material.hex 모양이 틀리면 멈춘다', () {
      expect(
        () => Prop.fromJson({
          'id': 'x',
          'slot': 'hat',
          'name': 'x',
          'unlock': {'kind': 'default'},
          'material': {'hex': 'A4502F'},
        }),
        throwsFormatException,
      );
    });
  });

  group('순서: 기본 소품 바로 뒤', () {
    test('색 소품은 저마다 기본 소품 바로 뒤, 나머지는 props.json 순서 그대로', () {
      final ordered = variantsAfterBase(props);
      expect(ordered, hasLength(props.length));
      expect(_ids(ordered.where((p) => !p.isColorVariant)),
          _ids(props.where((p) => !p.isColorVariant)));
      final ids = _ids(ordered);
      for (final base in _bases) {
        final at = ids.indexOf(base);
        final mine = _ids(props.where((p) => p.variantOf == base));
        expect(mine, hasLength(3), reason: base);
        expect(ids.sublist(at + 1, at + 1 + mine.length), mine, reason: base);
      }
      expect(ids.sublist(0, 6), ['hat_01', 'hat_01_c1', 'hat_01_c2', 'hat_01_c3', 'hat_02', 'hat_02_c1']);
    });

    test('기본 소품이 목록에 없는 색 소품은 맨 뒤', () {
      final lone = props.firstWhere((p) => p.id == 'hat_01_c1');
      final rest = props.where((p) => p.id != 'hat_01' && p.variantOf != 'hat_01').toList();
      expect(_ids(variantsAfterBase([lone, ...rest])).last, 'hat_01_c1');
    });
  });

  group('상점 상품', () {
    test('색 소품 21개를 소품 탭 상품으로: 값은 props unlock.price, requires는 기본 소품', () {
      final items = colorShopItems(props);
      expect(items, hasLength(21));
      expect(_ids(items), _ids(variantsAfterBase(props).where((p) => p.isColorVariant)));
      for (final (i, item) in items.indexed) {
        final p = props.firstWhere((p) => p.id == item.id);
        expect(item.tab, ShopTab.prop);
        expect(item.propId, p.id);
        expect(item.name, p.name);
        expect(item.price, p.price);
        expect(item.requires, p.variantOf);
        expect(item.order, i + 1);
        expect(item.effect, isNull);
      }
      expect(colorShopItem(props, 'hat_01_c1')!.name, '봄하늘 베레모');
      expect(colorShopItem(props, 'hat_01'), isNull);
      expect(colorShopItem(props, 'face_01'), isNull);
    });

    test('shop.json 상품과 id가 겹치지 않는다', () {
      final shopIds = {for (final i in shopCatalog.items) i.id};
      expect(_ids(colorShopItems(props)).where(shopIds.contains), isEmpty);
    });

    test('처음에는 기본 색 소품 3종(베레모·앞치마·갈색 신발)의 9개만 보인다', () {
      final have = havePropIds(props, const {});
      expect(have, containsAll(initialPropIds));
      expect(_ids(shownColorItems(props, have)), [
        for (final base in ['hat_01', 'cloth_01', 'shoe_01'])
          for (var n = 1; n <= 3; n++) '${base}_c$n',
      ]);
    });

    test('기본 소품을 얻으면 그 색 소품이 기본 소품 순서 자리에 끼어든다', () {
      final have = havePropIds(props, {'hat_04'});
      final ids = _ids(shownColorItems(props, have));
      expect(ids, hasLength(12));
      expect(ids.sublist(3, 6), ['hat_04_c1', 'hat_04_c2', 'hat_04_c3']);
    });

    test('기본 소품이 없으면 막는다 (잔액이 넉넉해도)', () {
      final item = colorShopItem(props, 'hat_02_c1')!;
      ShopBlock? block({required bool base, int balance = 1000, bool owned = false}) => buyBlock(
            item,
            balance: balance,
            held: 0,
            maxHold: 9,
            owned: owned,
            hasRequired: base,
          );
      expect(block(base: false), ShopBlock.needsBase);
      expect(block(base: true), isNull);
      expect(block(base: true, balance: item.price - 1), ShopBlock.notEnoughCoins);
      expect(block(base: true, owned: true), ShopBlock.owned);
    });
  });

  group('꾸미기에 보이는가', () {
    test('색 소품은 기본 소품을 가졌을 때만, 기본 소품이 아닌 것은 늘', () {
      final byId = {for (final p in props) p.id: p};
      final have = havePropIds(props, {'hat_02_c1'});
      expect(baseHeld(byId['hat_01_c1']!, have), isTrue);
      expect(baseHeld(byId['hat_02_c1']!, have), isFalse);
      expect(baseHeld(byId['face_01']!, have), isTrue);
    });
  });
}
