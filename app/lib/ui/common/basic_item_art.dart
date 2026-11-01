import 'package:flutter/material.dart';

import 'palette.dart';

/// 그림이 준비된 기본 소품만 사용하고, 나머지는 기존 글자 표시를 유지한다.
class BasicItemIcon extends StatelessWidget {
  const BasicItemIcon({super.key, required this.id, required this.fallback});
  final String id;
  final String fallback;
  static const ids = {
    'hat_01',
    'hand_01',
    'pet_01',
    'bag_01',
    'cloth_01',
    'shoe_01',
  };
  static String? pathFor(String id) => ids.contains(id)
      ? 'assets/items/basic_v02/item_${id}_icon_v02.png'
      : null;
  @override
  Widget build(BuildContext context) {
    final path = pathFor(id);
    return path == null
        ? Text(
            fallback,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Palette.ink,
            ),
          )
        : Image.asset(
            path,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
            cacheWidth: 128,
          );
  }
}

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
