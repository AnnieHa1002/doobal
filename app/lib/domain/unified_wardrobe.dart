/// 확정 통합 Rive의 37종 소품 입력. 게임 소품 id와 그림 선택 번호를 한곳에서 대응한다.
class UnifiedProp {
  const UnifiedProp(
    this.id,
    this.slot,
    this.choice,
    this.colorField,
    this.argb,
  );
  final String id, slot, colorField;
  final int choice, argb;
}

const unifiedProps = <UnifiedProp>[
  UnifiedProp('hat_01', 'hat', 1, 'beretColor', 0xFFB66D55),
  UnifiedProp('hat_02', 'hat', 2, 'featherHatColor', 0xFF84967B),
  UnifiedProp('hat_04', 'hat', 3, 'bambooHatColor', 0xFFB7A076),
  UnifiedProp('hat_05', 'hat', 4, 'sillaCrownColor', 0xFFD4B266),
  UnifiedProp('hat_11', 'face', 1, 'roundGlassesColor', 0xFF87A68B),
  UnifiedProp('face_01', 'face', 2, 'headphonesColor', 0xFF87A68B),
  UnifiedProp('face_02', 'face', 3, 'earmuffsColor', 0xFFD5A48E),
  UnifiedProp('cloth_05', 'cloth', 1, 'travelCapeColor', 0xFF8CA58D),
  UnifiedProp('cloth_03', 'cloth', 2, 'starryCapeColor', 0xFF8CA58D),
  UnifiedProp('cloth_01', 'cloth', 3, 'workApronColor', 0xFF8CA58D),
  UnifiedProp('cloth_02', 'cloth', 4, 'travelVestColor', 0xFF8CA58D),
  UnifiedProp('cloth_04', 'cloth', 5, 'goldArtistCoatColor', 0xFF8CA58D),
  UnifiedProp('shoe_04', 'shoe', 1, 'greenBootsColor', 0xFF7D9879),
  UnifiedProp('shoe_05', 'shoe', 2, 'catSlippersColor', 0xFFE5C4AC),
  UnifiedProp('shoe_06', 'shoe', 3, 'strawSandalsColor', 0xFFC8AA78),
  UnifiedProp('shoe_01', 'shoe', 4, 'brownShoesColor', 0xFFB1815C),
  UnifiedProp('shoe_02', 'shoe', 5, 'hikingBootsColor', 0xFF9E755A),
  UnifiedProp('hand_11', 'hand', 1, 'woolMittensColor', 0xFFD3A38E),
  UnifiedProp('hand_12', 'hand', 2, 'birdWingsColor', 0xFFF0E2CE),
  UnifiedProp('hand_13', 'hand', 3, 'leafGlovesColor', 0xFF8CA577),
  UnifiedProp('hand_09', 'hand', 4, 'catPawMittensColor', 0xFFD3A38E),
  UnifiedProp('hand_10', 'hand', 5, 'goldWingArmsColor', 0xFFD7B66C),
  UnifiedProp('hand_01', 'bag', 1, 'brushBagColor', 0xFFA57952),
  UnifiedProp('bag_01', 'bag', 2, 'artSatchelColor', 0xFFA57952),
  UnifiedProp('bag_02', 'bag', 3, 'easelBackpackColor', 0xFFA57952),
  UnifiedProp('bag_03', 'bag', 4, 'scrollCaseColor', 0xFFA57952),
  UnifiedProp('hand_02', 'bag', 5, 'walkingStickPackColor', 0xFFA57952),
  UnifiedProp('pet_01', 'pet', 1, 'paperBirdColor', 0xFFF0DAB9),
  UnifiedProp('pet_02', 'pet', 2, 'haechiFriendColor', 0xFFD5AE79),
  UnifiedProp('pet_03', 'pet', 3, 'lambFriendColor', 0xFFF0E6D6),
  UnifiedProp('pet_04', 'pet', 4, 'dolhareubangFriendColor', 0xFFB6A58F),
  UnifiedProp('pet_05', 'pet', 5, 'gullFriendColor', 0xFFF1E8DA),
  UnifiedProp('float_01', 'float', 1, 'starLanternColor', 0xFFD8BD7D),
  UnifiedProp('hand_05', 'float', 2, 'lotusLeafFloatColor', 0xFF8FA57D),
  UnifiedProp('hat_10', 'float', 3, 'smallMoonFloatColor', 0xFFD8BD7D),
  UnifiedProp('float_02', 'float', 4, 'floatCloudColor', 0xFFE8E4DB),
  UnifiedProp('float_03', 'float', 5, 'floatBalloonColor', 0xFFCF9B83),
];
UnifiedProp? unifiedProp(String? id) {
  for (final p in unifiedProps) {
    if (p.id == id) return p;
  }
  return null;
}
