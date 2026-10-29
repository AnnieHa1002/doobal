import 'package:flutter/material.dart';

import 'ink_press.dart';
import 'name_tag.dart';
import 'palette.dart';

/// 모서리 둥근 버튼: 프로필·설정 56pt, 출발 72pt. 누르는 자리는 44pt 이상.
/// [tag]가 있으면 아래에 이름표를 붙인다. [label]은 접근성·툴팁용
class CornerButton extends StatelessWidget {
  const CornerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 56,
    this.primary = false,
    this.tag,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;
  final bool primary;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkPress(
            onPressed: onPressed,
            fill: primary ? Palette.terracotta : Palette.card,
            height: size,
            width: size,
            circle: true,
            child: Icon(icon, size: size * 0.5, color: primary ? Palette.paper : Palette.ink),
          ),
          if (tag != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: NameTag(tag!),
            ),
        ],
      ),
    );
  }
}
