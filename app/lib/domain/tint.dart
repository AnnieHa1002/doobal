import 'color.dart';

// 모습에 색 입히기 (M4 명세, palette.json formula).
// 머리카락 앞·뒤와 눈썹은 머리색, 얼굴형·귀·몸 맨살은 피부색을 입힌다. 눈·코·입·옷·소품은 그대로

/// 휘도 L = 0.299R + 0.587G + 0.114B 의 계수 (합이 1이라 회색 g는 L = g)
const _lumaR = 0.299;
const _lumaG = 0.587;
const _lumaB = 0.114;

/// 회색조 그림에 [swatchArgb]를 입히는 `ColorFilter.matrix` 값 20개 (4×5, 한 줄에 R G B A 계수와 더하는 값).
/// 출력 RGB = 견본 RGB × L ÷ [base], 알파는 그대로. 기준 밝기([base])의 회색은 견본색 그대로 나온다
/// (머리 182, 피부 196). 밝은 쪽은 255에서 잘린다
List<double> tintMatrix(int swatchArgb, num base) {
  assert(base > 0, '기준 밝기는 0보다 커야 한다');
  List<double> row(int channel) {
    final k = channel / base;
    return [k * _lumaR, k * _lumaG, k * _lumaB, 0, 0];
  }

  return [
    ...row((swatchArgb >> 16) & 0xFF),
    ...row((swatchArgb >> 8) & 0xFF),
    ...row(swatchArgb & 0xFF),
    0, 0, 0, 1, 0,
  ];
}

/// [matrix]를 [argb] 한 픽셀에 적용한 색 (ColorFilter.matrix가 하는 계산: 채널을 0~255로 자른다).
/// 테스트와 계산 확인용
int applyColorMatrix(List<double> matrix, int argb) {
  final src = [(argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, (argb >> 24) & 0xFF];
  int out(int row) {
    var v = matrix[row * 5 + 4];
    for (var i = 0; i < 4; i++) {
      v += matrix[row * 5 + i] * src[i];
    }
    return v.round().clamp(0, 255);
  }

  return out(3) << 24 | out(0) << 16 | out(1) << 8 | out(2);
}

/// [argb]의 HSL 밝기를 [minPercent]~[maxPercent]%로 자른다 (직접 고르기의 밝기 제한).
/// 색조·채도는 그대로이고, 범위 안이면 같은 색을 돌려준다 (결과는 불투명)
int clampLightness(int argb, {required int minPercent, required int maxPercent}) {
  final c = hslOfArgb(argb);
  final l = c.l.clamp(minPercent / 100, maxPercent / 100);
  if (l == c.l) return 0xFF000000 | (argb & 0xFFFFFF);
  return argbOfHsl(c.h, c.s, l);
}

/// 그러데이션의 세로 stop (머리카락 위 0 → 아래 1): 뿌리색이 [rootUntil]까지, 끝색이 [tipFrom]부터.
/// 끝색 겹 ShaderMask의 알파가 [0, 0, 1, 1]로 변하는 자리이기도 하다
List<double> gradientStops(double rootUntil, double tipFrom) => [0, rootUntil, tipFrom, 1];

/// 세로 위치 [t](0 머리카락 위 ~ 1 아래)에 끝색이 섞인 정도: 0 = 뿌리색, 1 = 끝색.
/// [rootUntil]까지 0, [tipFrom]부터 1, 그 사이는 직선으로 올라간다
double tipMixAt(double t, {required double rootUntil, required double tipFrom}) =>
    ((t - rootUntil) / (tipFrom - rootUntil)).clamp(0.0, 1.0);
