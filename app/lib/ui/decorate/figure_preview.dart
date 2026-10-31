import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/look.dart';
import '../../domain/prop.dart';
import '../common/figure_painter.dart';
import '../common/format.dart';
import '../common/palette.dart';
import 'decorate_widgets.dart';

/// 흔들리는 시간 (누르면 한 번)
const _wiggleDuration = Duration(milliseconds: 600);

/// 꾸미기 위 미리보기 (자리표시): 쉼터 바탕 자리에 그림을 놓고, 누르면 기지개처럼 한 번 흔든다.
/// TODO(M4): 캐릭터 그림(Rive, 3/4 측면)과 쉼터 배경이 나오면 바꾼다
class FigurePreview extends StatefulWidget {
  const FigurePreview({super.key, required this.painter});

  final FigurePainter painter;

  @override
  State<FigurePreview> createState() => _FigurePreviewState();
}

class _FigurePreviewState extends State<FigurePreview> with SingleTickerProviderStateMixin {
  late final _wiggle = AnimationController(vsync: this, duration: _wiggleDuration);

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Semantics(
        button: true,
        label: '캐릭터 미리보기',
        excludeSemantics: true,
        child: GestureDetector(
          key: const ValueKey('preview'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _wiggle.forward(from: 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.ink, width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9.5),
              child: LayoutBuilder(builder: (context, box) {
                final side = math.min(box.maxWidth, box.maxHeight);
                return Stack(
                  children: [
                    // 풀밭 자리
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: box.maxHeight * 0.22,
                      child: ColoredBox(color: Palette.moss.withValues(alpha: 0.25)),
                    ),
                    Center(
                      child: SizedBox.square(
                        dimension: side,
                        child: AnimatedBuilder(
                          animation: _wiggle,
                          builder: (context, child) {
                            final t = _wiggle.value;
                            return Transform(
                              key: const ValueKey('figure-wiggle'),
                              alignment: Alignment.bottomCenter,
                              transform: Matrix4.identity()
                                ..rotateZ(math.sin(t * math.pi * 4) * 0.07 * (1 - t))
                                ..scaleByDouble(1, 1 + 0.05 * math.sin(t * math.pi), 1, 1),
                              child: child,
                            );
                          },
                          child: CustomPaint(painter: widget.painter),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// 미리보기 아래의 끼운 소품 줄: 칸마다 아이콘(자리표시)과 이름, 비운 칸은 흐리게 "없음"
class EquippedRow extends StatelessWidget {
  const EquippedRow({super.key, required this.look, required this.props});

  final Look look;
  final List<Prop> props;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in props) p.id: p};
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          for (final slot in decorateSlotOrder)
            Expanded(
              child: _Equipped(
                key: ValueKey('equip-$slot'),
                slot: slot,
                name: look.slots[slot] == null ? null : byId[look.slots[slot]]?.name,
              ),
            ),
        ],
      ),
    );
  }
}

class _Equipped extends StatelessWidget {
  const _Equipped({super.key, required this.slot, required this.name});

  final String slot;

  /// 끼운 소품 이름. 비었으면 null
  final String? name;

  @override
  Widget build(BuildContext context) {
    final worn = name != null;
    return Semantics(
      label: '${propSlotLabels[slot]} ${name ?? '없음'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: worn ? 1 : 0.4,
        child: Column(
          children: [
            Icon(slotIcons[slot], size: 22, color: Palette.ink),
            Text(
              name ?? '없음',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.2, color: Palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}
