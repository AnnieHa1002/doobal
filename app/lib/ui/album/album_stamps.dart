import 'package:flutter/material.dart';

import '../../domain/badge.dart' as stamp;
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/palette.dart';

/// 화집 도장 탭 (캔버스 Gallery): 묶음마다 카드 하나, 안에 4열 도장 칸. 받은 도장은 진하게(테라코타 고리 +
/// 이름 + 받은 날), 못 받은 도장은 흐린 고리에 이름과 조건 글. 진행도·자물쇠는 없다.
/// 도장 아이콘 그림(ui_stamp_*)이 리포에 들어오기 전까지는 Material 아이콘 자리표시

const _stampColumns = 4;
const _ringSize = 52.0;

/// 도장 id → 자리표시 아이콘 (캔버스의 걷기·해·달·산·물결·잎·배·액자·팔레트). 모르는 id는 묶음 기본
IconData stampIcon(stamp.Badge b) => switch (b.id) {
      'b_dawn' || 'b_sunset' => Icons.wb_twilight,
      'b_night' => Icons.nightlight_round,
      'b_day_10k' || 'b_day_20k' => Icons.wb_sunny_outlined,
      'b_mountain' => Icons.landscape,
      'b_coast' => Icons.waves,
      'b_field' || 'b_seasons' => Icons.eco_outlined,
      'b_city' || 'b_first_gold' => Icons.filter_frames_outlined,
      'b_first_boat' => Icons.directions_boat_outlined,
      'b_first_arrival' || 'b_first_finale' => Icons.palette_outlined,
      'b_all_friends' => Icons.group_outlined,
      _ => Icons.directions_walk,
    };

/// 도장 탭 내용: [owned]는 받은 도장 id → 받은 시각. 칸을 누르면 받은 도장의 이름·설명·받은 날
class StampSections extends StatelessWidget {
  const StampSections({super.key, required this.sections, required this.owned});

  final List<stamp.BadgeSection> sections;
  final Map<String, DateTime> owned;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Section(section: s, owned: owned),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.owned});

  final stamp.BadgeSection section;
  final Map<String, DateTime> owned;

  @override
  Widget build(BuildContext context) {
    final got = section.badges.where((b) => owned.containsKey(b.id)).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(section.name, style: context.display(14))),
              Text('$got / ${section.badges.length}',
                  style: const TextStyle(fontSize: 12, color: Palette.subInk)),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            const gap = 6.0;
            final w = (c.maxWidth - gap * (_stampColumns - 1)) / _stampColumns;
            return Wrap(
              spacing: gap,
              runSpacing: 10,
              children: [
                for (final b in section.badges)
                  SizedBox(
                    width: w,
                    child: _StampCell(badge: b, at: owned[b.id]),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _StampCell extends StatelessWidget {
  const _StampCell({required this.badge, required this.at});

  final stamp.Badge badge;

  /// 받은 시각. 못 받았으면 null
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final got = at != null;
    final ring = Container(
      width: _ringSize,
      height: _ringSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: got ? const Color(0xFFF6E6D6) : Colors.transparent,
        border: Border.all(
          color: got ? Palette.terracotta : Palette.ink.withValues(alpha: 0.18),
          width: got ? 2.5 : 2,
        ),
      ),
      child: Icon(stampIcon(badge),
          size: 24, color: got ? Palette.terracotta : Palette.ink.withValues(alpha: 0.18)),
    );
    return Semantics(
      button: got,
      label: got ? '${badge.name} 도장' : '${badge.name} 도장, 아직 못 받음. ${badge.desc}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('stamp-${badge.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: got ? () => showStampSheet(context, badge, at!) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            children: [
              got ? Transform.rotate(angle: -8 * 3.1415926 / 180, child: ring) : ring,
              const SizedBox(height: 3),
              Text(badge.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, height: 1.25, color: Palette.ink)),
              Text(got ? formatMonthDay(kstDate(at!)) : badge.desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, height: 1.2, color: Palette.subInk)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 받은 도장을 누르면 아래에서 올라오는 시트: 이름, 설명, 받은 날
Future<void> showStampSheet(BuildContext context, stamp.Badge badge, DateTime at) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: Palette.ink, width: InkLine.panel),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        key: const ValueKey('stamp-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(stampIcon(badge), size: 28, color: Palette.terracotta),
                const SizedBox(width: 10),
                Expanded(child: Text(badge.name, style: context.display(21))),
              ],
            ),
            const SizedBox(height: 10),
            Text(badge.desc, style: const TextStyle(fontSize: 15, color: Palette.ink)),
            const SizedBox(height: 6),
            Text('${formatMonthDay(kstDate(at))}에 받았어요',
                style: const TextStyle(fontSize: 13, color: Palette.subInk)),
          ],
        ),
      ),
    ),
  );
}
