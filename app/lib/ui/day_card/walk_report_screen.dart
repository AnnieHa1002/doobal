import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/report_providers.dart';
import '../../domain/day_card.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import 'day_card_view.dart' show dayBarOther;

/// 물감 길 붓과 연필 선 (캔버스 6-3·6-4)
const _brushWide = Color(0x52C97B54);
const _brushCore = Color(0xBFB5603A);
const _pencil = Color(0xFF7A6A5C);

/// 눈금·요일 글자 (11pt)
const _tick = TextStyle(fontSize: 11, color: Palette.subInk);

/// 요일 이름 (config report.weekStartsMonday 순서)
List<String> weekdayNames(bool startsMonday) => startsMonday
    ? const ['월', '화', '수', '목', '금', '토', '일']
    : const ['일', '월', '화', '수', '목', '금', '토'];

/// 가장 많이 걷는 때: 이웃한 두 시면 ‘저녁 6~8시’, 아니면 가장 많은 한 시 ‘아침 7~8시’. 걸음이 없으면 ‘-’
String peakHoursLabel(List<int> peak) {
  if (peak.isEmpty) return '-';
  var from = peak.first;
  var to = peak.first + 1;
  if (peak.length > 1 && (peak[0] - peak[1]).abs() == 1) {
    from = math.min(peak[0], peak[1]);
    to = from + 2;
  }
  final start = formatHourKo(from);
  final end = to % 12 == 0 ? 12 : to % 12;
  return '${start.substring(0, start.length - 1)}~$end시';
}

/// 비율(0~1)을 반올림한 % 두 개 (합 100). 둘 다 없으면 (0, 0)
(int, int) splitPercent(double share, {required bool any}) {
  if (!any) return (0, 0);
  final a = (share * 100).round();
  return (a, 100 - a);
}

/// 걷기 리포트 (캔버스 6-4): 하루 카드 ‘자세히 보기’와 노트 걷기 기록 맨 위 줄에서 연다. 공유 없음.
/// 기간 탭(config report.detailDays, 처음은 default) · 하루 평균 · 걷는 때(24칸) · 걷기·달리기 · 물감 길 · 요일.
/// 기간은 다 지난 날(카드 어제)까지, 설치한 날부터. 자료는 기기의 하루·분 걸음뿐
class WalkReportScreen extends ConsumerStatefulWidget {
  const WalkReportScreen({super.key});

  @override
  ConsumerState<WalkReportScreen> createState() => _WalkReportScreenState();
}

class _WalkReportScreenState extends ConsumerState<WalkReportScreen> {
  int? _days;

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value;
    final days = _days ?? rules?.report.defaultDetailDays;
    final report = days == null ? null : ref.watch(walkReportProvider(days));
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('걷기 리포트'),
            if (rules != null && days != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    for (final (i, d) in rules.report.detailDays.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _PeriodTab(
                          '$d일',
                          ValueKey('report-tab-$d'),
                          selected: d == days,
                          onTap: () => setState(() => _days = d),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: switch (report) {
                AsyncData(value: final r?) => _Body(r, startsMonday: rules!.report.weekStartsMonday),
                AsyncData() => const Center(
                    child: Text('아직 걷기 기록이 없어요', style: AppText.bodySub),
                  ),
                AsyncError() => const Center(
                    child: Text('리포트를 불러오지 못했어요', style: AppText.bodySub),
                  ),
                _ => const SizedBox(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 기간 탭 (노트 탭과 같은 모양)
class _PeriodTab extends StatelessWidget {
  const _PeriodTab(this.label, Key key, {required this.selected, required this.onTap})
      : super(key: key);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.terracotta : Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ink, width: InkLine.panel),
          ),
          child: Text(
            label,
            style: context.display(16, color: selected ? Palette.paper : Palette.ink),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.r, {required this.startsMonday});

  final WalkReport r;
  final bool startsMonday;

  @override
  Widget build(BuildContext context) {
    final any = r.walkSteps + r.runSteps > 0;
    final (walkPct, runPct) = splitPercent(1 - r.runRatio, any: any);
    final (trailPct, pencilPct) = splitPercent(r.trailRatio, any: r.actualM > 0);
    final names = weekdayNames(startsMonday);
    final peakDay = r.peakWeekday;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _Card(
          child: Row(
            children: [
              Expanded(child: _BigStat('하루 평균', '${formatInt(r.avgSteps)}보')),
              Expanded(child: _BigStat('하루 거리', formatKmShort(r.avgM))),
            ],
          ),
        ),
        _Card(
          title: '걷는 때',
          side: peakHoursLabel(r.peakHours),
          child: _HourBars(r),
        ),
        _Card(
          title: '걷기 · 달리기',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      if (walkPct > 0) Expanded(flex: walkPct, child: const ColoredBox(color: Palette.moss)),
                      if (runPct > 0)
                        Expanded(flex: runPct, child: const ColoredBox(color: Palette.terracotta)),
                      if (!any) const Expanded(child: ColoredBox(color: Palette.line)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _EndLabels('걷기 $walkPct%', '달리기 $runPct%'),
            ],
          ),
        ),
        _Card(
          title: '물감 길',
          side: '${formatKmShort(r.trailM)} / ${formatKmShort(r.actualM)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16, child: CustomPaint(painter: _TrailLinePainter(r.trailRatio))),
              const SizedBox(height: 8),
              _EndLabels('물감 길 $trailPct%', '연필 선 $pencilPct%'),
            ],
          ),
        ),
        _Card(
          title: '요일',
          side: peakDay == null ? '-' : '${names[peakDay]}요일',
          child: _WeekdayBars(r, names),
        ),
      ],
    );
  }
}

