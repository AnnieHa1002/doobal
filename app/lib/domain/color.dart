/// 두 불투명 ARGB 색 사이를 채널별로 섞는다 (t 0 → a, 1 → b). 반올림하고 결과는 불투명
int lerpArgb(int a, int b, double t) {
  int channel(int shift) {
    final x = (a >> shift) & 0xFF;
    final y = (b >> shift) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

  return 0xFF000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
}
