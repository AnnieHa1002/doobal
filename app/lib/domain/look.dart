import 'color.dart';

/// 머리 모양 칸 수 (머리 1~6). 그림이 나오면 그 종류 수와 맞춘다
const hairShapeCount = 6;

/// 얼굴 칸 수: 눈 3 · 코 3 · 눈썹 3 · 귀 2 (UI 명세 12장). 그림이 나오면 그 종류 수와 맞춘다
const eyeShapeCount = 3;
const noseShapeCount = 3;
const browShapeCount = 3;
const earShapeCount = 2;

/// 소품 칸 여섯 (M4 명세의 순서). props.json의 slot 이름과 같다
const lookSlots = ['hat', 'hand', 'pet', 'bag', 'shoe', 'cloth'];

/// 비울 수 없는 칸: 옷은 늘 무언가를 입는다
const alwaysWornSlot = 'cloth';

/// 칸마다 처음 끼는 소품: props.json에서 unlock.kind가 default인 소품 (칸마다 하나).
/// 처음부터 가진 소품이라 새 프로필과 옛 JSON(slots가 없는 것)이 이 값으로 시작한다.
/// props.json이 바뀌면 같이 바꾼다 (look_test가 맞는지 본다)
const defaultSlots = <String, String?>{
  'hat': 'hat_01',
  'hand': 'hand_01',
  'pet': 'pet_01',
  'bag': 'bag_01',
  'shoe': 'shoe_01',
  'cloth': 'cloth_01',
};

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
/// `{hair, hairColor, skin, eyes, nose, brows, ears, slots{hat, hand, pet, bag, shoe, cloth}}`.
/// 옛 JSON(`{hair, hairColor}`만 있는 것)은 빠진 키를 기본값으로 읽는다
class Look {
  const Look({
    required this.hair,
    required this.hairColor,
    this.skin = const SwatchSkinColor(1),
    this.eyes = 1,
    this.nose = 1,
    this.brows = 1,
    this.ears = 1,
    this.slots = defaultSlots,
  })  : assert(hair >= 1 && hair <= hairShapeCount),
        assert(eyes >= 1 && eyes <= eyeShapeCount),
        assert(nose >= 1 && nose <= noseShapeCount),
        assert(brows >= 1 && brows <= browShapeCount),
        assert(ears >= 1 && ears <= earShapeCount);

  /// 첫 실행의 기본 모습: 머리 1, 머리색 견본 1, 피부 견본 1, 얼굴 1, 칸마다 기본 소품
  static const initial = Look(hair: 1, hairColor: SwatchHairColor(1));

  /// 머리 모양 번호 (1~[hairShapeCount])
  final int hair;
  final HairColor hairColor;
  final SkinColor skin;

  /// 눈·코·눈썹 번호 (1~3), 귀 번호 (1~2)
  final int eyes;
  final int nose;
  final int brows;
  final int ears;

  /// 칸 이름([lookSlots]) → 끼운 소품 id. 비운 칸은 null. 여섯 칸을 모두 가진다
  final Map<String, String?> slots;

  Look copyWith({
    int? hair,
    HairColor? hairColor,
    SkinColor? skin,
    int? eyes,
    int? nose,
    int? brows,
    int? ears,
  }) =>
      Look(
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        skin: skin ?? this.skin,
        eyes: eyes ?? this.eyes,
        nose: nose ?? this.nose,
        brows: brows ?? this.brows,
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
        'ears': ears,
        'slots': {for (final s in lookSlots) s: slots[s]},
      };

  /// 옛 JSON처럼 빠진 키(skin·eyes·nose·brows·ears·slots, slots 안의 칸)는 기본값으로 읽는다.
  /// 있는데 틀린 값(범위 밖 번호, 모르는 종류, 빈 옷 칸 …)은 FormatException
  factory Look.fromJson(Map<String, dynamic> j) {
    final hair = _int(j['hair']);
    if (hair < 1 || hair > hairShapeCount) throw FormatException('머리 모양 범위 밖: $hair');
    return Look(
      hair: hair,
      hairColor: HairColor.fromJson(_map(j['hairColor'], '머리색')),
      skin: j['skin'] == null
          ? const SwatchSkinColor(1)
          : SkinColor.fromJson(_map(j['skin'], '피부색')),
      eyes: _shape(j, 'eyes', eyeShapeCount),
      nose: _shape(j, 'nose', noseShapeCount),
      brows: _shape(j, 'brows', browShapeCount),
      ears: _shape(j, 'ears', earShapeCount),
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
        ears,
        Object.hashAll([for (final s in lookSlots) slots[s]]),
      );

  @override
  String toString() => 'Look(hair: $hair, hairColor: $hairColor, skin: $skin, eyes: $eyes, '
      'nose: $nose, brows: $brows, ears: $ears, slots: $slots)';
}

/// 얼굴 번호 하나. 없으면 1, 있는데 [count] 밖이면 FormatException
int _shape(Map<String, dynamic> j, String key, int count) {
  final v = j[key];
  if (v == null) return 1;
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
  final hair = json['hair'] as Map<String, dynamic>;
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
