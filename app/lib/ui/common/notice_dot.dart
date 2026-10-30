import 'package:flutter/material.dart';

import 'palette.dart';

/// 알림 점: 지름 10 테라코타 원에 잉크 1.5 테두리 (UI 명세 2장).
/// 쓰는 쪽이 오른쪽 위 모서리에 걸치게 Positioned로 놓는다
class NoticeDot extends StatelessWidget {
  const NoticeDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Palette.terracotta,
        shape: BoxShape.circle,
        border: Border.all(color: Palette.ink, width: 1.5),
      ),
    );
  }
}
