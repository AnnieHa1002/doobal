import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/camp_theme.dart';
import 'package:doobal/domain/decor.dart';
import 'package:doobal/domain/decor_place.dart';
import 'package:doobal/domain/decor_rules.dart';
import 'package:doobal/domain/sky.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _json(String file) =>
    jsonDecode(File('assets/data/$file').readAsStringSync()) as Map<String, dynamic>;

final _decor = parseDecor(_json('decor.json'));
DecorItem _item(String id) => _decor.byId(id)!;

final DecorStage _stage = DecorStage.of(campTheme, rules.decor.place, screenHeightPx: rules.screenHeightPx)!;

void main() {
  group('decor.json v2 자리 (T15)', () {
    test('캔버스·화면 크기·바닥점·걸 자리·빛을 읽는다', () {
      final easel = _item('decor_easel');
      expect((easel.canvasPx!.w, easel.canvasPx!.h), (768, 768));
      expect((easel.showPx!.w, easel.showPx!.h), (216, 330));
      expect((easel.groundAt!.x, easel.groundAt!.y), (384, 707));
      expect(easel.slotsAt, hasLength(1));
      final s = easel.slotsAt.single;
      expect((s.x, s.y, s.w, s.h, s.hangAt.x, s.hangAt.y, s.frameVisiblePx, s.attach),
          (192, 202, 391, 293, 387, 202, 150, 'bottom_on_ledge'));
      expect(_item('decor_clothesline').slotsAt, hasLength(3));
      final lantern = _item('decor_lantern').light!;
      expect((lantern.at.x, lantern.at.y, lantern.radiusPx, lantern.dayOff), (323, 231, 220, true));
      expect(_item('decor_stone_lantern').light!.radiusPx, 260);
      expect(_item('decor_bench').light, isNull);
      for (final i in _decor.items) {
        expect(i.slotsAt.length, i.paintingSlots, reason: i.id);
        expect(_stage.canPlace(i), isTrue, reason: i.id);
      }
    });

    test('캔버스 → 화면 배율: 그림 상자가 있으면 상자로, 없으면 걸 칸의 보이는 높이 ÷ 칸 높이', () {
      // README: 이젤 칸 293px이 화면 150px (그림 상자 높이 645 → 330과 같은 배율)
      expect(_item('decor_easel').pxPerCanvasPx, closeTo(150 / 293, 1e-9));
      expect(_item('decor_easel').pxPerCanvasPx, closeTo(330 / 645, 0.002));
      expect(_item('decor_clothesline').pxPerCanvasPx, closeTo(120 / 158, 1e-9));
      // 걸 칸이 없으면 화면 높이 ÷ 바닥점 y (추정)
      expect(_item('decor_lantern').pxPerCanvasPx, closeTo(230 / 471, 1e-9));
      final withBox = parseDecor({
        'maxPlaced': 20,
        'perItem': 1,
        'items': [
          {
            'id': 'x',
            'name': 'x',
            'order': 1,
            'art': 'a',
            'unlock': {'kind': 'shop', 'price': 1},
            'canvasPx': [512, 512],
            'showPx': [146, 230],
            'groundAt': [256, 471],
            'bboxPx': [119, 41, 392, 471],
          }
        ],
      }).items.single;
      expect(withBox.pxPerCanvasPx, closeTo(230 / 430, 1e-9));
    });

    test('자리 값이 틀리면 FormatException', () {
      Map<String, dynamic> file(Map<String, dynamic> extra) => {
            'maxPlaced': 20,
            'perItem': 1,
            'items': [
              {'id': 'x', 'name': 'x', 'order': 1, 'art': 'a', 'unlock': {'kind': 'shop', 'price': 1}, ...extra}
            ],
          };
      expect(() => parseDecor(file({'showPx': [1]})), throwsFormatException);
      expect(() => parseDecor(file({'paintingSlots': 2, 'paintingSlotsAt': [{'slot': [0, 0, 1, 1]}]})),
          throwsFormatException);
      expect(() => parseDecor(file({'light': {'lightRadiusPx': 3}})), throwsFormatException);
      // v1 꼴(자리 값 없음)은 읽되 놓지 못한다
      final v1 = parseDecor(file({})).items.single;
      expect(_stage.canPlace(v1), isFalse);
      expect(_stage.freeSpotNear(v1, _stage.easelStart), isNull);
    });
  });

  group('camp_wide decor (T15)', () {
    test('땅 띠·못 놓는 자리(정령은 둥둥 정령 + 둘레 8pt)·이젤 첫 자리', () {
      final d = campTheme.decor!;
      expect((d.band.xMin, d.band.xMax, d.band.footYMin, d.band.footYMax), (8, 577, 650, 800));
      final c = d.blockedOf('character')!.box;
      // characterFloat x 46·폭 92·키 115·발 725·뜸 17 → 몸 593~708, 둘레 8
      expect((c.x, c.y, c.w, c.h), (38, 585, 108, 148));
      final f = d.blockedOf('campfire')!.box;
      expect((f.x, f.y, f.w, f.h), (166, 676, 62, 85));
      final cart = d.blockedOf('cart')!.box;
      expect((cart.x, cart.y, cart.w, cart.h), (432, 522, 136, 148));
      expect((d.easelFootX, d.easelFootY), (300, 700));
    });

    test('decor가 없는 테마(v3 꼴)는 꾸미기 자리도 없다', () {
      expect(campThemeV3.decor, isNull);
      expect(DecorStage.of(campThemeV3, rules.decor.place, screenHeightPx: 2532), isNull);
    });
  });

  group('config rest.decor·firstSketchGift·finaleRoam (T15)', () {
    test('지금 config 값', () {
      final r = rules.decor.place;
      expect(r.maxPlaced, 20);
      expect(r.blocked, {'character', 'campfire', 'cart'});
      expect(r.flipButton, isTrue);
      expect((r.edgeScroll.edgePt, r.edgeScroll.ptPerSec), (40, 240));
      expect((r.tintSeason, r.tintTime, r.hungTapOpensBigView), (true, true, true));
      expect(r.nightLight.items, {'decor_lantern', 'decor_stone_lantern'});
      expect((r.nightLight.radiusPt, r.nightLight.centerAlpha), (90, 0.35));
      expect(r.nightLight.phases, {SkyPhase.night, SkyPhase.dawn, SkyPhase.sunset});
      expect(r.nightLight.onAt(SkyPhase.day), isFalse);
      // 반딧불 빛(effects.items.effect_05.glow) 재사용: 색 두 개, 더하기
      expect(r.nightLight.colors, [0xFFFFFFFF, 0xFFFFF6C8]);
      expect(r.nightLight.additive, isTrue);
      final g = rules.decor.firstSketchGift!;
      expect((g.decorId, g.hangs), ('decor_easel', 'sketch'));
      final roam = rules.decor.finaleRoam!;
      expect((roam.walkPtPerSec, roam.stopMinSec, roam.stopMaxSec, roam.sitChance), (12, 4, 10, 0.3));
      expect((roam.bubbleSec, roam.noRepeat, roam.secondTapOpensCompanion), (3, true, true));
    });

    test('모르는 동작이면 FormatException, rest.decor가 없으면 꾸미기 없음', () {
      Map<String, dynamic> config() =>
          jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
      Map<String, dynamic> decor(Map<String, dynamic> c) =>
          (c['rest'] as Map<String, dynamic>)['decor'] as Map<String, dynamic>;
      for (final (key, value) in [
        ('editMode', true),
        ('pick', 'tap'),
        ('order', 'upperIsFront'),
        ('remove', 'trashButton'),
        ('tint', ['weather']),
      ]) {
        final c = config();
        decor(c)[key] = value;
        expect(() => DecorRules.fromJson(c), throwsFormatException, reason: key);
      }
      final reuse = config();
      (decor(reuse)['nightLight'] as Map)['reuse'] = 'effects.items.effect_99.glow';
      expect(() => DecorRules.fromJson(reuse), throwsFormatException);
      final phase = config();
      (decor(phase)['nightLight'] as Map)['phases'] = ['noon'];
      expect(() => DecorRules.fromJson(phase), throwsFormatException);
      final none = config();
      (none['rest'] as Map).remove('decor');
      expect(DecorRules.fromJson(none).enabled, isFalse);
      final roam = config();
      ((roam['companions'] as Map)['finaleRoam'] as Map)['when'] = 'chapter9Read';
      expect(() => FinaleRoamRules.fromJson(roam), throwsFormatException);
      final gift = config();
      ((gift['coins'] as Map)['firstSketchGift'] as Map)['placeAt'] = 'random';
      expect(() => FirstSketchGift.fromJson(gift), throwsFormatException);
    });
  });

  group('DecorStage 자리 계산 (T15)', () {
    test('비율로 저장하고 되읽는다 (x ÷ 장면 폭, 발 y는 띠 안 비율), 띠 밖 값은 띠 안으로', () {
      const p = ScenePoint(300, 700);
      final r = _stage.toRatio(p);
      expect(r.x, closeTo(300 / 585, 1e-9));
      expect(r.y, closeTo(50 / 150, 1e-9));
      final back = _stage.fromRatio(r.x, r.y);
      expect(back.x, closeTo(300, 1e-9));
      expect(back.y, closeTo(700, 1e-9));
      expect(_stage.fromRatio(2, -1), const ScenePoint(577, 650));
      expect(_stage.clampToBand(const ScenePoint(0, 900)), const ScenePoint(8, 800));
      expect(_stage.easelStart, const ScenePoint(300, 700));
    });

    test('보이는 크기는 화면 px ÷ 3 (기준 화면 844pt ÷ 2532px), 발이 아래 가운데', () {
      expect(_stage.ptPerPx, closeTo(1 / 3, 1e-12));
      final s = _stage.shownSize(_item('decor_easel'))!;
      expect(s.w, closeTo(72, 1e-9));
      expect(s.h, closeTo(110, 1e-9));
      final box = _stage.boxAt(_item('decor_easel'), const ScenePoint(300, 700));
      expect([box.left, box.top, box.width, box.height],
          [closeTo(264, 1e-9), closeTo(590, 1e-9), closeTo(72, 1e-9), closeTo(110, 1e-9)]);
    });

    test('그림 칸·빛 자리, 좌우 뒤집으면 칸 x → W − x − w', () {
      final easel = _item('decor_easel');
      const foot = ScenePoint(300, 700);
      final k = 150 / 293 / 3;
      final l = _stage.layout(easel, foot);
      // 칸 높이 = 보이는 액자 높이 150px = 50pt
      expect(l.slots.single.height, closeTo(50, 1e-9));
      expect(l.slots.single.left, closeTo(300 + (192 - 384) * k, 1e-9));
      expect(l.slots.single.top, closeTo(700 + (202 - 707) * k, 1e-9));
      expect(l.hangs.single.x, closeTo(300 + (387 - 384) * k, 1e-9));
      final f = _stage.layout(easel, foot, flipped: true);
      expect(f.slots.single.left, closeTo(300 + (768 - 192 - 391 - 384) * k, 1e-9));
      expect(f.hangs.single.x, closeTo(300 + (768 - 387 - 384) * k, 1e-9));
      // 보이는 상자는 뒤집어도 같다
      expect(f.box.left, l.box.left);
      expect(l.lightAt, isNull);
      final lantern = _stage.layout(_item('decor_lantern'), foot);
      final lk = 230 / 471 / 3;
      expect(lantern.lightAt!.x, closeTo(300 + (323 - 256) * lk, 1e-9));
      expect(lantern.lightAt!.y, closeTo(700 + (231 - 471) * lk, 1e-9));
      expect(lantern.lightRadius, closeTo(220 / 3, 1e-9));
      final flipped = _stage.layout(_item('decor_lantern'), foot, flipped: true);
      expect(flipped.lightAt!.x, closeTo(300 + (512 - 323 - 256) * lk, 1e-9));
    });

    test('못 놓는 자리: 정령·모닥불·수레 상자에 물품 상자가 겹치면, 띠 밖이면 막힘', () {
      final easel = _item('decor_easel');
      expect(_stage.blockedAt(easel, _stage.easelStart), isNull);
      expect(_stage.blockedAt(easel, const ScenePoint(92, 725)), 'character');
      expect(_stage.blockedAt(easel, const ScenePoint(197, 760)), 'campfire');
      expect(_stage.blockedAt(easel, const ScenePoint(500, 700)), 'cart');
      expect(_stage.blockedAt(easel, const ScenePoint(500, 790)), isNull);
      expect(_stage.blockedAt(easel, const ScenePoint(300, 640)), 'band');
      // 규칙에 없는 자리는 막지 않는다
      final noCart = DecorStage(
        decor: campTheme.decor!,
        rules: DecorRules(
          maxPlaced: 20,
          blocked: const {'character', 'campfire'},
          flipButton: true,
          edgeScroll: rules.decor.place.edgeScroll,
          tintSeason: true,
          tintTime: true,
          hungTapOpensBigView: true,
          nightLight: rules.decor.place.nightLight,
        ),
        sceneWidth: 585,
        spiritFootY: 725,
        ptPerPx: 1 / 3,
      );
      expect(noCart.blockedAt(easel, const ScenePoint(500, 700)), isNull);
    });

    test('빈 자리 찾기: 막힌 곳이면 옆으로, 모두 막히면 null', () {
      final easel = _item('decor_easel');
      final spot = _stage.freeSpotNear(easel, const ScenePoint(92, 725))!;
      expect(_stage.blockedAt(easel, spot), isNull);
      expect(_stage.inBand(spot), isTrue);
      expect(_stage.freeSpotNear(easel, _stage.easelStart), _stage.easelStart);
      final tight = DecorStage(
        decor: CampDecor(
          band: const CampGroundBand(xMin: 0, xMax: 100, footYMin: 650, footYMax: 660),
          blocked: const [CampBlocked(id: 'campfire', box: CampBox(0, 0, 200, 1000))],
        ),
        rules: rules.decor.place,
        sceneWidth: 585,
        spiritFootY: 725,
        ptPerPx: 1 / 3,
      );
      expect(tight.freeSpotNear(easel, const ScenePoint(50, 655)), isNull);
    });

    test('앞뒤: 발 y가 큰 것이 앞, 같으면 나중에 놓은 것이 앞. 정령 발보다 아래면 정령 앞', () {
      final order = _stage.drawOrder(const [
        DecorSpot(decorId: 'a', foot: ScenePoint(10, 760), placedUtc: 1),
        DecorSpot(decorId: 'b', foot: ScenePoint(10, 700), placedUtc: 5),
        DecorSpot(decorId: 'c', foot: ScenePoint(10, 760), placedUtc: 0),
      ]);
      expect([for (final s in order) s.decorId], ['b', 'c', 'a']);
      expect(_stage.frontOfSpirit(const ScenePoint(0, 725)), isFalse);
      expect(_stage.frontOfSpirit(const ScenePoint(0, 726)), isTrue);
    });

    test('화면 끝 40pt 안으로 끌면 초당 240pt로 민다 (오른쪽 끝 → 장면을 왼쪽으로)', () {
      expect(_stage.edgeScrollSpeed(380, 390), -240);
      expect(_stage.edgeScrollSpeed(350, 390), -240);
      expect(_stage.edgeScrollSpeed(200, 390), 0);
      expect(_stage.edgeScrollSpeed(40, 390), 240);
      expect(_stage.edgeScrollSpeed(41, 390), 0);
    });
  });

  group('보상·선물 물품 (T15)', () {
    test('명소 n곳은 서로 다른 명소 수, 이젤은 첫 그림을 가지면, 상점 물품은 사야 한다', () {
      List<String> got({Set<String> owned = const {}, int visited = 0, bool sketch = false}) => [
            for (final i in decorToUnlock(_decor, owned: owned, visitedLandmarks: visited, sketchArrived: sketch))
              i.id,
          ];
      expect(got(), isEmpty);
      expect(got(sketch: true), ['decor_easel']);
      expect(got(sketch: true, visited: 1), ['decor_easel', 'decor_hanging_frame']);
      expect(got(visited: 4), ['decor_hanging_frame']);
      expect(got(visited: 5), ['decor_hanging_frame', 'decor_clothesline']);
      expect(got(visited: 10, sketch: true),
          ['decor_easel', 'decor_hanging_frame', 'decor_clothesline', 'decor_big_frame']);
      expect(got(visited: 10, sketch: true, owned: {'decor_easel', 'decor_hanging_frame'}),
          ['decor_clothesline', 'decor_big_frame']);
      expect(got(visited: 999, sketch: true).where((id) => _item(id).kind == DecorUnlockKind.shop), isEmpty);
    });
  });
}
