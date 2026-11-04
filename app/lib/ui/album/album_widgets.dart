import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/prop.dart';
import '../../domain/sketch.dart';
import '../common/app_text.dart';
import '../common/basic_item_art.dart';
import '../common/framed_painting.dart';
import '../common/notice_dot.dart';
import '../common/palette.dart';

/// 그림 칸 격자: 3열, 칸 너비 : (그림 + 이름 줄) 높이 = 0.78, 좌우 여백 16pt·칸 사이 8pt
const _cellColumns = 3;
const _cellAspect = 0.78;
const _gridGutter = 16.0;
const _gridGap = 8.0;

/// 그림 칸 이름 줄의 기본 높이: 한 줄 (12pt, 줄 높이 1.25) + 2pt. 긴 이름은 말줄임표
const _labelHeight = 17.0;

/// 이름 줄 높이: 글자 크기를 키우면 한 줄이 같이 커진다 (기본 크기에서는 17pt)
double paintingLabelHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(12) * 1.25 + 2;

/// 그림 칸 3열 격자. 칸 높이는 기본 크기에서 너비 : 높이 = 0.78이고,
/// 글자 크기를 키우면 이름 줄이 커진 만큼 칸이 길어져서 그림 크기는 그대로다
SliverGridDelegate paintingGridDelegate(BuildContext context) {
  final cellWidth =
      (MediaQuery.sizeOf(context).width - 2 * _gridGutter - (_cellColumns - 1) * _gridGap) /
          _cellColumns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: _cellColumns,
    mainAxisSpacing: 12,
    crossAxisSpacing: _gridGap,
    mainAxisExtent: cellWidth / _cellAspect + paintingLabelHeight(context) - _labelHeight,
  );
}

/// `그림` / `소품` / `도장 5 / 20` 탭 셋 (캔버스 Gallery). [propsDot]이면 `소품`, [stampsDot]이면 `도장`
/// 라벨 오른쪽 위에 알림 점이 붙는다. [stampsLabel]은 도장 탭 글 (받은 수 / 전체)
class AlbumTabs extends StatelessWidget {
  const AlbumTabs({
    super.key,
    required this.selected,
    required this.onSelect,
    this.propsDot = false,
    this.stampsDot = false,
    this.stampsLabel = '도장',
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final bool propsDot;
  final bool stampsDot;
  final String stampsLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tab(context, 0, '그림', const ValueKey('tab-paintings'))),
        const SizedBox(width: 8),
        Expanded(child: _tab(context, 1, '소품', const ValueKey('tab-props'), dot: propsDot)),
        const SizedBox(width: 8),
        Expanded(
          child: _tab(context, 2, stampsLabel, const ValueKey('tab-stamps'),
              dot: stampsDot, dotKey: const ValueKey('stamps-tab-dot')),
        ),
      ],
    );
  }

  Widget _tab(
    BuildContext context,
    int index,
    String label,
    Key key, {
    bool dot = false,
    Key dotKey = const ValueKey('props-tab-dot'),
  }) {
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
            border: Border.all(color: Palette.ink, width: InkLine.panel),
          ),
          // 점은 글자 칸 바깥 오른쪽 위에 걸친다 (글자 위치는 그대로)
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 글자를 키워도 세 칸 안에 들어오게 줄인다
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: context.display(16, color: on ? Palette.paper : Palette.ink),
                ),
              ),
              if (dot)
                Positioned(
                  top: -4,
                  right: -12,
                  child: NoticeDot(key: dotKey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 권역 걸러 보기 칩: `전체` + [labels]의 권역 (얻은 그림이 있는 권역만 넘긴다). [region]이 null이면 전체
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
                border: Border.all(color: Palette.ink, width: InkLine.panel),
              ),
              child: Text(
                label,
                style: context.display(14, color: selected ? Palette.paper : Palette.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 얻은 그림 한 칸의 뼈대: 액자 + 한 줄 이름 (긴 이름은 말줄임표).
/// [isNew]이면 오른쪽 위에 알림 점이 붙는다 (점 키는 `new-painting-<그림 id>`)
class _OwnedCell extends StatelessWidget {
  const _OwnedCell({
    required this.paintingId,
    required this.frame,
    required this.name,
    required this.onTap,
    required this.isNew,
  });

  final String paintingId;
  final Widget frame;
  final String name;
  final VoidCallback? onTap;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Expanded(child: frame),
              const SizedBox(height: 4),
              SizedBox(
                height: paintingLabelHeight(context),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.display(12).copyWith(height: 1.25),
                ),
              ),
            ],
          ),
          if (isNew)
            Positioned(
              top: -4,
              right: -4,
              child: NoticeDot(key: ValueKey('new-painting-$paintingId')),
            ),
        ],
      ),
    );
  }
}

/// 명소 그림 한 칸: 색 액자 + 명소 이름. 얻은 그림만 그린다 (못 얻은 그림은 칸이 없다).
/// [isNew]이면(이번에 화집을 열기 전에 얻은 그림) 오른쪽 위에 알림 점이 붙는다
class PaintingCell extends StatelessWidget {
  const PaintingCell({super.key, required this.owned, this.onTap, this.isNew = false});

  final OwnedPaintingView owned;
  final VoidCallback? onTap;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return _OwnedCell(
      paintingId: owned.landmark.id,
      frame: FramedPainting(landmark: owned.landmark, frame: owned.frame),
      name: owned.landmark.name,
      onTap: onTap,
      isNew: isNew,
    );
  }
}

/// 첫 그림 칸 (그림 격자 맨 앞): 나무 액자에 낀 짐 꾸러미 그림, 아래에 이름표 '첫 그림'.
/// 첫 그림을 얻었을 때만 그린다. [isNew]이면 오른쪽 위에 알림 점이 붙는다 (명소 칸과 같다)
class FirstPackCell extends StatelessWidget {
  const FirstPackCell({super.key, this.onTap, this.isNew = false});

  final VoidCallback? onTap;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return _OwnedCell(
      paintingId: sketchId,
      frame: const FramedPainting.firstPack(),
      name: firstPackLabel,
      onTap: onTap,
      isNew: isNew,
    );
  }
}

/// 얻은 그림 [p]의 칸: 첫 그림이면 [FirstPackCell], 명소 그림이면 [PaintingCell]
Widget ownedPaintingCell(
  OwnedPaintingView p, {
  Key? key,
  VoidCallback? onTap,
  bool isNew = false,
}) =>
    p.isFirstPack
        ? FirstPackCell(key: key, onTap: onTap, isNew: isNew)
        : PaintingCell(key: key, owned: p, onTap: onTap, isNew: isNew);

/// 소품 한 줄: 첫 글자 원 + 이름. 얻은 소품만 나온다 (얻는 방법은 꾸미기의 잠긴 칸에서 본다)
class PropRow extends StatelessWidget {
  const PropRow({super.key, required this.prop});

  final Prop prop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.paper,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.ink, width: InkLine.panel),
            ),
            child: BasicItemIcon(id: prop.id, fallback: prop.name.substring(0, 1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prop.name,
              style: context.display(16),
            ),
          ),
        ],
      ),
    );
  }
}
