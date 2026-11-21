import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paint_service.dart';
import '../../app/providers.dart';
import '../../domain/paint_color.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart' show Season, seasonOf;
import '../../domain/time_kst.dart';
import '../../domain/trail_pattern.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/item_cell.dart';
import '../common/notice_dot.dart';
import '../common/paint_art.dart';
import '../common/palette.dart';

/// 물감 탭 글 (가안: 캔버스에 없는 흐름). 걷는 중에 못 고르는 안내는 config choose.whileWalking이 false일 때만
const paintChooseWhileWalkingLine = '걷는 중에는 물감을 고르지 않아요';
const paintUsingLabel = '쓰는 중';

/// 맨 위 무늬 줄 제목 (가안: 캔버스 6-1에 무늬 줄이 아직 없다)
const patternRowTitle = '무늬';

/// 묶음 이름 (캔버스 6-1, 11/16)
const paintGroupTitles = {
  PaintGroup.recent: '최근',
  PaintGroup.season: '계절 색',
  PaintGroup.region: '지역 색',
};

/// 배낭 물감 탭 묶음 하나: 묶음 종류와 칸 (차례대로)
typedef PaintShelfGroup = ({PaintGroup kind, List<PaintStockView> colors});

/// 배낭 물감 탭 묶음 (캔버스 6-1 11/16 ‘묶음 3개’, config paintColor.backpack.order·recentCount):
/// - 최근: 기본 물감이 늘 맨 앞 + 최근에 고른(쓴) 색 (recentCount − 1)칸 (16장 11/17, 캔버스 6-1 ‘최근 쓴’.
///   차례는 [PaintShelfData.recent]: 지금 고른 색 → 물감 길에 마지막으로 칠한 차례. 고른 적 없으면 기본 한 칸)
/// - 계절 색: 지금 계절 → 지난 계절 차례(가을이면 가을·여름·봄·겨울), 계절 안은 16색 차례. 계절이 없는 키(1단계에서 모은 것)는
///   마지막으로 주운 날의 계절에 든다
/// - 지역 색: config region.colors 차례
/// 같은 색이 최근과 계절·지역에 둘 다 있어도 된다 (캔버스 6-1 메모). 빈 묶음은 없다
List<PaintShelfGroup> paintShelfGroups(PaintShelfData data, Rules rules, DateTime now) {
  final pc = rules.paintColor;
  final basic = data.colors.where((c) => c.basic).toList();
  final owned = [for (final c in data.colors) if (!c.basic) c];
  final ownedById = {for (final c in owned) c.colorId: c};
  final recent = [for (final id in data.recent) ?ownedById[id]];

  final current = seasonOf(kstDayKey(now), rules);
  // 지금 계절부터 거꾸로
  final seasonRank = {
    for (var i = 0; i < Season.values.length; i++)
      Season.values[(current.index - i) % Season.values.length]: i,
  };
  final colorRank = {for (final (i, id) in pc.colorIds.indexed) id: i};
  Season seasonOfColor(PaintStockView c) =>
      paintSeason(c.colorId) ?? seasonOf(kstDayKey(c.lastGotAt ?? now), rules);
  int baseRank(String id) => colorRank[id.substring(id.indexOf('.') + 1)] ?? colorRank.length;
  final seasonal = [for (final c in owned) if (pc.regionOf(c.colorId) == null) c]
    ..sort((a, b) {
      final s = seasonRank[seasonOfColor(a)]!.compareTo(seasonRank[seasonOfColor(b)]!);
      if (s != 0) return s;
      final r = baseRank(a.colorId).compareTo(baseRank(b.colorId));
      return r != 0 ? r : a.colorId.compareTo(b.colorId);
    });

  final regionRank = {for (final (i, r) in pc.regions.values.indexed) r.stockId: i};
  final regional = [for (final c in owned) if (pc.regionOf(c.colorId) != null) c]
    ..sort((a, b) => regionRank[a.colorId]!.compareTo(regionRank[b.colorId]!));

  return [
    for (final kind in pc.backpack.order)
      ?switch (kind) {
        PaintGroup.basic => null,
        PaintGroup.recent => (
            kind: kind,
            colors: [...basic, ...recent.take(math.max(0, pc.backpack.recentCount - basic.length))],
          ),
        PaintGroup.season => seasonal.isEmpty ? null : (kind: kind, colors: seasonal),
        PaintGroup.region => regional.isEmpty ? null : (kind: kind, colors: regional),
      },
  ];
}

