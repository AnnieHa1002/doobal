import '../common/app_text.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/gait.dart';
import '../../domain/rules.dart';
import '../../domain/walk_record.dart';
import '../common/focus_badge.dart';
import '../common/format.dart';
import '../common/palette.dart';

/// 걷는 중 위·아래 UI (UI 명세 3장 10/30판). 큰 패널 대신
/// ① 얇은 진행 줄(글자 없음) ② 걸음 알약 ③ 알약을 누르면 펼쳐지는 숫자 카드(8초 뒤 접힘)
/// ④ 아래 ‘걷기 마치기’ 알약. 배경(SceneView) 위에 Stack으로 얹는다.
/// 본격 걷기 중이면([focusBadge]) 걸음 알약 오른쪽 끝에 이끼색 딱지(`×1.3`)가 붙는다.
/// 아이콘은 ui_icon SVG를 넣기 전까지 Material 아이콘으로 대신한다
class WalkingHud extends StatefulWidget {
  const WalkingHud({
    super.key,
    required this.rules,
    required this.snap,
    required this.summary,
    required this.shownM,
    required this.shownSteps,
    required this.walkingTime,
    required this.running,
    required this.nextMilestone,
    required this.onFinish,
    this.focusBadge,
    this.event,
    this.eventKm = 2,
    this.onCloseEvent,
    this.badgeLine,
    this.storyLine,
  });

  final Rules rules;
  final Snapshot snap;
  final WalkSummary? summary;

  /// 화면에 보이는 이번 걷기 거리(m)
  final double shownM;

  /// 걸음 알약에 보이는 걸음 수 (걷는 중 화면이 부드럽게 따라 올린 값, CountFollower)
  final int shownSteps;
  final Duration walkingTime;
  final bool running;

  /// 다음 방명록 지점까지 남은 걸음. 없으면 null
  final int? nextMilestone;
  final VoidCallback onFinish;

  /// 본격 걷기 중일 때 걸음 알약에 붙는 배수 글(`×1.3`). 아니면 null
  final String? focusBadge;

  /// 지금 보여 줄 길 위 이벤트 카드(2km 이정표)와 그 칸의 크기(km, config events.everyKm). 없으면 null
  final RoadEventView? event;
  final double eventKm;
  final VoidCallback? onCloseEvent;

  /// 걸음 알약 아래 작은 줄: 새 도장 문구. 없으면 null
  final String? badgeLine;

  /// 펼침 카드의 동행 줄: ‘퐁이 이야기 2/4’. 혼자 걷는 중이면 null
  final String? storyLine;

  @override
  State<WalkingHud> createState() => _WalkingHudState();
}

/// 크기·위치 (pt, 레이어 조정기 시안 px ÷ 3)
abstract final class HudMetrics {
  static const lineTop = 50.0;
  static const lineSide = 20.0;
  static const lineSideLandscape = 23.0;
  static const lineHeight = 3.0;
  static const pillGap = 13.0;
  static const pillMinWidth = 143.0;

  /// 본격 걷기 딱지가 붙으면 알약 최소 폭이 이만큼 는다 (딱지 폭 + 간격)
  static const pillBadgeExtra = 40.0;
  static const pillHeight = 32.0;
  static const finishWidth = 120.0;
  static const finishHeight = 44.0;
  static const bottomGap = 16.0;
  static const collapseAfter = Duration(seconds: 8);

  /// 시험에서만: 이정표 카드·새 도장 줄이 떠 있는 시간을 바꾼다.
  /// null이면 config 값(hud.eventCardSec·stampLineSec)
  static Duration? eventCardOverride;
  static Duration? badgeLineOverride;
}

class _WalkingHudState extends State<WalkingHud> {
  var _expanded = false;
  Timer? _collapse;

  @override
  void dispose() {
    _collapse?.cancel();
    super.dispose();
  }

