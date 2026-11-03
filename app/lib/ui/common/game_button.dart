import 'package:flutter/material.dart';

import 'app_text.dart';
import 'ink_press.dart';
import 'palette.dart';

/// primary = 테라코타 주 버튼, secondary = 카드색 보조 버튼,
/// danger = 되돌릴 수 없는 일(계정 삭제·기록 지우기)의 붉은 오류색 버튼 (11/3)
enum GameButtonKind { primary, secondary, danger }

/// 비활성일 때 버튼의 불투명도
const _disabledOpacity = 0.4;

/// 높이 52pt·모서리 12pt 큰 버튼 (UI 명세 공통).
/// primary = 테라코타 바탕 + 종이색 글자, secondary = 카드색 바탕 + 잉크 글자,
/// danger = 오류색 바탕 + 카드색 글자.
/// 글자 크기를 키워 라벨이 줄바꿈되면 52pt가 최소 높이라 버튼이 같이 커진다.
/// [onPressed]가 null이면 흐리게 보이고 눌리지 않는다
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = GameButtonKind.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final GameButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final (fill, text) = switch (kind) {
      GameButtonKind.primary => (Palette.terracotta, Palette.paper),
      GameButtonKind.secondary => (Palette.card, Palette.ink),
      GameButtonKind.danger => (Palette.danger, Palette.card),
    };
    return Opacity(
      opacity: onPressed == null ? _disabledOpacity : 1,
      child: InkPress(
        onPressed: onPressed,
        fill: fill,
        height: 52,
        child: Padding(
          // 줄바꿈된 글자가 테두리에 붙지 않게 (한 줄일 때는 보이지 않는다)
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.display(18, color: text),
          ),
        ),
      ),
    );
  }
}
