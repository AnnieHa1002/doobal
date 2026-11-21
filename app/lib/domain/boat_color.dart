import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'look.dart' show BodyColor;

// 상점 배 색 (T4c, 16장 11/6 배 색, boats.json v4 recolorRule·배마다 recolor). 화면 없이 순수하게:
// 저장 꼴, 색 입히기 자료, 픽셀 계산. 픽셀은 모두 프리멀티플라이 RGBA 8비트(ui.Image rawRgba·PixelFormat.rgba8888)

/// 배 색 구역 (boats.json recolorRule.zones 키)
enum BoatZone { hull, upper, accent }

/// 배 판 (같은 원점·같은 캔버스)
enum BoatSide { rear, front }

/// 색 입히는 법 (boats.json recolor.method)
enum RecolorMethod {
  /// premium 3척: 판마다 fixed 층 + 구역 shading 층마다 rgb = min(255, 고른 색 × shadingGray ÷ neutralMidpoint), 알파 그대로
  materialIds,

  /// theme 3척: rgb = clamp(중립 × 고른 색 ÷ 구역 meanLuminance), 구역 마스크 안에서만
  meanLuminance,
}

/// 고른 배 색 (BoatsOwned.colors, recolorRule.save): `{"hull": {"kind": "swatch", "i": 3}, "upper": {"kind": "custom", "hex": "#C9775A"}}`.
/// 고르지 않은 구역은 키가 없고 그림 원래 색이다. 하나도 없으면 null로 저장한다 (원래 색)
class BoatColors {
  const BoatColors([this.zones = const {}]);

  static const none = BoatColors();

  final Map<BoatZone, BodyColor> zones;

  bool get isEmpty => zones.isEmpty;

  BodyColor? operator [](BoatZone z) => zones[z];

  /// [zone]만 바꾼 새 값 ([color]가 null이면 원래 색으로)
  BoatColors withZone(BoatZone zone, BodyColor? color) {
    final next = {...zones};
    if (color == null) {
      next.remove(zone);
    } else {
      next[zone] = color;
    }
    return BoatColors(next);
  }

  /// 저장 글 (구역 순서 hull·upper·accent). 고른 구역이 없으면 null
  String? encode() => isEmpty
      ? null
      : jsonEncode({
          for (final z in BoatZone.values)
            if (zones[z] case final c?) z.name: c.toJson(),
        });

