import 'map_projection.dart';

/// 지도 캔버스 위의 사각형 (px)
class MapRect {
  const MapRect(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  MapPoint get center => MapPoint((left + right) / 2, (top + bottom) / 2);

  bool contains(MapPoint p) => p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;
}

/// ui_map_regions_v01.svg의 경계 하나 (17 시도 + 울릉도).
/// 구멍·섬이 있어서 고리가 여러 개이고, 색칠은 even-odd 규칙이다
class MapRegion {
  const MapRegion({
    required this.id,
    required this.region,
    required this.name,
    required this.fill,
    required this.rings,
  });

  /// busan, seoul … (SVG path id)
  final String id;

  /// 권역 7: capital·gangwon·chungcheong·jeolla·gyeongsang·jeju·ulleung
  final String region;

  /// 부산광역시 …
  final String name;

  /// 불투명 ARGB
  final int fill;
  final List<List<MapPoint>> rings;
}

/// 경계들을 모두 담는 가장 작은 사각형. 비어 있으면 StateError
MapRect boundsOf(Iterable<MapRegion> regions) {
  double? left, top, right, bottom;
  for (final r in regions) {
    for (final ring in r.rings) {
      for (final p in ring) {
        left = left == null || p.x < left ? p.x : left;
        top = top == null || p.y < top ? p.y : top;
        right = right == null || p.x > right ? p.x : right;
        bottom = bottom == null || p.y > bottom ? p.y : bottom;
      }
    }
  }
  if (left == null || top == null || right == null || bottom == null) {
    throw StateError('점이 하나도 없어요');
  }
  return MapRect(left, top, right, bottom);
}

final _pathTag = RegExp(r'<path\b([^>]*?)/?>');
final _attr = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');
final _pathToken = RegExp(r'[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');
final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

/// SVG 텍스트의 `<path …/>`를 모두 읽는다. 속성은 id·data-region·data-name·fill·d가 모두 있어야 한다.
/// d는 절대 좌표 M·L·Z만 쓴다 (좌표는 쉼표나 공백으로 구분, M 뒤의 좌표 쌍은 L로 이어진다).
/// 그 밖의 명령이나 형식이 다르면 FormatException
List<MapRegion> parseMapRegions(String svg) {
  return [
    for (final m in _pathTag.allMatches(svg))
      _region({for (final a in _attr.allMatches(m.group(1)!)) a.group(1)!: a.group(2)!}),
  ];
}

MapRegion _region(Map<String, String> attrs) {
  String need(String key) =>
      attrs[key] ?? (throw FormatException('path에 $key가 없어요: ${attrs['id']}'));
  final fill = need('fill');
  if (!_hex.hasMatch(fill)) throw FormatException('색 형식이 달라요: $fill');
  return MapRegion(
    id: need('id'),
    region: need('data-region'),
    name: need('data-name'),
    fill: 0xFF000000 | int.parse(fill.substring(1), radix: 16),
    rings: _parseRings(need('d')),
  );
}

List<List<MapPoint>> _parseRings(String d) {
  final rings = <List<MapPoint>>[];
  List<MapPoint>? ring;
  final nums = <double>[];

  void closeRing() {
    if (ring != null && ring!.isNotEmpty) rings.add(ring!);
    ring = null;
  }

  // 모인 숫자를 좌표 쌍으로 바꿔 현재 고리에 더한다 (M 뒤의 쌍도 L처럼 이어진다)
  void flushNums(String cmd) {
    if (cmd != 'M' && cmd != 'L') return;
    if (nums.isEmpty || nums.length.isOdd) throw FormatException('좌표가 짝이 맞지 않아요: $cmd');
    final r = ring ?? (throw const FormatException('M 없이 L이 나왔어요'));
    for (var i = 0; i < nums.length; i += 2) {
      r.add(MapPoint(nums[i], nums[i + 1]));
    }
    nums.clear();
  }

  var cmd = '';
  for (final t in _pathToken.allMatches(d)) {
    final s = t.group(0)!;
    final c = s.codeUnitAt(0);
    final isLetter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
    if (!isLetter) {
      if (cmd != 'M' && cmd != 'L') throw FormatException('명령 없이 좌표가 나왔어요: $s');
      nums.add(double.parse(s));
      continue;
    }
    if (s != 'M' && s != 'L' && s != 'Z') throw FormatException('지원하지 않는 명령: $s');
    flushNums(cmd);
    if (s == 'M') {
      closeRing();
      ring = [];
    } else if (s == 'Z') {
      closeRing();
    }
    cmd = s;
  }
  flushNums(cmd);
  closeRing();
  return rings;
}
