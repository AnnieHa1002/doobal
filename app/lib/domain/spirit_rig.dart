import 'look.dart';
import 'prop.dart';

// 정령 Rive v32·앱용 v33(`spirit_v33.riv`)의 입력 표 (16장 11/11·11/13, T5).
// 이름·번호는 Rive 파일이 정한 값이다: 뷰 모델 `WardrobeColors`, Drive 01_최신_Rive_v32 inputs.md,
// 번호와 소품은 Rive 소스 시험 버튼 이름으로 대조했다(11/13). v33은 v32와 이름·번호가 같다.
// 지금 앱은 아직 Rive v25(`SpiritLook`)를 그린다. v33이 오면 이 표로 바꾼다.

/// 자세 (poseChoice). 바꾸기만 하면 Rive 안에서 넘어간다 (두 그림을 겹쳐 흐리지 않는다)
enum RigPose {
  floatFront(0),
  floatSide(1),
  sitFront(2),
  sitSide(3),
  sleep(4),
  floatBack(5),
  move(6);

  const RigPose(this.value);
  final int value;
}

/// 한 번 하는 동작·누르기 (뷰 모델 트리거)
enum RigTrigger { greet, joy, resetMotion, tapHead, tapBelly, angry }

/// 소품 하나가 Rive에서 무엇인지: 칸 입력 이름, 번호(0은 안 입음), 색 입력 이름
class RigProp {
  const RigProp(this.choice, this.value, this.color);

  final String choice;
  final int value;
  final String color;
}

/// 소품 칸 → Rive 칸 입력. 효과 칸은 Rive에 없다 (입자 효과는 코드로)
const rigChoiceOfSlot = {
  'hat': 'hatChoice',
  'face': 'faceChoice',
  'cloth': 'clothChoice',
  'shoe': 'shoeChoice',
  'hand': 'handChoice',
  'bag': 'bagChoice',
  'pet': 'petChoice',
  'float': 'floatChoice',
};

/// props.json 소품 id → Rive (모자 1~4·얼굴 소품 1~3·나머지 칸 1~5). 색 소품은 기본 소품 줄을 쓴다
const rigProps = <String, RigProp>{
  'hat_01': RigProp('hatChoice', 1, 'beretColor'),
  'hat_02': RigProp('hatChoice', 2, 'featherHatColor'),
  'hat_04': RigProp('hatChoice', 3, 'bambooHatColor'),
  'hat_05': RigProp('hatChoice', 4, 'sillaCrownColor'),
  'hat_11': RigProp('faceChoice', 1, 'roundGlassesColor'),
  'face_01': RigProp('faceChoice', 2, 'headphonesColor'),
  'face_02': RigProp('faceChoice', 3, 'earmuffsColor'),
  'cloth_05': RigProp('clothChoice', 1, 'travelCapeColor'),
  'cloth_03': RigProp('clothChoice', 2, 'starryCapeColor'),
  'cloth_01': RigProp('clothChoice', 3, 'workApronColor'),
  'cloth_02': RigProp('clothChoice', 4, 'travelVestColor'),
  'cloth_04': RigProp('clothChoice', 5, 'goldArtistCoatColor'),
  'shoe_04': RigProp('shoeChoice', 1, 'greenBootsColor'),
  'shoe_05': RigProp('shoeChoice', 2, 'catSlippersColor'),
  'shoe_06': RigProp('shoeChoice', 3, 'strawSandalsColor'),
  'shoe_01': RigProp('shoeChoice', 4, 'brownShoesColor'),
  'shoe_02': RigProp('shoeChoice', 5, 'hikingBootsColor'),
  'hand_11': RigProp('handChoice', 1, 'woolMittensColor'),
  'hand_12': RigProp('handChoice', 2, 'birdWingsColor'),
  'hand_13': RigProp('handChoice', 3, 'leafGlovesColor'),
  'hand_09': RigProp('handChoice', 4, 'catPawMittensColor'),
  'hand_10': RigProp('handChoice', 5, 'goldWingArmsColor'),
  'hand_01': RigProp('bagChoice', 1, 'brushBagColor'),
  'bag_01': RigProp('bagChoice', 2, 'artSatchelColor'),
  'bag_02': RigProp('bagChoice', 3, 'easelBackpackColor'),
  'bag_03': RigProp('bagChoice', 4, 'scrollCaseColor'),
  'hand_02': RigProp('bagChoice', 5, 'walkingStickPackColor'),
  'pet_01': RigProp('petChoice', 1, 'paperBirdColor'),
  'pet_02': RigProp('petChoice', 2, 'haechiFriendColor'),
  'pet_03': RigProp('petChoice', 3, 'lambFriendColor'),
  'pet_04': RigProp('petChoice', 4, 'dolhareubangFriendColor'),
  'pet_05': RigProp('petChoice', 5, 'gullFriendColor'),
  'float_01': RigProp('floatChoice', 1, 'starLanternColor'),
  'hand_05': RigProp('floatChoice', 2, 'lotusLeafFloatColor'),
  'hat_10': RigProp('floatChoice', 3, 'smallMoonFloatColor'),
  'float_02': RigProp('floatChoice', 4, 'floatCloudColor'),
  'float_03': RigProp('floatChoice', 5, 'floatBalloonColor'),
};

