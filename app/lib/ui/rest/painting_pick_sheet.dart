import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/decor_providers.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart' show OwnedPaintingView;
import '../../domain/decor.dart';
import '../common/app_text.dart';
import '../common/framed_painting.dart';
import '../common/palette.dart';

/// 그림 고르기 시트 (T15, 16장 11/18 ①·11/19 ⑦, config decor.paintingNote): 그림 거는 물품의 칸마다 화집에서 얻은
/// 그림을 골라 건다. 같은 그림을 여러 물품·칸에 걸어도 된다(가안). 액자 등급은 그 그림 그대로. 칸이 여럿이면
/// (빨랫줄 3칸) 위에서 칸을 고른다. 고르면 바로 걸리고(저장 버튼 없음), 칸이 하나면 시트가 닫힌다.
/// 탭 바까지 덮어 뜬다 (캔버스 TabBar 메모 ‘시트는 탭 바 위에’)
Future<void> showPaintingPickSheet(BuildContext context, DecorItem item, {int slot = 0}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Palette.card,
      barrierColor: Palette.ink.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: Palette.ink, width: InkLine.panel),
      ),
      builder: (_) => _PickSheet(item: item, slot: slot.clamp(0, item.paintingSlots - 1)),
    );

class _PickSheet extends ConsumerStatefulWidget {
  const _PickSheet({required this.item, required this.slot});

  final DecorItem item;
  final int slot;

  @override
  ConsumerState<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends ConsumerState<_PickSheet> {
  late int _slot = widget.slot;

  DecorItem get _item => widget.item;

  Future<void> _hang(String? key) async {
    await ref.read(decorProvider.notifier).hang(_item.id, _slot, key, slots: _item.paintingSlots);
    if (!mounted) return;
    if (_item.paintingSlots == 1 && key != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final paintings = ref.watch(paintingsProvider).value;
    final hung = ref.watch(decorProvider).value?.paintings[_item.id] ?? const <int, String>{};
    final current = hung[_slot];
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.7),
      child: Padding(
        key: const ValueKey('painting-pick-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('${_item.name}에 걸 그림', style: context.display(18))),
                if (current != null)
                  TextButton(
                    key: const ValueKey('painting-pick-clear'),
                    onPressed: () => _hang(null),
                    child: Text('내리기', style: context.display(14, color: Palette.terracotta)),
                  ),
              ],
            ),
            if (_item.paintingSlots > 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < _item.paintingSlots; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _SlotChip(
                      key: ValueKey('painting-pick-slot-$i'),
                      label: '${i + 1}번 칸',
                      selected: i == _slot,
                      filled: hung[i] != null,
                      onTap: () => setState(() => _slot = i),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (paintings == null)
              const SizedBox(height: 80)
            else if (paintings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '아직 얻은 그림이 없어요',
                  key: const ValueKey('painting-pick-empty'),
                  textAlign: TextAlign.center,
                  style: AppText.label,
                ),
              )
            else
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: paintings.length,
                  itemBuilder: (context, i) => _PaintingCell(
                    painting: paintings[i],
                    selected: paintings[i].landmark.id == current,
                    onTap: () => _hang(paintings[i].landmark.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 칸 고르기 (빨랫줄 3칸). 그림이 걸린 칸은 점
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    super.key,
    required this.label,
    required this.selected,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: filled ? '$label (그림 있음)' : label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? Palette.ink : Palette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Palette.ink, width: InkLine.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: context.display(13, color: selected ? Palette.card : Palette.ink)),
                if (filled) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected ? Palette.card : Palette.terracotta,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// 그림 한 장 (액자째 + 이름). 지금 칸에 걸린 그림은 테라코타 테두리
class _PaintingCell extends StatelessWidget {
  const _PaintingCell({required this.painting, required this.selected, required this.onTap});

  final OwnedPaintingView painting;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = painting;
    return Semantics(
      button: true,
      selected: selected,
      label: p.landmark.name,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('painting-pick-${p.landmark.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? Palette.terracotta : Colors.transparent, width: 3),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: p.isFirstPack
                        ? const FramedPainting.firstPack(thickness: 4)
                        : FramedPainting(landmark: p.landmark, frame: p.frame, thickness: 4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.landmark.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}
