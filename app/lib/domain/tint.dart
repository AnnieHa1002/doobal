// 그림에 색 입히기 (palette.json formula). 정령 몸 색과 회색조 소품(베레모) 색에 쓴다

/// 휘도 L = 0.299R + 0.587G + 0.114B 의 계수 (합이 1이라 회색 g는 L = g)
const _lumaR = 0.299;
const _lumaG = 0.587;
const _lumaB = 0.114;

/// 회색조 그림에 [swatchArgb]를 입히는 `ColorFilter.matrix` 값 20개 (4×5, 한 줄에 R G B A 계수와 더하는 값).
/// 출력 RGB = 견본 RGB × L ÷ [base], 알파는 그대로. 기준 밝기([base])의 회색은 견본색 그대로 나온다
/// (소품마다 palette.json tintProps의 base). 밝은 쪽은 255에서 잘린다
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

/// 정령 그림 전체에 몸 색을 입히는 `ColorFilter.matrix` 값 20개: 채널별 곱하기
/// (출력 R = R × 견본 R ÷ 기준색 R, G·B도 같게, 알파는 그대로). 기준색([baseArgb])의 픽셀은 견본색 그대로 나온다
/// (지금 Rive 몸통은 평면색 #FFF5E2, 회색조 그림이 오면 회색). 기준색보다 밝은 쪽은 255에서 잘린다.
/// 임시 방법이다: 얼굴·소품에도 같이 입혀진다 (Rive에 몸 색 입력이 생기면 바꾼다)
List<double> bodyTintMatrix(int swatchArgb, int baseArgb) {
  double k(int shift) {
    final base = (baseArgb >> shift) & 0xFF;
    assert(base > 0, '기준색의 채널은 0보다 커야 한다');
    return ((swatchArgb >> shift) & 0xFF) / base;
  }

  return [
    k(16), 0, 0, 0, 0,
    0, k(8), 0, 0, 0,
    0, 0, k(0), 0, 0,
    0, 0, 0, 1, 0,
  ];
}
