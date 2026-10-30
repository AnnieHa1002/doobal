import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/milestones.dart';
import '../../domain/rules.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/big_number.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/ink_bar.dart';
import '../common/ink_card.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import 'session_line.dart';

/// 진행 막대가 걷기 전 비율에서 지금 비율까지 차오르는 시간
const _barDuration = Duration(milliseconds: 1200);

/// 걷기 기록 (걷기 마치기 직후). 열자마자 동기화를 한 번 하고 [start, end)의 기록을 계산한다.
/// [ratioBefore]는 걷기 전 여정 진행 비율 (여정이 없으면 null).
/// [review]는 노트에서 지난 걷기를 다시 보는 모드: 동기화하지 않고(마지막 동기화 시각이 과거로
/// 돌아가지 않게), 진행 막대 연출과 `쉼터로` 대신 뒤로 가기만 둔다
class WalkRecordScreen extends ConsumerStatefulWidget {
  const WalkRecordScreen({
    super.key,
    required this.start,
    required this.end,
    required this.ratioBefore,
    this.review = false,
  });

  final DateTime start;
  final DateTime end;
  final double? ratioBefore;
  final bool review;

  @override
  ConsumerState<WalkRecordScreen> createState() => _WalkRecordScreenState();
}

class _WalkRecordScreenState extends ConsumerState<WalkRecordScreen> {
  WalkRecord? _record;
  Snapshot? _snapshot;

  /// 다시 볼 때만: 그날 인정된 걷기 1번 중 이 걷기가 몇 번째인지
  int? _nth;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = await ref.read(syncServiceProvider.future);
      if (!widget.review) await svc.sync(widget.end);
      final record = await svc.walkRecord(widget.start, widget.end);
      final nth =
          widget.review ? await ref.read(statsServiceProvider).countedNth(widget.start) : null;
      // 기다리는 동안 화면을 떠났으면 ref를 더 쓰지 않는다
      if (!mounted) return;
      final snap = widget.review
          ? await ref.read(snapshotProvider.future)
          : await ref.refresh(snapshotProvider.future);
      if (!mounted) return;
      setState(() {
        _record = record;
        _snapshot = snap;
        _nth = nth;
      });
    } catch (e) {
      debugPrint('걷기 기록 실패: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value;
    final milestones = ref.watch(milestonesProvider).value;
    final record = _record;
    final snap = _snapshot;

    final Widget card;
    if (_error != null) {
      card = const InkCard(child: Text('기록을 불러오지 못했어요', style: AppText.body));
    } else if (record == null || snap == null || rules == null) {
      card = const InkCard(child: Text('기록을 정리하는 중', style: AppText.body));
    } else {
      card = InkCard(child: _content(rules, record, snap, milestones));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.review)
              const ScreenHeader('걷기 기록')
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('걷기 기록', style: AppText.title),
              ),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: card)),
            if (!widget.review)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GameButton(
                  label: '쉼터로',
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 다시 볼 때 맨 위에 보이는 그 걷기의 날짜와 시각: '11월 18일 14:05 ~ 14:35'
  String get _whenText =>
      '${formatMonthDay(kstDate(widget.start))} ${formatKstClock(widget.start)} ~ '
      '${formatKstClock(widget.end)}';

  /// 걷기 1번 줄. 다시 볼 때 그날이 오늘이 아니면 오늘 대신 날짜로 부르고, 그날 몇 번째인지를 쓴다
  String _sessionText(Rules rules, WalkRecord record) {
    if (!widget.review) return sessionLine(record, rules);
    final today = kstDayKey(ref.read(clockProvider)());
    final day = kstDayKey(widget.start);
    return sessionLine(
      record,
      rules,
      dayLabel: day == today ? '오늘' : formatMonthDay(kstDate(widget.start)),
      nth: _nth,
    );
  }

  Widget _content(Rules rules, WalkRecord record, Snapshot snap, List<int>? milestones) {
    final s = record.summary;
    final run = s.runRatio;
    final j = snap.journey;
    final left = milestones == null ? null : stepsToNextMilestone(snap.totalSteps, milestones);
    final before = widget.ratioBefore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.review) ...[
          Text(_whenText, style: AppText.bodySub),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            _Big(BigNumber(formatInt(s.steps)), '걸음'),
            _Big(BigNumber((s.distanceM / 1000).toStringAsFixed(2), unit: 'km'), '거리'),
            _Big(BigNumber(formatDuration(widget.end.difference(widget.start))), '시간'),
          ],
        ),
        const SizedBox(height: 16),
        InkBar(segments: [
          BarSegment(1 - run, Palette.moss),
          BarSegment(run, Palette.terracotta),
        ]),
        const SizedBox(height: 4),
        Text(
          '걷기 ${((1 - run) * 100).round()}% · 달리기 ${(run * 100).round()}%',
          style: AppText.label,
        ),
        const SizedBox(height: 16),
        Text(
          _sessionText(rules, record),
          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        // 다시 볼 때는 걷기 전 비율을 몰라서 진행 막대 연출이 없다
        if (!widget.review && j != null && before != null) ...[
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: before, end: j.progress.ratio),
            duration: _barDuration,
            curve: Curves.easeOut,
            builder: (context, v, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkBar(segments: [BarSegment(v, Palette.moss)]),
                const SizedBox(height: 4),
                Text('${j.dest.name}까지 ${(v * 100).round()}% 왔어요', style: AppText.bodySub),
              ],
            ),
          ),
        ],
        if (left != null) ...[
          const SizedBox(height: 12),
          Text('다음 방명록 지점까지 ${formatInt(left)}보', style: AppText.bodySub),
        ],
      ],
    );
  }
}

/// 큰 숫자 + 이름 (라벨 12)
class _Big extends StatelessWidget {
  const _Big(this.number, this.label);

  final Widget number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          number,
          Text(label, style: AppText.label),
        ],
      ),
    );
  }
}
