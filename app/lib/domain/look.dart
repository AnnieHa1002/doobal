import 'color.dart';

/// 머리 모양 칸 수 (머리 1~6). 그림이 나오면 그 종류 수와 맞춘다
const hairShapeCount = 6;

/// 얼굴 칸 수 (정령 얼굴 v24, UI 명세 12장): 눈 5 · 눈썹 5(없음 포함) · 코 7(없음 포함) · 입 6.
/// 귀는 정령에 없어 화면에서 뺐고, 저장값만 남아 있다
const eyeShapeCount = 5;
const browShapeCount = 5;
const noseShapeCount = 7;
const mouthShapeCount = 6;
const earShapeCount = 2;

/// 기본 얼굴 번호: 점+반짝 눈 · 시바 눈썹 · /// 코 · ω 입 (기준 문서 7장)
const defaultEyes = 1;
const defaultBrows = 2;
const defaultNose = 7;
const defaultMouth = 2;

/// 소품 칸 아홉 (props.json v4 slots). 얼굴 소품·손·둥실·효과는 처음에 비어 있다
const lookSlots = ['hat', 'face', 'cloth', 'shoe', 'hand', 'bag', 'pet', 'float', 'effect'];

/// 비울 수 없는 칸: 옷은 늘 무언가를 입는다
const alwaysWornSlot = 'cloth';

/// 칸마다 처음 끼는 소품: 새 프로필과 옛 JSON(slots가 없는 것)이 이 값으로 시작한다. 가방은 큰 붓이다
const defaultSlots = <String, String?>{
  'hat': 'hat_01',
  'face': null,
  'cloth': 'cloth_01',
  'shoe': 'shoe_01',
  'hand': null,
  'bag': 'hand_01',
  'pet': 'pet_01',
  'float': null,
  'effect': null,
};

/// 처음부터 가진 소품: props.json에서 unlock.kind가 default인 것 (look_test가 맞는지 본다)
const initialPropIds = {'hat_01', 'cloth_01', 'shoe_01', 'hand_01', 'bag_01', 'pet_01'};

/// 머리색 (M4 명세): 견본 번호 | 직접 고른 색 | 뿌리·끝 그러데이션.
/// JSON은 {kind: swatch, i} | {kind: custom, hex} | {kind: gradient, root, tip}
sealed class HairColor {
  const HairColor();

  Map<String, dynamic> toJson();

  factory HairColor.fromJson(Map<String, dynamic> j) => switch (j['kind']) {
        'swatch' => SwatchHairColor(_int(j['i'])),
        'custom' => CustomHairColor(checkedHex(j['hex'])),
        'gradient' => GradientHairColor(checkedHex(j['root']), checkedHex(j['tip'])),
        final k => throw FormatException('모르는 머리색 종류: $k'),
      };
}

/// palette.json hair.swatches의 번호 (1부터)
class SwatchHairColor extends HairColor {
  const SwatchHairColor(this.i);

  final int i;

  @override
  Map<String, dynamic> toJson() => {'kind': 'swatch', 'i': i};

  @override
  bool operator ==(Object other) => other is SwatchHairColor && other.i == i;

  @override
  int get hashCode => Object.hash('swatch', i);

  @override
  String toString() => 'SwatchHairColor($i)';
}

/// "#RRGGBB"
class CustomHairColor extends HairColor {
  const CustomHairColor(this.hex);

  final String hex;

  @override
  Map<String, dynamic> toJson() => {'kind': 'custom', 'hex': hex};

  @override
  bool operator ==(Object other) => other is CustomHairColor && other.hex == hex;

  @override
  int get hashCode => Object.hash('custom', hex);

  @override
  String toString() => 'CustomHairColor($hex)';
}

/// 뿌리·끝 색 ("#RRGGBB")
class GradientHairColor extends HairColor {
  const GradientHairColor(this.root, this.tip);

  final String root;
  final String tip;

  @override
  Map<String, dynamic> toJson() => {'kind': 'gradient', 'root': root, 'tip': tip};

  @override
  bool operator ==(Object other) =>
      other is GradientHairColor && other.root == root && other.tip == tip;

  @override
  int get hashCode => Object.hash('gradient', root, tip);

  @override
  String toString() => 'GradientHairColor($root, $tip)';
}

/// 피부색 (M4 명세): 견본 번호 | 직접 고른 색.
/// JSON은 {kind: swatch, i} | {kind: custom, hex}
sealed class SkinColor {
  const SkinColor();

  Map<String, dynamic> toJson();

  factory SkinColor.fromJson(Map<String, dynamic> j) => switch (j['kind']) {
        'swatch' => SwatchSkinColor(_int(j['i'])),
        'custom' => CustomSkinColor(checkedHex(j['hex'])),
        final k => throw FormatException('모르는 피부색 종류: $k'),
      };
}

/// palette.json skin.swatches의 번호 (1부터)
class SwatchSkinColor extends SkinColor {
  const SwatchSkinColor(this.i);

  final int i;

  @override
  Map<String, dynamic> toJson() => {'kind': 'swatch', 'i': i};

