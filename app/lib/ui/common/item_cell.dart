import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/catalog_providers.dart';
import '../../domain/prop.dart';
import 'app_text.dart';
import 'palette.dart';

// 상점·꾸미기·화집이 같이 쓰는 칸 (디자인 시스템 ItemCard): 선반 위 그림 + 종이 꼬리표.
// 그림 파일이 있으면 그 그림, 없으면 점선 칸 + 이름 (16장 11/6)

const _signColor = Color(0xFFE6C99A);
const _woodColor = Color(0xFF8C6F4E);

/// 선반 3열 (캔버스 3-col)
const _shelfColumns = 3;
const _shelfRowGap = 20.0;

/// 칸 그림 상자 (소품·상품)
const itemArtSize = Size(64, 64);

/// 칸 그림 상자 (배, 캔버스 8-1)
const boatArtSize = Size(96, 52);

/// 3배 기기 기준으로 줄여 읽는다 (64pt → 192px)
int artCacheWidth(double width) => (width * 3).round();

/// 칸에 그림 한 장
class ItemImage extends StatelessWidget {
  const ItemImage(this.path, {super.key, required this.size, required this.fallback});

  final String path;
  final Size size;

  /// 파일을 못 읽었을 때
  final Widget fallback;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: size,
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: artCacheWidth(size.width),
          errorBuilder: (_, _, _) => fallback,
        ),
      );
}

/// 그림 없는 칸: 점선 상자 + 이름. [name]이 null이면 빈 칸 ("없음")
class ItemPlaceholder extends StatelessWidget {
  const ItemPlaceholder({super.key, this.name});

  final String? name;

  static const _size = Size(60, 56);

  /// 11pt로 상자 한 줄에 들어가는 글자 수
  static const _oneLineChars = 5;

  @override
  Widget build(BuildContext context) {
    final label = name;
    return SizedBox.fromSize(
      size: _size,
      child: CustomPaint(
        key: const ValueKey('item-placeholder'),
        painter: const DashedBoxPainter(),
        child: label == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Center(
                  child: Text(
                    // 긴 이름은 글자 중간이 아니라 낱말에서 끊는다 ('고양이 슬리퍼')
                    label.length > _oneLineChars ? label.replaceFirst(' ', '\n') : label,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    // 정해진 상자 안이라 글자 배율 상한을 둔다
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: badgeMaxTextScale),
                    style: const TextStyle(fontSize: 11, height: 1.2, color: Palette.subInk),
                  ),
                ),
              ),
      ),
    );
  }
}

/// 그림 없는 색 소품 칸: 그 색의 상자 (캔버스 8-1 색 소품, 56×50)
class ItemSwatch extends StatelessWidget {
  const ItemSwatch(this.color, {super.key});

  final Color color;

  static const size = Size(56, 50);

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          key: const ValueKey('item-swatch'),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.ink, width: InkLine.pill),
          ),
        ),
      );
}

/// 소품·상품 [id]의 칸 그림: 파일이 있으면 그 그림, 없으면 [swatch] 색 상자, 그것도 없으면 점선 칸 + [name]
class ItemArt extends ConsumerWidget {
  const ItemArt({
    super.key,
    required this.id,
    required this.name,
    this.size = itemArtSize,
    this.swatch,
  });

  /// 소품의 칸 그림. 색 소품은 그림이 없으면 material.hex 색 상자다
  ItemArt.prop(Prop p, {super.key, this.size = itemArtSize})
      : id = p.id,
        name = p.name,
        swatch = p.isColorVariant && p.materialArgb != null ? Color(p.materialArgb!) : null;

  final String id;
  final String name;
  final Size size;
  final Color? swatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(assetIndexProvider).value?.itemIcon(id);
    final color = swatch;
    final none = color == null ? ItemPlaceholder(name: name) : ItemSwatch(color);
    return path == null ? none : ItemImage(path, size: size, fallback: none);
  }
}

/// 선반 위 칸 하나: 그림([art]), 선반, 꼬리표(이름 + [state]). [selected]면 점선 고리.
/// [state]가 비면 상태 줄이 없고, [onTap]이 없으면 눌리지 않는다
class ItemCell extends StatelessWidget {
  const ItemCell({
    super.key,
    required this.name,
    required this.art,
    required this.tilt,
    this.state = '',
    this.stateColor = Palette.moss,
    this.selected = false,
    this.onTap,
  });

  final String name;
  final Widget art;

  /// 꼬리표 기울기 방향: 짝수 칸 -2도, 홀수 칸 +2도
  final int tilt;
  final String state;
  final Color stateColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: state.isEmpty ? name : '$name, $state',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  // 배 그림은 상자보다 넓다
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 12,
                      bottom: 0,
                      child: Container(
                        width: 60,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Palette.ink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned.fill(child: CustomPaint(painter: _DashedRingPainter())),
                    Positioned(bottom: 5, child: art),
                  ],
                ),
              ),
            ),
            Container(
              height: 8,
              decoration: const BoxDecoration(
                color: _signColor,
                border: Border(top: BorderSide(color: Palette.ink, width: InkLine.panel)),
              ),
            ),
            Container(
              height: 14,
              decoration: const BoxDecoration(
                color: _woodColor,
                border: Border(bottom: BorderSide(color: Palette.ink, width: InkLine.panel)),
              ),
            ),
            Center(child: Container(width: 1, height: 10, color: Palette.subInk)),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.92,
                child: Transform.rotate(
                  angle: (tilt.isOdd ? 2 : -2) * math.pi / 180,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Palette.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Palette.ink, width: InkLine.pill),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, height: 1.3, color: Palette.ink),
                        ),
                        if (state.isNotEmpty)
                          Text(
                            state,
                            textAlign: TextAlign.center,
                            style: context.display(13, color: stateColor, weight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 칸들을 선반 3열로 놓는다 (남는 자리는 비운다)
class ItemShelf extends StatelessWidget {
  const ItemShelf({super.key, required this.cells, this.rowGap = _shelfRowGap});

  final List<Widget> cells;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < cells.length; start += _shelfColumns) ...[
          if (start > 0) SizedBox(height: rowGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = start; i < start + _shelfColumns; i++)
                Expanded(child: i < cells.length ? cells[i] : const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }
}

/// 둥근 점선 상자. 수레 자리표시도 같은 선을 쓴다
class DashedBoxPainter extends CustomPainter {
  const DashedBoxPainter({this.fill});

  /// 속 색. 없으면 비운다
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    if (fill case final color?) canvas.drawRRect(box, Paint()..color = color);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = InkLine.pill
      ..color = Palette.lineDashed;
    for (final m in (Path()..addRRect(box.deflate(InkLine.pill / 2))).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBoxPainter old) => old.fill != fill;
}

/// 고른 칸 둘레의 점선 고리 (84×84 안, 중심 (42, 44), 반지름 38)
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Palette.terracotta;
    final ring = Path()..addOval(Rect.fromCircle(center: const Offset(42, 44), radius: 38));
    for (final m in ring.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}
