import 'face_parts.dart';
import 'unified_wardrobe.dart';

export 'face_parts.dart'
    show defaultBrows, defaultEyes, defaultMouth, defaultNose;

/// 소품 칸 아홉 (props.json v4 slots). 얼굴 소품·손·둥실·효과는 처음에 비어 있다
const lookSlots = [
  'hat',
  'face',
  'cloth',
  'shoe',
  'hand',
  'bag',
  'pet',
  'float',
  'effect',
];

/// 비울 수 없는 칸: 옷은 늘 무언가를 입는다
const alwaysWornSlot = 'cloth';

/// 칸마다 처음 끼는 소품: 새 프로필과 옛 JSON(slots가 없는 것)이 이 값으로 시작한다. 가방은 큰 붓이다
const defaultSlots = <String, String?>{
  'hat': 'hat_01',
  'face': null,
  'cloth': 'cloth_02',
  'shoe': 'shoe_01',
  'hand': null,
  'bag': 'hand_01',
  'pet': 'pet_01',
  'float': null,
  'effect': null,
};

/// 처음부터 가진 소품: props.json에서 unlock.kind가 default인 것 (look_test가 맞는지 본다)
const initialPropIds = {
  'hat_01',
  'cloth_02',
  'shoe_01',
  'hand_01',
  'bag_01',
  'pet_01',
};

/// 11/10 전 기본 옷(앞치마). 지금은 300km 보상이라, 그 전에 저장된 모습에 끼워져 있으면 여행복으로 읽는다
const _oldDefaultCloth = 'cloth_01';

/// 기본 옷 시작 색 번호의 기본값: props.json 기본 옷 startColors의 첫 색(카키)
const defaultClothColor = 1;

/// 몸 색 (palette.json body): 견본 번호 | 직접 고른 색.
/// JSON은 {kind: swatch, i} | {kind: custom, hex}
sealed class BodyColor {
  const BodyColor();

  Map<String, dynamic> toJson();

  factory BodyColor.fromJson(Map<String, dynamic> j) => switch (j['kind']) {
    'swatch' => SwatchBodyColor(_int(j['i'])),
    'custom' => CustomBodyColor(checkedHex(j['hex'])),
    final k => throw FormatException('모르는 색 종류: $k'),
  };
}

/// palette.json body.swatches의 번호 (1부터)
class SwatchBodyColor extends BodyColor {
  const SwatchBodyColor(this.i);

  final int i;

  @override
  Map<String, dynamic> toJson() => {'kind': 'swatch', 'i': i};

  @override
  bool operator ==(Object other) => other is SwatchBodyColor && other.i == i;

  @override
  int get hashCode => Object.hash('swatch', i);

  @override
  String toString() => 'SwatchBodyColor($i)';
}

/// "#RRGGBB"
class CustomBodyColor extends BodyColor {
  const CustomBodyColor(this.hex);

  final String hex;

  @override
  Map<String, dynamic> toJson() => {'kind': 'custom', 'hex': hex};

  @override
  bool operator ==(Object other) =>
      other is CustomBodyColor && other.hex == hex;

  @override
  int get hashCode => Object.hash('custom', hex);

  @override
  String toString() => 'CustomBodyColor($hex)';
}

/// 기본 몸 색: 견본 1 (크림)
const defaultBody = SwatchBodyColor(1);

/// 캐릭터(정령)의 모습 (Profile.look): `{eyes, brows, nose, mouth, body, clothColor, slots{9칸}}`.
/// clothColor는 기본 옷(여행복)의 시작 색 번호(props.json startColors, 1부터, 16장 11/8)다. 이 키가 없는 JSON은
/// 11/10 전에 저장된 것이라 옷 칸의 앞치마(그때 기본 옷)를 여행복으로 읽는다.
/// 얼굴 값은 palette.json customParts의 문자 id다 (Rive 값으로는 domain/spirit_look.dart가 바꾼다).
/// 옛 사람형 JSON은 기본 얼굴·크림으로 읽는다. 소품별 직접 색은 propColors에 추가하며,
/// 이 키가 없는 기존 저장도 그대로 읽는다. 이전의 별개 tints 키는 읽지 않는다.
class Look {
  const Look({
    this.eyes = defaultEyes,
    this.brows = defaultBrows,
    this.nose = defaultNose,
    this.mouth = defaultMouth,
    this.body = defaultBody,
    this.clothColor = defaultClothColor,
    this.slots = defaultSlots,
    this.propColors = const {},
  });