/// 배낭 물감 탭 (캔버스 6-1 물감 탭, 16장 11/14·11/15·11/16): 가진 색만 선반에, 기본 물감은 늘 ‘최근’ 맨 앞(무제한,
/// 꼬리표 아래 줄 빈칸). 칸을 누르면 바로 그 색이 ‘쓰는 중’(확인 없음), 꼬리표 아래 줄은 쓰는 중이면 ‘쓰는 중’, 아니면
/// 남은 거리(config backpack.remainStep 단위 내림, ‘1.2 km’). 묶음([paintShelfGroups])은 제목을 누르면 접힌다.
/// 걷는 중(물감 길이 열린 동안)에도 고르고 그 순간부터 그 색으로 칠한다 (16장 11/16, config choose.whileWalking).
/// [canChoose]가 false면(config가 걷는 중 고르기를 끄면) 칸이 안 눌리고 안내 한 줄
///
/// 맨 위 무늬 줄 (T17b, config paintPattern.choose, 16장 11/19·11/20): 기본 방울 + 가진 무늬만(trails.json 차례, 0개면
/// 기본 방울 1칸). 칸 상태는 누름·쓰는 중 둘 (안 가진 칸·예시·잠긴 칸 없음). 누르면 바로 그 무늬가 ‘쓰는 중’이고
/// 걷는 중이면 그 순간부터 그 무늬로 칠한다. 새로 얻어도 저절로 고르지 않고, 안 본 무늬 칸에 새 표시 점
class PaintShelves extends StatefulWidget {
  const PaintShelves({
    super.key,
    required this.data,
    required this.rules,
    required this.now,
    required this.canChoose,
    required this.onChoose,
    this.canChoosePattern = true,
    this.onChoosePattern,
  });

  final PaintShelfData data;
  final Rules rules;

  /// 지금 계절을 정하는 시각
  final DateTime now;

  /// 지금 고를 수 있는가
  final bool canChoose;
  final ValueChanged<String> onChoose;

  /// 지금 무늬를 고를 수 있는가 (config paintPattern.choose.whileWalking)
  final bool canChoosePattern;
  final ValueChanged<String>? onChoosePattern;

  @override
  State<PaintShelves> createState() => _PaintShelvesState();
}

class _PaintShelvesState extends State<PaintShelves> {
  /// 접은 묶음. 처음은 config backpack.openOnStart: none이면 모두 접고, 그 밖은 모두 펼친다
  /// (캔버스 6-1 11/16은 처음에 모두 펼침, 묶음 안에 계절별 소제목이 없어서 currentSeason도 그대로 펼친다)
  late final Set<PaintGroup> _folded = {
    if (widget.rules.paintColor.backpack.collapsible &&
        widget.rules.paintColor.backpack.openOnStart == PaintOpenOnStart.none)
      ...PaintGroup.values,
  };

