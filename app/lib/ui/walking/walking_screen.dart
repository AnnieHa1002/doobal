import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/companion_providers.dart';
import '../../app/paint_trail_controller.dart';
import '../../app/providers.dart';
import '../../app/shop_providers.dart';
import '../../app/sync_service.dart';
import '../../domain/badge.dart' as stamp;
import '../../domain/companion.dart';
import '../../domain/companion_pace.dart';
import '../../domain/follow.dart';
import '../../domain/gait.dart';
import '../../domain/milestones.dart';
import '../../domain/rules.dart';
import '../../domain/walk_arrival.dart';
import '../../domain/walk_record.dart';
import '../arrival/arrival_screen.dart';
import '../common/toast.dart';
import '../companion/companion_pacer.dart';
import '../companion/companion_walk_layer.dart';
import '../companion/meet_flow.dart';
import '../companion/story_lines.dart';
import '../scene/scene_view.dart';
import 'paint_drop_layer.dart';
import 'walking_hud.dart';

/// 걷는 중 (캔버스 3-1, 16장 11/13 물감 길): 물감 길이 열려 있는 동안 보는 화면. PaintTrailHost가
/// 물감 길이 열리면 열고 걸음이 멈춰 끝나면 쉼터로 닫는다. 왼쪽 위 쉼터 아이콘은 화면만 쉼터로 돌린다
/// (물감 길은 이어진다). ‘걷기 마치기’는 없다.
/// 숫자는 PaintTrailController가 주는 이번 물감 길 값이다: 걸음·거리는 health 기록과 센서 중 큰 쪽,
/// 분당 걸음과 걷기/뛰기는 센서 기준. 보이는 거리는 새 값을 향해 부드럽게 따라간다.
/// 화면이 꺼져 있던 동안 센 걸음은 앱이 돌아올 때 한꺼번에 들어오고, 그때 거리는 바로 맞춘다.
/// 땅 위로 이번 물감 길 거리 config paintDrop.spacingM마다 물감 방울이 흘러와 정령에 닿으면 줍는다 (연출만).
/// 이정표 카드(길 위 이벤트)는 컨트롤러가 만든 것을 config hud.eventCardSec 동안 띄운다 (화면이 꺼진 동안
/// 넘은 칸은 마지막 events.offScreenCards장만). 새 도장을 받으면 걸음 알약 아래 작은 줄이 잠깐 뜬다.
/// 칸이 이벤트 대신 동행 만남이면(pendingMeeting) HUD를 가리고 길 위 만남(MeetFlow)을 이 화면 위에 띄운다.
/// 함께 걷는 동행은 장면에서 pace대로 따라온다. 화면을 떠날 때 뒤처진 거리로 쉼터에 늦게 오는 시간을 넘긴다.
/// 진행이 100%가 되면 도착 화면으로 바꾼다 (물감 길은 이어지고, 닫으면 쉼터). 도착은 늘 health 동기화가
/// 정한다: 센서 미리보기가 남은 거리를 넘으면 동기화를 바로 돌려 보고 도착이 확정되면 넘어간다.
/// 이 화면이 떠 있는 동안은 walkingActiveProvider로 AutoSync가 도착 화면을 따로 띄우지 않게 한다
class WalkingScreen extends ConsumerStatefulWidget {
  const WalkingScreen({super.key});

  @override
  ConsumerState<WalkingScreen> createState() => _WalkingScreenState();
}

/// 몰려 온 걸음을 화면 숫자가 따라잡는 시간(초)
const _stepCatchUpSec = 3.0;

/// 동행 걸음에 넣는 프레임 사이 시간의 최대(초). 앱이 뒤에 있어 프레임이 끊긴 틈은 연출에 넣지 않는다
const _paceMaxDt = 0.25;

