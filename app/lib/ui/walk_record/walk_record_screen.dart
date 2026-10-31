import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/gait.dart';
import '../../domain/laps.dart';
import '../../domain/milestones.dart';
import '../../domain/rules.dart';
import '../../domain/time_kst.dart';
import '../../domain/walk_record.dart';
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
/// 돌아가지 않게), 진행 막대 연출과 `쉼터로` 대신 뒤로 가기만 둔다.
/// [liveMinutes]는 걷는 중 화면 센서가 센 이번 걷기의 분 단위 걸음: health 기록이 아직 모자라면
/// 이 값이 걸음·거리·랩이 된다 (다시 볼 때는 health가 다 들어와 있어서 넘기지 않는다)
class WalkRecordScreen extends ConsumerStatefulWidget {
  const WalkRecordScreen({
    super.key,
    required this.start,
    required this.end,
    required this.ratioBefore,
    this.review = false,
    this.liveMinutes = const [],
  });

  final DateTime start;
  final DateTime end;
  final double? ratioBefore;
  final bool review;
  final List<GaitMinute> liveMinutes;

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
      final record = await svc.walkRecord(widget.start, widget.end, live: widget.liveMinutes);
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

  /// `평균 페이스 14'17"/km · 평균 분당 걸음 112보`. 시간은 위 시간 숫자와 같다.
  /// 거리가 없어 페이스를 못 내면 페이스 부분은 뺀다
  String _averageLine(WalkSummary s) {
    final pace = paceSecPerKm(s.distanceM, widget.end.difference(widget.start));
    return [
      if (pace != null) '평균 페이스 ${formatPace(pace)}/km',
      '평균 분당 걸음 ${s.avgSpm}보',
    ].join(' · ');
  }

  /// 랩마다 한 줄: 그 랩이 끝난 곳까지의 거리와 그 랩의 페이스.
  /// 가득 찬 랩은 `1 km`, 남은 부분 랩은 `1.05 km`처럼 소수 둘째 자리까지
  List<Widget> _lapRows(List<Lap> laps) {
    final rows = <Widget>[];
    var cumM = 0.0;
    for (final lap in laps) {
      cumM += lap.distanceM;
      final pace = lap.paceSecPerKm;
      rows.add(_LapRow(
        lap.partial ? formatKm(cumM / 1000, digits: 2) : '${_plainKm(cumM / 1000)} km',
        pace == null ? '-' : '${formatPace(pace)}/km',
      ));
    }
    return rows;
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
        // 자리표시: 평균 줄과 1km 기록의 화면 구성은 디자인팀이 정할 때까지(10/31) 이 모양으로 둔다
        if (s.steps > 0) ...[
          const SizedBox(height: 12),
          Text(_averageLine(s), style: AppText.bodySub),
        ],
        if (record.laps.any((l) => !l.partial)) ...[
          const SizedBox(height: 12),
          Text('${_plainKm(rules.lapKm)}km 기록', style: AppText.label),
          const SizedBox(height: 4),
          ..._lapRows(record.laps),
        ],
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

/// 거리(km)를 군더더기 없이: 1 → '1', 0.5 → '0.5', 1.25 → '1.25' (랩 길이는 config라 1km가 아닐 수 있다)
String _plainKm(double km) =>
    double.parse(km.toStringAsFixed(2)).toString().replaceFirst(RegExp(r'\.0$'), '');

/// 1km 기록 한 줄 (왼쪽 거리, 오른쪽 페이스). 글자를 키우면 줄바꿈으로 읽힌다
class _LapRow extends StatelessWidget {
  const _LapRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppText.bodySub)),
          Flexible(child: Text(value, style: AppText.body, textAlign: TextAlign.end)),
        ],
      ),
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
