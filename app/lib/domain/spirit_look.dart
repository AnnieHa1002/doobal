import 'look.dart';

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
  });

  /// 기본 얼굴(점+반짝 눈·시바 눈썹·/// 코·ω 입), 소품 없음. Rive 파일의 기본값과 같다
  static const base = SpiritLook();

  /// eyeStyle · browStyle · noseStyle · mouthStyle
  final int eye, brow, nose, mouth;

  /// bagStyle · outfitStyle · companionStyle (0은 없음)
  final int bag, outfit, companion;

  SpiritLook copyWith({int? bag, int? outfit, int? companion}) => SpiritLook(
        eye: eye,
        brow: brow,
        nose: nose,
        mouth: mouth,
        bag: bag ?? this.bag,
        outfit: outfit ?? this.outfit,
        companion: companion ?? this.companion,
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
      other.companion == companion;

  @override
  int get hashCode => Object.hash(eye, brow, nose, mouth, bag, outfit, companion);

  @override
  String toString() => 'SpiritLook(eye: $eye, brow: $brow, nose: $nose, mouth: $mouth, '
      'bag: $bag, outfit: $outfit, companion: $companion)';
}

/// 코 번호(UI 명세 12장 순서: 없음·점·넓적·삼각·하트·고리·///) → noseStyle.
/// 눈·눈썹·입은 명세 순서와 Rive 값 순서가 같다
const _noseStyles = [3, 1, 2, 4, 5, 0, 6];

/// Rive에 붙은 소품 → 값 (v25는 5종). 나머지 소품은 리깅 전이라 정령에 보이지 않는다.
/// cloth_02·pet_05는 지금 props.json의 id, 나머지는 소품 목록(props v4)의 id다.
/// 큰 붓·봇짐·연두 망토는 지금 props.json에 없어서 props v4가 들어와야 고를 수 있다
const _bagStyles = {'hand_01': 1, 'hand_02': 2};
const _outfitStyles = {'cloth_02': 1, 'cloth_05': 2};
const _companionStyles = {'pet_05': 1};

/// 저장된 모습을 정령 입력값으로 바꾼다
SpiritLook spiritLookOf(Look look) => SpiritLook(
      eye: look.eyes - 1,
      brow: look.brows - 1,
      nose: _noseStyles[look.nose - 1],
      mouth: look.mouth - 1,
      bag: _bagStyles[look.slots['bag']] ?? 0,
      outfit: _outfitStyles[look.slots['cloth']] ?? 0,
      companion: _companionStyles[look.slots['pet']] ?? 0,
    );
