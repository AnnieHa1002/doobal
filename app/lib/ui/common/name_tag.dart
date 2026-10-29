import 'package:flutter/material.dart';

import 'palette.dart';

/// 물건·버튼 아래에 붙는 작은 이름표
class NameTag extends StatelessWidget {
  const NameTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.ink, width: 1.5),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.ink),
      ),
    );
  }
}
