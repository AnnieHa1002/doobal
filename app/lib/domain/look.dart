/// 머리 모양 칸 수 (머리 1~6). 그림이 나오면 그 종류 수와 맞춘다
const hairShapeCount = 6;

/// 머리색 (M4 명세): 견본 번호 | 직접 고른 색 | 뿌리·끝 그러데이션.
/// JSON은 {kind: swatch, i} | {kind: custom, hex} | {kind: gradient, root, tip}
sealed class HairColor {
  const HairColor();

  Map<String, dynamic> toJson();

  factory HairColor.fromJson(Map<String, dynamic> j) => switch (j['kind']) {
        'swatch' => SwatchHairColor(_int(j['i'])),
        'custom' => CustomHairColor(_hex(j['hex'])),
        'gradient' => GradientHairColor(_hex(j['root']), _hex(j['tip'])),
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

/// 캐릭터의 모습 (Profile.look). 지금은 머리 모양·머리색만 있다.
/// 얼굴·피부·옷 같은 나머지 꾸미기 항목은 M4에서 여기에 더한다
class Look {
  const Look({required this.hair, required this.hairColor})
      : assert(hair >= 1 && hair <= hairShapeCount);

  /// 첫 실행의 기본 모습: 머리 1, 견본 1
  static const initial = Look(hair: 1, hairColor: SwatchHairColor(1));

  /// 머리 모양 번호 (1~[hairShapeCount])
  final int hair;
  final HairColor hairColor;

  Look copyWith({int? hair, HairColor? hairColor}) =>
      Look(hair: hair ?? this.hair, hairColor: hairColor ?? this.hairColor);

  Map<String, dynamic> toJson() => {'hair': hair, 'hairColor': hairColor.toJson()};

  factory Look.fromJson(Map<String, dynamic> j) {
    final hair = _int(j['hair']);
    if (hair < 1 || hair > hairShapeCount) throw FormatException('머리 모양 범위 밖: $hair');
    return Look(
      hair: hair,
      hairColor: HairColor.fromJson(j['hairColor'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Look && other.hair == hair && other.hairColor == hairColor;

  @override
  int get hashCode => Object.hash(hair, hairColor);

  @override
  String toString() => 'Look(hair: $hair, hairColor: $hairColor)';
}

/// palette.json의 머리색 견본 하나 (번호는 1부터, 이름은 접근성 label)
class HairSwatch {
  const HairSwatch(this.id, this.name, this.color);

  final int id;
  final String name;

  /// 불투명 ARGB (0xFFRRGGBB)
  final int color;
}

/// palette.json 전체에서 hair.swatches만 읽는다 (피부·잔디는 M4)
List<HairSwatch> parseHairSwatches(Map<String, dynamic> json) {
  final hair = json['hair'] as Map<String, dynamic>;
  return [
    for (final s in hair['swatches'] as List)
      HairSwatch(
        _int((s as Map<String, dynamic>)['id']),
        s['name'] as String,
        _argb(_hex(s['hex'])),
      ),
  ];
}

/// 머리색을 그릴 색(불투명 ARGB)으로. 견본 번호가 [swatches]에 없으면 첫 견본,
/// 그러데이션은 뿌리 색 (그러데이션 그리기는 M4)
int hairArgb(HairColor c, List<HairSwatch> swatches) => switch (c) {
      SwatchHairColor(:final i) =>
        swatches.firstWhere((s) => s.id == i, orElse: () => swatches.first).color,
      CustomHairColor(:final hex) => _argb(hex),
      GradientHairColor(:final root) => _argb(root),
    };

/// "#RRGGBB" → 불투명 ARGB
int _argb(String hex) => 0xFF000000 | int.parse(hex.substring(1), radix: 16);

int _int(dynamic v) => v is int ? v : throw FormatException('정수가 아니다: $v');

final _hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

String _hex(dynamic v) =>
    v is String && _hexPattern.hasMatch(v) ? v : throw FormatException('#RRGGBB가 아니다: $v');
