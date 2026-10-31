import 'dart:math' as math;

/// 두 불투명 ARGB 색 사이를 채널별로 섞는다 (t 0 → a, 1 → b). 반올림하고 결과는 불투명
int lerpArgb(int a, int b, double t) {
  int channel(int shift) {
    final x = (a >> shift) & 0xFF;
    final y = (b >> shift) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

  return 0xFF000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
}

/// "#RRGGBB" → 불투명 ARGB. 모양은 부르는 쪽이 이미 검사한 값이어야 한다
int argbFromHex(String hex) => 0xFF000000 | int.parse(hex.substring(1), radix: 16);

/// 불투명 ARGB → "#RRGGBB" (대문자). 알파는 버린다
String hexFromArgb(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// HSL 색: 색조 h 0~360, 채도 s·밝기 l 0~1
typedef Hsl = ({double h, double s, double l});

/// 불투명 ARGB의 HSL. 무채색이면 색조·채도는 0
Hsl hslOfArgb(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255;
  final g = ((argb >> 8) & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  final hi = math.max(r, math.max(g, b));
  final lo = math.min(r, math.min(g, b));
  final l = (hi + lo) / 2;
  final d = hi - lo;
  if (d == 0) return (h: 0, s: 0, l: l);
  final s = d / (1 - (2 * l - 1).abs());
  final sector = hi == r
      ? ((g - b) / d) % 6
      : hi == g
          ? (b - r) / d + 2
          : (r - g) / d + 4;
  return (h: sector * 60, s: s, l: l);
}

/// HSL → 불투명 ARGB (채널은 반올림). 색조는 360으로 돌려서 쓴다
int argbOfHsl(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final sector = (h % 360) / 60;
  final x = c * (1 - (sector % 2 - 1).abs());
  final (r, g, b) = switch (sector.floor()) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  final m = l - c / 2;
  int channel(double v) => ((v + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | channel(r) << 16 | channel(g) << 8 | channel(b);
}
