import 'color.dart';
import 'face_parts.dart';
import 'look.dart';

/// palette.json body.swatches의 견본 하나 (번호는 1부터, 이름은 접근성 label)
class BodySwatch {
  const BodySwatch(this.id, this.name, this.color);

  final int id;
  final String name;

  /// 불투명 ARGB (0xFFRRGGBB)
  final int color;
}

/// 몸 색 규칙 (palette.json body): 견본, 기준 밝기, 기본 견본 번호.
/// 직접 고르기는 밝기 제한·채도 막대가 없다 (색상환 + 밝기만)
class BodyPalette {
  const BodyPalette({
    required this.base,
    required this.baseArgb,
    required this.swatches,
    required this.defaultId,
  });

  /// 정령 몸 그림의 기준 밝기: 이 값의 회색이 견본색 그대로 나온다 (근사값)
  final int base;

  /// 몸 그림의 기준 색 (불투명 ARGB): 곱하기 필터가 채널별로 나누는 값. palette.json body.baseHex가 있으면
  /// 그 색(지금 Rive 몸통은 평면색 #FFF5E2), 없으면 회색 [base]
  final int baseArgb;
  final List<BodySwatch> swatches;
  final int defaultId;

  /// 몸 색을 그릴 색(불투명 ARGB)으로. 견본 번호가 없으면 기본 견본
  int argbOf(BodyColor c) => switch (c) {
        SwatchBodyColor(:final i) => swatchArgb(i),
        CustomBodyColor(:final hex) => argbFromHex(hex),
      };

  /// 견본 [id]의 색. 모르는 번호는 기본 견본
  int swatchArgb(int id) => swatches
      .firstWhere((s) => s.id == id, orElse: () => swatches.firstWhere((s) => s.id == defaultId))
      .color;

  /// 견본 이름 (직접 고른 색은 '직접 고르기')
  String nameOf(BodyColor c) => switch (c) {
        SwatchBodyColor(:final i) => swatches
            .firstWhere((s) => s.id == i,
                orElse: () => swatches.firstWhere((s) => s.id == defaultId))
            .name,
        CustomBodyColor() => '직접 고르기',
      };
}

/// 얼굴 파츠 하나: 저장 id와 화면 이름
typedef FacePart = ({String id, String name});

/// 꾸미기·시작 화면이 읽는 palette.json: 몸 색, 얼굴 파츠 이름
/// (잔디는 쉼터 쪽이 따로 읽는다)
class SpiritPalette {
  const SpiritPalette({required this.body, required this.faces});

  final BodyPalette body;

  /// 'eyes'·'brows'·'nose'·'mouth' → 파츠 목록 (palette.json 순서)
  final Map<String, List<FacePart>> faces;


  /// 모양이 틀리면 FormatException (견본 없음, 기본 견본이 없음, 파츠 id가 코드 표와 다름 …)
  factory SpiritPalette.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>;
    final swatches = [
      for (final s in body['swatches'] as List)
        BodySwatch(
          _int((s as Map<String, dynamic>)['id']),
          s['name'] as String,
          argbFromHex(checkedHex(s['hex'])),
        ),
    ];
    final base = _int(body['base']);
    if (base <= 0) throw FormatException('몸 기준 밝기는 0보다 커야 한다: $base');
    final defaultId = _int(body['default']);
    if (!swatches.any((s) => s.id == defaultId)) {
      throw FormatException('기본 몸 색 견본이 없다: $defaultId');
    }

    final parts = json['customParts'] as Map<String, dynamic>;
    List<FacePart> face(String key, Map<String, int> table) {
      final list = [
        for (final p in parts[key] as List)
          (id: (p as Map<String, dynamic>)['id'] as String, name: p['name'] as String),
      ];
      if (list.isEmpty) throw FormatException('$key 파츠가 없다');
      for (final p in list) {
        if (!table.containsKey(p.id)) throw FormatException('모르는 $key 파츠: ${p.id}');
      }
      return list;
    }

    return SpiritPalette(
      body: BodyPalette(
        base: base,
        baseArgb: body['baseHex'] == null
            ? 0xFF000000 | base << 16 | base << 8 | base
            : argbFromHex(checkedHex(body['baseHex'])),
        swatches: swatches,
        defaultId: defaultId,
      ),
      faces: {
        'eyes': face('eyes', eyeParts),
        'brows': face('brows', browParts),
        'nose': face('nose', noseParts),
        'mouth': face('mouth', mouthParts),
      },
    );
  }
}

int _int(dynamic v) => v is int ? v : throw FormatException('정수가 아니다: $v');
