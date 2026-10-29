import 'package:flutter/material.dart';

import 'ink_press.dart';
import 'palette.dart';

enum GameButtonKind { primary, secondary }

/// 높이 52pt·모서리 12pt 큰 버튼 (UI 명세 공통).
/// primary = 테라코타 바탕 + 종이색 글자, secondary = 카드색 바탕 + 잉크 글자
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = GameButtonKind.primary,
  });

  final String label;
  final VoidCallback onPressed;
  final GameButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final primary = kind == GameButtonKind.primary;
    return InkPress(
      onPressed: onPressed,
      fill: primary ? Palette.terracotta : Palette.card,
      height: 52,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: primary ? Palette.paper : Palette.ink,
        ),
      ),
    );
  }
}