  /// 저장 글을 읽는다. null·빈 글은 원래 색, 모르는 구역 키는 건너뛴다. 꼴이 틀리면 FormatException
  static BoatColors decode(String? text) {
    if (text == null || text.trim().isEmpty) return none;
    final j = jsonDecode(text);
    if (j is! Map<String, dynamic>) throw FormatException('배 색 저장 꼴이 아니다: $text');
    return BoatColors({
      for (final z in BoatZone.values)
        if (j[z.name] case final Map<String, dynamic> c) z: BodyColor.fromJson(c),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is BoatColors &&
      other.zones.length == zones.length &&
      zones.entries.every((e) => other.zones[e.key] == e.value);

  @override
  int get hashCode => Object.hashAll([for (final z in BoatZone.values) zones[z]]);

  @override
  String toString() => 'BoatColors(${encode()})';
}

/// 배 색 규칙 (boats.json recolorRule): 구역 이름, 값(0 = 무료)
class BoatRecolorRule {
  const BoatRecolorRule({required this.zoneNames, required this.price});

  /// 구역 → 화면 이름 (선체·지붕·좌석·장식 천)
  final Map<BoatZone, String> zoneNames;
  final int price;

  factory BoatRecolorRule.fromJson(Map<String, dynamic> j) {
    final zones = j['zones'] as Map<String, dynamic>;
    return BoatRecolorRule(
      zoneNames: {for (final z in BoatZone.values) z: zones[z.name] as String? ?? z.name},
      price: (j['price'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 배 한 척의 색 입히기 자료 (boats.json recolor). 그림 파일 이름은 [dir] 아래 상대 경로
class BoatRecolor {
  const BoatRecolor({
    required this.method,
    required this.zones,
    required this.dir,
    this.defaults = const {},
    this.zoneLabels = const {},
    this.neutralMidpoint = 192,
    this.fixed = const {},
    this.shading = const {},
    this.review,
  });

  final RecolorMethod method;
  final List<BoatZone> zones;

  /// 그림 폴더 (boats.json assetDir 아래, 끝에 /)
  final String dir;

  /// 구역 대표색 (불투명 ARGB, theme만). 색 시트의 ‘기본’ 견본 점에 쓴다
  final Map<BoatZone, int> defaults;

  /// 구역 설명 (premium, 읽어 주는 글)
  final Map<BoatZone, String> zoneLabels;

  /// shading 회색의 중간값 (premium 192)
  final double neutralMidpoint;

  /// materialIds: 판마다 고정 층, 판·구역마다 shading 층 (파일 이름)
  final Map<BoatSide, String> fixed;
  final Map<BoatSide, Map<BoatZone, String>> shading;

  /// 미술 승인 전 검토본 등 메모
  final String? review;

  /// meanLuminance 판의 중립 그림 (가안 이름, boats.json에 아직 이름이 없다: ‘이름은 리포에 넣을 때 확정’).
  /// 판마다 `<판>_neutral.png`가 있으면 그것, 없으면 판 공통 `neutral.png`
  List<String> neutralFiles(BoatSide side) => ['${side.name}_neutral.png', 'neutral.png'];

  /// meanLuminance 판의 구역 마스크 (가안 이름): `<판>_<구역>_mask.png`, 없으면 판 공통 `<구역>_mask.png`
  List<String> maskFiles(BoatSide side, BoatZone zone) =>
      ['${side.name}_${zone.name}_mask.png', '${zone.name}_mask.png'];

  /// [codexId]는 boats.json codexId (theme_01 …). theme 판은 dir이 없어 `recolor/<codexId>/`로 둔다 (가안)
  factory BoatRecolor.fromJson(Map<String, dynamic> j, {required String codexId}) {
    BoatZone zone(Object? name) => BoatZone.values.firstWhere((z) => z.name == name,
        orElse: () => throw FormatException('배 색 구역을 모른다: $name ($codexId)'));
    final method = switch (j['method']) {
      'materialIds' => RecolorMethod.materialIds,
      'meanLuminance' => RecolorMethod.meanLuminance,
      final m => throw FormatException('배 색 방식을 모른다: $m ($codexId)'),
    };
    final zones = [for (final z in j['zones'] as List) zone(z)];
    final defaults = j['defaults'] as Map<String, dynamic>?;
    final labels = j['zoneLabels'] as Map<String, dynamic>?;
    final files = j['files'];
    var fixed = const <BoatSide, String>{};
    var shading = const <BoatSide, Map<BoatZone, String>>{};
    if (method == RecolorMethod.materialIds) {
      if (files is! Map<String, dynamic>) {
        throw FormatException('materialIds 배는 files 표가 있어야 한다 ($codexId)');
      }
      final f = files['fixed'] as Map<String, dynamic>;
      final s = files['shading'] as Map<String, dynamic>;
      fixed = {for (final side in BoatSide.values) side: f[side.name] as String};
      shading = {
        for (final side in BoatSide.values)
          side: {
            for (final e in (s[side.name] as Map<String, dynamic>).entries) zone(e.key): e.value as String,
          },
      };
      for (final side in BoatSide.values) {
        if (!zones.every(shading[side]!.containsKey)) {
          throw FormatException('materialIds 배의 ${side.name} shading 층이 구역마다 있어야 한다 ($codexId)');
        }
      }
    }
    var dir = j['dir'] as String? ?? 'recolor/$codexId/';
    if (!dir.endsWith('/')) dir = '$dir/';
    return BoatRecolor(
      method: method,
      zones: zones,
      dir: dir,
      defaults: {
        if (defaults != null)
          for (final e in defaults.entries) zone(e.key): _argb(e.value as String, codexId),
      },
      zoneLabels: {
        if (labels != null)
          for (final e in labels.entries) zone(e.key): e.value as String,
      },
      neutralMidpoint: (j['neutralMidpoint'] as num?)?.toDouble() ?? 192,
      fixed: fixed,
      shading: shading,
      review: j['review'] as String?,
    );
  }
}

int _argb(String hex, String where) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (m == null) throw FormatException('배 색 대표색이 #RRGGBB가 아니다: $hex ($where)');
  return 0xFF000000 | int.parse(m.group(1)!, radix: 16);
}

/// 프리멀티플라이 회색 (Rec.709 밝기, 0~255)
double _luma(Uint8List p, int i) => p[i] * .2126 + p[i + 1] * .7152 + p[i + 2] * .0722;

int _byte(double v) => v <= 0 ? 0 : (v >= 255 ? 255 : v.round());

/// premium 판 하나 (materialIds): 구역마다 shading 층을 고른 색으로 칠해(rgb = min(255, 색 × 회색 ÷ [midpoint]),
/// 알파는 shading 그대로) 차례로 겹치고 맨 위에 고정 층(나무·금속·창틀·외곽선)을 얹는다.
/// 고르지 않은 구역은 그 자리의 원래 그림([clean]) 색을 shading 알파로 쓴다 (평균색을 쓰지 않는다).
/// [colors]는 고른 구역의 색(불투명 ARGB)만. 모두 같은 크기의 프리멀티플라이 RGBA
Uint8List recolorByShading({
  required Uint8List clean,
  required Uint8List fixed,
  required Map<BoatZone, Uint8List> shading,
  required Map<BoatZone, int> colors,
  required double midpoint,
  List<BoatZone> order = BoatZone.values,
}) {
  final n = clean.length;
  for (final s in [fixed, ...shading.values]) {
    if (s.length != n) throw ArgumentError('배 색 층의 크기가 다르다');
  }
  final out = Uint8List(n);
  final layers = [
    for (final z in order)
      if (shading[z] case final s?) (s, colors[z]),
  ];
  for (var i = 0; i < n; i += 4) {
    var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
    for (final (s, color) in layers) {
      final sa = s[i + 3];
      if (sa == 0) continue;
      double lr, lg, lb;
      if (color != null) {
        // 프리멀티플라이 회색 × 색 ÷ 중간값 = (색 × 회색 ÷ 중간값) × 알파. 255에서 자르면 알파에서 자른다
        final gray = _luma(s, i);
        lr = math.min(sa.toDouble(), ((color >> 16) & 0xFF) * gray / midpoint);
        lg = math.min(sa.toDouble(), ((color >> 8) & 0xFF) * gray / midpoint);
        lb = math.min(sa.toDouble(), (color & 0xFF) * gray / midpoint);
      } else {
        final ca = clean[i + 3];
        if (ca == 0) continue;
        final k = sa / ca;
        lr = math.min(sa.toDouble(), clean[i] * k);
        lg = math.min(sa.toDouble(), clean[i + 1] * k);
        lb = math.min(sa.toDouble(), clean[i + 2] * k);
      }
      final keep = 1 - sa / 255;
      r = lr + r * keep;
      g = lg + g * keep;
      b = lb + b * keep;
      a = sa + a * keep;
    }
    final fa = fixed[i + 3];
    final keep = 1 - fa / 255;
    out[i] = _byte(fixed[i] + r * keep);
    out[i + 1] = _byte(fixed[i + 1] + g * keep);
    out[i + 2] = _byte(fixed[i + 2] + b * keep);
    out[i + 3] = _byte(fa + a * keep);
  }
  return out;
}

/// 마스크 세기 0~1: 프리멀티플라이 밝기 ÷ 255 (흰 마스크면 알파, 불투명 흑백 마스크면 밝기)
double _maskAt(Uint8List mask, int i) => _luma(mask, i) / 255;

/// 구역 [mask] 안 중립 그림의 평균 밝기 (0~255, 마스크 세기로 무게): theme 판의 ‘구역 meanLuminance’.
/// 마스크가 비었으면 null
double? zoneMeanLuminance(Uint8List neutral, Uint8List mask) {
  if (neutral.length != mask.length) throw ArgumentError('중립 그림과 마스크의 크기가 다르다');
  var sum = 0.0, weight = 0.0;
  for (var i = 0; i < neutral.length; i += 4) {
    final a = neutral[i + 3];
    if (a == 0) continue;
    final m = _maskAt(mask, i);
    if (m <= 0) continue;
    // 곧은 밝기 = 프리멀티플라이 밝기 ÷ 알파
    sum += _luma(neutral, i) * 255 / a * m;
    weight += m;
  }
  return weight <= 0 ? null : sum / weight;
}

/// theme 판 하나 (meanLuminance): 원래 그림([clean]) 위에, 고른 구역마다 마스크 세기만큼
/// rgb = clamp(중립 × 고른 색 ÷ 구역 평균 밝기)를 섞는다 (알파는 중립 그림). 고르지 않은 구역은 원래 그림 그대로.
/// [means]는 [zoneMeanLuminance] 값 (없는 구역은 칠하지 않는다)
Uint8List recolorByNeutral({
  required Uint8List clean,
  required Uint8List neutral,
  required Map<BoatZone, Uint8List> masks,
  required Map<BoatZone, int> colors,
  required Map<BoatZone, double> means,
  List<BoatZone> order = BoatZone.values,
}) {
  final n = clean.length;
  for (final s in [neutral, ...masks.values]) {
    if (s.length != n) throw ArgumentError('배 색 층의 크기가 다르다');
  }
  final out = Uint8List.fromList(clean);
  final zones = [
    for (final z in order)
      if ((masks[z], colors[z], means[z]) case (final m?, final c?, final mean?) when mean > 0) (m, c, mean),
  ];
  if (zones.isEmpty) return out;
  for (var i = 0; i < n; i += 4) {
    final na = neutral[i + 3];
    if (na == 0) continue;
    for (final (mask, color, mean) in zones) {
      final m = _maskAt(mask, i);
      if (m <= 0) continue;
      final rr = math.min(na.toDouble(), neutral[i] * ((color >> 16) & 0xFF) / mean);
      final rg = math.min(na.toDouble(), neutral[i + 1] * ((color >> 8) & 0xFF) / mean);
      final rb = math.min(na.toDouble(), neutral[i + 2] * (color & 0xFF) / mean);
      out[i] = _byte(out[i] + (rr - out[i]) * m);
      out[i + 1] = _byte(out[i + 1] + (rg - out[i + 1]) * m);
      out[i + 2] = _byte(out[i + 2] + (rb - out[i + 2]) * m);
      out[i + 3] = _byte(out[i + 3] + (na - out[i + 3]) * m);
    }
  }
  return out;
}

/// 마스크·인덱스 그림을 보간 없이 줄이거나 늘린다 (가장 가까운 픽셀, recolorRule: 인덱스·마스크 PNG는 보간하지 않는다)
Uint8List resampleNearest(Uint8List src, int sw, int sh, int dw, int dh) {
  if (src.length != sw * sh * 4) throw ArgumentError('그림 크기가 맞지 않는다');
  if (sw == dw && sh == dh) return src;
  final out = Uint8List(dw * dh * 4);
  for (var y = 0; y < dh; y++) {
    final sy = math.min(sh - 1, ((y + .5) * sh / dh).floor());
    for (var x = 0; x < dw; x++) {
      final sx = math.min(sw - 1, ((x + .5) * sw / dw).floor());
      final s = (sy * sw + sx) * 4;
      final d = (y * dw + x) * 4;
      out[d] = src[s];
      out[d + 1] = src[s + 1];
      out[d + 2] = src[s + 2];
      out[d + 3] = src[s + 3];
    }
  }
  return out;
}

/// 고른 색을 구역 → 불투명 ARGB로 ([argbOf]는 견본 번호·직접 고른 색을 색으로, palette body와 같다)
Map<BoatZone, int> boatZoneArgb(BoatColors colors, int Function(BodyColor) argbOf) => {
      for (final e in colors.zones.entries) e.key: argbOf(e.value),
    };
