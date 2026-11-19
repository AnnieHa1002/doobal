import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/companion.dart';
import 'package:doobal/domain/decor.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/domain/trail_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _json(String file) =>
    jsonDecode(File('assets/data/$file').readAsStringSync()) as Map<String, dynamic>;

final _shop = parseShop(_json('shop.json'));
final _boats = parseBoats(_json('boats.json'));
final _companions = parseCompanions(_json('companions.json'));
final _decor = parseDecor(_json('decor.json'));
final _trails = parseTrails(_json('trails.json'));

void main() {
  group('shop.json', () {
    test('지금 상점 화면의 탭 4개는 옛 탭(v6)과 같은 상품을 order 순서로 (v9는 탭 대신 분류)', () {
      expect(ShopTab.values.map((t) => _shop.inTab(t).length), [2, 10, 5, 6]);
      expect(ShopTab.values.map((t) => t.label), ['여행 효과', '소품', '꾸밈 효과', '배']);
      for (final t in ShopTab.values) {
        final orders = _shop.inTab(t).map((i) => i.order).toList();
        expect(orders, [...orders]..sort(), reason: t.name);
      }
      expect(_shop.inTab(ShopTab.effect).every((i) => i.slot == 'effect'), isTrue);
    });

    test('v9 분류: 분류 순서·아이콘을 읽고, 꾸밈 물품·무늬·물감 통·상점 미니 친구는 지금 탭에 없다', () {
      expect(_shop.categories, ShopCategory.values);
      expect(_shop.categoryIcons, {
        ShopCategory.travel: 'icon_shop_cat_effect_v01',
        ShopCategory.prop: 'icon_shop_cat_prop_v01',
        ShopCategory.decor: 'icon_shop_cat_deco_v01',
        ShopCategory.boat: 'icon_shop_cat_boat_v01',
      });
      final hidden = [for (final i in _shop.items) if (i.tab == null) i.id];
      expect(hidden, [
        for (var n = 6; n <= 13; n++) 'pet_${n.toString().padLeft(2, '0')}',
        'trail_01',
        'trail_02',
        'trail_03',
        'paint_tube',
        for (final d in _decor.items)
          if (d.kind == DecorUnlockKind.shop) d.id,
      ]);
      final tube = _shop.byId('paint_tube')!;
      expect((tube.category, tube.slot, tube.consumable, tube.effect), (ShopCategory.prop, 'paintTube', true, null));
      expect((_shop.byId('trail_02')!.trailId, _shop.byId('trail_02')!.slot), ('trail_02', 'trail'));
      expect(_shop.byId('decor_pond')!.decorId, 'decor_pond');
      expect(_shop.byId('pet_06')!.propId, 'pet_06');
    });

    test('꾸밈 물품·무늬 상품은 decor.json·trails.json과 값이 같다', () {
      for (final i in _shop.items) {
        if (i.decorId case final id?) {
          expect(_decor.byId(id)?.price, i.price, reason: i.id);
        }
        if (i.trailId case final id?) {
          expect(_trails.byId(id)?.shopPrice, i.price, reason: i.id);
        }
      }
    });

    test('여행 효과는 종류와 값, 하루 한도, 보관 한도를 가진다', () {
      final shortcut = _shop.byId('fx_shortcut')!;
      expect((shortcut.effect!.kind, shortcut.effect!.km, shortcut.price, shortcut.dailyLimit),
          (ShopEffectKind.travelKmInstant, 1.0, 50, 2));
      final tailwind = _shop.byId('fx_tailwind')!;
      expect((tailwind.effect!.kind, tailwind.effect!.ratio, tailwind.price, tailwind.dailyLimit),
          (ShopEffectKind.travelRatioUntilWalkEnd, 0.2, 40, 1));
      for (final i in _shop.inTab(ShopTab.travel)) {
        expect(i.requiresJourney, isTrue, reason: i.id);
        expect(i.maxHold, rules.shopMaxHoldPerItem, reason: i.id);
      }
    });

    test('소품·꾸밈 효과 상품은 props.json과 값이 같다', () {
      final byId = {for (final p in parseProps(_json('props.json'))) p.id: p};
      for (final tab in [ShopTab.prop, ShopTab.effect]) {
        for (final i in _shop.inTab(tab)) {
          final p = byId[i.propId];
          expect(p, isNotNull, reason: '${i.id}: props.json에 없다');
          expect((p!.kind, p.price), (PropUnlockKind.shop, i.price), reason: i.id);
        }
      }
    });

    test('배 상품은 boats.json 상점 배와 값이 같고, 빠진 배가 없다', () {
      final sold = {for (final i in _shop.inTab(ShopTab.boat)) i.boatId: i.price};
      expect(sold, {
        for (final b in _boats.boats)
          if (b.kind == BoatUnlockKind.shop) b.id: b.price,
      });
    });

    test('모르는 분류나 효과는 FormatException', () {
      Map<String, dynamic> withItem(Map<String, dynamic> item, [List<String> categories = const []]) =>
          {'categories': categories, 'defaultBoat': 'b', 'items': [item]};
      Map<String, dynamic> item(String category, [Object? effect]) =>
          {'id': 'x', 'category': category, 'name': 'x', 'price': 1, 'order': 1, 'effect': effect};
      expect(parseShop(withItem(item('decor'))).items.single.tab, isNull);
      expect(() => parseShop(withItem(item('hat'))), throwsFormatException);
      expect(() => parseShop(withItem(item('travel', {'kind': 'warp'}))), throwsFormatException);
      expect(() => parseShop(withItem(item('travel'), ['effect'])), throwsFormatException);
    });
  });

  group('boats.json', () {
    test('9척을 order 순서로 읽고, 기본 배는 shop.json defaultBoat다', () {
      expect(_boats.boats, hasLength(9));
      final orders = _boats.boats.map((b) => b.order).toList();
      expect(orders, [...orders]..sort());
      final initial = [for (final b in _boats.boats) if (b.kind == BoatUnlockKind.initial) b.id];
      expect(initial, [_shop.defaultBoat]);
    });

    test('섬 도착 배: 조각배는 둘 중 하나, 돛단배는 둘 다', () {
      final skiff = _boats.byId('boat_skiff')!;
      expect((skiff.kind, skiff.allIslands), (BoatUnlockKind.islandArrival, false));
      expect(skiff.islands, ['jeju', 'ulleung']);
      expect(_boats.byId('boat_voyage')!.allIslands, isTrue);
    });

    test('그림은 앞판·뒤판 이름과 발 자리를 갖고, 창 불빛은 유람선만', () {
      for (final b in _boats.boats) {
        expect(b.layers.rear, contains('rear'), reason: b.id);
        expect(b.layers.front, contains('front'), reason: b.id);
        expect(b.layers.mainFoot.y, _boats.deckY, reason: b.id);
        expect(b.layers.mainFoot.x, inInclusiveRange(0, _boats.canvasWidth), reason: b.id);
      }
      expect([for (final b in _boats.boats) if (b.nightOverlay != null) b.id], ['boat_cruise']);
      expect(_boats.assetPath('a.png'), 'assets/boats/v01fix/a.png');
    });

    test('모르는 해금 조건은 FormatException', () {
      final raw = jsonDecode(jsonEncode(_json('boats.json'))) as Map<String, dynamic>;
      ((raw['boats'] as List).first as Map<String, dynamic>)['unlock'] = {'kind': 'gift'};
      expect(() => parseBoats(raw), throwsFormatException);
    });
  });

  group('companions.json', () {
    test('세 동행, 장은 0부터 config companions.chapters까지 빠짐없이', () {
      expect(_companions.companions.map((c) => c.id), ['bright', 'rest', 'doctor']);
      for (final c in _companions.companions) {
        expect(c.chapters.map((ch) => ch.no),
            List.generate(rules.companionChapters + 1, (i) => i), reason: c.id);
      }
    });

    test('완결 소품은 props.json의 그 동행 소품이고, 마지막 장에서 받는다', () {
      final byId = {for (final p in parseProps(_json('props.json'))) p.id: p};
      for (final c in _companions.companions) {
        final p = byId[c.finaleProp];
        expect(p, isNotNull, reason: '${c.id}: ${c.finaleProp}가 props.json mvp에 없다');
        expect((p!.kind, p.companion), (PropUnlockKind.companion, c.id), reason: c.id);
        expect(c.chapters.last.prop, c.finaleProp, reason: c.id);
      }
    });

    test('그림은 프롤로그와 마지막 장만, 고르기는 프롤로그만', () {
      for (final c in _companions.companions) {
        expect([for (final ch in c.chapters) if (ch.art != null) ch.no],
            [0, rules.companionChapters], reason: c.id);
        expect(c.chapters.first.choices, ['together', 'solo'], reason: c.id);
        expect(c.chapters.skip(1).every((ch) => ch.choices.isEmpty), isTrue, reason: c.id);
      }
    });

    test('대사의 표정은 그 동행의 표정 목록 안에 있다', () {
      for (final c in _companions.companions) {
        for (final ch in c.chapters) {
          expect(ch.lines, isNotEmpty, reason: '${c.id} ${ch.no}');
          for (final l in ch.lines) {
            if (l.face != null) expect(c.faces, contains(l.face), reason: '${c.id} ${ch.no}');
          }
        }
      }
    });

    test('안경 층을 숨기는 동행은 심 박사뿐이다', () {
      expect([for (final c in _companions.companions) if (c.hideLayerOnFinale != null) c.id],
          ['doctor']);
    });

    test('v3: 종 이름과 층을 숨기는 때를 읽는다', () {
      expect({for (final c in _companions.companions) c.id: c.speciesName},
          {'bright': '오리', 'rest': '고양이', 'doctor': '산삼'});
      expect(_companions.byId('doctor')!.hideLayerWhen, HideLayerWhen.finaleRead);
      expect(_companions.byId('bright')!.hideLayerWhen, isNull);
    });

    test('v4: 쉼터 한마디를 동행마다 셋씩 읽는다 (출처는 있을 때만)', () {
      for (final c in _companions.companions) {
        expect(c.restLines, hasLength(3), reason: c.id);
        expect(c.restLines.every((l) => l.text.isNotEmpty), isTrue, reason: c.id);
      }
      final doctor = _companions.byId('doctor')!.restLines;
      expect((doctor.first.text, doctor.first.source), ('물은 마셨지요? 호호.', 'H5'));
      expect(_companions.byId('bright')!.restLines.first.source, isNull);
    });

    test('모르는 pace나 말하는 이는 FormatException', () {
      Map<String, dynamic> one(String pace, String who) => {
            'companions': [
              {
                'id': 'x',
                'name': 'x',
                'species': 'x',
                'speciesName': 'x',
                'terrain': 'city',
                'pace': pace,
                'finaleProp': 'p',
                'faces': <String>[],
                'chapters': [
                  {
                    'no': 0,
                    'title': 't',
                    'lines': [
                      {'who': who, 'text': 't'}
                    ],
                  }
                ],
              }
            ]
          };
      expect(parseCompanions(one('match', 'me')).byId('x')!.restLines, isEmpty);
      expect(() => parseCompanions(one('fly', 'me')), throwsFormatException);
      expect(() => parseCompanions(one('match', 'cat')), throwsFormatException);
      final when = one('match', 'me');
      (when['companions'] as List).first['hideLayerWhen'] = 'chapterOpened';
      expect(() => parseCompanions(when), throwsFormatException);
    });
  });

  group('decor.json', () {
    test('보상 4 + 상점 8을 order 순서로, 얻는 길과 값을 읽는다', () {
      expect(_decor.items, hasLength(12));
      expect((_decor.maxPlaced, _decor.perItem), (20, 1));
      final orders = _decor.items.map((i) => i.order).toList();
      expect(orders, [...orders]..sort());
      expect(_decor.items.where((i) => i.kind == DecorUnlockKind.shop), hasLength(8));
      final easel = _decor.byId('decor_easel')!;
      expect((easel.kind, easel.giftOn, easel.paintingSlots, easel.startPainting),
          (DecorUnlockKind.gift, 'firstSketchArrival', 1, 'sketch'));
      expect([for (final i in _decor.items) if (i.kind == DecorUnlockKind.landmarksVisited) i.landmarks],
          [1, 5, 10]);
      expect(_decor.byId('decor_clothesline')!.paintingSlots, 3);
      expect([for (final i in _decor.items) if (i.nightLight) i.id], ['decor_lantern', 'decor_stone_lantern']);
      expect(_decor.byId('decor_pond')!.price, 800);
      expect(_decor.byId('decor_bench')!.art, 'obj_camp_deco_bench_v01_clean');
    });

    test('모르는 얻는 길, 빠진 값, 겹친 id는 FormatException', () {
      Map<String, dynamic> one(Map<String, dynamic> unlock, {String id = 'x'}) =>
          {'id': id, 'name': 'x', 'unlock': unlock, 'order': 1, 'art': 'a'};
      Map<String, dynamic> file(List<Map<String, dynamic>> items) =>
          {'maxPlaced': 20, 'perItem': 1, 'items': items};
      expect(parseDecor(file([one({'kind': 'shop', 'price': 1})])).items.single.paintingSlots, 0);
      expect(() => parseDecor(file([one({'kind': 'quest'})])), throwsFormatException);
      expect(() => parseDecor(file([one({'kind': 'shop'})])), throwsFormatException);
      expect(() => parseDecor(file([one({'kind': 'landmarksVisited'})])), throwsFormatException);
      expect(() => parseDecor(file([one({'kind': 'gift'})])), throwsFormatException);
      final dup = one({'kind': 'shop', 'price': 1});
      expect(() => parseDecor(file([dup, dup])), throwsFormatException);
    });
  });

  group('trails.json', () {
    test('기본 방울 + 무늬 3종, 거리 10·50·100km와 값 200 럭 (가안)', () {
      expect(_trails.patterns.map((p) => p.id), ['drops', 'trail_01', 'trail_02', 'trail_03']);
      expect(_trails.defaultPattern.id, 'drops');
      expect((_trails.defaultPattern.kind, _trails.defaultPattern.icon, _trails.defaultPattern.pending),
          (TrailUnlockKind.initial, null, false));
      final rest = _trails.patterns.skip(1);
      expect(rest.map((p) => p.km), [10, 50, 100]);
      expect(rest.every((p) => p.kind == TrailUnlockKind.trailKm && p.shopPrice == 200 && p.pending),
          isTrue);
      expect((_trails.byId('trail_02')!.tile, _trails.byId('trail_02')!.cap),
          ('map_trail_petal_tile_v01', 'map_trail_petal_cap_v01'));
    });

    test('모르는 얻는 길, 거리 없음, 기본 무늬 없음, 겹친 id는 FormatException', () {
      Map<String, dynamic> one(String id, Map<String, dynamic> unlock) =>
          {'id': id, 'name': id, 'unlock': unlock, 'tile': 't', 'cap': 'c'};
      final drops = one('drops', {'kind': 'default'});
      Map<String, dynamic> file(List<Map<String, dynamic>> p, [String d = 'drops']) =>
          {'default': d, 'patterns': p};
      expect(parseTrails(file([drops])).defaultPattern.name, 'drops');
      expect(() => parseTrails(file([drops, one('a', {'kind': 'shop'})])), throwsFormatException);
      expect(() => parseTrails(file([drops, one('a', {'kind': 'trailKm'})])), throwsFormatException);
      expect(() => parseTrails(file([drops], 'stars')), throwsFormatException);
      expect(() => parseTrails(file([drops, drops])), throwsFormatException);
    });
  });

  test('config: 동행·상점·광고 값을 읽는다', () {
    expect(rules.companionGuaranteeDays, [14, 28]);
    expect((rules.companionWalksPerChapter, rules.companionChapters), (4, 8));
    expect((rules.companionAheadEverySec, rules.companionAheadAwaySec), (90, 8));
    expect((rules.companionLagCatchUpMps, rules.companionLateArrivalMaxSec), (0.5, 600));
    expect(rules.companionWalkMps, 1.3);
    expect((rules.shopDailyEffectCapKm, rules.shopMaxHoldPerItem), (3, 9));
    expect((rules.adsRewardedPerDay, rules.adsMaxRewardCoins), (1, 400));
  });
}
