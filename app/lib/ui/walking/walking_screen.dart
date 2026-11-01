import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/live_walker.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/walk_notice.dart';
import '../../domain/follow.dart';
import '../../domain/gait.dart';
import '../../domain/journey.dart';
import '../../domain/live_walk.dart';
import '../../domain/milestones.dart';
import '../../domain/walk_record.dart';
import '../common/toast.dart';
import '../scene/scene_view.dart';
import '../walk_record/walk_record_screen.dart';
import 'walking_hud.dart';

/// 걷는 중. 열 때 걷기 시작 시각을 적고, rules.walkingRefreshSec마다 동기화해서
/// 이번 걷기의 걸음·거리를 새로 받는다. 보이는 거리는 새 값을 향해 부드럽게 따라간다.
/// health 기록은 늦게 들어오므로, 기기 걸음 센서(LiveWalker)가 있으면 걸음·거리는 둘 중 큰 쪽,
/// 분당 걸음과 걷기/뛰기는 센서 기준으로 보여 준다. 진행 바·남은 km·도착은 동기화 값 그대로.
/// 화면이 꺼져 있던 동안 센 걸음은 앱이 돌아올 때 한꺼번에 들어오고, 그때 거리는 바로 맞춘다.
/// 안드로이드는 걷는 동안 상시 알림(포그라운드 서비스)으로 앱을 살려 두고, 알림에 걸음을 보여 준다
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

  /// 걷는 중 상시 알림. 켰을 때만(_noticeOn) 마지막으로 새로 쓴 걸음·거리와 그 시각을 적어 두고,
  /// 알림 글(걸음, 0.1km 단위 거리)이 바뀔 때만 rules.liveNoticeUpdateSec초에 한 번까지 새로 쓴다
  late final WalkNotice _notice;
  var _noticeOn = false;
  var _noticeSteps = 0;
  var _noticeDistanceM = 0.0;
  DateTime? _noticeAt;

  /// 마지막으로 본 LiveWalk.catchUps. 바뀌면 숨어 있던 동안의 걸음이 들어온 것이라 거리를 바로 맞춘다
  var _catchUps = 0;

  /// 새 기록이 왔을 때 그때 남은 거리를 한 주기에 메우는 속도(m/s).
  /// 걷는 속도보다 크면 이 속도로 따라가서 한 주기 안에 목표에 닿는다
  var _catchUpMps = 0.0;

  /// 걷기를 시작하기 전의 여정 진행 비율. 여정이 없으면 null
  double? _ratioBefore;

  var _refreshing = false;
  var _wasOnSea = false;

  @override
  void initState() {
    super.initState();
    final clock = ref.read(clockProvider);
    _notice = ref.read(walkNoticeProvider);
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
    _noticeOn = false;
    _notice.stop();
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
      final live = _live = LiveWalker(
        steps: ref.read(liveStepsProvider),
        rules: rules,
        clock: ref.read(clockProvider),
        denied: () => denied.denied,
        onDenied: () => denied.set(true),
        // 화면이 꺼져 있는 동안은 센서가 센 걸음·거리로 알림만 새로 쓴다 (줄어들지는 않게)
        onHiddenSteps: (p) => _pushNotice(
          math.max(_noticeSteps, p.steps),
          math.max(_noticeDistanceM, p.distanceM),
        ),
      );
      live.start().then((_) => _startNotice(live));
      _timer = Timer.periodic(Duration(seconds: rules.walkingRefreshSec), (_) => _refresh());
      await _refresh();
    } catch (e) {
      debugPrint('걷는 중 시작 실패: $e');
    }
  }

  /// 센서를 읽을 수 있으면 상시 알림을 시작한다 (센서 권한이 없으면 안드로이드 14가
  /// 건강 서비스를 못 띄우게 하므로 시작하지 않는다)
  void _startNotice(LiveWalker live) {
    if (!mounted || !live.ready) return;
    final now = ref.read(clockProvider)();
    final summary = _summaryAt(now);
    _noticeSteps = summary?.steps ?? 0;
    _noticeDistanceM = summary?.distanceM ?? 0;
    _noticeAt = now;
    _noticeOn = true;
    _notice.start(_noticeSteps, _noticeDistanceM);
  }

  /// 알림의 걸음·거리를 [steps]·[distanceM]으로 새로 쓴다. 알림 글이 바뀔 때만
  /// (걸음이 다르거나 0.1km 단위 거리가 다를 때), rules.liveNoticeUpdateSec초에 한 번까지
  void _pushNotice(int steps, double distanceM) {
    if (!_noticeOn) return;
    if (steps == _noticeSteps && noticeKm(distanceM) == noticeKm(_noticeDistanceM)) return;
    final rules = ref.read(rulesProvider).value;
    final now = ref.read(clockProvider)();
    final last = _noticeAt;
    if (rules == null ||
        (last != null && now.difference(last) < Duration(seconds: rules.liveNoticeUpdateSec))) {
      return;
    }
    _noticeAt = now;
    _noticeSteps = steps;
    _noticeDistanceM = distanceM;
    _notice.update(steps, distanceM);
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
    _pushNotice(summary?.steps ?? 0, summary?.distanceM ?? 0);
    final walkMps = summary == null ? 0.0 : speedMps(summary.lastSteps, summary.lastGait, rules);
    var shown = followDistance(
      _shownM,
      summary?.distanceM ?? 0,
      math.max(walkMps, _catchUpMps),
      dt,
      rules.walkingRefreshSec.toDouble(),
    );
    // 숨어 있던 동안의 걸음이 한꺼번에 들어왔으면 따라가지 않고 바로 맞춘다
    final catchUps = _live?.walk.catchUps ?? 0;
    if (catchUps != _catchUps) {
      _catchUps = catchUps;
      shown = math.max(shown, summary?.distanceM ?? 0);
    }
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
    _noticeOn = false;
    _notice.stop();
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
            moving: summary != null && summary.lastSteps > 0,
            sceneSeed: snap.journey?.dest.id ?? 'home',
          ),
          WalkingHud(
            rules: rules,
            snap: snap,
            summary: summary,
            shownM: _shownM,
            walkingTime: _now.difference(_start),
            running: running,
            nextMilestone: _nextMilestone(snap),
            onFinish: _finish,
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
