import 'color.dart';
import 'look.dart';

/// palette.json의 피부색 견본 하나 (번호는 1부터, 이름은 접근성 label)
class SkinSwatch {
  const SkinSwatch(this.id, this.name, this.color);

  final int id;
  final String name;

  /// 불투명 ARGB (0xFFRRGGBB)
  final int color;
}

/// 머리색 규칙 (palette.json hair): 견본, 기준 밝기, 직접 고르기의 HSL 밝기 범위(%),
/// 그러데이션에서 뿌리색이 이어지는 곳과 끝색이 시작하는 곳 (머리카락 위 0 → 아래 1)
class HairPalette {
  const HairPalette({
    required this.base,
    required this.swatches,
    required this.lightMin,
    required this.lightMax,
    required this.rootUntil,
    required this.tipFrom,
  });

  /// 머리카락 그림의 기준 밝기 (회색 이 값이 견본색 그대로 나온다)
  final int base;
  final List<HairSwatch> swatches;
  final int lightMin;
  final int lightMax;
  final double rootUntil;
  final double tipFrom;
}

/// 피부색 규칙 (palette.json skin): 견본, 기준 밝기, 직접 고르기의 HSL 밝기 범위(%)
class SkinPalette {
  const SkinPalette({
    required this.base,
    required this.swatches,
    required this.lightMin,
    required this.lightMax,
  });

  final int base;
  final List<SkinSwatch> swatches;
  final int lightMin;
  final int lightMax;
}

/// 꾸미기가 읽는 palette.json: 머리와 피부 (잔디는 쉼터 쪽이 읽는다)
class LookPalette {
  const LookPalette({required this.hair, required this.skin});

  final HairPalette hair;
  final SkinPalette skin;

  /// 모양이 틀리면 FormatException (견본 없음, 범위가 거꾸로, 그러데이션 구간이 0~1 밖 …)
  factory LookPalette.fromJson(Map<String, dynamic> json) {
    final hair = json['hair'] as Map<String, dynamic>;
    final skin = json['skin'] as Map<String, dynamic>;
    final hairLight = _lightRange(hair['custom'], '머리');
    final skinLight = _lightRange(skin['custom'], '피부');
    final gradient = hair['gradient'] as Map<String, dynamic>;
    final rootUntil = _fraction(gradient['rootUntil'], 'rootUntil');
    final tipFrom = _fraction(gradient['tipFrom'], 'tipFrom');
    if (rootUntil >= tipFrom) {
      throw FormatException('그러데이션 구간이 거꾸로다: $rootUntil ≥ $tipFrom');
    }
    final hairSwatches = parseHairSwatches(json);
    final skinSwatches = parseSkinSwatches(json);
    if (hairSwatches.isEmpty || skinSwatches.isEmpty) throw const FormatException('견본이 없다');
    return LookPalette(
      hair: HairPalette(
        base: _base(hair['base'], '머리'),
        swatches: hairSwatches,
        lightMin: hairLight.$1,
        lightMax: hairLight.$2,
        rootUntil: rootUntil,
        tipFrom: tipFrom,
      ),
      skin: SkinPalette(
        base: _base(skin['base'], '피부'),
        swatches: skinSwatches,
        lightMin: skinLight.$1,
        lightMax: skinLight.$2,
      ),
    );
  }
}

/// palette.json 전체에서 skin.swatches만 읽는다
List<SkinSwatch> parseSkinSwatches(Map<String, dynamic> json) {
  final skin = json['skin'] as Map<String, dynamic>;
  return [
    for (final s in skin['swatches'] as List)
      SkinSwatch(
        _int((s as Map<String, dynamic>)['id']),
        s['name'] as String,
        argbFromHex(checkedHex(s['hex'])),
      ),
  ];
}

/// 피부색을 그릴 색(불투명 ARGB)으로. 견본 번호가 [swatches]에 없으면 첫 견본
int skinArgb(SkinColor c, List<SkinSwatch> swatches) => switch (c) {
      SwatchSkinColor(:final i) =>
        swatches.firstWhere((s) => s.id == i, orElse: () => swatches.first).color,
      CustomSkinColor(:final hex) => argbFromHex(hex),
    };

int _int(dynamic v) => v is int ? v : throw FormatException('정수가 아니다: $v');

int _base(dynamic v, String what) {
  final n = _int(v);
  if (n <= 0) throw FormatException('$what 기준 밝기는 0보다 커야 한다: $n');
  return n;
}

(int, int) _lightRange(dynamic custom, String what) {
  final c = custom as Map<String, dynamic>;
  final lo = _int(c['lightMin']);
  final hi = _int(c['lightMax']);
  if (lo < 0 || hi > 100 || lo >= hi) throw FormatException('$what 밝기 범위가 틀렸다: $lo~$hi');
  return (lo, hi);
}

double _fraction(dynamic v, String what) {
  if (v is! num || v < 0 || v > 1) throw FormatException('$what은(는) 0~1이어야 한다: $v');
  return v.toDouble();
}
