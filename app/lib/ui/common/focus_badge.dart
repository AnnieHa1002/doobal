import 'package:flutter/material.dart';

import 'app_text.dart';
import 'palette.dart';

/// 본격 걷기 딱지: 이끼색 바탕에 종이색 표시 글꼴 12. 걸음 알약의 `×1.3`과
/// 걷기 기록의 럭 `×2`가 같은 모양이다. 딱지는 칸이 정해진 표식이라 글자 배율은
/// badgeMaxTextScale(1.3)에서 멈춘다
class FocusBadge extends StatelessWidget {
  const FocusBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '본격 걷기 $text',
      excludeSemantics: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: badgeMaxTextScale,
        child: Container(
          key: const Key('focus-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Palette.moss,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            maxLines: 1,
            style: context.display(12, color: Palette.paper),
          ),
        ),
      ),
    );
  }
}
