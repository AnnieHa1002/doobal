// 정령 얼굴 파츠: 저장하는 id → Rive 정수. 순서는 palette.json customParts와 같다
// (test/domain/spirit_look_test.dart가 같은지 본다). 코는 없음=3·고리=0 순서에 주의

const eyeParts = <String, int>{'dot': 0, 'bean': 1, 'sleepy': 2, 'fierce': 3, 'cat': 4};
const browParts = <String, int>{'none': 0, 'shiba': 1, 'thin': 2, 'thick': 3, 'fierce': 4};
const noseParts = <String, int>{
  'none': 3,
  'ring': 0,
  'dot': 1,
  'wide': 2,
  'triangle': 4,
  'heart': 5,
  'shy': 6,
};
const mouthParts = <String, int>{
  'smile': 0,
  'omega': 1,
  'o': 2,
  'flat': 3,
  'tongue': 4,
  'smirk': 5,
};

/// 기본 얼굴: 점+반짝 눈 · 시바 눈썹 · /// 코 · ω 입 (palette.json defaultFace)
const defaultEyes = 'dot';
const defaultBrows = 'shiba';
const defaultNose = 'shy';
const defaultMouth = 'omega';
