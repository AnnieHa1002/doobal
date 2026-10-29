/// 레이어 스크롤 위치(px) = 거리(m) × 배율 × px/m 를 이미지 가로로 나눈 나머지. 항상 0 이상
double layerOffsetPx(double distanceM, double speed, double pxPerM, double widthPx) {
  final r = distanceM * speed * pxPerM % widthPx;
  // 아주 작은 음수가 나머지 연산에서 widthPx로 올림되는 경우를 막는다
  return r < widthPx ? r : 0.0;
}

/// 화면 [leftPx, leftPx + viewportPx)와 겹치는 조각 번호(왼쪽부터). 조각 끝을 넘으면 처음으로 이어진다.
/// 1170px 화면은 1024px 조각 3장에 걸칠 수 있다.
/// leftPx는 음수도 된다. 레이어는 layerOffsetPx를 leftPx로 쓴다
List<int> visibleTiles(
  double leftPx,
  double viewportPx,
  double tileWidthPx,
  int tileCount,
) {
  if (viewportPx <= 0) return const [];
  final first = (leftPx / tileWidthPx).floor();
  final last = ((leftPx + viewportPx) / tileWidthPx).ceil() - 1;
  final n = last - first + 1 < tileCount ? last - first + 1 : tileCount;
  return [for (var i = 0; i < n; i++) (first + i) % tileCount];
}
