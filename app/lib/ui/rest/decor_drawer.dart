import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/decor_providers.dart';
import '../../app/providers.dart';
import '../../domain/decor.dart';
import '../common/app_text.dart';
import '../common/item_cell.dart' show ItemArt;
import '../common/palette.dart';
import 'decor_edit.dart';

/// 쉼터 꾸미기 서랍 (쉼터 옆 ‘꾸미기’ 버튼 또는 물품을 집으면 열림, 캔버스 2-2 꾸미기 중 아래 서랍).
/// 가진 물품 중 안 놓은 것을 얻은 순서로 한 줄에. 칸을 누르면 보이는 장면 가운데(막혔으면 옆)에 놓이고,
/// 길게 눌러 끌면 원하는 자리에 놓는다. 놓인 물품을 서랍 위로 끌어 놓으면 치운다. 저장 버튼은 없다
class DecorDrawer extends ConsumerWidget {
  const DecorDrawer({super.key, required this.edit, required this.dragger, required this.onDone});

  final DecorEdit edit;
  final DecorDragger dragger;

  /// ‘완료’ (서랍 닫기)
  final VoidCallback onDone;

  /// 서랍 높이 (탭 바 위, 머리 줄 + 칸 한 줄)
  static const height = 112.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(decorProvider).value;
    final catalog = ref.watch(decorCatalogProvider).value;
    final stage = ref.watch(decorStageProvider).value;
    final ids = [
      for (final id in state?.drawer ?? const <String>[])
        if (catalog?.byId(id) case final item? when stage?.canPlace(item) ?? false) item,
    ];
    final placed = state?.placed.length ?? 0;
    final full = stage != null && placed >= stage.rules.maxPlaced;
    return ValueListenableBuilder<bool>(
      valueListenable: edit.overDrawer,
      builder: (context, over, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: over ? Color.lerp(Palette.card, Palette.terracotta, 0.12) : Palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(
            top: BorderSide(color: over ? Palette.terracotta : Palette.ink, width: InkLine.panel),
          ),
          boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, -InkLine.shadow))],
        ),
        child: child,
      ),
      child: Semantics(
        container: true,
        label: '쉼터 꾸미기 서랍',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '가진 물품',
                      style: AppText.label.copyWith(color: Palette.subInk),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '완료',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('decor-drawer-done'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onDone,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 56, minHeight: 32),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('완료', style: context.display(14, color: Palette.terracotta)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ids.isEmpty
                  ? Center(
                      child: Text(
                        (state?.owned.isEmpty ?? true) ? '아직 가진 쉼터 물품이 없어요' : '가진 물품을 모두 놓았어요',
                        key: const ValueKey('decor-drawer-empty'),
                        style: AppText.label.copyWith(color: Palette.subInk),
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey('decor-drawer-list'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                      itemCount: ids.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _DrawerCell(
                        item: ids[i],
                        edit: edit,
                        dragger: dragger,
                        disabled: full,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 서랍 칸 하나: 칸 그림(없으면 점선 + 이름) + 이름
class _DrawerCell extends StatelessWidget {
  const _DrawerCell({required this.item, required this.edit, required this.dragger, required this.disabled});

  final DecorItem item;
  final DecorEdit edit;
  final DecorDragger dragger;

  /// 쉼터에 이미 최대로 놓았다
  final bool disabled;

  static const _art = Size(52, 44);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: edit,
      builder: (context, _) {
        final held = edit.held?.id == item.id;
        return Semantics(
          button: !disabled,
          label: item.name,
          excludeSemantics: true,
          child: GestureDetector(
            key: ValueKey('decor-drawer-${item.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: disabled ? null : () => dragger.placeAtCenter(item.id),
            onLongPressStart: disabled ? null : (d) => dragger.pick(item.id, global: d.globalPosition),
            onLongPressMoveUpdate: disabled ? null : (d) => dragger.move(d.globalPosition),
            onLongPressEnd: disabled ? null : (_) => dragger.drop(),
            onLongPressCancel: disabled ? null : dragger.cancel,
            child: Opacity(
              opacity: held || disabled ? 0.4 : 1,
              child: SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.fromSize(
                      size: _art,
                      child: FittedBox(child: ItemArt(id: item.id, name: item.name, size: _art)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, height: 1.2, color: Palette.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
