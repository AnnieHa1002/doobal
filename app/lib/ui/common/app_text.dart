import 'package:flutter/painting.dart';

import 'palette.dart';

/// UI 명세 0장의 글자 크기: 화면 제목 22, 카드 제목 18, 큰 숫자 40, 본문 15, 라벨 12
abstract final class AppText {
  static const title = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ink);
  static const cardTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink);
  static const bigNumber = TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Palette.ink);
  static const body = TextStyle(fontSize: 15, color: Palette.ink);
  static const bodySub = TextStyle(fontSize: 15, color: Palette.subInk);
  static const label = TextStyle(fontSize: 12, color: Palette.subInk);
}
