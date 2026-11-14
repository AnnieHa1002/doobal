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

void main() {
  // 11/12 통합 작업의 표(unified_wardrobe.dart)가 v32 Rive 소스 시험 버튼 이름과 맞는지 (11/13 대조)
  group('소품 → Rive 칸·번호·색 (unifiedProps)', () {
    final mvp = [for (final p in props) if (!p.isColorVariant && p.slot != 'effect') p];
    final byId = {for (final u in unifiedProps) u.id: u};

    test('효과 말고 모든 소품(37)이 자기 칸에 있다', () {
      expect(mvp, hasLength(37));
      expect(byId.keys.toSet(), {for (final p in mvp) p.id});
      for (final p in mvp) {
        expect(byId[p.id]!.slot, p.slot, reason: p.id);
      }
    });

    test('칸마다 번호는 1부터 겹치지 않고(모자 4·얼굴 3·나머지 5), 색 입력은 v32의 37개와 같다', () {
      for (final slot in ['hat', 'face', 'cloth', 'shoe', 'hand', 'bag', 'pet', 'float']) {
        final values = [for (final u in unifiedProps) if (u.slot == slot) u.choice]..sort();
        final n = switch (slot) { 'hat' => 4, 'face' => 3, _ => 5 };
        expect(values, [for (var i = 1; i <= n; i++) i], reason: slot);
      }
      expect({for (final u in unifiedProps) u.colorField}, _rigColors.toSet());
    });

    test('v32 시험 버튼과 같은 짝: 여행복 = 옷 4, 연두 망토 = 옷 1, 갈색 신발 = 신발 4, 큰 붓 = 가방 1, 봇짐 = 가방 5, 연잎 = 둥실 2, 달 = 둥실 3', () {
      expect([
        for (final id in ['cloth_02', 'cloth_05', 'shoe_01', 'hand_01', 'hand_02', 'hand_05', 'hat_10'])
          (byId[id]!.slot, byId[id]!.choice),
      ], [('cloth', 4), ('cloth', 1), ('shoe', 4), ('bag', 1), ('bag', 5), ('float', 2), ('float', 3)]);
    });
  });

  test('얼굴 부위 수는 v32와 같다: 눈 6·눈썹 없음+6·코 없음+7·입 8', () {
    expect([eyeParts.length, browParts.length, noseParts.length, mouthParts.length], [6, 7, 8, 8]);
    expect(browParts['none'], 0);
    expect(noseParts.containsKey('none'), isTrue);
  });
}
