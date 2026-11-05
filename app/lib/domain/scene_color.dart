import 'rules.dart';

// 장면 그림의 색 보정. 모두 ColorFilter.matrix 값(4×5, 마지막 칸은 0~255)이고,
// 순서(풀 계절색 → 계절 보정 → 시간대 보정)대로 곱해 한 번에 입힌다 (명세 M2 배경 엔진)

const _lumaR = 0.2126;
const _lumaG = 0.7152;
const _lumaB = 0.0722;

/// 채널별 곱하기
List<double> diagonalMatrix(double r, double g, double b) => [
      r, 0, 0, 0, 0,
      0, g, 0, 0, 0,
      0, 0, b, 0, 0,
      0, 0, 0, 1, 0,
    ];

/// 곱하기 색 [argb]를 세기 [strength]로: 출력 = c × (1 − s + s × t)
List<double> multiplyMatrix(int argb, double strength) {
  double k(int shift) => 1 - strength + strength * ((argb >> shift) & 0xFF) / 255;
  return diagonalMatrix(k(16), k(8), k(0));
}

/// 곱할 색 그대로 (시간대 보정의 계산된 색)
List<double> factorMatrix(int argb) =>
    diagonalMatrix(((argb >> 16) & 0xFF) / 255, ((argb >> 8) & 0xFF) / 255, (argb & 0xFF) / 255);

/// 채도를 [delta]만큼 (−0.45 = 45% 빼기). 밝기(휘도)는 그대로
List<double> saturationMatrix(double delta) {
  final s = 1 + delta;
  final r = (1 - s) * _lumaR, g = (1 - s) * _lumaG, b = (1 - s) * _lumaB;
  return [
    r + s, g, b, 0, 0,
    r, g + s, b, 0, 0,
    r, g, b + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// 밝기를 [delta]만큼 (0.12 = 12% 더)
List<double> brightnessMatrix(double delta) => diagonalMatrix(1 + delta, 1 + delta, 1 + delta);

/// 안개: 색 [argb]를 [amount]만큼 얹는다. 투명한 곳은 그대로
List<double> hazeMatrix(int argb, double amount) {
  final keep = 1 - amount;
  return [
    keep, 0, 0, 0, amount * ((argb >> 16) & 0xFF),
    0, keep, 0, 0, amount * ((argb >> 8) & 0xFF),
    0, 0, keep, 0, amount * (argb & 0xFF),
    0, 0, 0, 1, 0,
  ];
}

/// [inner]를 먼저 입히고 [outer]를 입히는 한 행렬
List<double> chainMatrix(List<double> outer, List<double> inner) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = col == 4 ? outer[row * 5 + 4] : 0.0;
      for (var i = 0; i < 4; i++) {
        v += outer[row * 5 + i] * inner[i * 5 + col];
      }
      out[row * 5 + col] = v;
    }
  }
  return out;
}

/// 입히는 순서대로 곱한다. null은 건너뛰고, 다 null이면 null (입힐 것 없음)
List<double>? chainAll(Iterable<List<double>?> inOrder) {
  List<double>? out;
  for (final m in inOrder) {
    if (m == null) continue;
    out = out == null ? m : chainMatrix(m, out);
  }
  return out;
}

/// 이 레이어의 계절 보정 (config scene.seasonTint). 해당 없으면 null
List<double>? seasonTintMatrix(SeasonTint? tint, SceneLayerId layer) {
  if (tint == null || !tint.layers.contains(layer)) return null;
  return chainAll([
    if (tint.saturation != 0) saturationMatrix(tint.saturation),
    if (tint.brightness != 0) brightnessMatrix(tint.brightness),
    multiplyMatrix(tint.multiply, tint.strength),
  ]);
}
