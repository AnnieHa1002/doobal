import 'package:flutter/material.dart';

import '../../domain/journey.dart' show Frame;
import '../../domain/landmark.dart';
import 'frame_style.dart';
import 'palette.dart';

const _outerLine = 2.0;
const _innerLine = 1.5;

/// 액자 한 겹이 차지하는 두께: 바깥 잉크선 + 액자 띠 + 안쪽 잉크선
double frameInset(double thickness) => _outerLine + thickness + _innerLine;

/// 액자 테두리만 (안은 비어 있다). 부모를 꽉 채운다. [color]는 액자 띠, [lineColor]는 잉크선
class FrameBorder extends StatelessWidget {
  const FrameBorder({
    super.key,
    required this.color,
    this.lineColor = Palette.ink,
    this.thickness = 6,
  });

  final Color color;
  final Color lineColor;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: lineColor, width: _outerLine),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: color, width: thickness)),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: lineColor, width: _innerLine)),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// 그림 자리 표시: 후경 지역 색으로 칠한 종이. [label]이 있으면 아래에 이름을 붙인다.
/// 부모를 꽉 채운다
class PaintingFace extends StatelessWidget {
  const PaintingFace({super.key, required this.landmark, this.label});

  final Landmark landmark;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tint = paintingTint(landmark);
    return LayoutBuilder(builder: (context, box) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(Palette.paper, tint, 0.25)!,
              Color.lerp(Palette.paper, tint, 0.85)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.landscape_outlined,
                size: (box.biggest.shortestSide * 0.4).clamp(16.0, 64.0),
                color: Palette.card.withValues(alpha: 0.7),
              ),
            ),
            if (label != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Palette.card.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// 첫 그림 '첫 여행 짐 꾸러미'의 에셋 이름 (Drive Assets 03_Paintings, 1536×1152).
/// 그림이 나오면 [FirstPackFace]를 Image.asset으로 바꾼다 (pubspec에 등록하고 이 이름으로 부른다)
const firstPackAsset = 'painting_first_pack_v01';

/// 첫 그림 자리 표시: 종이색 바탕에 짐 꾸러미 아이콘. 부모를 꽉 채운다.
/// 같은 그림을 늘 보여 주니 명소처럼 지역 색을 입히지 않는다
class FirstPackFace extends StatelessWidget {
  const FirstPackFace({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return ColoredBox(
        color: Palette.paper,
        child: Center(
          child: Icon(
            Icons.backpack_outlined,
            size: (box.biggest.shortestSide * 0.5).clamp(16.0, 96.0),
            color: Palette.subInk,
          ),
        ),
      );
    });
  }
}

/// 액자에 낀 그림 자리 표시. 부모가 정한 크기를 꽉 채운다.
/// [frame]의 색 액자, [FramedPainting.empty]는 얻지 못한 그림의 빈 액자(밝은 색, 잉크선은 흐리게),
/// [FramedPainting.firstPack]은 첫 그림(짐 꾸러미)을 나무 액자에 낀 것
class FramedPainting extends StatelessWidget {
  const FramedPainting({
    super.key,
    required Landmark this.landmark,
    required Frame this.frame,
    this.thickness = 6,
    this.label,
  }) : firstPack = false;

  const FramedPainting.empty({super.key, this.thickness = 6})
      : landmark = null,
        frame = null,
        label = null,
        firstPack = false;

  /// 첫 그림은 등급이 없어서 늘 나무 액자다
  const FramedPainting.firstPack({super.key, this.thickness = 6})
      : landmark = null,
        frame = Frame.wood,
        label = null,
        firstPack = true;

  final Landmark? landmark;
  final Frame? frame;
  final double thickness;
  final String? label;
  final bool firstPack;

  @override
  Widget build(BuildContext context) {
    final l = landmark;
    final f = frame;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.all(frameInset(thickness)),
          child: firstPack
              ? const FirstPackFace()
              : l == null
                  ? const ColoredBox(color: Palette.paper)
                  : PaintingFace(landmark: l, label: label),
        ),
        FrameBorder(
          color: f == null ? Palette.card : frameColors[f]!,
          lineColor: f == null ? Palette.subInk : Palette.ink,
          thickness: thickness,
        ),
      ],
    );
  }
}
