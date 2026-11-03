import 'package:flutter/material.dart';

import 'palette.dart';

/// 카드색 바탕 + 잉크 1.8 선 + 아래 2pt 옅은 그림자 카드 (UI 명세 0장 카드·시트). 가로는 부모를 꽉 채운다
class InkCard extends StatelessWidget {
  const InkCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
        boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
      ),
      child: child,
    );
  }
}