class _WalkingScreenState extends ConsumerState<WalkingScreen>
    with SingleTickerProviderStateMixin {
  late final DateTime _start;
  late DateTime _now;
  late final Ticker _ticker;
  var _lastTick = Duration.zero;

  /// 화면에 보이는 이번 물감 길 거리(m)
  var _shownM = 0.0;

  /// 걸음 알약에 보이는 걸음 수: 한꺼번에 들어온 걸음도 뛰지 않고 부드럽게 오른다 (거리와 같이)
  final _stepFollower = CountFollower(catchUpSec: _stepCatchUpSec);

  /// 마지막으로 본 LiveWalk.catchUps. 바뀌면 숨어 있던 동안의 걸음이 들어온 것이라 거리를 바로 맞춘다
  var _catchUps = 0;

  /// 새 기록이 왔을 때 그때 남은 거리를 한 주기에 메우는 속도(m/s)
  var _catchUpMps = 0.0;

  var _wasOnSea = false;

  /// 화면이 정리되는 중(dispose)에는 ref를 못 쓰므로 시계·서비스·알릴 곳은 처음에 필드에 담아 둔다
  late final DateTime Function() _clock;
  late final Future<SyncService> _service;
  late final PaintTrailController _trail;
  late final WalkingActive _active;

  /// 지금 떠 있는 카드와 기다리는 카드, 새 도장 줄
  RoadEventView? _event;
  final _eventQueue = <RoadEventView>[];
  Timer? _eventTimer;
  String? _badgeLine;
  Timer? _badgeTimer;
  StreamSubscription<List<stamp.Badge>>? _badgeSub;

  /// 지금 띄운 길 위 만남의 동행과 그때 함께 걷던 동행 (만남은 이벤트 대신 나온다, 없으면 null)
  Companion? _meet;
  Companion? _meetWith;

  /// 만남이 뜬 순간의 거리. 만남 동안 장면은 멈춰 있고, 걸음은 뒤에서 계속 센다
  var _meetShownM = 0.0;

  /// 이 화면에서 이미 고른 동행 (저장이 끝나기 전에 읽어도 다시 띄우지 않게)
  final _meetDone = <String>{};

  /// 도착으로 넘어가는 중 (한 번만) / 마지막으로 도착 확인 동기화를 돌린 시각
  var _ending = false;
  DateTime? _probeAt;

  /// 함께 걷는 동행 (혼자면 null, 화면을 지을 때 읽는다)과 그 걸음 연출
  Companion? _walkingWith;
  final _pacer = CompanionPacer();

  /// 쉼터 늦은 도착을 넘길 곳, 넘겼는가, 마지막 규칙
  late final CampArrivalNotifier _arrival;
  var _arrivalSent = false;
  Rules? _rules;

  @override
  void initState() {
    super.initState();
    final clock = _clock = ref.read(clockProvider);
    _service = ref.read(syncServiceProvider.future);
    _trail = ref.read(paintTrailProvider.notifier);
    _active = ref.read(walkingActiveProvider.notifier);
    _arrival = ref.read(campArrivalProvider.notifier);
    // 위젯을 짓는 중에는 provider를 못 바꾼다
    Future.microtask(() => _setActive(true));
    _now = clock();
    _start = ref.read(paintTrailProvider).start ?? _now;
    final summary = _trail.summaryAt(_now);
    _shownM = summary?.distanceM ?? 0;
    _stepFollower.snap(summary?.steps ?? 0);
    _catchUps = _trail.live?.catchUps ?? 0;
    _ticker = createTicker(_onTick)..start();
    ref.listenManual(snapshotProvider, (_, next) {
      final s = next.value;
      if (s != null) _onSnapshot(s);
    }, fireImmediately: true);
    ref.listenManual(paintTrailProvider, _onTrail, fireImmediately: true);
    _service.then((svc) {
      if (!mounted) return;
      _badgeSub = svc.newBadges.listen(_onBadges);
      // 지난번에 만남 흐름을 못 끝냈으면 이어서 보여 준다
      unawaited(_checkMeeting(svc).catchError((Object e) => debugPrint('길 위 만남 읽기 실패: $e')));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _badgeSub?.cancel();
    _eventTimer?.cancel();
    _badgeTimer?.cancel();
    Future.microtask(() => _setActive(false));
    _ticker.dispose();
    // 화면을 떠나면 쉼터 늦은 도착을 넘긴다 (정리 중에는 provider를 못 바꾼다)
    if (!_arrivalSent) {
      final send = _arrivalSender(_clock());
      Future.microtask(send);
    }
    _pacer.dispose();
    super.dispose();
  }

  /// 물감 길 상태가 바뀌었다: 새 기록이면 따라갈 속도를, 새 카드면 띄우고, 이정표를 넘겼으면 만남을 본다
  void _onTrail(PaintTrailState? prev, PaintTrailState next) {
    if (prev != null && next.refreshes != prev.refreshes) {
      final record = next.record;
      final rules = ref.read(rulesProvider).value;
      if (record != null && rules != null) {
        _catchUpMps =
            math.max(0.0, record.summary.distanceM - _shownM) / rules.walkingRefreshSec;
      }
    }
    if (next.cards.isNotEmpty && next.cardSeq != prev?.cardSeq) {
      _eventQueue.addAll(next.cards);
      Future.microtask(_trail.takeCards);
      if (_event == null) Future.microtask(_nextCard);
    }
    if (prev != null && next.flushes != prev.flushes) {
      unawaited(_service.then(_checkMeeting).catchError((Object e) {
        debugPrint('길 위 만남 읽기 실패: $e');
      }));
    }
  }

  /// 기다리는 카드를 하나 띄우고 config hud.eventCardSec 뒤 다음으로 넘긴다
  void _nextCard() {
    if (!mounted) return;
    _eventTimer?.cancel();
    if (_eventQueue.isEmpty) {
      if (_event != null) setState(() => _event = null);
      return;
    }
    setState(() => _event = _eventQueue.removeAt(0));
    final shownFor = HudMetrics.eventCardOverride ??
        _seconds(ref.read(rulesProvider).requireValue.eventCardSec);
    _eventTimer = Timer(shownFor, _nextCard);
  }

  /// 새 도장 한 줄을 걸음 알약 아래에 잠깐 띄운다
  void _onBadges(List<stamp.Badge> badges) {
    if (!mounted) return;
    _badgeTimer?.cancel();
    setState(() => _badgeLine = stamp.newBadgeToast(badges));
    final shownFor = HudMetrics.badgeLineOverride ??
        _seconds(ref.read(rulesProvider).requireValue.stampLineSec);
    _badgeTimer = Timer(shownFor, () {
      if (mounted) setState(() => _badgeLine = null);
    });
  }

  void _closeEvent() {
    _eventQueue.clear();
    _nextCard();
  }

  /// 만남 칸이 나왔거나 지난번에 흐름을 못 끝낸 동행이 있으면 길 위 만남을 띄운다
  Future<void> _checkMeeting(SyncService svc) async {
    if (_meet != null || _ending || !mounted) return;
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
      if (mounted) ref.invalidate(companionsViewProvider);
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

  /// 도착이 확정됐으면(동기화가 정한다) 도착 화면으로 바꾼다. 배 구간에 들어설 때마다 한 번만 토스트
  void _onSnapshot(Snapshot s) {
    final arrival = s.pendingArrival;
    if (arrival != null && !_ending) {
      _ending = true;
      // 화면을 짓는 중일 수 있어서 이번 프레임이 끝난 뒤에 넘어간다
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toArrival(arrival.journeyId);
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

  void _onTick(Duration elapsed) {
    final rules = ref.read(rulesProvider).value;
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (rules == null) return;

    _rules = rules;
    final now = ref.read(clockProvider)();
    final summary = _trail.summaryAt(now);
    _probeArrival(summary, now);
    _trail.flushEvents(now);
    final walkMps = summary == null ? 0.0 : speedMps(summary.lastSteps, summary.lastGait, rules);
    _stepCompanion(summary, walkMps, dt, rules);
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
    final catchUps = _trail.live?.catchUps ?? 0;
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

  /// 함께 걷는 동행을 프레임 하나만큼 움직인다 (장면과 같은 기준: 걸음이 있으면 걷기, 뛰는 중이면 뛰기,
  /// 길 위 만남 동안은 장면이 멈춰 있어 서 있기)
  void _stepCompanion(WalkSummary? summary, double walkMps, double dt, Rules rules) {
    final companion = _walkingWith;
    if (companion == null) return;
    final moving = _meet == null && summary != null && summary.lastSteps > 0;
    _pacer.step(
      companion: companion,
      user: !moving
          ? PaceMotion.stand
          : _isRunning(summary)
          ? PaceMotion.run
          : PaceMotion.walk,
      userMps: moving ? walkMps : 0,
      onSea: ref.read(snapshotProvider).value?.onSea ?? false,
      dt: math.min(dt, _paceMaxDt),
      rules: rules,
    );
  }

  /// 지금 뛰는 중인가 (화면의 '달리는 중'과 같은 기준)
  bool _isRunning(WalkSummary? s) => s != null && s.lastSteps > 0 && s.lastGait == Gait.run;

  /// 화면을 [end]에 떠났다고 쉼터에 넘기는 일 (한 번만). 뒤처지지 않았으면 늦은 도착 0
  void Function() _arrivalSender(DateTime end) {
    _arrivalSent = true;
    final rules = _rules;
    final lateSec = rules == null ? 0.0 : lateArrivalSec(_pacer.lagM, rules);
    return () {
      try {
        _arrival.finishWalk(end, lateSec);
      } catch (_) {
        // 앱이 통째로 정리되는 중이면 넘길 곳이 없다
      }
    };
  }

  /// 센서 미리보기가 남은 거리를 넘으면 동기화를 바로 돌려 도착이 확정됐는지 본다.
  /// 진행 기준은 언제나 health 동기화 값이라 여기서 도착을 정하지는 않는다 (M1)
  void _probeArrival(WalkSummary? summary, DateTime now) {
    if (_ending || summary == null) return;
    final j = ref.read(snapshotProvider).value?.journey;
    if (j == null) return;
    final saved = ref.read(paintTrailProvider).record?.summary.distanceM ?? 0;
    final extraM = summary.distanceM - saved;
    if (!previewReachesDest(remainingKm: j.progress.remainingKm, extraM: extraM)) return;
    final probeSec = ref.read(rulesProvider).requireValue.arrivalProbeSec;
    if (!arrivalProbeDue(_probeAt, now, probeSec)) return;
    _probeAt = now;
    unawaited(_trail.refreshNow());
  }

  /// 진행 100%: 도착 화면으로 바꾼다 (물감 길은 이어지고, 도착 화면을 닫으면 쉼터).
  /// 이 화면이 맨 위가 아니면(물감 길이 끝나 닫히는 중) 바꾸지 않는다: pushReplacement는 맨 위 경로를
  /// 바꾸므로 쉼터를 바꿔 버린다. 그때는 이 화면이 닫힌 뒤 AutoSync가 도착 화면을 띄운다
  void _toArrival(String journeyId) {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (!_arrivalSent) _arrivalSender(_clock())();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ArrivalScreen(journeyId: journeyId, fromWalk: true),
    ));
  }

  /// 쉼터 아이콘: 화면만 쉼터로 (물감 길은 이어진다)
  void _toRest() => Navigator.of(context).popUntil((r) => r.isFirst);

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
    final summary = _trail.summaryAt(_now);
    final running = _isRunning(summary);
    final spirit = ref.watch(spiritLookProvider);
    final meet = _meet;
    final view = ref.watch(companionsViewProvider).value;
    final companion = _walkingWith = view?.metById(view.walkingWith)?.companion;
    final shownM = meet == null ? _shownM : _meetShownM;

    return Scaffold(
      body: Stack(
        children: [
          SceneView(
            mode: SceneMode.walking,
            distanceM: shownM,
            nowUtc: _now,
            position: position,
            onSea: snap.onSea,
            rules: rules,
            landmarks: landmarks,
            running: meet == null && running,
            moving: meet == null && summary != null && summary.lastSteps > 0,
            sceneSeed: snap.journey?.dest.id ?? 'home',
            spirit: spirit,
            boat: ref.watch(sceneBoatProvider).value,
            // 길 위 만남 동안에는 장면에 동행을 두지 않는다 (캔버스 3-4)
            walkCompanion: companion == null || meet != null
                ? null
                : (spot) => WalkCompanionLayer(
                      companion: companion,
                      pace: _pacer.frame,
                      spot: spot,
                    ),
            walkGround: (spot) => PaintDropLayer(spot: spot, shownM: shownM, rules: rules),
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
              event: _event,
              eventKm: rules.eventEveryKm,
              onCloseEvent: _closeEvent,
              badgeLine: _badgeLine,
              storyLine: _storyLine(rules),
              onRest: _toRest,
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

  /// 펼침 카드의 동행 줄. 혼자 걷는 중이면(또는 아직 못 읽었으면) null
  String? _storyLine(Rules rules) {
    final view = ref.watch(companionsViewProvider).value;
    final now = view?.metById(view.walkingWith);
    return now == null ? null : walkingStoryLine(now, rules);
  }

  /// 다음 방명록 지점까지 남은 걸음. 마지막 숫자를 넘었거나 아직 못 읽었으면 null
  int? _nextMilestone(Snapshot snap) {
    final milestones = ref.watch(milestonesProvider).value;
    if (milestones == null) return null;
    final next = nextMilestone(snap.totalSteps, milestones);
    return next == null ? null : next - snap.totalSteps;
  }
}

/// config의 초(소수 가능) → Duration
Duration _seconds(double sec) => Duration(milliseconds: (sec * 1000).round());
