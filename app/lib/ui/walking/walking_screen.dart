import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/companion_providers.dart';
import '../../app/paint_providers.dart';
import '../../app/paint_trail_controller.dart';
import '../../app/providers.dart';
import '../../app/shop_providers.dart';
import '../../app/sync_service.dart';
import '../../domain/badge.dart' as stamp;
import '../../domain/bucket.dart' show epochMinute;
import '../../domain/companion.dart';
import '../../domain/companion_pace.dart';
import '../../domain/follow.dart';
import '../../domain/gait.dart';
import '../../domain/geo.dart';
import '../../domain/milestones.dart';
import '../../domain/landmark.dart';
import '../../domain/paint_color.dart' show PaintWeather, RegionPaint, regionPaintAt;
import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
import '../../domain/walk_arrival.dart';
import '../../domain/walk_record.dart';
import '../common/toast.dart';
import '../companion/companion_pacer.dart';
import '../companion/companion_slot.dart' show openCompanions;
import '../companion/companion_walk_layer.dart';
import '../companion/meet_flow.dart';
import '../companion/story_lines.dart';
import '../guestbook/guestbook_write_screen.dart';
import '../scene/scene_view.dart';
import '../tabs/home_tabs.dart';
import 'guestbook_sign.dart';
import 'paint_drop_layer.dart';
import 'walking_hud.dart';

