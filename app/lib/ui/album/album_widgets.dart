import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/landmark.dart';
import '../../domain/prop.dart';
import '../../domain/sketch.dart';
import '../common/framed_painting.dart';
import '../common/notice_dot.dart';
import '../common/palette.dart';
import '../common/sketch_painting.dart';

/// 벽 한 칸의 크기 비율 (너비 : 높이 = 4 : 5)
const _wallSlotAspect = 0.8;

/// 화집 벽: 액자 [wall].length칸을 한 줄로. 건 칸은 색 액자, 빈 칸은 빈 액자.
/// [replacing]이면 칸마다 테라코타 테두리를 둘러 눌러서 고르게 한다
class WallRow extends StatelessWidget {
  const WallRow({
    super.key,
    required this.wall,
    required this.owned,
    required this.replacing,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String?> wall;
  final Map<String, OwnedPaintingView> owned;
  final bool replacing;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < wall.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _slot(i)),
        ],
      ],
    );
  }

  Widget _slot(int i) {
    final p = wall[i] == null ? null : owned[wall[i]];
    final sketch = p?.sketch;
    return AspectRatio(
      aspectRatio: _wallSlotAspect,
      child: GestureDetector(
        key: ValueKey('wall-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        onLongPress: () => onLongPress(i),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: replacing ? Palette.terracotta : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: p == null
                ? const FramedPainting.empty(thickness: 5)
                : sketch != null
                    // 내 동네 스케치는 액자 등급이 없다
                    ? SketchThumb(sketch: sketch)
                    : FramedPainting(landmark: p.landmark, frame: p.frame, thickness: 5),
          ),
        ),
      ),
    );
  }
}

/// `그림` / `소품` 탭 두 개. [propsDot]이면 `소품` 라벨 오른쪽 위에 알림 점이 붙는다
class AlbumTabs extends StatelessWidget {
  const AlbumTabs({
    super.key,
    required this.selected,
    required this.onSelect,
    this.propsDot = false,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final bool propsDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tab(0, '그림', const ValueKey('tab-paintings'))),
        const SizedBox(width: 8),
        Expanded(child: _tab(1, '소품', const ValueKey('tab-props'), dot: propsDot)),
      ],
    );
  }

  Widget _tab(int index, String label, Key key, {bool dot = false}) {
    final on = selected == index;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(index),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Palette.terracotta : Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ink, width: 2.5),
          ),
          // 점은 글자 칸 바깥 오른쪽 위에 걸친다 (글자 위치는 그대로)
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: on ? Palette.paper : Palette.ink,
                ),
              ),
              if (dot)
                const Positioned(
                  top: -4,
                  right: -12,
                  child: NoticeDot(key: ValueKey('props-tab-dot')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 권역 걸러 보기 칩: `전체` + 권역 7개. [region]이 null이면 전체
class RegionFilterChips extends StatelessWidget {
  const RegionFilterChips({
    super.key,
    required this.labels,
    required this.region,
    required this.onSelect,
  });

  /// 권역 키 → 이름 (칩 순서 그대로)
  final Map<String, String> labels;
  final String? region;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Chip(
            key: const ValueKey('album-chip-all'),
            label: '전체',
            selected: region == null,
            onTap: () => onSelect(null),
          ),
          for (final e in labels.entries) ...[
            const SizedBox(width: 8),
            _Chip(
              key: ValueKey('album-chip-${e.key}'),
              label: e.value,
              selected: region == e.key,
              onTap: () => onSelect(e.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 누르는 자리는 44pt, 눈에 보이는 칩은 36pt
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Palette.terracotta : Palette.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.ink, width: 2),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Palette.paper : Palette.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 명소 하나의 칸: 그림 자리 + 이름. 얻은 그림은 색 액자와 잉크색 이름,
/// 못 얻은 그림은 빈 밝은 액자와 흐린 이름. 누르는 동작은 얻은 그림만 [onTap]이 있다.
/// [isNew]이면(이번에 화집을 열기 전에 얻은 그림) 오른쪽 위에 알림 점이 붙는다
class PaintingCell extends StatelessWidget {
  const PaintingCell({
    super.key,
    required this.landmark,
    required this.owned,
    this.onTap,
    this.isNew = false,
  });

  final Landmark landmark;
  final OwnedPaintingView? owned;
  final VoidCallback? onTap;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final p = owned;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Expanded(
                child: p == null
                    ? const FramedPainting.empty()
                    : FramedPainting(landmark: landmark, frame: p.frame),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: Text(
                  landmark.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: p == null ? Palette.subInk : Palette.ink,
                  ),
                ),
              ),
            ],
          ),
          if (isNew)
            Positioned(
              top: -4,
              right: -4,
              child: NoticeDot(key: ValueKey('new-painting-${landmark.id}')),
            ),
        ],
      ),
    );
  }
}

