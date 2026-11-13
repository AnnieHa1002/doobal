// 확정 PSD 얼굴 파츠: 저장 id → 통합 Rive 정수. 기존 저장은 아래 대응표로 읽는다.
const eyeParts = <String, int>{
  'default_drop': 0,
  'soft': 1,
  'mischievous': 2,
  'sleepy': 3,
  'closed': 4,
  'sparkle': 5,
};
const browParts = <String, int>{
  'none': 0,
  'gentle': 1,
  'short': 2,
  'angry': 3,
  'sleepy': 4,
  'worried': 5,
  'handsome': 6,
};
const noseParts = <String, int>{
  'none': 7,
  'slash': 0,
  'ring': 1,
  'arch': 2,
  'scoop': 3,
  'dots': 4,
  'curl': 5,
  'round': 6,
};
const mouthParts = <String, int>{
  'smile': 0,
  'omega': 1,
  'fangs': 2,
  'open': 3,
  'grin': 4,
  'long_smile': 5,
  'soft_smile': 6,
  'wide_smile': 7,
};
const defaultEyes = 'default_drop';
const defaultBrows = 'gentle';
const defaultNose = 'round';
const defaultMouth = 'soft_smile';
const legacyFaceAliases = <String, Map<String, String>>{
  'eyes': {
    'dot': 'default_drop',
    'bean': 'soft',
    'fierce': 'sleepy',
    'cat': 'mischievous',
  },
  'brows': {
    'shiba': 'gentle',
    'thin': 'short',
    'thick': 'handsome',
    'fierce': 'angry',
  },
  'nose': {
    'dot': 'round',
    'wide': 'dots',
    'triangle': 'arch',
    'heart': 'scoop',
    'shy': 'slash',
  },
  'mouth': {
    'o': 'open',
    'flat': 'soft_smile',
    'tongue': 'grin',
    'smirk': 'long_smile',
  },
};
String canonicalFacePart(String kind, String id) =>
    legacyFaceAliases[kind]?[id] ?? id;
