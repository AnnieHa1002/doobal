import 'package:flutter/painting.dart';

/// 기준 문서 9장·UI 명세 0장의 색
abstract final class Palette {
  static const paper = Color(0xFFF2E8D5);
  static const card = Color(0xFFFBF6EC);
  static const ink = Color(0xFF3E2C22);
  static const subInk = Color(0xFF6B5444);
  static const terracotta = Color(0xFFA4502F);
  static const moss = Color(0xFF56653A);

  /// 상품 값 글자 (캔버스 --terracotta-deep)
  static const terracottaDeep = Color(0xFF7E3A21);

  /// 옅은 선 (캔버스 --line)
  static const line = Color(0xFFD9C9AE);

  /// 그림 없는 칸의 점선 (캔버스 --line-dashed)
  static const lineDashed = Color(0xFFB8A385);

  /// 오류·경고와 되돌릴 수 없는 버튼(계정 삭제 등). 항상 아이콘·문구와 함께 (11/3)
  static const danger = Color(0xFF8E2A2E);
  static const dangerBg = Color(0xFFF5DCD6);

  /// 럭 보석 하늘색 (11/3, 금색 폐기)
  static const gem = Color(0xFF8EC5DF);

  /// 버튼·패널 아래 옅은 그림자: 잉크 18%, 번짐 없음
  static const shadow = Color(0x2E3E2C22);
}

/// 눌린 버튼의 면: 아래로 내려가지 않고 한 단계 진한 면이 된다 (UI 명세 0장 버튼, 11/3).
/// 정해진 색이 없는 면은 잉크를 15% 섞는다
Color pressedFill(Color fill) => switch (fill) {
      Palette.terracotta => const Color(0xFF7E3A21),
      Palette.moss => const Color(0xFF3F4B29),
      Palette.paper || Palette.card => const Color(0xFFE4D6BC),
      Palette.danger => const Color(0xFF6E1F23),
      _ => Color.lerp(fill, Palette.ink, 0.15)!,
    };

/// UI 선 굵기 (UI 명세 0장, 11/3 깔끔한 선): 버튼·패널·시트·칸 1.8, 알약·토스트 1.4,
/// 입력 칸 포커스 링 잉크 3. 판화 결·흔들린 선은 UI에 쓰지 않는다
abstract final class InkLine {
  static const panel = 1.8;
  static const pill = 1.4;
  static const focus = 3.0;

  /// 아래 옅은 그림자 높이
  static const shadow = 2.0;
}
