import 'package:flutter/material.dart';

import 'palette.dart';

/// 앱 글꼴 (11/12 Noto Sans KR 하나, 이전 Pretendard): 제목·숫자·버튼·딱지·이름표·본문 모두. 굵기는 400·600·700
const bodyFont = 'Noto Sans KR';

/// 동그라미 안 첫 글자처럼 칸 크기가 정해져 글자를 따라 커질 수 없는 곳의 글자 배율 상한.
/// 휴대폰 글자 크기를 키워도 이런 자리의 글자만 1.3배에서 멈춘다 (그 밖의 글자에는 상한이 없다)
const badgeMaxTextScale = 1.3;

/// 굵은 글자: 제목·숫자·버튼·딱지·이름표
extension DisplayText on BuildContext {
  /// [size]는 명세 pt. 굵기 기본은 700, 버튼은 600
  TextStyle display(double size, {Color color = Palette.ink, FontWeight weight = FontWeight.w700}) =>
      displayStyle(size, color: color, weight: weight);
}

/// 굵은 글자 (BuildContext 없이 고를 때)
TextStyle displayStyle(
  double size, {
  Color color = Palette.ink,
  FontWeight weight = FontWeight.w700,
}) =>
    TextStyle(fontFamily: bodyFont, fontSize: size, fontWeight: weight, color: color);

/// UI 명세 0장의 글자 크기: 화면 제목 22, 카드 제목 18, 큰 숫자 40 (표시 글꼴), 본문 15, 라벨 12
abstract final class AppText {
  static TextStyle title(BuildContext context) => context.display(22);
  static TextStyle cardTitle(BuildContext context) => context.display(18);
  static TextStyle bigNumber(BuildContext context) => context.display(40);
  static const body = TextStyle(fontSize: 15, color: Palette.ink);
  static const bodySub = TextStyle(fontSize: 15, color: Palette.subInk);
  static const label = TextStyle(fontSize: 12, color: Palette.subInk);
}