/// 얼굴 부위 하나: 저장하는 id, 화면 이름(캔버스 1-2 v32), Rive 번호
class RigFacePart {
  const RigFacePart(this.id, this.name, this.value);

  final String id;
  final String name;
  final int value;
}

/// 얼굴 부위 (16장 11/13, 캔버스 1-2: 눈 6·눈썹 없음+6·코 없음+7·입 8). 지금 palette.json의 v24 얼굴 id와는 다르다
const rigEyes = [
  RigFacePart('basic', '기본', 1),
  RigFacePart('soft', '부드러운', 2),
  RigFacePart('playful', '장난', 3),
  RigFacePart('prim', '새침', 4),
  RigFacePart('closed', '감은', 5),
  RigFacePart('sparkle', '반짝', 6),
];
const rigBrows = [
  RigFacePart('none', '없음', 0),
  RigFacePart('round', '둥근', 1),
  RigFacePart('short', '짧은', 2),
  RigFacePart('angry', '화난', 3),
  RigFacePart('sleepy', '졸린', 4),
  RigFacePart('worried', '걱정', 5),
  RigFacePart('sharp', '날렵', 6),
];
const rigNoses = [
  RigFacePart('none', '없음', 0),
  RigFacePart('n1', '코 1', 1),
  RigFacePart('n2', '코 2', 2),
  RigFacePart('n3', '코 3', 3),
  RigFacePart('n4', '코 4', 4),
  RigFacePart('n5', '코 5', 5),
  RigFacePart('n6', '코 6', 6),
  RigFacePart('round', '동그란', 7),
];
const rigMouths = [
  RigFacePart('m1', '입 1', 1),
  RigFacePart('m2', '입 2', 2),
  RigFacePart('m3', '입 3', 3),
  RigFacePart('m4', '입 4', 4),
  RigFacePart('m5', '입 5', 5),
  RigFacePart('m6', '입 6', 6),
  RigFacePart('smile', '살짝 웃음', 7),
  RigFacePart('grin', '활짝 웃음', 8),
];

/// 첫 얼굴 (v33 기본값: 눈 1·눈썹 1·코 7·입 7)
const rigDefaultFace = (eyes: 'basic', brows: 'round', nose: 'round', mouth: 'smile');

/// 앱 표정 번호(palette.json expressions 순서: 기본·행복·울먹임·놀람·졸림·화남) → Rive expr
/// (0 기본·1 행복·2 놀람·3 울먹임·4 졸림·5 화남). 울먹임과 놀람의 자리가 바뀐다
int rigExpr(int appExpression) => const [0, 1, 3, 2, 4, 5][appExpression.clamp(0, 5)];

/// Rive에 넣을 값: 숫자 입력과 색 입력 (불투명 ARGB). 여기 없는 색 입력은 Rive 기본색 그대로
class RigInputs {
  const RigInputs(this.numbers, this.colors);

  final Map<String, int> numbers;
  final Map<String, int> colors;

  @override
  bool operator ==(Object other) =>
      other is RigInputs && _mapEq(other.numbers, numbers) && _mapEq(other.colors, colors);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(numbers.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAllUnordered(colors.entries.map((e) => Object.hash(e.key, e.value))),
      );

  @override
  String toString() => 'RigInputs($numbers, $colors)';
}

bool _mapEq(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

int _face(List<RigFacePart> parts, String id, String fallback) =>
    (parts.where((p) => p.id == id).firstOrNull ?? parts.firstWhere((p) => p.id == fallback)).value;

/// 저장된 모습을 Rive 입력으로 바꾼다. [props]는 props.json(색 소품의 기본 소품·색을 찾는다).
/// 얼굴 id가 표에 없으면(v24 옛 id 등) 첫 얼굴. 몸 색은 [bodyArgb], 여행복은 [clothStartArgb](시작 색)를 입히고,
/// 색 소품을 입으면 기본 소품의 색 입력에 그 색을 넣는다. 그 밖의 소품 색은 Rive 기본색이다
RigInputs rigInputsOf(
  Look look, {
  required List<Prop> props,
  required int bodyArgb,
  int? clothStartArgb,
}) {
  final byId = {for (final p in props) p.id: p};
  final numbers = <String, int>{
    'eye': _face(rigEyes, look.eyes, rigDefaultFace.eyes),
    'brow': _face(rigBrows, look.brows, rigDefaultFace.brows),
    'nose': _face(rigNoses, look.nose, rigDefaultFace.nose),
    'mouth': _face(rigMouths, look.mouth, rigDefaultFace.mouth),
    for (final choice in rigChoiceOfSlot.values) choice: 0,
  };
  final colors = <String, int>{'bodyColor': bodyArgb};
  if (clothStartArgb != null) colors['travelVestColor'] = clothStartArgb;
  for (final slot in rigChoiceOfSlot.keys) {
    final id = look.slots[slot];
    if (id == null) continue;
    final prop = byId[id];
    final base = prop?.variantOf ?? id;
    final rig = rigProps[base];
    if (rig == null) continue;
    numbers[rig.choice] = rig.value;
    if (prop != null && prop.isColorVariant && prop.materialArgb != null) {
      colors[rig.color] = prop.materialArgb!;
    }
  }
  return RigInputs(numbers, colors);
}
