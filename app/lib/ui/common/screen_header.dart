import 'package:flutter/material.dart';

import 'app_text.dart';
import 'corner_button.dart';

/// 화면 맨 위: 뒤로 버튼(44pt) + 화면 제목 (화집과 같은 모양)
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          CornerButton(
            icon: Icons.arrow_back,
            label: '뒤로',
            size: 44,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Text(title, style: AppText.title),
        ],
      ),
    );
  }
}
