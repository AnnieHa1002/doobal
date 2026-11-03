import 'package:flutter/material.dart';

import '../../domain/display_font.dart';
import 'palette.dart';

/// 본문 글꼴: 본문·라벨. 앱 테마의 기본 글꼴이다. 굵게 쓰지 않는다 (굵은 글자는 표시 글꼴로)
const bodyFont = 'GowunDodum';

/// 동그라미 안 첫 글자처럼 칸 크기가 정해져 글자를 따라 커질 수 없는 곳의 글자 배율 상한.
/// 휴대폰 글자 크기를 키워도 이런 자리의 글자만 1.3배에서 멈춘다 (그 밖의 글자에는 상한이 없다)
const badgeMaxTextScale = 1.3;

/// 지금 고른 표시 글꼴. 앱 테마(ThemeData.extensions)로 내려보내서, 설정에서 바꾸면 테마를 쓰는
/// 화면이 모두 다시 그려진다
class DisplayType extends ThemeExtension<DisplayType> {
  const DisplayType(this.font);

  final DisplayFont font;

  @override
  DisplayType copyWith({DisplayFont? font}) => DisplayType(font ?? this.font);

  @override
  DisplayType lerp(DisplayType? other, double t) => t < 0.5 || other == null ? this : other;
}

/// 표시 글꼴로 쓰는 글자 모양
extension DisplayText on BuildContext {
  /// 앱 테마의 표시 글꼴. 테마가 없는 곳(낱개 위젯 테스트)은 배율 1.0인 고운 바탕
  DisplayFont get displayFont =>
      Theme.of(this).extension<DisplayType>()?.font ?? DisplayFont.batang;

  /// 표시 글꼴 굵은 글자. [size]는 명세 pt(고운 바탕 기준)이고 글꼴 배율이 곱해진다
  TextStyle display(double size, {Color color = Palette.ink}) =>
      displayStyle(displayFont, size, color: color);
}

/// [font]로 쓴 표시 글꼴 굵은 글자 (BuildContext 없이 고를 때)
TextStyle displayStyle(DisplayFont font, double size, {Color color = Palette.ink}) => TextStyle(
      fontFamily: font.family,
      fontSize: size * font.scale,
      fontWeight: FontWeight.w700,
      height: font.height,
      color: color,
    );

/// UI 명세 0장의 글자 크기: 화면 제목 22, 카드 제목 18, 큰 숫자 40 (표시 글꼴), 본문 15, 라벨 12
abstract final class AppText {
  static TextStyle title(BuildContext context) => context.display(22);
  static TextStyle cardTitle(BuildContext context) => context.display(18);
  static TextStyle bigNumber(BuildContext context) => context.display(40);
  static const body = TextStyle(fontSize: 15, color: Palette.ink);
  static const bodySub = TextStyle(fontSize: 15, color: Palette.subInk);
  static const label = TextStyle(fontSize: 12, color: Palette.subInk);
}