  @override
  bool operator ==(Object other) => other is SwatchSkinColor && other.i == i;

  @override
  int get hashCode => Object.hash('swatch', i);

  @override
  String toString() => 'SwatchSkinColor($i)';
}

/// "#RRGGBB"
class CustomSkinColor extends SkinColor {
  const CustomSkinColor(this.hex);

  final String hex;

  @override
  Map<String, dynamic> toJson() => {'kind': 'custom', 'hex': hex};

  @override
  bool operator ==(Object other) => other is CustomSkinColor && other.hex == hex;

  @override
  int get hashCode => Object.hash('custom', hex);

  @override
  String toString() => 'CustomSkinColor($hex)';
}

/// 캐릭터의 모습 (Profile.look, M4 명세):
/// `{hair, hairColor, skin, eyes, nose, brows, mouth, ears, slots{hat, hand, pet, bag, shoe, cloth}}`.
/// 옛 JSON(`{hair, hairColor}`만 있는 것)은 빠진 키를 기본값으로 읽는다.
/// 얼굴 번호의 순서는 UI 명세 12장이고, 정령 값으로는 domain/spirit_look.dart가 바꾼다
class Look {
  const Look({
    required this.hair,
    required this.hairColor,
    this.skin = const SwatchSkinColor(1),
    this.eyes = defaultEyes,
    this.nose = defaultNose,
    this.brows = defaultBrows,
    this.mouth = defaultMouth,
    this.ears = 1,
    this.slots = defaultSlots,
  })  : assert(hair >= 1 && hair <= hairShapeCount),
        assert(eyes >= 1 && eyes <= eyeShapeCount),
        assert(nose >= 1 && nose <= noseShapeCount),
        assert(brows >= 1 && brows <= browShapeCount),
        assert(mouth >= 1 && mouth <= mouthShapeCount),
        assert(ears >= 1 && ears <= earShapeCount);

  /// 첫 실행의 기본 모습: 머리 1, 머리색 견본 1, 피부 견본 1, 기본 얼굴, 칸마다 기본 소품
  static const initial = Look(hair: 1, hairColor: SwatchHairColor(1));

  /// 머리 모양 번호 (1~[hairShapeCount])
  final int hair;
  final HairColor hairColor;
  final SkinColor skin;

  /// 얼굴 번호 (1부터, 칸 수는 위 상수). 귀는 저장값만 남아 있다
  final int eyes;
  final int nose;
  final int brows;
  final int mouth;
  final int ears;

  /// 칸 이름([lookSlots]) → 끼운 소품 id. 비운 칸은 null. 아홉 칸을 모두 가진다
  final Map<String, String?> slots;

  Look copyWith({
    int? hair,
    HairColor? hairColor,
    SkinColor? skin,
    int? eyes,
    int? nose,
    int? brows,
    int? mouth,
    int? ears,
  }) =>
      Look(
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        skin: skin ?? this.skin,
        eyes: eyes ?? this.eyes,
        nose: nose ?? this.nose,
        brows: brows ?? this.brows,
        mouth: mouth ?? this.mouth,
        ears: ears ?? this.ears,
        slots: slots,
      );

  /// [slot] 칸에 [propId]를 끼운 모습 (null이면 비운다). 칸 이름과 옷 비우기만 막고,
  /// 가진 소품인지는 ProfileService.saveLook이 본다
  Look withSlot(String slot, String? propId) {
    if (!lookSlots.contains(slot)) throw ArgumentError.value(slot, 'slot', '모르는 소품 칸');
    if (propId == null && slot == alwaysWornSlot) {
      throw ArgumentError.value(slot, 'slot', '옷은 비울 수 없다');
    }
    return Look(
      hair: hair,
      hairColor: hairColor,
      skin: skin,
      eyes: eyes,
      nose: nose,
      brows: brows,
      mouth: mouth,
      ears: ears,
      slots: Map.unmodifiable({
        for (final s in lookSlots) s: s == slot ? propId : slots[s],
      }),
    );
  }

  Map<String, dynamic> toJson() => {
        'hair': hair,
        'hairColor': hairColor.toJson(),
        'skin': skin.toJson(),
        'eyes': eyes,
        'nose': nose,
        'brows': brows,
        'mouth': mouth,
        'ears': ears,
        'slots': {for (final s in lookSlots) s: slots[s]},
      };