  @override
  Widget build(BuildContext context) {
    final groups = paintShelfGroups(widget.data, widget.rules, widget.now);
    final foldable = widget.rules.paintColor.backpack.collapsible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.canChoose)
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              paintChooseWhileWalkingLine,
              key: ValueKey('paint-walking-line'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Palette.subInk),
            ),
          ),
        if (widget.data.patterns.isNotEmpty) ...[
          _patternRow(),
          const SizedBox(height: 10),
        ],
        for (final (i, g) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _group(g, foldable: foldable),
        ],
      ],
    );
  }

  /// 맨 위 무늬 줄 (접지 않는다)
  Widget _patternRow() {
    final cells = widget.data.patterns;
    final onChoose = widget.onChoosePattern;
    return Container(
      key: const ValueKey('pattern-row'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(patternRowTitle, style: context.display(14))),
              Text('${cells.length}', style: AppText.label),
            ],
          ),
          const SizedBox(height: 8),
          ItemShelf(
            rowGap: 16,
            cells: [
              for (final (i, c) in cells.indexed)
                _PatternCell(
                  key: ValueKey('pattern-${c.id}'),
                  cell: c,
                  tilt: i,
                  using: c.id == widget.data.currentPattern,
                  onTap: widget.canChoosePattern && onChoose != null ? () => onChoose(c.id) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _group(PaintShelfGroup g, {required bool foldable}) {
    final key = g.kind.name;
    final folded = foldable && _folded.contains(g.kind);
    final header = Row(
      children: [
        Expanded(child: Text(paintGroupTitles[g.kind]!, style: context.display(14))),
        Text('${g.colors.length}', style: AppText.label),
        if (foldable)
          Icon(folded ? Icons.expand_more : Icons.expand_less, size: 20, color: Palette.subInk),
      ],
    );
    return Container(
      key: ValueKey('paint-group-$key'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (foldable)
            Semantics(
              button: true,
              expanded: !folded,
              child: GestureDetector(
                key: ValueKey('paint-fold-$key'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => folded ? _folded.remove(g.kind) : _folded.add(g.kind)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(alignment: Alignment.centerLeft, child: header),
                ),
              ),
            )
          else
            header,
          if (!folded) ...[
            const SizedBox(height: 8),
            ItemShelf(
              rowGap: 16,
              cells: [for (final (i, c) in g.colors.indexed) _cell(key, c, i)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String group, PaintStockView c, int i) {
    final pc = widget.rules.paintColor;
    final using = c.colorId == widget.data.current;
    return ItemCell(
      key: ValueKey('paint-$group-${c.colorId}'),
      name: pc.nameOf(c.colorId),
      art: SizedBox(
        width: 56,
        height: 56,
        child: PaintTubeArt(color: Color(pc.hexOf(c.colorId))),
      ),
      tilt: i,
      selected: using,
      state: using ? paintUsingLabel : (c.basic ? '' : formatKm(pc.backpack.remainKm(c.remainM))),
      stateColor: using ? Palette.terracotta : Palette.moss,
      onTap: widget.canChoose && !using ? () => widget.onChoose(c.colorId) : null,
    );
  }
}

/// 무늬 줄 칸 하나: 누르는 동안 그림이 조금 작아지고(누름), 쓰는 중이면 점선 고리 + ‘쓰는 중’ (config states pressed·inUse).
/// 쓰는 중인 칸은 다시 눌러도 아무 일이 없다
class _PatternCell extends StatefulWidget {
  const _PatternCell({
    super.key,
    required this.cell,
    required this.tilt,
    required this.using,
    required this.onTap,
  });

  final PatternCellView cell;
  final int tilt;
  final bool using;
  final VoidCallback? onTap;

  @override
  State<_PatternCell> createState() => _PatternCellState();
}

class _PatternCellState extends State<_PatternCell> {
  var _pressed = false;

  void _press(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final tap = widget.using ? null : widget.onTap;
    return Listener(
      onPointerDown: tap == null ? null : (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: ItemCell(
        name: widget.cell.pattern.name,
        art: AnimatedScale(
          key: const ValueKey('pattern-art'),
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 80),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: PatternArt(pattern: widget.cell.pattern)),
                if (!widget.cell.seen)
                  const Positioned(key: ValueKey('pattern-new'), right: -2, top: -2, child: NoticeDot()),
              ],
            ),
          ),
        ),
        tilt: widget.tilt,
        selected: widget.using,
        state: widget.using ? paintUsingLabel : '',
        stateColor: Palette.terracotta,
        onTap: tap,
      ),
    );
  }
}

/// 무늬 칸 그림: 아이콘 그림(trails.json icon, 없으면 이름에 무늬 id가 든 칸 그림)이 있으면 그 그림, 기본 방울은 코드로
/// 그린 방울 줄 (trails.json ‘아이콘은 앱이 방울 타일로 만듦’), 그 밖은 점선 칸 + 이름 (16장 11/6 그림 없는 소품 규칙)
class PatternArt extends ConsumerWidget {
  const PatternArt({super.key, required this.pattern});

  final TrailPattern pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetIndexProvider).value;
    final icon = pattern.icon;
    final path = (icon == null ? null : assets?.sprite(icon)) ?? assets?.itemIcon(pattern.id);
    final Widget none = pattern.kind == TrailUnlockKind.initial
        ? const CustomPaint(key: ValueKey('pattern-drops-art'), painter: _DropsIconPainter())
        : Center(child: ItemPlaceholder(name: pattern.name));
    return path == null ? none : ItemImage(path, size: const Size(56, 56), fallback: none);
  }
}

/// 기본 방울 칸 그림: 테라코타 방울 넷을 비스듬히 (지도 방울처럼 옅은 번짐 + 진한 속, 잉크 25% 테두리)
class _DropsIconPainter extends CustomPainter {
  const _DropsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.11;
    final outline = Paint()..color = Palette.ink.withValues(alpha: 0.25);
    final wash = Paint()..color = Palette.terracotta.withValues(alpha: 0.35);
    final core = Paint()..color = Palette.terracotta.withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      final t = (i + 0.5) / 4;
      final at = Offset(size.width * (0.14 + 0.72 * t), size.height * (0.66 - 0.32 * t));
      canvas
        ..drawCircle(at, r + 1, outline)
        ..drawCircle(at, r, wash)
        ..drawCircle(at, r * 0.62, core);
    }
  }

  @override
  bool shouldRepaint(_DropsIconPainter old) => false;
}
