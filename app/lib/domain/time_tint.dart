import 'rules.dart';
import 'sky.dart';

/// 하늘 단계의 색 입히기. 낮은 null (입히지 않는다)
TimeTint? timeTintOf(SkyPhase phase, Rules rules) => rules.timeTint[phase.name];

/// 곱하기 색: 흰색에서 [color] 쪽으로 [strength]만큼 옮긴 색(채널별). 불투명 ARGB.
/// 그림 × 이 색 = 세기 [strength]로 곱한 것
int multiplyFactor(int color, double strength) {
  int channel(int shift) {
    final c = (color >> shift) & 0xFF;
    return (255 + (c - 255) * strength).round().clamp(0, 255);
  }

  return 0xFF000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
}