  /// 옛 JSON처럼 빠진 키(skin·eyes·nose·brows·mouth·ears·slots, slots 안의 칸)는 기본값으로 읽는다.
  /// 입이 없는 JSON은 사람 얼굴 때 저장한 것이라 얼굴 번호를 버리고 기본 얼굴로 시작한다 (11/4 정령).
  /// 있는데 틀린 값(범위 밖 번호, 모르는 종류, 빈 옷 칸 …)은 FormatException
  factory Look.fromJson(Map<String, dynamic> j) {
    final hair = _int(j['hair']);
    if (hair < 1 || hair > hairShapeCount) throw FormatException('머리 모양 범위 밖: $hair');
    final spiritFace = j.containsKey('mouth');
    return Look(
      hair: hair,
      hairColor: HairColor.fromJson(_map(j['hairColor'], '머리색')),
      skin: j['skin'] == null
          ? const SwatchSkinColor(1)
          : SkinColor.fromJson(_map(j['skin'], '피부색')),
      eyes: spiritFace ? _shape(j, 'eyes', eyeShapeCount, defaultEyes) : defaultEyes,
      nose: spiritFace ? _shape(j, 'nose', noseShapeCount, defaultNose) : defaultNose,
      brows: spiritFace ? _shape(j, 'brows', browShapeCount, defaultBrows) : defaultBrows,
      mouth: spiritFace ? _shape(j, 'mouth', mouthShapeCount, defaultMouth) : defaultMouth,
      ears: _shape(j, 'ears', earShapeCount, 1),
      slots: _slotsOf(j['slots']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Look &&
      other.hair == hair &&
      other.hairColor == hairColor &&
      other.skin == skin &&
      other.eyes == eyes &&
      other.nose == nose &&
      other.brows == brows &&
      other.mouth == mouth &&
      other.ears == ears &&
      lookSlots.every((s) => other.slots[s] == slots[s]);

  @override
  int get hashCode => Object.hash(
        hair,
        hairColor,
        skin,
        eyes,
        nose,
        brows,
        mouth,
        ears,
        Object.hashAll([for (final s in lookSlots) slots[s]]),
      );

  @override
  String toString() => 'Look(hair: $hair, hairColor: $hairColor, skin: $skin, eyes: $eyes, '
      'nose: $nose, brows: $brows, mouth: $mouth, ears: $ears, slots: $slots)';
}

/// 얼굴 번호 하나. 없으면 [fallback], 있는데 [count] 밖이면 FormatException
int _shape(Map<String, dynamic> j, String key, int count, int fallback) {
  final v = j[key];
  if (v == null) return fallback;
  final n = _int(v);
  if (n < 1 || n > count) throw FormatException('$key 범위 밖: $n');
  return n;
}

/// slots 읽기. 통째로 없으면 기본 소품, 맵 안에서 빠진 칸도 그 칸의 기본 소품.
/// 칸이 있고 null이면 비운 것이다 (옷은 비울 수 없다). 모르는 칸 이름은 무시한다
Map<String, String?> _slotsOf(dynamic raw) {
  if (raw == null) return defaultSlots;
  if (raw is! Map) throw FormatException('slots가 맵이 아니다: $raw');
  final out = <String, String?>{};
  for (final slot in lookSlots) {
    if (!raw.containsKey(slot)) {
      out[slot] = defaultSlots[slot];
      continue;
    }
    final v = raw[slot];
    if (v == null) {
      if (slot == alwaysWornSlot) throw const FormatException('옷 칸은 비울 수 없다');
      out[slot] = null;
    } else if (v is String && v.isNotEmpty) {
      out[slot] = v;
    } else {
      throw FormatException('소품 id가 아니다: $slot = $v');
    }
  }
  return Map.unmodifiable(out);
}

/// palette.json의 머리색 견본 하나 (번호는 1부터, 이름은 접근성 label)
class HairSwatch {
  const HairSwatch(this.id, this.name, this.color);

  final int id;
  final String name;

  /// 불투명 ARGB (0xFFRRGGBB)
  final int color;
}

/// palette.json 전체에서 hair.swatches만 읽는다 (피부·그러데이션·범위까지 읽는 것은 look_palette.dart)
List<HairSwatch> parseHairSwatches(Map<String, dynamic> json) {
  final hair = (json['legacy'] as Map<String, dynamic>)['hair'] as Map<String, dynamic>;
  return [
    for (final s in hair['swatches'] as List)
      HairSwatch(
        _int((s as Map<String, dynamic>)['id']),
        s['name'] as String,
        argbFromHex(checkedHex(s['hex'])),
      ),
  ];
}

/// 머리색을 그릴 색(불투명 ARGB)으로. 견본 번호가 [swatches]에 없으면 첫 견본,
/// 그러데이션은 뿌리 색 (끝 색은 [hairTipArgb])
int hairArgb(HairColor c, List<HairSwatch> swatches) => switch (c) {
      SwatchHairColor(:final i) =>
        swatches.firstWhere((s) => s.id == i, orElse: () => swatches.first).color,
      CustomHairColor(:final hex) => argbFromHex(hex),
      GradientHairColor(:final root) => argbFromHex(root),
    };

/// 그러데이션의 끝 색(불투명 ARGB). 그러데이션이 아니면 null
int? hairTipArgb(HairColor c) => switch (c) {
      GradientHairColor(:final tip) => argbFromHex(tip),
      _ => null,
    };

int _int(dynamic v) => v is int ? v : throw FormatException('정수가 아니다: $v');

Map<String, dynamic> _map(dynamic v, String what) =>
    v is Map<String, dynamic> ? v : throw FormatException('$what이(가) 맵이 아니다: $v');

final _hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// "#RRGGBB"면 그대로, 아니면 FormatException
String checkedHex(dynamic v) =>
    v is String && _hexPattern.hasMatch(v) ? v : throw FormatException('#RRGGBB가 아니다: $v');
