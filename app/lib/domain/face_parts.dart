// 정령 얼굴 부위: 저장 id(계약 v0.5, palette.json customPartsV33) → 정령 Rive 값의 앞 단계 번호.
// SpiritController가 Rive 입력으로 바꾼다: eye = 번호 + 1(1~6), brow = 번호(0 없음·1~6),
// nose = 번호 7이면 0(없음), 아니면 번호 + 1(1~7), mouth = 번호 + 1(1~8). 순서는 palette.json customParts와 같다
const eyeParts = <String, int>{'e1': 0, 'e2': 1, 'e3': 2, 'e4': 3, 'e5': 4, 'e6': 5};
const browParts = <String, int>{'none': 0, 'b1': 1, 'b2': 2, 'b3': 3, 'b4': 4, 'b5': 5, 'b6': 6};
const noseParts = <String, int>{
  'none': 7,
  'n1': 0,
  'n2': 1,
  'n3': 2,
  'n4': 3,
  'n5': 4,
  'n6': 5,
  'n7': 6,
};
const mouthParts = <String, int>{
  'm1': 0,
  'm2': 1,
  'm3': 2,
  'm4': 3,
  'm5': 4,
  'm6': 5,
  'm7': 6,
  'm8': 7,
};

/// 첫 얼굴 (계약 v0.5 기본 얼굴, Rive v33 기본값: 눈 1·눈썹 1·코 7·입 7)
const defaultEyes = 'e1';
const defaultBrows = 'b1';
const defaultNose = 'n7';
const defaultMouth = 'm7';

/// 옛 저장값 → 지금 id. 11/12 통합 작업의 PSD 이름 id는 같은 부위로 옮기고, 그 전 v24 id는
/// 계약 v0.5대로 첫 얼굴로 돌린다(출시 전). 두 목록에 같은 이름이 있으면(졸린 눈 등) PSD 쪽을 따른다
const legacyFaceAliases = <String, Map<String, String>>{
  'eyes': {
    'default_drop': 'e1',
    'soft': 'e2',
    'mischievous': 'e3',
    'sleepy': 'e4',
    'closed': 'e5',
    'sparkle': 'e6',
    'dot': defaultEyes,
    'bean': defaultEyes,
    'fierce': defaultEyes,
    'cat': defaultEyes,
  },
  'brows': {
    'gentle': 'b1',
    'short': 'b2',
    'angry': 'b3',
    'sleepy': 'b4',
    'worried': 'b5',
    'handsome': 'b6',
    'shiba': defaultBrows,
    'thin': defaultBrows,
    'thick': defaultBrows,
    'fierce': defaultBrows,
  },
  'nose': {
    'slash': 'n1',
    'ring': 'n2',
    'arch': 'n3',
    'scoop': 'n4',
    'dots': 'n5',
    'curl': 'n6',
    'round': 'n7',
    'dot': defaultNose,
    'wide': defaultNose,
    'triangle': defaultNose,
    'heart': defaultNose,
    'shy': defaultNose,
  },
  'mouth': {
    'smile': 'm1',
    'omega': 'm2',
    'fangs': 'm3',
    'open': 'm4',
    'grin': 'm5',
    'long_smile': 'm6',
    'soft_smile': 'm7',
    'wide_smile': 'm8',
    'o': defaultMouth,
    'flat': defaultMouth,
    'tongue': defaultMouth,
    'smirk': defaultMouth,
  },
};

String canonicalFacePart(String kind, String id) => legacyFaceAliases[kind]?[id] ?? id;
