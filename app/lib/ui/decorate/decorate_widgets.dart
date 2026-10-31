import 'package:flutter/material.dart';

import '../common/palette.dart';

const _cellRadius = 12.0;

/// 소품 탭과 끼운 소품 줄의 칸 순서 (UI 명세 12장: 옷 · 모자 · 손 · 가방 · 신발 · 어깨 친구).
/// 화집 소품 탭 순서(propSlotLabels)와 다르다
const decorateSlotOrder = ['cloth', 'hat', 'hand', 'bag', 'shoe', 'pet'];

/// 칸별 아이콘 (자리표시). 소품 아이콘 그림(item_*_icon)이 나오면 그 그림으로 바꾼다
const slotIcons = {
  'cloth': Icons.checkroom,
  'hat': Icons.school,
  'hand': Icons.brush,
  'bag': Icons.backpack,
  'shoe': Icons.directions_walk,
  'pet': Icons.pets,
};

/// 견본 한 칸: 번호, 접근성 이름, 불투명 ARGB 색
typedef SwatchItem = ({int id, String name, int color});

/// 탭 안의 작은 제목 (머리 모양·색처럼)
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink),
      ),
    );
  }
}

/// 색 견본 동그라미. 이름은 접근성 label, 고른 것은 굵은 테두리와 체크
class SwatchDot extends StatelessWidget {
  const SwatchDot({super.key, required this.item, required this.selected, required this.onTap});

  final SwatchItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(item.color);
    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 누르는 자리는 44pt
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.ink, width: selected ? 4 : 2),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: color.computeLuminance() > 0.5 ? Palette.ink : Palette.paper,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 견본을 한 줄에 5개씩 늘어놓는다 (남는 칸은 비워서 줄마다 자리가 같다).
/// 칸의 key는 `'$keyPrefix-번호'`. [isSelected]가 true인 칸에 체크가 붙는다
class SwatchGrid extends StatelessWidget {
  const SwatchGrid({
    super.key,
    required this.keyPrefix,
    required this.items,
    required this.isSelected,
    required this.onPick,
  });

  static const perRow = 5;

  final String keyPrefix;
  final List<SwatchItem> items;
  final bool Function(SwatchItem item) isSelected;
  final ValueChanged<SwatchItem> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var start = 0; start < items.length; start += perRow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = start; i < start + perRow; i++)
                if (i < items.length)
                  SwatchDot(
                    key: ValueKey('$keyPrefix-${items[i].id}'),
                    item: items[i],
                    selected: isSelected(items[i]),
                    onTap: () => onPick(items[i]),
                  )
                else
                  const SizedBox(width: 44, height: 44),
            ],
          ),
      ],
    );
  }
}

/// 번호 칸 한 줄 (머리 모양 1~6, 눈 1~3처럼). 칸 폭은 [columns]칸 기준으로 같고, [count]보다 큰 번호 자리는 빈다.
/// 칸의 key는 `'$keyPrefix-번호'`. 그림이 나오면 번호 대신 그 그림을 넣는다
class NumberRow extends StatelessWidget {
  const NumberRow({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.count,
    required this.selected,
    required this.onPick,
    this.columns = 6,
  });

  final String keyPrefix;

  /// 접근성 이름 ("머리 모양" → "머리 모양 3")
  final String label;
  final int count;
  final int selected;
  final ValueChanged<int> onPick;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= columns; i++) ...[
          if (i > 1) const SizedBox(width: 8),
          Expanded(
            child: i <= count
                ? _NumberCell(
                    key: ValueKey('$keyPrefix-$i'),
                    number: i,
                    label: '$label $i',
                    selected: selected == i,
                    onTap: () => onPick(i),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({
    super.key,
    required this.number,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.terracotta : Palette.paper,
            borderRadius: BorderRadius.circular(_cellRadius),
            border: Border.all(color: Palette.ink, width: 2.5),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: selected ? Palette.paper : Palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 알약 모양 고르기 단추 (직접 고르기·그라데이션). 고른 것은 테라코타
class OptionChip extends StatelessWidget {
  const OptionChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          // widthFactor: 1 이 없으면 Wrap 안에서 줄을 꽉 채운다 (alignment를 준 Container도 마찬가지)
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? Palette.terracotta : Palette.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.ink, width: 2.5),
              ),
              child: Align(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Palette.paper : Palette.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 소품 칸 하나: 아이콘(자리표시)과 이름. 고른 것은 테라코타 테두리와 체크, 잠긴 것은 흐리게 자물쇠.
/// [icon]이 null이면 "없음" 칸이다
class PropCell extends StatelessWidget {
  const PropCell({
    super.key,
    required this.name,
    required this.icon,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String name;
  final IconData? icon;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cell = Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: selected ? Palette.terracotta.withValues(alpha: 0.18) : Palette.paper,
              borderRadius: BorderRadius.circular(_cellRadius),
              border: Border.all(
                color: selected ? Palette.terracotta : Palette.ink,
                width: selected ? 4 : 2.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon ?? Icons.block,
                  size: 32,
                  color: icon == null ? Palette.subInk : Palette.ink,
                ),
                if (locked)
                  const Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(Icons.lock, size: 16, color: Palette.ink),
                  ),
                if (selected)
                  const Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(Icons.check_circle, size: 18, color: Palette.terracotta),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Palette.ink),
        ),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$name, 잠김' : name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: locked ? Opacity(opacity: 0.45, child: cell) : cell,
      ),
    );
  }
}