/// 리포트 카드 하나: 위에 굵은 제목과 오른쪽 작은 값 (있으면)
class _Card extends StatelessWidget {
  const _Card({required this.child, this.title, this.side});

  final Widget child;
  final String? title;
  final String? side;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text(title, style: context.display(16))),
                  if (side != null)
                    Text(side!, style: const TextStyle(fontSize: 13, color: Palette.subInk)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Palette.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      );
}

class _EndLabels extends StatelessWidget {
  const _EndLabels(this.left, this.right);

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: const TextStyle(fontSize: 12, color: Palette.ink)),
          Text(right, style: const TextStyle(fontSize: 12, color: Palette.ink)),
        ],
      );
}

/// 시간대별 걸음 24칸 (높이 = max(2, 걸음 ÷ 최댓값 × 70), 가장 많은 두 칸 테라코타) + 눈금
class _HourBars extends StatelessWidget {
  const _HourBars(this.r);

  final WalkReport r;

  @override
  Widget build(BuildContext context) {
    final most = r.hourSteps.reduce(math.max);
    final peak = r.peakHours.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '시간대별 걸음: ${peakHoursLabel(r.peakHours)}에 많음',
          child: ExcludeSemantics(
            child: Container(
              height: 72,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Palette.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var h = 0; h < 24; h++) ...[
                    if (h > 0) const SizedBox(width: 2),
                    Expanded(
                      child: Container(
                        key: ValueKey('hour-bar-$h'),
                        height: most == 0
                            ? 2
                            : math.max(2, (r.hourSteps[h] / most * 70).roundToDouble()),
                        decoration: BoxDecoration(
                          color: peak.contains(h) ? Palette.terracotta : dayBarOther,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final t in const ['0시', '6시', '12시', '18시', '24시']) Text(t, style: _tick),
          ],
        ),
      ],
    );
  }
}

/// 요일마다 하루 평균 걸음 7칸 (가장 많은 요일 테라코타)
class _WeekdayBars extends StatelessWidget {
  const _WeekdayBars(this.r, this.names);

  final WalkReport r;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final most = r.weekdaySteps.reduce(math.max);
    final peak = r.peakWeekday;
    return Semantics(
      label: '요일별 하루 걸음: '
          '${[for (var i = 0; i < 7; i++) '${names[i]} ${formatInt(r.weekdaySteps[i])}보'].join(', ')}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        key: ValueKey('weekday-bar-$i'),
                        width: 26,
                        height: most == 0 ? 0 : (r.weekdaySteps[i] / most * 56).roundToDouble(),
                        decoration: BoxDecoration(
                          color: i == peak ? Palette.terracotta : dayBarOther,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4), bottom: Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(names[i], style: _tick),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 연필 선 끝까지 + 물감 붓을 [ratio]만큼 (캔버스 6-4)
class _TrailLinePainter extends CustomPainter {
  const _TrailLinePainter(this.ratio);

  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const inset = 4.0;
    final pencil = Paint()
      ..color = _pencil
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), pencil);
    if (ratio <= 0) return;
    final end = inset + (size.width - inset * 2) * ratio.clamp(0.0, 1.0);
    for (final (color, width) in [(_brushWide, 12.0), (_brushCore, 5.0)]) {
      canvas.drawLine(
        Offset(inset, y),
        Offset(end, y),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailLinePainter oldDelegate) => oldDelegate.ratio != ratio;
}
