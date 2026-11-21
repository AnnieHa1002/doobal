import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/face_parts.dart';
import 'package:doobal/domain/unified_wardrobe.dart';
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

/// 정령 옷 v11 inputs.md(11/20)가 ‘추가’로 적은 색 입력 8개: 상점 미니 친구 pet_06~13 (petChoice 6~13).
/// 물빛 구슬 float_04(floatChoice 6)는 원화 색 고정이라 색 입력이 없다 (props v10 `rive.color` null)
const _v11FriendColors = [
  'bluebirdFriendColor', 'canaryFriendColor', 'dragonflyFriendColor', 'wispFriendColor', //
  'ginsengKidFriendColor', 'moleFriendColor', 'hedgehogFriendColor', 'raccoonDogFriendColor',
];

/// props.json에서 `rive.pending`인 소품 (props v10부터 없음)
Set<String> _rivePending() {
  final raw = jsonDecode(File('assets/data/props.json').readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final m in (raw['props'] as List).cast<Map<String, dynamic>>())
      if ((m['rive'] as Map?)?['pending'] == true) m['id'] as String,
  };
}

void main() {
  // 11/12 통합 작업의 표(unified_wardrobe.dart)가 v32 Rive 소스 시험 버튼 이름과 맞는지 (11/13 대조),
  // 11/21 T17a 정령 v11: 상점 미니 친구 8과 물빛 구슬을 더함 (개발인계_20261120 2·7장)
  group('소품 → Rive 칸·번호·색 (unifiedProps)', () {
    final mvp = [
      for (final p in props)
        if (!p.isColorVariant && p.slot != 'effect') p,
    ];
    final byId = {for (final u in unifiedProps) u.id: u};

    test('props v10은 rive.pending이 없고, 상점 미니 친구 8은 pet 6~13, 물빛 구슬은 둥실 6에 색 입력 없음', () {
      expect(_rivePending(), isEmpty);
      expect([for (var n = 6; n <= 13; n++) (byId['pet_${n.toString().padLeft(2, '0')}']!.slot, byId['pet_${n.toString().padLeft(2, '0')}']!.choice)],
          [for (var n = 6; n <= 13; n++) ('pet', n)]);
      final bead = byId['float_04']!;
      expect((bead.slot, bead.choice, bead.colorField), ('float', 6, null));
    });

    test('효과 말고 모든 소품(46)이 자기 칸에 있다', () {
      expect(mvp, hasLength(46));
      expect(byId.keys.toSet(), {for (final p in mvp) p.id});
      for (final p in mvp) {
        expect(byId[p.id]!.slot, p.slot, reason: p.id);
      }
    });

    test('칸마다 번호는 1부터 겹치지 않고(모자 4·얼굴 3·친구 13·둥실 6·나머지 5), 색 입력은 v32의 37개 + v11 친구 8개', () {
      for (final slot in ['hat', 'face', 'cloth', 'shoe', 'hand', 'bag', 'pet', 'float']) {
        final values = [for (final u in unifiedProps) if (u.slot == slot) u.choice]..sort();
        final n = switch (slot) { 'hat' => 4, 'face' => 3, 'pet' => 13, 'float' => 6, _ => 5 };
        expect(values, [for (var i = 1; i <= n; i++) i], reason: slot);
      }
      final fields = [for (final u in unifiedProps) ?u.colorField];
      expect(fields, hasLength(45));
      expect(fields.toSet(), {..._rigColors, ..._v11FriendColors});
    });

    test('v32 시험 버튼과 같은 짝: 여행복 = 옷 4, 연두 망토 = 옷 1, 갈색 신발 = 신발 4, 큰 붓 = 가방 1, 봇짐 = 가방 5, 연잎 = 둥실 2, 달 = 둥실 3', () {
      expect([
        for (final id in ['cloth_02', 'cloth_05', 'shoe_01', 'hand_01', 'hand_02', 'hand_05', 'hat_10'])
          (byId[id]!.slot, byId[id]!.choice),
      ], [('cloth', 4), ('cloth', 1), ('shoe', 4), ('bag', 1), ('bag', 5), ('float', 2), ('float', 3)]);
    });

    // 11/16 T5 정리: 코드 표가 데이터(props.json v8 `rive`, 정령 계약 5장)와 어긋나지 않게 묶는다.
    // 색 소품(variantOf)은 기본 소품과 같은 칸·번호·색 이름이다
    test('props.json `rive`의 칸 입력·번호·색 이름과 같다 (색 소품은 기본 소품 값)', () {
      final raw = jsonDecode(File('assets/data/props.json').readAsStringSync()) as Map<String, dynamic>;
      final withRive = <String>{};
      for (final m in (raw['props'] as List).cast<Map<String, dynamic>>()) {
        final rive = m['rive'] as Map<String, dynamic>?;
        if (rive == null || rive['pending'] == true) continue;
        final base = byId[m['variantOf'] ?? m['id']];
        expect(base, isNotNull, reason: '${m['id']}: 코드 표에 없다');
        expect((rive['choice'], rive['n'], rive['color']), ('${base!.slot}Choice', base.choice, base.colorField),
            reason: m['id'] as String);
        withRive.add(base.id);
      }
      expect(withRive, byId.keys.toSet());
    });
  });

  test('얼굴 부위 수는 v32와 같다: 눈 6·눈썹 없음+6·코 없음+7·입 8', () {
    expect([eyeParts.length, browParts.length, noseParts.length, mouthParts.length], [6, 7, 8, 8]);
    expect(browParts['none'], 0);
    expect(noseParts.containsKey('none'), isTrue);
  });
}
