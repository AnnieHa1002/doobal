import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/prop.dart';
import '../../domain/sketch.dart';
import '../common/app_text.dart' show badgeMaxTextScale;
import '../common/framed_painting.dart';
import '../common/notice_dot.dart';
import '../common/palette.dart';

/// 벽 한 칸의 크기 비율 (너비 : 높이 = 4 : 5)
const _wallSlotAspect = 0.8;

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

/// 빈 칸 안내 글. 길게 눌러서 건다는 뜻이다
const emptyWallHint = '길게 눌러 걸기';

/// 화집 벽: 액자 [wall].length칸을 한 줄로. 건 칸은 색 액자(첫 그림은 나무 액자),
/// 빈 칸은 점선 액자와 `길게 눌러 걸기`. [replacing]이면 칸마다 테라코타 테두리를 둘러 눌러서 고르게 한다.
/// 벽 그림(나무 선반·못과 끈) 에셋은 아직 없어서 벽 뒤는 비워 둔다. 나오면 이 줄 뒤에 깐다
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
                ? const _EmptyWallSlot()
                : p.isFirstPack
                    ? const FramedPainting.firstPack(thickness: 5)
                    : FramedPainting(landmark: p.landmark, frame: p.frame, thickness: 5),
          ),
        ),
      ),
    );
  }
}

/// 벽의 빈 칸: 점선 액자 안에 안내 글. 부모를 꽉 채운다
class _EmptyWallSlot extends StatelessWidget {
  const _EmptyWallSlot();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const DottedFramePainter(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            emptyWallHint,
            textAlign: TextAlign.center,
            // 칸 크기가 정해져 있어서 글자 배율 상한을 둔다
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: badgeMaxTextScale),
            style: const TextStyle(fontSize: 11, color: Palette.subInk),
          ),
        ),
      ),
    );
  }
}

/// 둥근 네모 점선 테두리 (빈 액자 자리). [dash]·[gap]은 점선 한 토막과 틈의 길이
class DottedFramePainter extends CustomPainter {
  const DottedFramePainter({
    this.color = Palette.subInk,
    this.radius = 6,
    this.width = 1.5,
    this.dash = 4,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    // 선 굵기의 절반만큼 안쪽으로 그려서 칸 밖으로 번지지 않게 한다
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DottedFramePainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.width != width ||
      old.dash != dash ||
      old.gap != gap;
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: Palette.ink,
                  ),
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
        border: Border.all(color: Palette.ink, width: 2),
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
              border: Border.all(color: Palette.ink, width: 2),
            ),
            child: Text(
              prop.name.substring(0, 1),
              // 40pt 동그라미 안이라 글자 배율 상한을 둔다
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: badgeMaxTextScale),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prop.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
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
          gridDelegate: paintingGridDelegate(context),
          itemCount: paintings.length,
          itemBuilder: (context, i) {
            final p = paintings[i];
            return KeyedSubtree(
              key: ValueKey('pick-${p.landmark.id}'),
              child: ownedPaintingCell(p,
                  onTap: () => Navigator.of(context).pop(p.landmark.id)),
            );
          },
        ),
      ),
    ),
  );
}