  void _toggle() {
    _collapse?.cancel();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _collapse = Timer(HudMetrics.collapseAfter, () {
        if (mounted) setState(() => _expanded = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final side = landscape ? HudMetrics.lineSideLandscape : HudMetrics.lineSide;
    // 세로는 화면 위에서 50pt, 가로는 13pt. 노치·상태 표시줄보다는 아래에 둔다
    final top = math.max(
        landscape ? HudMetrics.pillGap : HudMetrics.lineTop, mq.padding.top + 4);
    final j = widget.snap.journey;

    return Stack(
      children: [
        Positioned(
          top: top,
          left: side + mq.padding.left,
          right: side + mq.padding.right,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressLine(ratio: j?.progress.ratio ?? 0),
              const SizedBox(height: HudMetrics.pillGap),
              StepPill(
                steps: widget.shownSteps,
                km: widget.shownM / 1000,
                running: widget.running,
                badge: widget.focusBadge,
                onTap: _toggle,
              ),
              if (widget.badgeLine != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _BadgeLine(widget.badgeLine!),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.topLeft,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _DetailCard(widget: widget),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              if (widget.event != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: MilestoneCard(
                    event: widget.event!,
                    everyKm: widget.eventKm,
                    onClose: widget.onCloseEvent,
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          bottom: mq.padding.bottom + HudMetrics.bottomGap,
          left: landscape ? null : 0,
          right: landscape ? side + mq.padding.right : 0,
          child: Align(
            alignment: landscape ? Alignment.centerRight : Alignment.center,
            child: FinishPill(onPressed: widget.onFinish),
          ),
        ),
      ],
    );
  }
}

/// 출발지 → 목적지 진행률. 높이 3pt 둥근 줄, 바탕 잉크 25%, 채움 카드색. 글자 없음
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final r = ratio.clamp(0.0, 1.0);
    return Semantics(
      label: '여정 ${(r * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HudMetrics.lineHeight / 2),
        child: SizedBox(
          height: HudMetrics.lineHeight,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: Palette.ink.withValues(alpha: 0.25))),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: r,
                heightFactor: 1,
                child: const ColoredBox(color: Palette.card),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _tabular = [FontFeature.tabularFigures()];

/// 카드색 90% 알약 + 잉크 테두리. 걷기/뛰기 아이콘 + 이번 걸음 수 + ‘걸음 · 1.99 km’.
/// 본격 걷기 중이면 [badge](`×1.3`)가 오른쪽 끝에 이끼색 딱지로 붙고 알약 폭이 40pt 는다.
/// 글자를 키워서 알약이 칸보다 넓어지면 안의 글을 통째로 줄인다
class StepPill extends StatelessWidget {
  const StepPill({
    super.key,
    required this.steps,
    required this.km,
    required this.running,
    required this.onTap,
    this.badge,
  });

  final int steps;
  final double km;
  final bool running;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: running ? '달리는 중' : '걷는 중',
      child: GestureDetector(
        key: const Key('walk-pill'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minWidth: HudMetrics.pillMinWidth + (badge == null ? 0 : HudMetrics.pillBadgeExtra),
            minHeight: HudMetrics.pillHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Palette.card.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(HudMetrics.pillHeight / 2),
            border: Border.all(color: Palette.ink, width: InkLine.pill),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  running ? Icons.directions_run : Icons.directions_walk,
                  size: 16,
                  color: Palette.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  formatInt(steps),
                  style: context.display(18).copyWith(fontFeatures: _tabular),
                ),
                const SizedBox(width: 6),
                Text(
                  '걸음 · ${formatKm(km, digits: 2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 12 * 0.08,
                    color: Palette.subInk,
                    fontFeatures: _tabular,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  FocusBadge(badge!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 걸음 알약을 누르면 아래로 펼쳐지는 숫자 카드
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.widget});

  final WalkingHud widget;

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final snap = widget.snap;
    final j = snap.journey;
    final spm = widget.summary?.lastSteps ?? 0;
    final gait = widget.summary?.lastGait ?? Gait.walk;
    final pace = livePaceSecPerKm(spm, gait, rules);

    return Container(
      key: const Key('walk-detail'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: InkLine.pill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line('걷기 시간', formatDuration(widget.walkingTime)),
          _Line('분당 걸음', '$spm보'),
          _Line('속도', '${speedKmh(spm, gait, rules).toStringAsFixed(1)} km/h'),
          _Line('페이스', pace == null ? '-' : '${formatPace(pace)}/km'),
          _Line('보폭', '${strideM(gait, rules).toStringAsFixed(2)} m'),
          _Line('오늘 걸음', '${formatInt(snap.todaySteps)}보'),
          if (j != null) ...[
            _Line('${j.dest.name}까지', formatKm(j.progress.remainingKm)),
            _Line('도착 예정일', formatMonthDay(j.eta)),
          ],
          if (widget.nextMilestone != null)
            _Note('다음 방명록 지점까지 ${formatInt(widget.nextMilestone!)}보'),
          _Note(widget.storyLine ?? '혼자 걷는 중'),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Palette.subInk)),
          ),
          const Spacer(),
          Text(value,
              style: context.display(14).copyWith(fontFeatures: _tabular)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 14, color: Palette.subInk)),
      );
}

/// 보조 버튼 ‘걷기 마치기’. 120×44pt 알약, 카드색 90% + 잉크 테두리
/// (주 버튼이 아님: 실수로 끝내지 않게)
class FinishPill extends StatelessWidget {
  const FinishPill({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: HudMetrics.finishWidth,
          height: HudMetrics.finishHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.card.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(HudMetrics.finishHeight / 2),
            border: Border.all(color: Palette.ink, width: InkLine.pill),
          ),
          child: Text(
            '걷기 마치기',
            style: context.display(15),
          ),
        ),
      ),
    );
  }
}

/// 새 도장을 받았을 때 걸음 알약 아래에 잠깐 뜨는 작은 줄 (캔버스 Walk의 도장 줄).
/// 카드색 92% + 잉크 1.4 선, 앞에 테라코타 체크 원
class _BadgeLine extends StatelessWidget {
  const _BadgeLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('walk-badge-line'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Palette.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.ink, width: InkLine.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 20, color: Palette.terracotta),
            const SizedBox(width: 8),
            Flexible(child: Text(text, style: const TextStyle(fontSize: 13, color: Palette.ink))),
          ],
        ),
      ),
    );
  }
}

