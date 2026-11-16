import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/paint_service.dart';
import '../../domain/paint_color.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart' show Season, seasonOf;
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/item_cell.dart';
import '../common/paint_art.dart';
import '../common/palette.dart';

/// 물감 탭 글 (가안: 캔버스에 없는 흐름). 걷는 중에 못 고르는 안내는 config choose.whileWalking이 false일 때만
const paintChooseWhileWalkingLine = '걷는 중에는 물감을 고르지 않아요';
const paintUsingLabel = '쓰는 중';

/// 묶음 이름 (캔버스 6-1, 11/16)
const paintGroupTitles = {
  PaintGroup.recent: '최근',
  PaintGroup.season: '계절 색',
  PaintGroup.region: '지역 색',
};

/// 배낭 물감 탭 묶음 하나: 묶음 종류와 칸 (차례대로)
typedef PaintShelfGroup = ({PaintGroup kind, List<PaintStockView> colors});

/// 배낭 물감 탭 묶음 (캔버스 6-1 11/16 ‘묶음 3개’, config paintColor.backpack.order·recentCount):
/// - 최근: 기본 물감이 늘 맨 앞 + 마지막으로 주운 색 (recentCount − 1)칸 (첫날은 기본 한 칸)
/// - 계절 색: 지금 계절 → 지난 계절 차례(가을이면 가을·여름·봄·겨울), 계절 안은 16색 차례. 계절이 없는 키(1단계에서 모은 것)는
///   마지막으로 주운 날의 계절에 든다
/// - 지역 색: config region.colors 차례
/// 같은 색이 최근과 계절·지역에 둘 다 있어도 된다 (캔버스 6-1 메모). 빈 묶음은 없다
List<PaintShelfGroup> paintShelfGroups(PaintShelfData data, Rules rules, DateTime now) {
  final pc = rules.paintColor;
  final basic = data.colors.where((c) => c.basic).toList();
  final owned = [for (final c in data.colors) if (!c.basic) c];
  final recent = [...owned]..sort((a, b) => b.lastGotAt!.compareTo(a.lastGotAt!));

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
class PaintShelves extends StatefulWidget {
  const PaintShelves({
    super.key,
    required this.data,
    required this.rules,
    required this.now,
    required this.canChoose,
    required this.onChoose,
  });

  final PaintShelfData data;
  final Rules rules;

  /// 지금 계절을 정하는 시각
  final DateTime now;

  /// 지금 고를 수 있는가
  final bool canChoose;
  final ValueChanged<String> onChoose;

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
        for (final (i, g) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _group(g, foldable: foldable),
        ],
      ],
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
