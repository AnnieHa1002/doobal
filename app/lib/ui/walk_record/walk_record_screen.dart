import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/milestones.dart';
import '../../domain/rules.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/ink_bar.dart';
import '../common/palette.dart';
import 'session_line.dart';

/// 진행 막대가 걷기 전 비율에서 지금 비율까지 차오르는 시간
const _barDuration = Duration(milliseconds: 1200);

/// 걷기 기록 (걷기 마치기 직후). 열자마자 동기화를 한 번 하고 [start, end)의 기록을 계산한다.
/// [ratioBefore]는 걷기 전 여정 진행 비율 (여정이 없으면 null)
class WalkRecordScreen extends ConsumerStatefulWidget {
  const WalkRecordScreen({
    super.key,
    required this.start,
    required this.end,
    required this.ratioBefore,
  });

  final DateTime start;
  final DateTime end;
  final double? ratioBefore;

  @override
  ConsumerState<WalkRecordScreen> createState() => _WalkRecordScreenState();
}

class _WalkRecordScreenState extends ConsumerState<WalkRecordScreen> {
  WalkRecord? _record;
  Snapshot? _snapshot;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.sync(widget.end);
      final record = await svc.walkRecord(widget.start, widget.end);
      // 기다리는 동안 화면을 떠났으면 ref를 더 쓰지 않는다
      if (!mounted) return;
      final snap = await ref.refresh(snapshotProvider.future);
      if (!mounted) return;
      setState(() {
        _record = record;
        _snapshot = snap;
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
      card = const _Card(child: Text('기록을 불러오지 못했어요'));
    } else if (record == null || snap == null || rules == null) {
      card = const _Card(child: Text('기록을 정리하는 중'));
    } else {
      card = _Card(child: _content(rules, record, snap, milestones));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '걷기 기록',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ink),
              ),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(child: card)),
              const SizedBox(height: 16),
              GameButton(
                label: '쉼터로',
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(Rules rules, WalkRecord record, Snapshot snap, List<int>? milestones) {
    const small = TextStyle(fontSize: 14, color: Palette.subInk);
    final s = record.summary;
    final run = s.runRatio;
    final j = snap.journey;
    final next = milestones == null ? null : nextMilestone(snap.totalSteps, milestones);
    final before = widget.ratioBefore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Big(formatInt(s.steps), '걸음'),
            _Big(formatKm(s.distanceM / 1000, digits: 2), '거리'),
            _Big(formatDuration(widget.end.difference(widget.start)), '시간'),
          ],
        ),
        const SizedBox(height: 16),
        InkBar(segments: [
          BarSegment(1 - run, Palette.moss),
          BarSegment(run, Palette.terracotta),
        ]),
        const SizedBox(height: 4),
        Text('걷기 ${((1 - run) * 100).round()}% · 달리기 ${(run * 100).round()}%', style: small),
        const SizedBox(height: 16),
        Text(
          sessionLine(record, rules),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink),
        ),
        if (j != null && before != null) ...[
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
                Text('${j.dest.name}까지 ${(v * 100).round()}% 왔어요', style: small),
              ],
            ),
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: 12),
          Text('다음 방명록 지점까지 ${formatInt(next - snap.totalSteps)}보', style: small),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: child,
    );
  }
}

/// 큰 숫자 + 이름
class _Big extends StatelessWidget {
  const _Big(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Palette.ink),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 14, color: Palette.subInk)),
        ],
      ),
    );
  }
}
