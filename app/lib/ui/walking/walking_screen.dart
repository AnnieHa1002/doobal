import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/live_walker.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/follow.dart';
import '../../domain/gait.dart';
import '../../domain/journey.dart';
import '../../domain/live_walk.dart';
import '../../domain/milestones.dart';
import '../../domain/rules.dart';
import '../../domain/walk_record.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/ink_bar.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../scene/scene_view.dart';
import '../walk_record/walk_record_screen.dart';

/// 걷는 중. 열 때 걷기 시작 시각을 적고, rules.walkingRefreshSec마다 동기화해서
/// 이번 걷기의 걸음·거리를 새로 받는다. 보이는 거리는 새 값을 향해 부드럽게 따라간다.
/// health 기록은 늦게 들어오므로, 기기 걸음 센서(LiveWalker)가 있으면 걸음·거리는 둘 중 큰 쪽,
/// 분당 걸음과 걷기/뛰기는 센서 기준으로 보여 준다. 진행 바·남은 km·도착은 동기화 값 그대로
class WalkingScreen extends ConsumerStatefulWidget {
  const WalkingScreen({super.key});

  @override
  ConsumerState<WalkingScreen> createState() => _WalkingScreenState();
}

class _WalkingScreenState extends ConsumerState<WalkingScreen>
    with SingleTickerProviderStateMixin {
  late final DateTime _start;
  late DateTime _now;
  late final Ticker _ticker;
  Timer? _timer;
  var _lastTick = Duration.zero;

  /// 화면에 보이는 이번 걷기 거리(m)와 마지막으로 받은 이번 걷기 기록
  var _shownM = 0.0;
  WalkRecord? _record;

  /// 기기 걸음 센서. 센서나 권한이 없으면 값이 오지 않는다
  LiveWalker? _live;

  /// 새 기록이 왔을 때 그때 남은 거리를 한 주기에 메우는 속도(m/s).
  /// 걷는 속도보다 크면 이 속도로 따라가서 한 주기 안에 목표에 닿는다
  var _catchUpMps = 0.0;

  /// 걷기를 시작하기 전의 여정 진행 비율. 여정이 없으면 null
  double? _ratioBefore;

  var _expanded = false;
  var _refreshing = false;
  var _wasOnSea = false;

  @override
  void initState() {
    super.initState();
    final clock = ref.read(clockProvider);
    _start = _now = clock();
    _ratioBefore = ref.read(snapshotProvider).value?.journey?.progress.ratio;
    _ticker = createTicker(_onTick)..start();
    ref.listenManual(snapshotProvider, (_, next) {
      final s = next.value;
      if (s != null) _onSnapshot(s);
    }, fireImmediately: true);
    _startRefreshing();
  }

  @override
  void dispose() {
    _live?.dispose();
    _timer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _startRefreshing() async {
    try {
      final rules = await ref.read(rulesProvider.future);
      if (!mounted) return;
      final denied = ref.read(liveDeniedProvider.notifier);
      _live = LiveWalker(
        steps: ref.read(liveStepsProvider),
        rules: rules,
        clock: ref.read(clockProvider),
        denied: () => denied.denied,
        onDenied: () => denied.set(true),
      )..start();
      _timer = Timer.periodic(Duration(seconds: rules.walkingRefreshSec), (_) => _refresh());
      await _refresh();
    } catch (e) {
      debugPrint('걷는 중 시작 실패: $e');
    }
  }

  Future<void> _refresh() async {
    // 겹쳐 돌지 않게 한다 (동기화가 주기보다 오래 걸릴 수 있다)
    if (_refreshing) return;
    _refreshing = true;
    try {
      final svc = await ref.read(syncServiceProvider.future);
      final now = ref.read(clockProvider)();
      await svc.sync(now);
      final record = await svc.walkRecord(_start, now);
      if (!mounted) return;
      final snap = await ref.refresh(snapshotProvider.future);
      if (!mounted) return;
      final j = snap.journey;
      final refreshSec = ref.read(rulesProvider).requireValue.walkingRefreshSec;
      setState(() {
        _record = record;
        _catchUpMps = math.max(0.0, record.summary.distanceM - _shownM) / refreshSec;
        if (j != null) {
          _ratioBefore =
              ratioBeforeWalk(j.progress.progressKm, record.summary.distanceM / 1000, j.totalKm);
        }
      });
    } catch (e) {
      debugPrint('걷는 중 동기화 실패: $e');
    } finally {
      _refreshing = false;
    }
  }

  /// 배 구간에 들어설 때마다 한 번만 토스트
  void _onSnapshot(Snapshot s) {
    final entered = s.onSea && !_wasOnSea;
    _wasOnSea = s.onSea;
    if (!entered) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rules = ref.read(rulesProvider).value;
      if (rules == null) return;
      showToast(context, '배를 타고 건너요 (${(1 / rules.seaFactor).round()}배 빠르게)');
    });
  }

  /// 화면에 보이는 이번 걷기 숫자 (센서가 있으면 센서 값과 합친다)
  WalkSummary? _summaryAt(DateTime now) {
    final live = _live?.walk;
    final health = _record?.summary;
    return live == null ? health : liveSummary(health, live, now);
  }

  void _onTick(Duration elapsed) {
    final rules = ref.read(rulesProvider).value;
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (rules == null) return;

    final now = ref.read(clockProvider)();
    final summary = _summaryAt(now);
    final walkMps = summary == null ? 0.0 : speedMps(summary.lastSteps, summary.lastGait, rules);
    final shown = followDistance(
      _shownM,
      summary?.distanceM ?? 0,
      math.max(walkMps, _catchUpMps),
      dt,
      rules.walkingRefreshSec.toDouble(),
    );
    // 거리가 움직이거나 초가 바뀔 때만 다시 그린다
    final secondChanged =
        now.difference(_start).inSeconds != _now.difference(_start).inSeconds;
    if (shown == _shownM && !secondChanged) return;
    setState(() {
      _shownM = shown;
      _now = now;
    });
  }

  void _finish() {
    // 이 화면을 걷기 기록으로 바꾼다. 마지막 동기화와 기록 계산은 걷기 기록 화면이 한다
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => WalkRecordScreen(
        start: _start,
        end: ref.read(clockProvider)(),
        ratioBefore: _ratioBefore,
        liveMinutes: _live?.walk.minutes ?? const [],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value;
    final landmarks = ref.watch(landmarksProvider).value;
    final snap = ref.watch(snapshotProvider).value;
    // 위치는 여정이 있으면 늘 있다. 없으면(출발 동네 미선택) 다른 빠진 데이터처럼 빈 화면
    final position = snap?.position;
    if (rules == null || landmarks == null || snap == null || position == null) {
      return const Scaffold(body: SizedBox.expand());
    }
    final summary = _summaryAt(_now);
    final running = summary != null && summary.lastSteps > 0 && summary.lastGait == Gait.run;

    return Scaffold(
      body: Stack(
        children: [
          SceneView(
            mode: SceneMode.walking,
            distanceM: _shownM,
            nowUtc: _now,
            position: position,
            onSea: snap.onSea,
            rules: rules,
            landmarks: landmarks,
            running: running,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: _Panel(
                      expanded: _expanded,
                      rules: rules,
                      snap: snap,
                      summary: summary,
                      shownM: _shownM,
                      walkingTime: _now.difference(_start),
                      running: running,
                      nextMilestone: _nextMilestone(snap),
                    ),
                  ),
                  const Spacer(),
                  GameButton(
                    label: '걷기 마치기',
                    kind: GameButtonKind.secondary,
                    onPressed: _finish,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 다음 방명록 지점까지 남은 걸음. 마지막 숫자를 넘었거나 아직 못 읽었으면 null
  int? _nextMilestone(Snapshot snap) {
    final milestones = ref.watch(milestonesProvider).value;
    if (milestones == null) return null;
    final next = nextMilestone(snap.totalSteps, milestones);
    return next == null ? null : next - snap.totalSteps;
  }
}

/// 위쪽 패널. 접으면 상태·걸음·거리·시간·여정 진행, 누르면 자세한 숫자까지
class _Panel extends StatelessWidget {
  const _Panel({
    required this.expanded,
    required this.rules,
    required this.snap,
    required this.summary,
    required this.shownM,
    required this.walkingTime,
    required this.running,
    required this.nextMilestone,
  });

  final bool expanded;
  final Rules rules;
  final Snapshot snap;
  final WalkSummary? summary;
  final double shownM;
  final Duration walkingTime;
  final bool running;
  final int? nextMilestone;

  @override
  Widget build(BuildContext context) {
    final j = snap.journey;
    final spm = summary?.lastSteps ?? 0;
    final gait = summary?.lastGait ?? Gait.walk;
    final pace = livePaceSecPerKm(spm, gait, rules);
    const small = TextStyle(fontSize: 14, color: Palette.subInk);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  running ? '달리는 중' : '걷는 중',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Palette.terracotta,
                  ),
                ),
                const Spacer(),
                Text(formatDuration(walkingTime), style: small),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${formatInt(summary?.steps ?? 0)}보',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatKm(shownM / 1000, digits: 2), style: small),
              ],
            ),
            if (j != null) ...[
              const SizedBox(height: 8),
              InkBar(segments: [BarSegment(j.progress.ratio, Palette.moss)]),
              const SizedBox(height: 4),
              Text('${j.dest.name}까지 ${formatKm(j.progress.remainingKm)}', style: small),
            ],
            if (expanded) ...[
              const Divider(height: 24, color: Palette.ink),
              _Line('분당 걸음', '$spm보'),
              _Line('속도', '${speedKmh(spm, gait, rules).toStringAsFixed(1)} km/h'),
              _Line('페이스', pace == null ? '-' : '${formatPace(pace)}/km'),
              _Line('보폭', '${strideM(gait, rules).toStringAsFixed(2)} m'),
              _Line('오늘 걸음', '${formatInt(snap.todaySteps)}보'),
              if (j != null) _Line('도착 예정일', formatMonthDay(j.eta)),
              if (nextMilestone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('다음 방명록 지점까지 ${formatInt(nextMilestone!)}보', style: small),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('혼자 걷는 중', style: small),
              ),
            ],
          ],
        ),
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
    const style = TextStyle(fontSize: 14, color: Palette.subInk);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Palette.ink)),
        ],
      ),
    );
  }
}
