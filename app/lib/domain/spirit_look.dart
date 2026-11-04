import 'face_parts.dart';
import 'look.dart';

/// 정령 몸 그림의 기준 색 기본값 (palette.json body.baseHex와 같다: Rive v25 몸통의 평면색)
const defaultBodyBaseArgb = 0xFFFFF5E2;

/// 정령 Rive(v25)의 View Model 입력값. 번호는 Rive 파일이 정한 값이다 (docs/정령_애니메이션.md)
class SpiritLook {
  const SpiritLook({
    this.eye = 0,
    this.brow = 1,
    this.nose = 6,
    this.mouth = 1,
    this.bag = 0,
    this.outfit = 0,
    this.companion = 0,
    this.bodyArgb,
    this.bodyBaseArgb = defaultBodyBaseArgb,
  });

  /// 기본 얼굴(점+반짝 눈·시바 눈썹·/// 코·ω 입), 소품 없음, 몸 색 그대로. Rive 파일의 기본값과 같다
  static const base = SpiritLook();

  /// eyeStyle · browStyle · noseStyle · mouthStyle
  final int eye, brow, nose, mouth;

  /// bagStyle · outfitStyle · companionStyle (0은 없음)
  final int bag, outfit, companion;

  /// 몸 색 (불투명 ARGB). null이면 Rive 그림 그대로. Rive v25에는 몸 색 입력이 없어서
  /// SpiritCharacter가 곱하기 필터로 입힌다 ([bodyBaseArgb]는 palette.json body.baseHex)
  final int? bodyArgb;
  final int bodyBaseArgb;

  SpiritLook copyWith({int? bag, int? outfit, int? companion, int? bodyArgb, int? bodyBaseArgb}) =>
      SpiritLook(
        eye: eye,
        brow: brow,
        nose: nose,
        mouth: mouth,
        bag: bag ?? this.bag,
        outfit: outfit ?? this.outfit,
        companion: companion ?? this.companion,
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
      other.bodyBaseArgb == bodyBaseArgb;

  @override
  int get hashCode =>
      Object.hash(eye, brow, nose, mouth, bag, outfit, companion, bodyArgb, bodyBaseArgb);

  @override
  String toString() => 'SpiritLook(eye: $eye, brow: $brow, nose: $nose, mouth: $mouth, '
      'bag: $bag, outfit: $outfit, companion: $companion, '
      'bodyArgb: ${bodyArgb?.toRadixString(16)}, bodyBaseArgb: ${bodyBaseArgb.toRadixString(16)})';
}

/// Rive에 붙은 소품 → 값 (v25는 5종). 나머지 소품은 리깅 전이라 정령에 보이지 않는다.
/// 큰 붓·봇짐·연두 망토는 props v4의 id다
const _bagStyles = {'hand_01': 1, 'hand_02': 2};
const _outfitStyles = {'cloth_02': 1, 'cloth_05': 2};
const _companionStyles = {'pet_05': 1};

/// 저장된 모습을 정령 입력값으로 바꾼다. [bodyArgb]는 몸 색(BodyPalette.argbOf)이고,
/// 팔레트를 읽기 전이면 null (spiritLookProvider가 채운다)
SpiritLook spiritLookOf(
  Look look, {
  int? bodyArgb,
  int bodyBaseArgb = defaultBodyBaseArgb,
}) =>
    SpiritLook(
      eye: eyeParts[look.eyes] ?? 0,
      brow: browParts[look.brows] ?? 1,
      nose: noseParts[look.nose] ?? 6,
      mouth: mouthParts[look.mouth] ?? 1,
      bag: _bagStyles[look.slots['bag']] ?? 0,
      outfit: _outfitStyles[look.slots['cloth']] ?? 0,
      companion: _companionStyles[look.slots['pet']] ?? 0,
      bodyArgb: bodyArgb,
      bodyBaseArgb: bodyBaseArgb,
    );
