import 'package:flutter/material.dart';

import 'palette.dart';

/// 공용 잉크 테두리. 가운데 기호는 배지 화면에서 전달한다.
class StampFace extends StatelessWidget {
  const StampFace({
    super.key,
    required this.child,
    this.color = Palette.terracotta,
  });
  final Widget child;
  final Color color;
  static const asset = 'assets/ui/ui_stamp_frame_v02_clean.png';
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          color: color,
          colorBlendMode: BlendMode.srcIn,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
        Center(
          child: FractionallySizedBox(
            widthFactor: .5,
            heightFactor: .5,
            child: child,
          ),
        ),
      ],
    ),
  );
}
