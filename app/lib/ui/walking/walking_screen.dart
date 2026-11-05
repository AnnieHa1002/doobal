import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/live_walker.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/walk_notice.dart';
import '../../domain/companion.dart';
import '../../domain/focus_walk.dart';
import '../../domain/follow.dart';
import '../../domain/badge.dart' as stamp;
import '../../domain/gait.dart';
import '../../domain/journey.dart';
import '../../domain/live_walk.dart';
import '../../domain/milestones.dart';
import '../../domain/road_event.dart' show EventLive;
import '../../domain/rules.dart';
import '../../domain/walk_arrival.dart';
import '../../domain/walk_record.dart';
import '../arrival/arrival_screen.dart';
import '../common/toast.dart';
import '../companion/meet_flow.dart';
import '../scene/scene_view.dart';
import '../walk_record/walk_record_screen.dart';
import 'walking_hud.dart';

/// 걷는 중. 열 때 걷기 시작 시각을 적고, rules.walkingRefreshSec마다 동기화해서
/// 이번 걷기의 걸음·거리를 새로 받는다. 보이는 거리는 새 값을 향해 부드럽게 따라간다.
/// health 기록은 늦게 들어오므로, 기기 걸음 센서(LiveWalker)가 있으면 걸음·거리는 둘 중 큰 쪽,
/// 분당 걸음과 걷기/뛰기는 센서 기준으로 보여 준다. 진행 바·남은 km·도착은 동기화 값 그대로.
/// 화면이 꺼져 있던 동안 센 걸음은 앱이 돌아올 때 한꺼번에 들어오고, 그때 거리는 바로 맞춘다.
/// 안드로이드는 걷는 동안 상시 알림(포그라운드 서비스)으로 앱을 살려 두고, 알림에 걸음을 보여 준다.
/// 열면 앱 걷기 창(본격 걷기 보너스)을 열고, 걷기 마치기를 누르면 finish로 닫는다.
/// 마치기를 안 누르고 이 화면이 사라져도(되돌아가기 제스처 등) 그 시각에 finish로 닫는다.
/// 이번 걷기가 걷기 1번으로 인정되면(isFocusedWalk) 본격 걷기: 걸음 알약에 배수 딱지를 붙이고 토스트를
/// 한 번 띄우며 상시 알림 끝에도 쓴다. 마칠 때까지 그대로다.
/// 앱이 켜진 동안(이 화면이 떠 있는 동안) 센서가 센 실제 걸은 거리는 rules.eventFlushSec마다
/// SyncService.addEventDistance에 넘긴다 (길 위 이벤트: 2km 칸을 넘으면 `2km 이정표` 카드가 몇 초 뜬다).
/// 숨어 있던 동안 따라잡은 걸음은 넘기지 않고(LiveWalk.foregroundM), 아직 안 넘긴 거리는 앱이 꺼지면 잃는다.
/// 새 도장을 받으면(SyncService.newBadges) 걸음 알약 아래에 작은 줄이 잠깐 뜬다 (토스트 대신).
/// 칸이 이벤트 대신 동행 만남이면(pendingMeeting) HUD를 가리고 길 위 만남(MeetFlow)을 이 화면 위에 띄운다.
/// 앱이 통째로 끝나서 화면이 정리되지 못한 경우는 다음 실행 때 AutoSync가 마지막으로 살아 있던
/// 시각에서 닫는다 (appEnded).
/// 진행이 100%가 되면(11/4 Annie) 걷기를 자동으로 마치고 도착 화면으로 바꾼다. 도착은 늘 health 동기화가
/// 정한다: 센서 미리보기가 남은 거리를 넘으면 동기화를 바로 돌려 보고, 도착이 확정되면(pendingArrival)
/// 넘어간다. 도착 화면을 닫으면 그 걷기의 걷기 기록이 이어진다. 걷는 중 화면이 떠 있는 동안은
/// walkingActiveProvider로 AutoSync가 도착 화면을 따로 띄우지 않게 한다
class WalkingScreen extends ConsumerStatefulWidget {
  const WalkingScreen({super.key});

  @override
  ConsumerState<WalkingScreen> createState() => _WalkingScreenState();
}

/// 몰려 온 걸음을 화면 숫자가 따라잡는 시간(초)
const _stepCatchUpSec = 3.0;

