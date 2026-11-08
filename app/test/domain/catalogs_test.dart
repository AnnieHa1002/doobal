import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/companion.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/shop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _json(String file) =>
    jsonDecode(File('assets/data/$file').readAsStringSync()) as Map<String, dynamic>;

final _shop = parseShop(_json('shop.json'));
final _boats = parseBoats(_json('boats.json'));
final _companions = parseCompanions(_json('companions.json'));

void main() {
  group('shop.json', () {
    test('탭마다 상품을 order 순서로 읽는다', () {
      expect(ShopTab.values.map((t) => _shop.inTab(t).length), [2, 10, 5, 6]);
      for (final t in ShopTab.values) {
        final orders = _shop.inTab(t).map((i) => i.order).toList();
        expect(orders, [...orders]..sort(), reason: t.name);
        expect(_shop.tabLabels[t], isNotEmpty, reason: t.name);
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

    test('모르는 탭이나 효과는 FormatException', () {
      Map<String, dynamic> withItem(Map<String, dynamic> item) =>
          {'tabLabels': <String, dynamic>{}, 'defaultBoat': 'b', 'items': [item]};
      Map<String, dynamic> item(String tab, [Object? effect]) =>
          {'id': 'x', 'tab': tab, 'name': 'x', 'price': 1, 'order': 1, 'effect': effect};
      expect(() => parseShop(withItem(item('hat'))), throwsFormatException);
      expect(() => parseShop(withItem(item('travel', {'kind': 'warp'}))), throwsFormatException);
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
      expect(parseCompanions(one('match', 'me')).byId('x'), isNotNull);
      expect(() => parseCompanions(one('fly', 'me')), throwsFormatException);
      expect(() => parseCompanions(one('match', 'cat')), throwsFormatException);
      final when = one('match', 'me');
      (when['companions'] as List).first['hideLayerWhen'] = 'chapterOpened';
      expect(() => parseCompanions(when), throwsFormatException);
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
