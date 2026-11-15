import 'package:flutter/material.dart';

import '../../app/paint_service.dart';
import '../../domain/paint_color.dart';
import '../../domain/sky.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/item_cell.dart';
import '../common/paint_art.dart';
import '../common/palette.dart';

/// 물감 색 이름 (화면 글): 시간대·날씨 이름, 뛰기면 앞에 ‘진한’(16장 11/15 디자인 기획 ‘진한 ○○’),
/// 계절이 붙은 id면 계절 이름을 앞에(‘가을 진한 노을’, 16장 11/15). 기본 물감은 ‘기본’
const _phaseNames = {
  SkyPhase.dawn: '새벽',
  SkyPhase.morning: '아침',
  SkyPhase.day: '낮',
  SkyPhase.sunset: '노을',
  SkyPhase.night: '밤',
};
const _weatherNames = {
  PaintWeather.rain: '비',
  PaintWeather.snow: '눈',
  PaintWeather.cloudy: '흐림',
};
const _seasonNames = {'spring': '봄', 'summer': '여름', 'autumn': '가을', 'winter': '겨울'};

/// 물감 탭 글 (가안: 캔버스에 없는 흐름)
const paintChooseWhileWalkingLine = '걷는 중에는 물감을 고르지 않아요';
const paintUsingLabel = '쓰는 중';

String paintColorName(String id, PaintColorRules rules) {
  if (id == rules.defaultId) return '기본';
  if (id.startsWith('region.')) {
    // 지역 색 이름은 권역 데이터가 오면 (16장 11/15). 그전에는 권역 이름만
    final region = id.substring(id.lastIndexOf('.') + 1);
    return regionLabels[region] ?? '지역 색';
  }
  final base = paintBase(id);
  if (base == null) return id;
  final name = base.phase != null ? _phaseNames[base.phase]! : _weatherNames[base.weather]!;
  final dot = id.indexOf('.');
  final season = dot < 0 ? null : _seasonNames[id.substring(0, dot)];
  return [?season, if (base.run) '진한', name].join(' ');
}

/// 배낭 물감 탭 (캔버스 6-1 물감 탭, 16장 11/14·11/15): 가진 색만 선반에, 기본 물감은 늘 맨 앞(무제한, 꼬리표 빈칸).
/// 칸을 누르면 바로 그 색이 ‘쓰는 중’(확인 없음), 꼬리표 아래 줄은 쓰는 중이면 ‘쓰는 중’, 아니면 남은 거리.
/// 가진 색이 3개보다 많으면 맨 위에 최근 주운 3칸 선반을 따로 둔다. 묶음은 접을 수 있다
/// (계절 색·지역 색 묶음은 개발 기획의 config가 오면 이 ‘모은 색’을 나눈다).
/// 걷는 중(물감 길이 열린 동안)에는 고르지 않는다 (config paintColor.choose.whileWalking)
class PaintShelves extends StatefulWidget {
  const PaintShelves({
    super.key,
    required this.data,
    required this.rules,
    required this.canChoose,
    required this.onChoose,
  });

  final PaintShelfData data;
  final PaintColorRules rules;

  /// 지금 고를 수 있는가 (걷는 중이 아니다)
  final bool canChoose;
  final ValueChanged<String> onChoose;

  @override
  State<PaintShelves> createState() => _PaintShelvesState();
}

class _PaintShelvesState extends State<PaintShelves> {
  /// 접은 묶음 이름
  final _folded = <String>{};

  @override
  Widget build(BuildContext context) {
    final colors = widget.data.colors;
    final owned = [for (final c in colors) if (!c.basic) c];
    final recent = [...owned]..sort((a, b) => b.lastGotAt!.compareTo(a.lastGotAt!));
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
        if (owned.length > 3) ...[
          _group('recent', '최근', recent.take(3).toList(), foldable: false),
          const SizedBox(height: 10),
        ],
        _group('all', '모은 색', colors, foldable: owned.isNotEmpty),
      ],
    );
  }

  Widget _group(String key, String title, List<PaintStockView> colors, {required bool foldable}) {
    final folded = foldable && _folded.contains(key);
    final header = Row(
      children: [
        Expanded(child: Text(title, style: context.display(14))),
        Text('${colors.length}', style: AppText.label),
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
                onTap: () => setState(() => folded ? _folded.remove(key) : _folded.add(key)),
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
              cells: [for (final (i, c) in colors.indexed) _cell(key, c, i)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String group, PaintStockView c, int i) {
    final using = c.colorId == widget.data.current;
    return ItemCell(
      key: ValueKey('paint-$group-${c.colorId}'),
      name: paintColorName(c.colorId, widget.rules),
      art: SizedBox(
        width: 56,
        height: 56,
        child: PaintTubeArt(color: Color(widget.rules.hexOf(c.colorId))),
      ),
      tilt: i,
      selected: using,
      state: using ? paintUsingLabel : (c.basic ? '' : formatKm(c.remainM / 1000)),
      stateColor: using ? Palette.terracotta : Palette.moss,
      onTap: widget.canChoose && !using ? () => widget.onChoose(c.colorId) : null,
    );
  }
}
