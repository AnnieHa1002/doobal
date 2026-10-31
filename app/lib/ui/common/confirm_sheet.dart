import 'package:flutter/material.dart';

import 'game_button.dart';
import 'palette.dart';

/// 아래에서 올라오는 카드색 시트 (뒤는 잉크 40%). 위 버튼은 true, 아래 버튼은 false를 돌려주고,
/// 시트 밖을 눌러 닫으면 null이다
Future<bool?> showConfirmSheet(BuildContext context, String text, String yes, String no) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Palette.card,
    barrierColor: Palette.ink.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      side: BorderSide(color: Palette.ink, width: 2.5),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Palette.ink),
            ),
            const SizedBox(height: 20),
            GameButton(label: yes, onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 8),
            GameButton(
              label: no,
              kind: GameButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}