  /// 첫 실행의 기본 모습: 기본 얼굴, 크림 몸, 칸마다 기본 소품
  static const initial = Look();

  /// 기본 소품 id → 직접 고른 #RRGGBB. 옛 프로필에는 없으며 기존 값은 그대로 읽는다.
  final Map<String, String> propColors;

  final String eyes;
  final String brows;
  final String nose;
  final String mouth;
  final BodyColor body;

  /// 기본 옷(여행복)의 시작 색 번호, 1부터. 정령 만들기에서 한 번 고른다
  final int clothColor;

  /// 칸 이름([lookSlots]) → 끼운 소품 id. 비운 칸은 null. 아홉 칸을 모두 가진다
  final Map<String, String?> slots;

  Look copyWith({
    String? eyes,
    String? brows,
    String? nose,
    String? mouth,
    BodyColor? body,
    int? clothColor,
    Map<String, String>? propColors,
  }) => Look(
    eyes: canonicalFacePart('eyes', eyes ?? this.eyes),
    brows: canonicalFacePart('brows', brows ?? this.brows),
    nose: canonicalFacePart('nose', nose ?? this.nose),
    mouth: canonicalFacePart('mouth', mouth ?? this.mouth),
    body: body ?? this.body,
    clothColor: clothColor ?? this.clothColor,
    slots: slots,
    propColors: propColors ?? this.propColors,
  );

  /// [slot] 칸에 [propId]를 끼운 모습 (null이면 비운다). 칸 이름과 옷 비우기만 막고,
  /// 가진 소품인지는 ProfileService.saveLook이 본다
  Look withSlot(String slot, String? propId) {
    if (!lookSlots.contains(slot))
      throw ArgumentError.value(slot, 'slot', '모르는 소품 칸');
    if (propId == null && slot == alwaysWornSlot) {
      throw ArgumentError.value(slot, 'slot', '옷은 비울 수 없다');
    }
    return Look(
      eyes: eyes,
      brows: brows,
      nose: nose,
      mouth: mouth,
      body: body,
      clothColor: clothColor,
      propColors: propColors,
      slots: Map.unmodifiable({
        for (final s in lookSlots) s: s == slot ? propId : slots[s],
      }),
    );
  }

  Look withPropColor(String id, String hex) {
    if (unifiedProp(id) == null)
      throw ArgumentError.value(id, 'id', '연결되지 않은 소품');
    return copyWith(
      propColors: Map.unmodifiable({
        ...propColors,
        id: checkedHex(hex).toUpperCase(),
      }),
    );
  }

  Map<String, dynamic> toJson() => {
    'eyes': canonicalFacePart('eyes', eyes),
    'brows': canonicalFacePart('brows', brows),
    'nose': canonicalFacePart('nose', nose),
    'mouth': canonicalFacePart('mouth', mouth),
    'body': body.toJson(),
    'clothColor': clothColor,
    if (propColors.isNotEmpty) 'propColors': propColors,
    'slots': {for (final s in lookSlots) s: slots[s]},
  };

