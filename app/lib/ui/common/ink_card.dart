import 'package:flutter/material.dart';

import 'palette.dart';

/// 카드색 바탕 + 잉크 2.5 테두리 카드 (UI 명세 공통). 가로는 부모를 꽉 채운다
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
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: child,
    );
  }
}
