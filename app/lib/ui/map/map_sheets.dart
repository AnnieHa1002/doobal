import 'package:flutter/material.dart';

import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';

/// 아래에서 올라오는 카드색 시트 (뒤는 잉크 40%). 위 버튼은 true, 아래 버튼은 false를 돌려주고,
/// 시트 밖을 눌러 닫으면 null이다
Future<bool?> _showSheet(BuildContext context, String text, String yes, String no) {
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

/// 목적지 바꾸기 확인. 바꾸기 = true, 취소 = false
Future<bool?> showChangeSheet(BuildContext context) =>
    _showSheet(context, '지금 자리에서 다시 출발해요. 액자 거리는 새로 세요.', '바꾸기', '취소');

/// 여행 경비 쓰기 묻기. 더하기 = true, 아껴 두기 = false
Future<bool?> showFundSheet(BuildContext context, double fundKm) => _showSheet(
      context,
      '경비 ${formatKm(fundKm)}를 더할까요? (경비로 가는 구간에는 이벤트가 없어요)',
      '더하기',
      '아껴 두기',
    );
