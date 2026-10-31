import 'package:flutter/painting.dart';

import 'palette.dart';

/// 제목 글꼴: 화면 제목·카드 제목·큰 숫자 (UI 명세 0장)
const titleFont = 'GowunBatang';

/// 본문 글꼴: 본문·라벨. 앱 테마의 기본 글꼴이다
const bodyFont = 'GowunDodum';

/// UI 명세 0장의 글자 크기: 화면 제목 22, 카드 제목 18, 큰 숫자 40, 본문 15, 라벨 12
abstract final class AppText {
  static const title = TextStyle(
    fontFamily: titleFont,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: Palette.ink,
  );
  static const cardTitle = TextStyle(
    fontFamily: titleFont,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Palette.ink,
  );
  static const bigNumber = TextStyle(
    fontFamily: titleFont,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: Palette.ink,
  );
  static const body = TextStyle(fontSize: 15, color: Palette.ink);
  static const bodySub = TextStyle(fontSize: 15, color: Palette.subInk);
  static const label = TextStyle(fontSize: 12, color: Palette.subInk);
}
