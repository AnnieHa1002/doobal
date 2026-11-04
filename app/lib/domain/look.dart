import 'face_parts.dart';

export 'face_parts.dart' show defaultBrows, defaultEyes, defaultMouth, defaultNose;

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

/// 몸 색 (palette.json body): 견본 번호 | 직접 고른 색. 소품 색(Look.tints)도 같은 모양이다.
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
  bool operator ==(Object other) => other is CustomBodyColor && other.hex == hex;

  @override
  int get hashCode => Object.hash('custom', hex);

  @override
  String toString() => 'CustomBodyColor($hex)';
}

/// 기본 몸 색: 견본 1 (크림)
const defaultBody = SwatchBodyColor(1);

/// 캐릭터(정령)의 모습 (Profile.look): `{eyes, brows, nose, mouth, body, slots{9칸}, tints{propId: 색}}`.
/// 얼굴 값은 palette.json customParts의 문자 id다 (Rive 값으로는 domain/spirit_look.dart가 바꾼다).
/// 옛 사람형 JSON은 [Look.fromJson]이 기본 얼굴·크림으로 읽는다
class Look {
  const Look({
    this.eyes = defaultEyes,
    this.brows = defaultBrows,
    this.nose = defaultNose,
    this.mouth = defaultMouth,
    this.body = defaultBody,
    this.slots = defaultSlots,
    this.tints = const {},
  });

  /// 첫 실행의 기본 모습: 기본 얼굴, 크림 몸, 칸마다 기본 소품, 소품 색 없음
  static const initial = Look();

  final String eyes;
  final String brows;
  final String nose;
  final String mouth;
  final BodyColor body;

  /// 칸 이름([lookSlots]) → 끼운 소품 id. 비운 칸은 null. 아홉 칸을 모두 가진다
  final Map<String, String?> slots;

  /// 소품 id → 고른 색 (props.json에서 tint가 있는 소품만). 없으면 소품의 기본 색
  final Map<String, BodyColor> tints;

  Look copyWith({String? eyes, String? brows, String? nose, String? mouth, BodyColor? body}) =>
      Look(
        eyes: eyes ?? this.eyes,
        brows: brows ?? this.brows,
        nose: nose ?? this.nose,
        mouth: mouth ?? this.mouth,
        body: body ?? this.body,
        slots: slots,
        tints: tints,
      );

  /// [slot] 칸에 [propId]를 끼운 모습 (null이면 비운다). 칸 이름과 옷 비우기만 막고,
  /// 가진 소품인지는 ProfileService.saveLook이 본다
  Look withSlot(String slot, String? propId) {
    if (!lookSlots.contains(slot)) throw ArgumentError.value(slot, 'slot', '모르는 소품 칸');
    if (propId == null && slot == alwaysWornSlot) {
      throw ArgumentError.value(slot, 'slot', '옷은 비울 수 없다');
    }
    return Look(
      eyes: eyes,
      brows: brows,
      nose: nose,
      mouth: mouth,
      body: body,
      slots: Map.unmodifiable({
        for (final s in lookSlots) s: s == slot ? propId : slots[s],
      }),
      tints: tints,
    );
  }

  /// [propId] 소품의 색을 [color]로 (null이면 기본 색으로 되돌린다)
  Look withTint(String propId, BodyColor? color) => Look(
        eyes: eyes,
        brows: brows,
        nose: nose,
        mouth: mouth,
        body: body,
        slots: slots,
        tints: Map.unmodifiable({
          for (final e in tints.entries)
            if (e.key != propId) e.key: e.value,
          propId: ?color,
        }),
      );

  Map<String, dynamic> toJson() => {
        'eyes': eyes,
        'brows': brows,
        'nose': nose,
        'mouth': mouth,
        'body': body.toJson(),
        'slots': {for (final s in lookSlots) s: slots[s]},
        'tints': {for (final e in tints.entries) e.key: e.value.toJson()},
      };

  /// 옛 사람형 JSON(`hair` 키가 있거나 eyes가 숫자)은 예외 없이 기본 얼굴·크림으로 읽고,
  /// slots는 읽을 수 있는 칸만 살린다 (모르는 칸은 무시, 읽을 수 없는 칸은 그 칸의 기본 소품).
  /// 새 형식에서 빠진 키는 기본값이고, 있는데 틀린 값(모르는 얼굴 id, 모르는 색 종류, 빈 옷 칸 …)은
  /// FormatException
  factory Look.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('hair') || j['eyes'] is num) {
      return Look(slots: _legacySlots(j['slots']));
    }
    return Look(
      eyes: _part(j, 'eyes', eyeParts, defaultEyes),
      brows: _part(j, 'brows', browParts, defaultBrows),
      nose: _part(j, 'nose', noseParts, defaultNose),
      mouth: _part(j, 'mouth', mouthParts, defaultMouth),
      body: j['body'] == null ? defaultBody : BodyColor.fromJson(_map(j['body'], '몸 색')),
      slots: _slotsOf(j['slots']),
      tints: _tintsOf(j['tints']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Look &&
      other.eyes == eyes &&
      other.brows == brows &&
      other.nose == nose &&
      other.mouth == mouth &&
      other.body == body &&
      lookSlots.every((s) => other.slots[s] == slots[s]) &&
      other.tints.length == tints.length &&
      tints.entries.every((e) => other.tints[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
        eyes,
        brows,
        nose,
        mouth,
        body,
        Object.hashAll([for (final s in lookSlots) slots[s]]),
        Object.hashAllUnordered([for (final e in tints.entries) Object.hash(e.key, e.value)]),
      );

  @override
  String toString() => 'Look(eyes: $eyes, brows: $brows, nose: $nose, mouth: $mouth, '
      'body: $body, slots: $slots, tints: $tints)';
}

/// 얼굴 파츠 id 하나. 없으면 [fallback], 있는데 [parts]에 없으면 FormatException
String _part(Map<String, dynamic> j, String key, Map<String, int> parts, String fallback) {
  final v = j[key];
  if (v == null) return fallback;
  if (v is! String || !parts.containsKey(v)) throw FormatException('모르는 $key: $v');
  return v;
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

/// tints 읽기: 없으면 비어 있고, 있으면 {propId: 색} 맵이어야 한다
Map<String, BodyColor> _tintsOf(dynamic raw) {
  if (raw == null) return const {};
  if (raw is! Map) throw FormatException('tints가 맵이 아니다: $raw');
  final out = <String, BodyColor>{};
  for (final e in raw.entries) {
    final id = e.key;
    if (id is! String) throw FormatException('소품 id가 아니다: $id');
    out[id] = BodyColor.fromJson(_map(e.value, '소품 색'));
  }
  return Map.unmodifiable(out);
}

int _int(dynamic v) => v is int ? v : throw FormatException('정수가 아니다: $v');

Map<String, dynamic> _map(dynamic v, String what) =>
    v is Map<String, dynamic> ? v : throw FormatException('$what이(가) 맵이 아니다: $v');

final _hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// "#RRGGBB"면 그대로, 아니면 FormatException
String checkedHex(dynamic v) =>
    v is String && _hexPattern.hasMatch(v) ? v : throw FormatException('#RRGGBB가 아니다: $v');