/// 길 위 이벤트 카드 `2km 이정표` (UI 명세, 캔버스 Walk): 위 줄 기록 칭찬, 아래 줄 풍경 한 줄.
/// 버튼·판정 없음. 몇 초 뒤 걷는 중 화면이 치우고, 위 접기 버튼으로 바로 접을 수도 있다.
/// 칸 크기는 config라 제목의 km는 [everyKm]에서 읽는다
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({super.key, required this.event, required this.everyKm, this.onClose});

  final RoadEventView event;
  final double everyKm;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final km = everyKm == everyKm.roundToDouble() ? '${everyKm.round()}' : '$everyKm';
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('walk-event-card'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Palette.ink, width: InkLine.panel),
          boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 22, color: Palette.ink),
                const SizedBox(width: 8),
                Expanded(child: Text('${km}km 이정표', style: context.display(17))),
                GestureDetector(
                  key: const Key('walk-event-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: const SizedBox(
                    width: 44,
                    height: 24,
                    child: Icon(Icons.keyboard_arrow_up, size: 22, color: Palette.subInk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.praiseText,
                key: const Key('walk-event-praise'),
                style: const TextStyle(fontSize: 15, height: 1.45, color: Palette.ink)),
            const SizedBox(height: 8),
            Text(event.sceneText,
                key: const Key('walk-event-scene'),
                style: const TextStyle(fontSize: 14, height: 1.45, color: Palette.subInk)),
          ],
        ),
      ),
    );
  }
}