/// 센서 미리보기가 100%를 넘은 동안 도착 확인 동기화를 돌리는 최소 간격(초).
/// config로 옮길 값 (평소 주기 walkingRefreshSec 30초보다 짧게)
const _arrivalProbeSec = 5;

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

  /// 걸음 알약에 보이는 걸음 수: 한꺼번에 들어온 걸음도 뛰지 않고 부드럽게 오른다 (거리와 같이).
  /// 멈췄다 다시 걸으면 폰 걸음 센서가 3~5초 지켜본 뒤 몰아서 보내서, 그 걸음을 3초에 걸쳐 걷는 속도처럼
  /// 차분히 푼다 (11/4 Annie, 폰 확인)
  final _stepFollower = CountFollower(catchUpSec: _stepCatchUpSec);

  /// 기기 걸음 센서. 센서나 권한이 없으면 값이 오지 않는다
  LiveWalker? _live;

  /// 걷는 중 상시 알림. 켰을 때만(_noticeOn) 마지막으로 새로 쓴 걸음·거리와 그 시각을 적어 두고,
  /// 알림 글(걸음, 0.1km 단위 거리)이 바뀔 때만 rules.liveNoticeUpdateSec초에 한 번까지 새로 쓴다
  late final WalkNotice _notice;
  var _noticeOn = false;
  var _noticeSteps = 0;
  var _noticeDistanceM = 0.0;
  String? _noticeFocus;

  /// 알림 제목에 마지막으로 쓴 뛰는 중 여부 (화면이 꺼져 있는 동안은 알 수 없어 그대로 둔다)
  var _noticeRunning = false;
  DateTime? _noticeAt;

  /// 본격 걷기가 된 뒤로는 마칠 때까지 true (딱지·알림 끝 글). 다시 가릴 때 쓰는 입력(마지막으로 받은
  /// 기록과 센서 걸음)이 그대로면 다시 계산하지 않는다
  var _focused = false;
  WalkRecord? _focusRecord;
  var _focusSteps = -1;

  /// 마지막으로 본 LiveWalk.catchUps. 바뀌면 숨어 있던 동안의 걸음이 들어온 것이라 거리를 바로 맞춘다
  var _catchUps = 0;

  /// 새 기록이 왔을 때 그때 남은 거리를 한 주기에 메우는 속도(m/s).
  /// 걷는 속도보다 크면 이 속도로 따라가서 한 주기 안에 목표에 닿는다
  var _catchUpMps = 0.0;

  /// 걷기를 시작하기 전의 여정 진행 비율. 여정이 없으면 null
  double? _ratioBefore;

  var _refreshing = false;
  var _wasOnSea = false;

  /// 이 화면이 연 앱 걷기 창의 번호 (열기가 실패했으면 null). 닫기는 한 번만.
  /// 화면이 정리되는 중(dispose)에는 ref를 못 쓰므로 시계와 서비스는 처음에 필드에 담아 둔다
  late final DateTime Function() _clock;
  late final Future<SyncService> _service;
  late final Future<int?> _appWalk;
  var _appWalkClosed = false;

  /// 걷는 중 화면이 떠 있다고 알리는 쪽 (dispose에서는 ref를 못 쓰므로 미리 담는다)
  late final WalkingActive _active;

  /// 길 위 이벤트: 지금까지 SyncService에 넘긴 센서 앞쪽 거리(m), 마지막으로 넘긴 시각, 넘기는 중,
  /// 지금 떠 있는 카드와 새 도장 줄
  var _eventSentM = 0.0;
  DateTime? _eventAt;
  var _eventBusy = false;
  RoadEventView? _event;
  Timer? _eventTimer;
  String? _badgeLine;
  Timer? _badgeTimer;
  StreamSubscription<List<stamp.Badge>>? _badgeSub;

  /// 지금 띄운 길 위 만남의 동행과 그때 함께 걷던 동행 (만남은 이벤트 대신 나온다, 없으면 null)
  Companion? _meet;
  Companion? _meetWith;

  /// 만남이 뜬 순간의 거리. 만남 동안 장면은 멈춰 있고, 걸음은 뒤에서 계속 센다
  var _meetShownM = 0.0;

  /// 이 걷기에서 이미 고른 동행 (저장이 끝나기 전에 읽어도 다시 띄우지 않게)
  final _meetDone = <String>{};

  /// 도착으로 걷기를 마치는 중 (한 번만) / 마지막으로 도착 확인 동기화를 돌린 시각
  var _ending = false;
  DateTime? _probeAt;

  @override
  void initState() {
    super.initState();
    final clock = _clock = ref.read(clockProvider);
    _service = ref.read(syncServiceProvider.future);
    _notice = ref.read(walkNoticeProvider);
    _active = ref.read(walkingActiveProvider.notifier);
    // 위젯을 짓는 중에는 provider를 못 바꾼다
    Future.microtask(() => _setActive(true));
    _start = _now = clock();
    _appWalk = _openAppWalk(_start);
    _ratioBefore = ref.read(snapshotProvider).value?.journey?.progress.ratio;
    _ticker = createTicker(_onTick)..start();
    ref.listenManual(snapshotProvider, (_, next) {
      final s = next.value;
      if (s != null) _onSnapshot(s);
    }, fireImmediately: true);
    _service.then((svc) {
      if (!mounted) return;
      _badgeSub = svc.newBadges.listen(_onBadges);
      // 지난번에 만남 흐름을 못 끝냈으면 이어서 보여 준다
      unawaited(_checkMeeting(svc).catchError((Object e) => debugPrint('길 위 만남 읽기 실패: $e')));
    }, onError: (_) {});
    _startRefreshing();
  }

  @override
  void dispose() {
    _badgeSub?.cancel();
    _eventTimer?.cancel();
    _badgeTimer?.cancel();
    // 마치기 없이 나가는 경우: 창이 열린 채 남지 않게 지금 시각에 닫는다 (마치기로 나갔으면 이미 닫혔다)
    unawaited(_closeAppWalk(_clock()));
    Future.microtask(() => _setActive(false));
    _noticeOn = false;
    _notice.stop();
    _live?.dispose();
    _timer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  /// 새 도장 한 줄을 걸음 알약 아래에 잠깐 띄운다
  void _onBadges(List<stamp.Badge> badges) {
    if (!mounted) return;
    _badgeTimer?.cancel();
    setState(() => _badgeLine = stamp.newBadgeToast(badges));
    _badgeTimer = Timer(HudMetrics.badgeLineFor, () {
      if (mounted) setState(() => _badgeLine = null);
    });
  }

  void _closeEvent() {
    _eventTimer?.cancel();
    setState(() => _event = null);
  }

  /// 센서가 앞에서 센 거리 중 아직 안 넘긴 만큼을 길 위 이벤트 계산에 넘긴다. 마지막으로 넘긴 뒤
  /// rules.eventFlushSec가 안 지났거나 넘기는 중이면 건너뛴다 ([now]가 걷기를 마친 시각이면 간격은 무시).
  /// 칸을 넘어 이벤트가 생기면 카드를 띄운다. 실패하면 안 넘긴 것으로 두고 다음에 다시 넘긴다.
  /// 이번 걷기·오늘·누적 값은 걷는 중 화면 숫자다 (동기화 값 + 센서가 먼저 센 만큼)
  void _flushEvents(Rules rules, DateTime now, {bool force = false}) {
    final live = _live?.walk;
    if (live == null || _eventBusy) return;
    final sendM = live.foregroundM;
    final delta = sendM - _eventSentM;
    if (delta <= 0) return;
    final last = _eventAt;
    if (!force && last != null && now.difference(last) < Duration(seconds: rules.eventFlushSec)) {
      return;
    }
    _eventBusy = true;
    _eventAt = now;
    final summary = _summaryAt(now);
    final saved = _record?.summary;
    final liveRunSteps = live.minutes.where((m) => m.gait == Gait.run).fold(0, (a, m) => a + m.steps);
    final runSteps = math.max(summary?.runSteps ?? 0, liveRunSteps);
    final facts = EventLive(
      sessionKm: (summary?.distanceM ?? 0) / 1000,
      runKm: runSteps * rules.runStrideM / 1000,
      pendingSteps: math.max(0, (summary?.steps ?? 0) - (saved?.steps ?? 0)),
      pendingM: math.max(0.0, (summary?.distanceM ?? 0) - (saved?.distanceM ?? 0)),
    );
    unawaited(_sendEvents(delta, sendM, now, facts));
  }

  Future<void> _sendEvents(double deltaM, double sentM, DateTime now, EventLive facts) async {
    try {
      final svc = await _service;
      final made = await svc.addEventDistance(deltaM, now, facts);
      _eventSentM = sentM;
      if (made.isNotEmpty && mounted) {
        _eventTimer?.cancel();
        setState(() => _event = made.last);
        _eventTimer = Timer(HudMetrics.eventCardFor, () {
          if (mounted) setState(() => _event = null);
        });
      }
      await _checkMeeting(svc);
    } catch (e) {
      debugPrint('길 위 이벤트 계산 실패: $e');
    } finally {
      _eventBusy = false;
    }
  }

  /// 만남 칸이 나왔거나 지난번에 흐름을 못 끝낸 동행이 있으면 길 위 만남을 띄운다
  Future<void> _checkMeeting(SyncService svc) async {
    if (_meet != null || _ending) return;
    final met = await svc.pendingMeeting();
    if (met == null || _meetDone.contains(met.id)) return;
    final view = await svc.companionsView();
    if (!mounted || _ending || _meetDone.contains(met.id)) return;
    setState(() {
      _meet = met;
      _meetWith = view.metById(view.walkingWith)?.companion;
      _meetShownM = _shownM;
    });
  }

  /// 길 위 만남에서 골랐다. 저장에 실패하면 대기로 남아 다음 걷는 중에 다시 나온다
  Future<void> _finishMeeting(bool together) async {
    final met = _meet;
    if (met == null) return;
    _meetDone.add(met.id);
    setState(() => _meet = null);
    try {
      await (await _service).finishMeeting(met.id, _clock(), together: together);
    } catch (e) {
      debugPrint('길 위 만남 저장 실패: $e');
    }
  }

  void _setActive(bool on) {
    try {
      on ? _active.enter() : _active.leave();
    } catch (_) {
      // 앱이 통째로 정리되는 중이면 알릴 곳이 없다
    }
  }

  /// 앱 걷기 창을 연다. 실패하면 null (이번 걷기는 보너스 없이 센다)
  Future<int?> _openAppWalk(DateTime start) async {
    try {
      return await (await _service).startAppWalk(start);
    } catch (e) {
      debugPrint('앱 걷기 열기 실패: $e');
      return null;
    }
  }

  /// 앱 걷기 창을 [end]에 finish로 닫는다 (한 번만). 열기가 아직 안 끝났으면 끝난 뒤에 닫는다.
  /// 화면이 정리되는 중에도 부른다 (ref를 쓰지 않는다)
  Future<void> _closeAppWalk(DateTime end) async {
    if (_appWalkClosed) return;
    _appWalkClosed = true;
    try {
      final id = await _appWalk;
      if (id == null) return;
      await (await _service).finishAppWalk(id, end);
    } catch (e) {
      debugPrint('앱 걷기 닫기 실패: $e');
    }
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
    _noticeFocus = _focusLabel();
    _noticeRunning = _isRunning(summary);
    _notice.start(
      _noticeSteps,
      _noticeDistanceM,
      focus: _noticeFocus,
      isRunning: _noticeRunning,
    );
  }

  /// 본격 걷기 중이면 알림 끝에 붙일 배수 글(`×1.3`), 아니면 null
  String? _focusLabel() {
    final rules = ref.read(rulesProvider).value;
    return _focused && rules != null ? focusBadgeText(rules) : null;
  }

  /// 지금 뛰는 중인가 (화면의 '달리는 중'과 같은 기준)
  bool _isRunning(WalkSummary? s) => s != null && s.lastSteps > 0 && s.lastGait == Gait.run;

  /// 알림의 걸음·거리를 [steps]·[distanceM]으로 새로 쓴다. 알림 글이 바뀔 때만
  /// (걸음이 다르거나 0.1km 단위 거리가 다르거나 본격 걷기 표시·뛰는 중 제목이 달라질 때),
  /// rules.liveNoticeUpdateSec초에 한 번까지. [isRunning]이 없으면(화면이 꺼져 모를 때) 마지막 값
  void _pushNotice(int steps, double distanceM, {bool? isRunning}) {
    if (!_noticeOn) return;
    final focus = _focusLabel();
    final running = isRunning ?? _noticeRunning;
    if (steps == _noticeSteps &&
        noticeKm(distanceM) == noticeKm(_noticeDistanceM) &&
        focus == _noticeFocus &&
        running == _noticeRunning) {
      return;
    }
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
    _noticeFocus = focus;
    _noticeRunning = running;
    _notice.update(steps, distanceM, focus: focus, isRunning: running);
  }

  /// 이번 걷기가 본격 걷기가 됐는지 본다 (한 번 되면 마칠 때까지 그대로). 됐으면 딱지를 켜고 토스트를
  /// 한 번 띄운다 (알림 글은 _pushNotice가 바뀐 표시를 보고 새로 쓴다).
  /// 건강 기록(동기화 때 바뀐다)이나 센서 걸음이 달라졌을 때만 다시 가린다
  void _checkFocus(Rules rules) {
    if (_focused) return;
    final record = _record;
    final liveSteps = _live?.walk.steps ?? 0;
    if (identical(record, _focusRecord) && liveSteps == _focusSteps) return;
    _focusRecord = record;
    _focusSteps = liveSteps;
    final focused = isFocusedWalk(
      start: _start,
      saved: record?.sessions ?? const [],
      live: _live?.walk.minutes ?? const [],
      rules: rules,
    );
    if (!focused) return;
    setState(() => _focused = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showToast(context, focusToastText(rules));
    });
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
          // 진행 거리는 이동 거리(앱 걷기 보너스 포함)라 이번 걷기도 이동 거리로 뺀다
          _ratioBefore = ratioBeforeWalk(j.progress.progressKm, record.travelM / 1000, j.totalKm);
        }
      });
      // 화면이 꺼져 있어 프레임이 없을 때도 동기화마다 본격 걷기를 가리고, 알림에 아직 안 쓴 표시가
      // 있으면 쓴다 (숫자는 줄지 않게 마지막으로 쓴 값과 큰 쪽)
      _checkFocus(ref.read(rulesProvider).requireValue);
      if (_focused && _noticeFocus == null) {
        final s = _summaryAt(ref.read(clockProvider)());
        _pushNotice(
          math.max(_noticeSteps, s?.steps ?? 0),
          math.max(_noticeDistanceM, s?.distanceM ?? 0),
        );
      }
    } catch (e) {
      debugPrint('걷는 중 동기화 실패: $e');
    } finally {
      _refreshing = false;
    }
  }

  /// 도착이 확정됐으면(동기화가 정한다) 걷기를 마치고 도착 화면으로 바꾼다.
  /// 배 구간에 들어설 때마다 한 번만 토스트
  void _onSnapshot(Snapshot s) {
    final arrival = s.pendingArrival;
    if (arrival != null && !_ending) {
      _ending = true;
      // 화면을 짓는 중일 수 있어서 이번 프레임이 끝난 뒤에 넘어간다
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finishByArrival(arrival.journeyId);
      });
      return;
    }
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
    _checkFocus(rules);
    final summary = _summaryAt(now);
    _pushNotice(summary?.steps ?? 0, summary?.distanceM ?? 0, isRunning: _isRunning(summary));
    _probeArrival(summary, now);
    _flushEvents(rules, now);
    final walkMps = summary == null ? 0.0 : speedMps(summary.lastSteps, summary.lastGait, rules);
    var shown = followDistance(
      _shownM,
      summary?.distanceM ?? 0,
      math.max(walkMps, _catchUpMps),
      dt,
      rules.walkingRefreshSec.toDouble(),
    );
    final shownSteps = _stepFollower.shown;
    _stepFollower.step(summary?.steps ?? 0, dt);
    // 숨어 있던 동안의 걸음이 한꺼번에 들어왔으면 따라가지 않고 바로 맞춘다
    final catchUps = _live?.walk.catchUps ?? 0;
    if (catchUps != _catchUps) {
      _catchUps = catchUps;
      shown = math.max(shown, summary?.distanceM ?? 0);
      _stepFollower.snap(summary?.steps ?? 0);
    }
    // 거리·걸음 숫자가 움직이거나 초가 바뀔 때만 다시 그린다
    final secondChanged =
        now.difference(_start).inSeconds != _now.difference(_start).inSeconds;
    if (shown == _shownM && _stepFollower.shown == shownSteps && !secondChanged) return;
    setState(() {
      _shownM = shown;
      _now = now;
    });
  }

  /// 센서 미리보기가 남은 거리를 넘으면 동기화를 바로 돌려 도착이 확정됐는지 본다.
  /// 진행 기준은 언제나 health 동기화 값이라 여기서 도착을 정하지는 않는다 (M1)
  void _probeArrival(WalkSummary? summary, DateTime now) {
    if (_ending || _refreshing || summary == null) return;
    final j = ref.read(snapshotProvider).value?.journey;
    if (j == null) return;
    final extraM = summary.distanceM - (_record?.summary.distanceM ?? 0);
    if (!previewReachesDest(remainingKm: j.progress.remainingKm, extraM: extraM)) return;
    if (!arrivalProbeDue(_probeAt, now, _arrivalProbeSec)) return;
    _probeAt = now;
    _refresh();
  }

  /// 걷기를 마친다: 알림을 끄고 앱 걷기 창을 마친 시각에 닫는다 (걷기 기록 화면의 계산은 DB 쓰기
  /// 순서상 닫힌 뒤에 읽는다). 이번 걷기의 값을 돌려준다
  WalkEnd _endWalk() {
    _noticeOn = false;
    _notice.stop();
    final end = ref.read(clockProvider)();
    // 마지막으로 넘기고 남은 거리까지 마친 시각으로 넘긴다 (걷기 기록의 이정표가 이 걷기 시간대에 들어오게)
    final rules = ref.read(rulesProvider).value;
    if (rules != null) _flushEvents(rules, end, force: true);
    unawaited(_closeAppWalk(end));
    return WalkEnd(
      start: _start,
      end: end,
      ratioBefore: _ratioBefore,
      liveMinutes: _live?.walk.minutes ?? const [],
    );
  }

  void _finish() {
    if (_ending) return;
    _ending = true;
    final walk = _endWalk();
    // 이 화면을 걷기 기록으로 바꾼다. 마지막 동기화와 기록 계산은 걷기 기록 화면이 한다
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => WalkRecordScreen(
        start: walk.start,
        end: walk.end,
        ratioBefore: walk.ratioBefore,
        liveMinutes: walk.liveMinutes,
      ),
    ));
  }

  /// 진행 100%: 걷기를 자동으로 마치고 도착 화면으로 바꾼다 (보통 '걷기 마치기'와 같은 경로).
  /// 도착 화면을 닫으면 이 걷기의 걷기 기록으로 간다
  void _finishByArrival(String journeyId) {
    final walk = _endWalk();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ArrivalScreen(journeyId: journeyId, walk: walk),
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
    final running = _isRunning(summary);
    final spirit = ref.watch(spiritLookProvider);
    final meet = _meet;

    return Scaffold(
      body: Stack(
        children: [
          SceneView(
            mode: SceneMode.walking,
            distanceM: meet == null ? _shownM : _meetShownM,
            nowUtc: _now,
            position: position,
            onSea: snap.onSea,
            rules: rules,
            landmarks: landmarks,
            running: meet == null && running,
            moving: meet == null && summary != null && summary.lastSteps > 0,
            sceneSeed: snap.journey?.dest.id ?? 'home',
            spirit: spirit,
          ),
          // 길 위 만남 동안에는 HUD를 가린다 (상태는 그대로 둔다)
          Offstage(
            offstage: meet != null,
            child: WalkingHud(
              rules: rules,
              snap: snap,
              summary: summary,
              shownM: _shownM,
              shownSteps: _stepFollower.shown,
              walkingTime: _now.difference(_start),
              running: running,
              nextMilestone: _nextMilestone(snap),
              focusBadge: _focused ? focusBadgeText(rules) : null,
              event: _event,
              eventKm: rules.eventEveryKm,
              onCloseEvent: _closeEvent,
              badgeLine: _badgeLine,
              onFinish: _finish,
            ),
          ),
          if (meet != null)
            Positioned.fill(
              child: MeetFlow(
                key: ValueKey(meet.id),
                companion: meet,
                walkingWith: _meetWith,
                rules: rules,
                onChoose: _finishMeeting,
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