/// 내 동네 스케치 칸 (그림 격자 맨 앞): 얻었으면 그림 썸네일, 아니면 빈 액자. 아래에 이름.
/// 액자 등급이 없어서 색 액자 대신 얇은 선만 두른다. 누르는 동작은 얻었을 때만 [onTap]이 있다.
/// [isNew]이면 오른쪽 위에 알림 점이 붙는다 (명소 칸과 같다)
class SketchCell extends StatelessWidget {
  const SketchCell({super.key, required this.owned, this.onTap, this.isNew = false});

  final OwnedPaintingView? owned;
  final VoidCallback? onTap;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final sketch = owned?.sketch;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Expanded(
                child: sketch == null
                    ? const FramedPainting.empty()
                    : SketchThumb(key: const ValueKey('sketch-thumb'), sketch: sketch),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: Text(
                  sketchName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: sketch == null ? Palette.subInk : Palette.ink,
                  ),
                ),
              ),
            ],
          ),
          if (isNew)
            const Positioned(
              top: -4,
              right: -4,
              child: NoticeDot(key: ValueKey('new-painting-$sketchId')),
            ),
        ],
      ),
    );
  }
}

/// 소품 한 줄: 첫 글자 원 + 이름. 잠긴 소품은 흐리게 하고 얻는 방법을 아래에 붙인다
class PropRow extends StatelessWidget {
  const PropRow({super.key, required this.prop, required this.owned, required this.howTo});

  final Prop prop;
  final bool owned;

  /// 잠긴 소품을 얻는 방법 (얻었거나 기본 소품이면 null)
  final String? howTo;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: owned ? Palette.paper : Palette.card,
              shape: BoxShape.circle,
              border: Border.all(color: owned ? Palette.ink : Palette.subInk, width: 2),
            ),
            child: Text(
              prop.name.substring(0, 1),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prop.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                  ),
                ),
                if (!owned && howTo != null)
                  Text(howTo!, style: const TextStyle(fontSize: 14, color: Palette.subInk)),
              ],
            ),
          ),
        ],
      ),
    );
    return owned ? row : Opacity(opacity: 0.55, child: row);
  }
}

/// 벽에 걸 그림을 고르는 시트 (얻은 그림 3열). 고르면 그 명소 id, 밖을 눌러 닫으면 null
Future<String?> showPaintingPicker(BuildContext context, List<OwnedPaintingView> paintings) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.card,
    barrierColor: Palette.ink.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      side: BorderSide(color: Palette.ink, width: 2.5),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemCount: paintings.length,
          itemBuilder: (context, i) {
            final p = paintings[i];
            void pick() => Navigator.of(context).pop(p.landmark.id);
            return KeyedSubtree(
              key: ValueKey('pick-${p.landmark.id}'),
              child: p.isSketch
                  ? SketchCell(owned: p, onTap: pick)
                  : PaintingCell(landmark: p.landmark, owned: p, onTap: pick),
            );
          },
        ),
      ),
    ),
  );
}