  /// 옛 사람형 JSON(`hair` 키가 있거나 eyes가 숫자)은 예외 없이 기본 얼굴·크림으로 읽고,
  /// slots는 읽을 수 있는 칸만 살린다 (모르는 칸은 무시, 읽을 수 없는 칸은 그 칸의 기본 소품).
  /// 새 형식에서 빠진 키는 기본값이고, 있는데 틀린 값(모르는 얼굴 id, 모르는 색 종류, 빈 옷 칸 …)은
  /// FormatException
  factory Look.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('hair') || j['eyes'] is num) {
      return Look(slots: _swapOldDefaultCloth(_legacySlots(j['slots'])));
    }
    final clothColor = j['clothColor'];
    if (clothColor != null && (clothColor is! int || clothColor < 1)) {
      throw FormatException('옷 색 번호가 1 이상의 정수가 아니다: $clothColor');
    }
    final slots = _slotsOf(j['slots']);
    return Look(
      eyes: _part(j, 'eyes', eyeParts, defaultEyes),
      brows: _part(j, 'brows', browParts, defaultBrows),
      nose: _part(j, 'nose', noseParts, defaultNose),
      mouth: _part(j, 'mouth', mouthParts, defaultMouth),
      body: j['body'] == null
          ? defaultBody
          : BodyColor.fromJson(_map(j['body'], '몸 색')),
      clothColor: clothColor as int? ?? defaultClothColor,
      propColors: _propColors(j['propColors']),
      slots: j.containsKey('clothColor') ? slots : _swapOldDefaultCloth(slots),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Look &&
      canonicalFacePart('eyes', other.eyes) ==
          canonicalFacePart('eyes', eyes) &&
      canonicalFacePart('brows', other.brows) ==
          canonicalFacePart('brows', brows) &&
      canonicalFacePart('nose', other.nose) ==
          canonicalFacePart('nose', nose) &&
      canonicalFacePart('mouth', other.mouth) ==
          canonicalFacePart('mouth', mouth) &&
      other.body == body &&
      other.clothColor == clothColor &&
      other.propColors.length == propColors.length &&
      propColors.entries.every((e) => other.propColors[e.key] == e.value) &&
      lookSlots.every((s) => other.slots[s] == slots[s]);

  @override
  int get hashCode => Object.hash(
    canonicalFacePart('eyes',eyes),
    canonicalFacePart('brows',brows),
    canonicalFacePart('nose',nose),
    canonicalFacePart('mouth',mouth),
    body,
    clothColor,
    Object.hashAllUnordered(
      propColors.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll([for (final s in lookSlots) slots[s]]),
  );

  @override
  String toString() =>
      'Look(eyes: $eyes, brows: $brows, nose: $nose, mouth: $mouth, '
      'body: $body, clothColor: $clothColor, slots: $slots)';
}

/// 얼굴 파츠 id 하나. 없으면 [fallback], 있는데 [parts]에 없으면 FormatException
String _part(
  Map<String, dynamic> j,
  String key,
  Map<String, int> parts,
  String fallback,
) {
  final v = j[key];
  if (v == null) return fallback;
  if (v is! String || !parts.containsKey(canonicalFacePart(key, v)))
    throw FormatException('모르는 $key: $v');
  return canonicalFacePart(key, v);
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

/// 11/10 전 모습의 옷 칸: 그때 기본 옷이던 앞치마는 여행복으로 (앞치마는 이제 300km 보상이다)
Map<String, String?> _swapOldDefaultCloth(Map<String, String?> slots) =>
    slots[alwaysWornSlot] != _oldDefaultCloth
    ? slots
    : Map.unmodifiable({
        ...slots,
        alwaysWornSlot: defaultSlots[alwaysWornSlot],
      });

/// 옛 JSON의 slots: 틀린 칸·맵이 아닌 값에도 멈추지 않고 그 칸의 기본 소품으로 둔다
Map<String, String?> _legacySlots(dynamic raw) {
  if (raw is! Map) return defaultSlots;
  final out = <String, String?>{};
  for (final slot in lookSlots) {
    final v = raw[slot];
    out[slot] = raw.containsKey(slot) && v == null && slot != alwaysWornSlot
        ? null
        : v is String && v.isNotEmpty
        ? v
        : defaultSlots[slot];
  }
  return Map.unmodifiable(out);
}

int _int(dynamic v) => v is int ? v : throw FormatException('정수가 아니다: $v');

Map<String, dynamic> _map(dynamic v, String what) => v is Map<String, dynamic>
    ? v
    : throw FormatException('$what이(가) 맵이 아니다: $v');

final _hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// "#RRGGBB"면 그대로, 아니면 FormatException
String checkedHex(dynamic v) => v is String && _hexPattern.hasMatch(v)
    ? v
    : throw FormatException('#RRGGBB가 아니다: $v');

Map<String, String> _propColors(dynamic raw) {
  if (raw is! Map) return const {};
  return Map.unmodifiable({
    for (final e in raw.entries)
      if (e.key is String &&
          unifiedProp(e.key) != null &&
          e.value is String &&
          _hexPattern.hasMatch(e.value))
        e.key as String: (e.value as String).toUpperCase(),
  });
}
