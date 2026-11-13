import 'face_parts.dart';
import 'look.dart';
import 'unified_wardrobe.dart';

/// 정령 몸 그림의 기준 색 기본값 (palette.json body.baseHex와 같다: Rive v25 몸통의 평면색)
const defaultBodyBaseArgb = 0xFFFFF5E2;

/// 통합 Rive의 choices·colors 입력과 기존 게임 호출의 호환 값.
class SpiritLook {
  const SpiritLook({
    this.eye = 0,
    this.brow = 1,
    this.nose = 6,
    this.mouth = 6,
    this.bag = 0,
    this.outfit = 0,
    this.companion = 0,
    this.bodyArgb,
    this.bodyBaseArgb = defaultBodyBaseArgb,
    this.choices = const {},
    this.colors = const {},
  });

  /// 기본 얼굴(점+반짝 눈·시바 눈썹·/// 코·ω 입), 소품 없음, 몸 색 그대로. Rive 파일의 기본값과 같다
  static const base = SpiritLook();

  /// eyeStyle · browStyle · noseStyle · mouthStyle
  final int eye, brow, nose, mouth;

  /// bagStyle · outfitStyle · companionStyle (0은 없음)
  final int bag, outfit, companion;

  /// 몸 색 (불투명 ARGB). null이면 확정 크림색. 필터 없이 bodyColor 채색 면에 직접 적용한다.
  final int? bodyArgb;
  final int bodyBaseArgb;
  final Map<String, int> choices, colors;

  SpiritLook copyWith({
    int? bag,
    int? outfit,
    int? companion,
    int? bodyArgb,
    int? bodyBaseArgb,
  }) => SpiritLook(
    eye: eye,
    brow: brow,
    nose: nose,
    mouth: mouth,
    bag: bag ?? this.bag,
    outfit: outfit ?? this.outfit,
    companion: companion ?? this.companion,
    choices: choices,
    colors: colors,
    bodyArgb: bodyArgb ?? this.bodyArgb,
    bodyBaseArgb: bodyBaseArgb ?? this.bodyBaseArgb,
  );

  @override
  bool operator ==(Object other) =>
      other is SpiritLook &&
      other.eye == eye &&
      other.brow == brow &&
      other.nose == nose &&
      other.mouth == mouth &&
      other.bag == bag &&
      other.outfit == outfit &&
      other.companion == companion &&
      other.bodyArgb == bodyArgb &&
      other.bodyBaseArgb == bodyBaseArgb &&
      _same(choices, other.choices) &&
      _same(colors, other.colors);

  @override
  int get hashCode => Object.hash(
    eye,
    brow,
    nose,
    mouth,
    bag,
    outfit,
    companion,
    bodyArgb,
    bodyBaseArgb,
    Object.hashAllUnordered(
      choices.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      colors.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'SpiritLook(eye: $eye, brow: $brow, nose: $nose, mouth: $mouth, '
      'bag: $bag, outfit: $outfit, companion: $companion, '
      'bodyArgb: ${bodyArgb?.toRadixString(16)}, bodyBaseArgb: ${bodyBaseArgb.toRadixString(16)})';
}

/// Rive에 붙은 소품 → 값 (v25는 5종). 나머지 소품은 리깅 전이라 정령에 보이지 않는다.
/// 큰 붓·봇짐·연두 망토는 props v4의 id다
const _bagStyles = {'hand_01': 1, 'hand_02': 2};
const _outfitStyles = {'cloth_02': 1, 'cloth_05': 2};
const _companionStyles = {'pet_05': 1};

/// 저장된 모습을 정령 입력값으로 바꾼다. [bodyArgb]는 몸 색(BodyPalette.argbOf)이고,
/// 팔레트를 읽기 전이면 null (spiritLookProvider가 채운다).
/// [baseOf]는 색 소품 id → 기본 소품 id(props variantOf, `variantBases`). 색 소품은 기본 소품 그림으로
/// 보인다(색은 컷아웃 연결 T5 때): 별밤 여행복을 입어도 정령이 여행복을 입는다
SpiritLook spiritLookOf(
  Look look, {
  int? bodyArgb,
  int bodyBaseArgb = defaultBodyBaseArgb,
  Map<String, String> baseOf = const {},
  Map<String, int> variantColors = const {},
  int? initialClothArgb,
}) {
  int style(Map<String, int> styles, String slot) {
    final id = look.slots[slot];
    return styles[id] ?? styles[baseOf[id]] ?? 0;
  }

  final choices = <String, int>{
    for (final slot in [
      'hat',
      'face',
      'cloth',
      'shoe',
      'hand',
      'bag',
      'pet',
      'float',
    ])
      slot: 0,
  };
  final colors = <String, int>{
    for (final p in unifiedProps) p.colorField: p.argb,
  };
  for (final e in look.slots.entries) {
    final id = e.value;
    final base = baseOf[id] ?? id;
    final p = unifiedProp(base);
    if (p == null) continue;
    choices[p.slot] = p.choice;
    final color = id != base
        ? variantColors[id]
        : p.id == 'cloth_02'
        ? initialClothArgb
        : null;
    if (color != null) colors[p.colorField] = color;
  }
  return SpiritLook(
    choices: Map.unmodifiable(choices),
    colors: Map.unmodifiable(colors),
    eye: eyeParts[canonicalFacePart('eyes', look.eyes)] ?? 0,
    brow: browParts[canonicalFacePart('brows', look.brows)] ?? 1,
    nose: noseParts[canonicalFacePart('nose', look.nose)] ?? 6,
    mouth: mouthParts[canonicalFacePart('mouth', look.mouth)] ?? 6,
    bag: style(_bagStyles, 'bag'),
    outfit: style(_outfitStyles, 'cloth'),
    companion: style(_companionStyles, 'pet'),
    bodyArgb: bodyArgb,
    bodyBaseArgb: bodyBaseArgb,
  );
}

bool _same(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