/// 걷기 탭의 처음 화면 = 걷는 중 (캔버스 3-1, 16장 11/13 물감 길·11/18 ④⑤·11/19). 앱이 떠 있는 동안 계속 있고
/// (탭을 오가도 그대로), 물감 길이 열려 있으면 걷는 중, 아니면 쉬는 중이다: 땅이 멈추고 정령은 둥둥 옆,
/// 동행은 옆면으로 서서 숨만 쉰다 (config companions.walkTab, 16장 11/19 걷기 탭은 무조건 옆면).
/// 걸어도·물감 길이 끝나도 탭은 저절로 바뀌지 않는다 (걷는 중이면 탭 바 걷기 아이콘의 발자국이 움직인다).
/// 왼쪽 위 쉼터 아이콘·‘걷기 마치기’·물감 고르는 버튼은 없다 (물감은 쉼터 배낭 물감 탭에서 바꾼다, 16장 11/16).
/// 장면 아래는 탭 바 위로 30pt 겹치고, 가로로 돌리면 탭 바가 숨는다 (탭 뼈대).
/// 숫자는 PaintTrailController가 주는 이번 물감 길 값이다: 걸음·거리는 health 기록과 센서 중 큰 쪽(안드로이드는
/// 감지 센서가 카운터보다 먼저 센 걸음까지, 16장 11/19), 분당 걸음과 걷기/뛰기는 센서 기준.
/// 보이는 거리는 새 값을 향해 부드럽게 따라간다. 새 물감 길이 열리면 0부터, 끝나면 0으로 돌아간다.
/// 화면이 꺼져 있던 동안 센 걸음은 앱이 돌아올 때 한꺼번에 들어오고, 그때 거리는 바로 맞춘다.
/// 땅 위로 이번 물감 길 거리 config paintDrop.spacingM마다 물감 방울이 흘러와 정령에 닿으면 줍는다 (연출만).
/// 이정표 카드(길 위 이벤트)는 컨트롤러가 만든 것을 이 화면이 보일 때 config hud.eventCardSec 동안 띄운다
/// (안 보이는 동안 넘은 칸은 마지막 events.offScreenCards장만). 새 도장을 받으면 걸음 알약 아래 작은 줄이 잠깐 뜬다.
/// 칸이 이벤트 대신 동행 만남이면(pendingMeeting) HUD를 가리고 길 위 만남(MeetFlow)을 이 화면 위에 띄운다.
/// 함께 걷는 동행은 장면에서 pace대로 따라오고, 누르면 동행 화면(안 읽은 장이 있으면 동행 위 알림 점).
/// 방명록을 쓸 수 있으면 정령 오른쪽 길가에 표지판이 화면에 고정돼 서고(걷는 중·쉬는 중 모두), 누르면 방명록 쓰기
/// (config guestbook.sign, 16장 11/18·11/19).
/// 도착은 동기화가 정하고 AutoSync가 이 탭 안에 도착 화면을 띄운다: 센서 미리보기가 남은 거리를 넘으면 이 화면이
/// 동기화를 바로 돌려 본다
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
  /// 이번 물감 길이 열린 시각 (쉬는 중이면 지금)
  late DateTime _start;
  late DateTime _now;

  /// 걷기 탭 처음 화면이 보이는가 (탭 뼈대, walkFrontProvider)
  var _front = false;
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

  /// 도착이 확정돼 더 미리 알아보지 않는다 (물감 길마다) / 마지막으로 도착 확인 동기화를 돌린 시각
  var _ending = false;
  DateTime? _probeAt;

  /// 함께 걷는 동행 (혼자면 null, 화면을 지을 때 읽는다)과 그 걸음 연출
  Companion? _walkingWith;
  final _pacer = CompanionPacer();

  /// 정령에 잠깐 보일 표정 (길 위 만남·새 소품, palette 표정 호출 표)과 마지막으로 본 안 본 소품 수
  SpiritCue? _cue;
  int? _unseenProps;

  /// [event]의 표정을 잠깐 보인다 (같은 표정이 이어져도 다시 울리게 새 객체로)
  void _cueFor(String event, {String? trigger}) {
    final c = ref.read(spiritPaletteProvider).value?.cues.of(event);
    if (c == null) return;
    setState(() => _cue = SpiritCue(c.expr, holdSec: c.holdSec, trigger: trigger ?? c.trigger));
  }

  @override
  void initState() {
    super.initState();
    final clock = _clock = ref.read(clockProvider);
    _service = ref.read(syncServiceProvider.future);
    _trail = ref.read(paintTrailProvider.notifier);
    _active = ref.read(walkingActiveProvider.notifier);
    _now = clock();
    _resetTrail(ref.read(paintTrailProvider));
    _ticker = createTicker(_onTick)..start();
    ref.listenManual(walkFrontProvider, (_, front) => _onFront(front), fireImmediately: true);
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
    if (_front) Future.microtask(() => _setActive(false));
    _ticker.dispose();
    _pacer.dispose();
    super.dispose();
  }

  /// 물감 길 상태가 바뀌었다: 새 기록이면 따라갈 속도를, 새 카드면 띄우고, 이정표를 넘겼으면 만남을 본다
  void _onTrail(PaintTrailState? prev, PaintTrailState next) {
    // 새 물감 길이 열렸거나 끝났다: 숫자를 0부터 (쉬는 중은 0)
    if (prev != null && next.id != prev.id) setState(() => _resetTrail(next));
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
    // 안 보이는 동안은 쌓아 두었다가 보일 때 띄운다 (마지막 events.offScreenCards장만)
    if (!_front) {
      final keep = ref.read(rulesProvider).value?.eventOffScreenCards ?? 1;
      if (_eventQueue.length > keep) _eventQueue.removeRange(0, _eventQueue.length - keep);
      if (_event != null) setState(() => _event = null);
      return;
    }
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
    // 길 위 만남: 놀람 + 인사 (palette companionMeet, 정령 계약 4장 ‘만남 greet’)
    _cueFor('companionMeet', trigger: 'greet');
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
    // 걷는 중에 소품을 얻으면(안 본 소품 수가 늘면) 잠깐 놀란다 (palette newProp)
    final before = _unseenProps;
    _unseenProps = s.unseenProps;
    if (before != null && s.unseenProps > before) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cueFor('newProp');
      });
    }
    // 도착이 확정됐다: 도착 화면은 AutoSync가 이 탭 안에 띄운다. 이 물감 길에서는 더 미리 알아보지 않는다
    if (s.pendingArrival != null) _ending = true;
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

    final now = ref.read(clockProvider)();
    final summary = _trail.summaryAt(now);
    // 화면 숫자·땅은 감지 센서가 먼저 센 걸음까지 (걸음마다 바로 움직인다, 16장 11/19)
    final target = _trail.shownAt(now);
    _probeArrival(summary, now);
    _trail.flushEvents(now);
    final walkMps = summary == null ? 0.0 : speedMps(summary.lastSteps, summary.lastGait, rules);
    _stepCompanion(summary, walkMps, dt, rules);
    var shown = followDistance(
      _shownM,
      target?.distanceM ?? 0,
      math.max(walkMps, _catchUpMps),
      dt,
      rules.walkingRefreshSec.toDouble(),
    );
    final shownSteps = _stepFollower.shown;
    _stepFollower.step(target?.steps ?? 0, dt);
    // 숨어 있던 동안의 걸음이 한꺼번에 들어왔으면 따라가지 않고 바로 맞춘다
    final catchUps = _trail.live?.catchUps ?? 0;
    if (catchUps != _catchUps) {
      _catchUps = catchUps;
      shown = math.max(shown, target?.distanceM ?? 0);
      _stepFollower.snap(target?.steps ?? 0);
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
  /// 그 순간 물감 색 id: 분·날씨·뛰기가 같으면 다시 계산하지 않는다 (해 뜨고 지는 시각 계산)
  String _momentColor(Rules rules, LatLng position, bool running) {
    final weather = ref.watch(paintWeatherProvider).kindFor(_now, _start);
    final key = (epochMinute(_now), weather, running, position.lat, position.lng);
    final cached = _moment;
    if (cached != null && cached.$1 == key) return cached.$2;
    final id = momentColorFor(position, _now, weather, running ? Gait.run : Gait.walk, rules);
    _moment = (key, id);
    return id;
  }

  ((int, PaintWeather?, bool, double, double), String)? _moment;

  /// 지금 권역의 지역 색 (가장 가까운 명소의 권역, M1 v0.8): 지점이 같으면 다시 찾지 않는다
  RegionPaint? _regionColor(Rules rules, LatLng position, List<Landmark> landmarks) {
    final cached = _region;
    if (cached != null && cached.$1 == position) return cached.$2;
    final region = regionPaintAt(position, landmarks, rules);
    _region = (position, region);
    return region;
  }

  (LatLng, RegionPaint?)? _region;

  bool _isRunning(WalkSummary? s) => s != null && s.lastSteps > 0 && s.lastGait == Gait.run;

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

  /// 물감 길 [t]에 맞춰 숫자를 0(또는 지금 값)부터 다시 (새 물감 길·끝·처음 지을 때)
  void _resetTrail(PaintTrailState t) {
    _start = t.start ?? _now;
    final shown = _trail.shownAt(_now);
    _shownM = shown?.distanceM ?? 0;
    _stepFollower.reset(shown?.steps ?? 0);
    _catchUps = _trail.live?.catchUps ?? 0;
    _catchUpMps = 0;
    _ending = false;
    _probeAt = null;
  }

  /// 걷기 탭 처음 화면이 보이게 됐거나 가려졌다 (탭 뼈대). 보이는 동안만 도장 줄을 이 화면이 맡고,
  /// 보이게 되면 쌓인 이정표 카드를 띄우고 숫자를 지금 값으로 맞춘다 (안 보이는 동안은 프레임이 멈춰 있었다)
  void _onFront(bool front) {
    if (front == _front) return;
    _front = front;
    Future.microtask(() => _setActive(front));
    if (!front) return;
    final shown = _trail.shownAt(_clock());
    if (shown != null) {
      _shownM = math.max(_shownM, shown.distanceM);
      _stepFollower.snap(shown.steps);
    }
    if (_event == null && _eventQueue.isNotEmpty) Future.microtask(_nextCard);
    if (mounted) setState(() {});
  }

  /// 함께 걷는 동행을 누르면 동행 화면 (config companions.walkTab.tap, 걷기 탭 안)
  void _openCompanion() => openCompanions(context);

  /// 길가 표지판을 누르면 방명록 쓰기 (config guestbook.sign.tap 5-1)
  void _openGuestbook(String ticketId) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => GuestbookWriteScreen(ticketId: ticketId)));

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
    // 방울에 곱하는 그 순간 물감 색 (시간대·날씨·뛰기, 16장 11/14), 방울 보상을 정하는 물감 길 번호,
    // 그 색 통을 더 주울 수 있는가 (장면 builder 안이 아니라 여기서 읽는다)
    final moment = _momentColor(rules, position, running);
    final dropColor = rules.paintColor.hexOf(moment);
    final trailId = ref.watch(paintTrailProvider.select((s) => s.id));
    final tubeAllowed = ref.watch(paintTubeRoomProvider(moment)).value ?? true;
    // 지역 색으로 나오는 물감 통 (통의 config region.chancePerTube, 지금 권역의 지역 색)
    final region = _regionColor(rules, position, landmarks);
    final regionAllowed =
        region == null || (ref.watch(paintTubeRoomProvider(region.stockId)).value ?? true);
    // 안 읽은 장 알림 점은 동행 위에도 (config companions.walkTab.dot)
    final storyDot = rules.screen.dotOn('companion') && ref.watch(unreadStoryProvider);
    final ticket = snap.guestbookTicket;

    return Scaffold(
      // 화면 가득: 길 위 만남 동안 HUD가 Offstage(0×0)여도 장면이 0으로 줄지 않게
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 장면 아래는 탭 바 위로 30pt 겹친다 (캔버스 3-1)
          Positioned.fill(
            bottom: TabBarSpace.sceneBottom(context),
            child: SceneView(
            mode: SceneMode.walking,
            distanceM: shownM,
            nowUtc: _now,
            position: position,
            onSea: snap.onSea,
            rules: rules,
            landmarks: landmarks,
            running: meet == null && running,
            moving: meet == null && summary != null && summary.lastSteps > 0,
            // 걷기·뛰기 동작을 분당 걸음에 맞춰 빠르게·느리게 (16장 11/19)
            playback: rules.screen.spirit.walkPlayback.rateFor(summary?.lastSteps ?? 0),
            sceneSeed: snap.journey?.dest.id ?? 'home',
            spirit: spirit,
            spiritCue: _cue,
            spiritCues: ref.watch(spiritPaletteProvider).value?.cues,
            boat: ref.watch(sceneBoatProvider).value,
            // 길 위 만남 동안에는 장면에 동행을 두지 않는다 (캔버스 3-4)
            walkCompanion: companion == null || meet != null
                ? null
                : (spot) => WalkCompanionLayer(
                      companion: companion,
                      pace: _pacer.frame,
                      spot: spot,
                      onTap: _openCompanion,
                      notice: storyDot,
                    ),
            // 방명록을 쓸 수 있으면 길가 표지판 (길 위 만남 동안은 숨김)
            walkRoadside: ticket == null || meet != null
                ? null
                : (spot) => GuestbookRoadSign(
                      spot: spot,
                      screenX: rules.screen.tabs.signScreenX,
                      onTap: () => _openGuestbook(ticket.id),
                    ),
            walkGround: (spot) => PaintDropLayer(
              spot: spot,
              shownM: shownM,
              rules: rules,
              color: dropColor,
              trailId: trailId,
              tubeAllowed: tubeAllowed,
              regionColor: region?.hex,
              regionAllowed: regionAllowed,
            ),
          ),
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
              // 쉬는 중(물감 길 없음)이면 0
              walkingTime: trailId == null ? Duration.zero : _now.difference(_start),
              running: running,
              nextMilestone: _nextMilestone(snap),
              event: _event,
              eventKm: rules.eventEveryKm,
              onCloseEvent: _closeEvent,
              badgeLine: _badgeLine,
              storyLine: _storyLine(rules),
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
