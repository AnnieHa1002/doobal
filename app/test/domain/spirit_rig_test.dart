import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_rig.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Rive v32 inputs.md의 색 입력 38개 (뷰 모델 WardrobeColors, 11/13 런타임으로 확인)
const _rigColors = [
  'beretColor', 'featherHatColor', 'bambooHatColor', 'sillaCrownColor', //
  'roundGlassesColor', 'headphonesColor', 'earmuffsColor',
  'travelCapeColor', 'starryCapeColor', 'workApronColor', 'travelVestColor', 'goldArtistCoatColor',
  'greenBootsColor', 'catSlippersColor', 'strawSandalsColor', 'brownShoesColor', 'hikingBootsColor',
  'woolMittensColor', 'birdWingsColor', 'leafGlovesColor', 'catPawMittensColor', 'goldWingArmsColor',
  'brushBagColor', 'artSatchelColor', 'easelBackpackColor', 'scrollCaseColor', 'walkingStickPackColor',
  'paperBirdColor', 'haechiFriendColor', 'lambFriendColor', 'dolhareubangFriendColor', 'gullFriendColor',
  'starLanternColor', 'lotusLeafFloatColor', 'smallMoonFloatColor', 'floatCloudColor', 'floatBalloonColor',
];

void main() {
  group('소품 → Rive 칸·번호·색 (v32 시험 버튼 이름으로 대조, 11/13)', () {
    final mvp = [for (final p in props) if (!p.isColorVariant && p.slot != 'effect') p];

    test('효과 말고 모든 소품(37)이 자기 칸의 Rive 입력에 있다', () {
      expect(mvp, hasLength(37));
      for (final p in mvp) {
        final rig = rigProps[p.id];
        expect(rig, isNotNull, reason: p.id);
        expect(rig!.choice, rigChoiceOfSlot[p.slot], reason: p.id);
      }
      expect(rigProps.keys.toSet(), {for (final p in mvp) p.id});
    });

    test('칸마다 번호는 1부터 겹치지 않고(모자 4·얼굴 3·나머지 5), 색 입력은 v32의 37개(몸 색 빼고)와 같다', () {
      for (final choice in rigChoiceOfSlot.values) {
        final values = [for (final r in rigProps.values) if (r.choice == choice) r.value]..sort();
        final n = switch (choice) { 'hatChoice' => 4, 'faceChoice' => 3, _ => 5 };
        expect(values, [for (var i = 1; i <= n; i++) i], reason: choice);
      }
      expect({for (final r in rigProps.values) r.color}, _rigColors.toSet());
    });

    test('기본 소품의 짝: 여행복 = 옷 4, 베레모 = 모자 1, 갈색 신발 = 신발 4, 큰 붓 = 가방 1, 종이새 = 친구 1', () {
      expect([
        for (final id in ['cloth_02', 'hat_01', 'shoe_01', 'hand_01', 'pet_01']) (rigProps[id]!.choice, rigProps[id]!.value),
      ], [('clothChoice', 4), ('hatChoice', 1), ('shoeChoice', 4), ('bagChoice', 1), ('petChoice', 1)]);
    });
  });

  group('얼굴 부위 (캔버스 1-2 v32)', () {
    test('눈 6·눈썹 없음+6·코 없음+7·입 8, 번호가 이어지고 id가 겹치지 않는다', () {
      for (final (parts, from, n) in [(rigEyes, 1, 6), (rigBrows, 0, 7), (rigNoses, 0, 8), (rigMouths, 1, 8)]) {
        expect([for (final p in parts) p.value], [for (var i = 0; i < n; i++) from + i]);
        expect({for (final p in parts) p.id}, hasLength(n));
      }
    });

    test('첫 얼굴은 v33 기본값(눈 1·눈썹 1·코 7·입 7)', () {
      final i = rigInputsOf(
        const Look(eyes: 'dot', brows: 'shiba', nose: 'shy', mouth: 'omega'),
        props: props,
        bodyArgb: 0xFFF3E4C4,
      );
      expect([i.numbers['eye'], i.numbers['brow'], i.numbers['nose'], i.numbers['mouth']], [1, 1, 7, 7],
          reason: 'v24 옛 id는 첫 얼굴로');
    });
  });

  test('표정: 울먹임과 놀람 자리만 바뀐다', () {
    expect([for (var e = 0; e < 6; e++) rigExpr(e)], [0, 1, 3, 2, 4, 5]);
    expect(rigExpr(9), 5);
  });

  group('rigInputsOf', () {
    test('첫 모습: 기본 소품 다섯(모자·옷·신발·가방·친구), 나머지 칸 0, 몸 색·여행복 시작 색', () {
      final i = rigInputsOf(Look.initial, props: props, bodyArgb: 0xFFF3E4C4, clothStartArgb: 0xFFC0A475);
      expect({for (final c in rigChoiceOfSlot.values) c: i.numbers[c]}, {
        'hatChoice': 1,
        'faceChoice': 0,
        'clothChoice': 4,
        'shoeChoice': 4,
        'handChoice': 0,
        'bagChoice': 1,
        'petChoice': 1,
        'floatChoice': 0,
      });
      expect(i.colors, {'bodyColor': 0xFFF3E4C4, 'travelVestColor': 0xFFC0A475});
    });

    test('새 얼굴 id는 그 번호로', () {
      const look = Look(eyes: 'sparkle', brows: 'none', nose: 'n3', mouth: 'grin');
      final i = rigInputsOf(look, props: props, bodyArgb: 0xFFF3E4C4);
      expect([i.numbers['eye'], i.numbers['brow'], i.numbers['nose'], i.numbers['mouth']], [6, 0, 3, 8]);
    });

    test('색 소품은 기본 소품 번호에 그 색을 입힌다 (여행복 시작 색보다 먼저)', () {
      final look = Look.initial.withSlot('cloth', 'cloth_02_c1').withSlot('hat', 'hat_01_c2');
      final starry = props.firstWhere((p) => p.id == 'cloth_02_c1').materialArgb;
      final navyBeret = props.firstWhere((p) => p.id == 'hat_01_c2').materialArgb;
      final i = rigInputsOf(look, props: props, bodyArgb: 0xFFF3E4C4, clothStartArgb: 0xFFC0A475);
      expect((i.numbers['clothChoice'], i.numbers['hatChoice']), (4, 1));
      expect(i.colors['travelVestColor'], starry);
      expect(i.colors['beretColor'], navyBeret);
    });

    test('비운 칸은 0, 모르는 소품도 0', () {
      final look = Look.initial.withSlot('hat', null).withSlot('pet', 'pet_99');
      final i = rigInputsOf(look, props: props, bodyArgb: 0xFFF3E4C4);
      expect((i.numbers['hatChoice'], i.numbers['petChoice']), (0, 0));
    });
  });
}
