import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/walk_notice.dart';
import '../domain/gait.dart';
import '../domain/live_walk.dart';
import '../domain/paint_trail.dart';
import '../domain/road_event.dart' show EventLive;
import '../domain/rules.dart';
import '../domain/walk_record.dart';
import 'companion_providers.dart';
import 'live_walker.dart';
import 'providers.dart';
import 'sync_service.dart';

/// 물감 길 판정·기록을 몇 초마다 돌리는 간격 (멈춤 판정·이정표 거리 넘기기·알림 갱신). 화면 구성값이다
const paintTrailTick = Duration(seconds: 5);

/// 화면이 보는 물감 길 상태 (PaintTrailController). 숫자 그 자체(센서 걸음)는 [PaintTrailController.live]에서
/// 프레임마다 읽는다
class PaintTrailState {
  const PaintTrailState({
    this.id,
    this.start,
    this.record,
    this.refreshes = 0,
    this.cards = const [],
    this.cardSeq = 0,
    this.flushes = 0,
    this.endedKm,
    this.endedSeq = 0,
  });

  /// 열린 물감 길 번호와 시작 (첫 걸음의 분). 없으면 null
  final int? id;
  final DateTime? start;

  /// 이 물감 길의 health 기록 (동기화마다 새로 계산, 아직이면 null)
  final WalkRecord? record;

  /// [record]를 새로 받은 횟수 (화면이 진행 줄·이야기 줄을 다시 읽는다)
  final int refreshes;

  /// 새로 보여 줄 이정표 카드 (화면이 꺼진 동안 넘은 칸은 마지막 config events.offScreenCards장만)와 그 차례 번호
  final List<RoadEventView> cards;
  final int cardSeq;

  /// 이정표 거리를 넘긴 횟수 (화면이 길 위 만남을 다시 본다)
  final int flushes;

  /// 방금 끝난 물감 길의 거리(km, 쉼터 토스트 `물감 길 n km를 그렸어요`)와 그 차례 번호
  final double? endedKm;
  final int endedSeq;

  bool get active => id != null;

  PaintTrailState copyWith({
    int? Function()? id,
    DateTime? Function()? start,
    WalkRecord? Function()? record,
    int? refreshes,
    List<RoadEventView>? cards,
    int? cardSeq,
    int? flushes,
    double? Function()? endedKm,
    int? endedSeq,
  }) =>
      PaintTrailState(
        id: id == null ? this.id : id(),
        start: start == null ? this.start : start(),
        record: record == null ? this.record : record(),
        refreshes: refreshes ?? this.refreshes,
        cards: cards ?? this.cards,
        cardSeq: cardSeq ?? this.cardSeq,
        flushes: flushes ?? this.flushes,
        endedKm: endedKm == null ? this.endedKm : endedKm(),
        endedSeq: endedSeq ?? this.endedSeq,
      );
}

/// 물감 길 (16장 11/13, M1 명세 v0.5 ②·④, M2~M6 v0.17 T): 앱이 살아 있는 동안 기기 걸음 센서를 듣고
/// - 앱이 앞에 있을 때 60초 안에 10보(config paintTrail.startMinSteps)가 늘면 물감 길을 연다 (DB PaintTrails,
///   안드로이드 상시 알림 N0 시작). 화면 전환(쉼터 → 걷는 중)은 PaintTrailHost가 이 상태를 보고 한다.
/// - 걸음이 idleEndMin분 멈추면 마지막 걸음 분의 끝에 닫는다 (idle, N0 끄기). 앱이 끝나면 다음 실행에서
///   AutoSync가 마지막으로 살아 있던 시각에 닫는다 (appEnded).
/// - 열린 동안 센서가 센 실제 거리(화면이 꺼진 동안 따라잡은 걸음 포함)를 config events.flushSec마다
///   길 위 이벤트 계산에 넘기고, 새 이정표 카드를 [PaintTrailState.cards]에 둔다.
/// - 열린 동안 앱이 앞에 있으면 config sync.walkingRefreshSec마다 동기화하고 이 물감 길의 health 기록을 낸다.
/// 센서 권한은 묻지 않는다 (시작 흐름 권한 단계가 묻는다). 없으면 물감 길이 열리지 않는다.
/// 앱을 켠 직후 앞 실행의 물감 길을 닫은 뒤(trailsReadyProvider)에 시작한다
class PaintTrailController extends Notifier<PaintTrailState> {
  LiveWalker? _walker;
  PaintTrailTracker? _tracker;
  Rules? _rules;
  Timer? _timer;
  var _begun = false;
  var _disposed = false;

  /// 물감 길을 여는 중 (DB에 쓰는 사이 같은 시작을 두 번 하지 않게)
  Future<void>? _opening;

  /// 이정표 계산에 넘긴 센서 거리(m)와 마지막으로 넘긴 시각, 넘기는 중
  var _eventSentM = 0.0;
  DateTime? _eventAt;
  var _eventBusy = false;

  /// 마지막 동기화 시각과 동기화 중
  DateTime? _refreshAt;
  var _refreshing = false;

  /// 상시 알림: 켰는가, 마지막으로 쓴 걸음·거리·뛰는 중·시각
  var _noticeOn = false;
  var _noticeSteps = 0;
  var _noticeDistanceM = 0.0;
  var _noticeRunning = false;
  DateTime? _noticeAt;

  /// 상시 알림 (정리할 때는 ref를 못 쓰므로 처음에 잡아 둔다)
  WalkNotice? _notice;

  @override
  PaintTrailState build() {
    _notice = ref.read(walkNoticeProvider);
    ref.onDispose(_dispose);
    ref.listen(trailsReadyProvider, (_, ready) {
      if (ready) unawaited(_begin());
    });
    if (ref.read(trailsReadyProvider)) Future.microtask(_begin);
    return const PaintTrailState();
  }

  /// 이번 물감 길의 센서 걸음 (센서가 없거나 물감 길이 없으면 null). 화면이 프레임마다 읽는다
  LiveWalk? get live => state.active && (_walker?.ready ?? false) ? _walker!.walk : null;

  /// 화면에 보이는 이번 물감 길 숫자 (health 기록과 센서 중 큰 쪽, liveSummary)
  WalkSummary? summaryAt(DateTime now) {
    final walk = live;
    final health = state.record?.summary;
    return walk == null ? health : liveSummary(health, walk, now);
  }

  /// 지금 바로 동기화해서 이 물감 길 기록을 새로 낸다 (도착 확인). 돌고 있으면 그것을 기다린다
  Future<void> refreshNow() => _refresh(force: true);

  /// 센서 판정을 기다리지 않고 지금 물감 길을 연다 (개발자 화면·시험). 이미 열려 있거나 판정이 아직
  /// 시작되지 않았으면 아무 일도 없다. 센서 걸음은 이 뒤에 처음 받는 값을 기준으로 센다
  Future<void> startNow() async {
    final tracker = _tracker;
    if (tracker == null || tracker.active || _opening != null) return;
    final now = _now();
    final start = minuteStart(now);
    tracker.resume(start, lastStep: now);
    _walker?.restart();
    await (_opening ??= _open(start).whenComplete(() => _opening = null));
  }

  /// 센서 거리 중 아직 안 넘긴 만큼을 이정표 계산에 넘긴다 (config events.flushSec 간격 안이면 건너뛴다).
  /// 걷는 중 화면이 프레임마다 부르고, 화면이 없을 때는 [paintTrailTick]마다 돈다
  void flushEvents(DateTime now) {
    final rules = _rules;
    if (rules == null || !state.active || _opening != null) return;
    unawaited(_flushEvents(rules, now));
  }

  /// 보여 준 카드를 치운다 (화면이 카드를 띄웠으면 부른다)
  void takeCards() {
    if (state.cards.isNotEmpty) state = state.copyWith(cards: const []);
  }

  Future<void> _begin() async {
    if (_begun || _disposed) return;
    _begun = true;
    try {
      final rules = await ref.read(rulesProvider.future);
      _rules = rules;
      final svc = await ref.read(syncServiceProvider.future);
      if (_disposed) return;
      final tracker = _tracker = PaintTrailTracker(rules);
      final denied = ref.read(liveDeniedProvider.notifier);
      final walker = _walker = LiveWalker(
        steps: ref.read(liveStepsProvider),
        rules: rules,
        clock: ref.read(clockProvider),
        denied: () => denied.denied,
        onDenied: () => denied.set(true),
        onGain: _onGain,
        onHiddenSteps: (p) => _pushNotice(
          math.max(_noticeSteps, p.steps),
          math.max(_noticeDistanceM, p.distanceM),
        ),
        ask: false,
      );
      // 앱이 살아 있는 채 새로 만들어졌으면 열린 물감 길을 이어 받는다
      final open = await svc.openPaintTrail();
      if (open != null && !_disposed) {
        final now = _now();
        tracker.resume(_utc(open.startUtc), lastStep: now);
        state = state.copyWith(id: () => open.id, start: () => _utc(open.startUtc));
      }
      await walker.start();
      if (_disposed) return;
      if (state.active) _startNotice();
      _timer = Timer.periodic(paintTrailTick, (_) => _tick());
    } catch (e) {
      debugPrint('물감 길 시작 실패: $e');
    }
  }

  void _dispose() {
    _disposed = true;
    _timer?.cancel();
    _walker?.dispose();
    if (_noticeOn) {
      _noticeOn = false;
      unawaited(_notice?.stop());
    }
  }

  DateTime _now() => ref.read(clockProvider)();

  void _onGain(SensorGain g, int total) {
    final tracker = _tracker;
    if (tracker == null || _disposed) return;
    final wasActive = tracker.active;
    final start = tracker.add(g);
    if (wasActive) {
      // 열린 동안 앞에서 센 걸음은 바로 이정표 계산(events.flushSec 간격)과 알림(live.noticeUpdateSec 간격)에
      if (g.foreground && state.active && _opening == null) {
        unawaited(_flushEvents(_rules!, g.at));
        final summary = summaryAt(g.at);
        if (summary != null) {
          _pushNotice(summary.steps, summary.distanceM, isRunning: _isRunning(summary));
        }
      }
      return;
    }
    if (start == null) return;
    // 시작을 일으킨 걸음까지 세게 그 걸음들 전 누적값을 기준으로 둔다
    final startSteps = tracker.lastStartSteps;
    _walker?.restart(baseline: total - startSteps, at: start);
    _opening ??= _open(start).whenComplete(() => _opening = null);
  }

  Future<void> _open(DateTime start) async {
    try {
      final svc = await ref.read(syncServiceProvider.future);
      final id = await svc.startPaintTrail(start, _now());
      if (_disposed) return;
      _eventSentM = 0;
      _eventAt = null;
      _refreshAt = null;
      state = PaintTrailState(
        id: id,
        start: start,
        cardSeq: state.cardSeq,
        flushes: state.flushes,
        endedSeq: state.endedSeq,
      );
      _startNotice();
      unawaited(_refresh(force: true));
    } catch (e) {
      debugPrint('물감 길 열기 실패: $e');
      // 판정기는 열린 채라 걸음이 멈추면 닫으려 한다: 번호가 없으니 판정기만 비운다
      _tracker?.close(_now(), PaintTrailEnd.idle);
    }
  }

  Future<void> _tick() async {
    final tracker = _tracker;
    if (tracker == null || _disposed || _opening != null || !state.active) return;
    final now = _now();
    final end = tracker.idleEnd(now);
    if (end != null) {
      await _close(end);
      return;
    }
    final rules = _rules!;
    _flushEvents(rules, now);
    final summary = summaryAt(now);
    if (summary != null && !(_walker?.hidden ?? false)) {
      _pushNotice(summary.steps, summary.distanceM, isRunning: _isRunning(summary));
    }
    final last = _refreshAt;
    if (last == null || now.difference(last) >= Duration(seconds: rules.walkingRefreshSec)) {
      unawaited(_refresh());
    }
  }

  /// 걸음이 멈춰 물감 길을 [end]에 닫는다: 숨어 있던 걸음까지 이정표에 넘기고, 알림을 끄고,
  /// 끝난 거리를 쉼터 토스트로 알린다
  Future<void> _close(DateTime end) async {
    final id = state.id;
    if (id == null) return;
    final now = _now();
    _walker?.feedHidden();
    final km = math.max(state.record?.actualM ?? 0, live?.distanceM ?? 0) / 1000;
    await _flushEvents(_rules!, now, force: true);
    _tracker?.close(end, PaintTrailEnd.idle);
    _stopNotice();
    final seq = state.endedSeq + 1;
    state = PaintTrailState(
      cardSeq: state.cardSeq,
      flushes: state.flushes,
      endedKm: km,
      endedSeq: seq,
    );
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.endPaintTrail(id, end, now);
      if (ref.read(appForegroundProvider)) await svc.sync(now);
      if (_disposed) return;
      ref.invalidate(snapshotProvider);
      ref.invalidate(companionsViewProvider);
    } catch (e) {
      debugPrint('물감 길 닫기 실패: $e');
    }
  }

  /// 센서가 센 거리 중 아직 안 넘긴 만큼을 길 위 이벤트 계산에 넘긴다. 마지막으로 넘긴 뒤
  /// events.flushSec가 안 지났거나 넘기는 중이면 건너뛴다 ([force]면 간격은 무시).
  /// 새 줄이 생기면 마지막 events.offScreenCards장을 카드로 둔다
  Future<void> _flushEvents(Rules rules, DateTime now, {bool force = false}) async {
    final walk = live;
    if (walk == null || _eventBusy) return;
    final sentM = walk.distanceM;
    final delta = sentM - _eventSentM;
    if (delta <= 0) return;
    final last = _eventAt;
    if (!force && last != null && now.difference(last) < Duration(seconds: rules.eventFlushSec)) {
      return;
    }
    _eventBusy = true;
    _eventAt = now;
    try {
      final summary = summaryAt(now);
      final saved = state.record?.summary;
      final liveRun =
          walk.minutes.where((m) => m.gait == Gait.run).fold(0, (a, m) => a + m.steps);
      final runSteps = math.max(summary?.runSteps ?? 0, liveRun);
      final facts = EventLive(
        sessionKm: (summary?.distanceM ?? 0) / 1000,
        runKm: runSteps * rules.runStrideM / 1000,
        pendingSteps: math.max(0, (summary?.steps ?? 0) - (saved?.steps ?? 0)),
        pendingM: math.max(0.0, (summary?.distanceM ?? 0) - (saved?.distanceM ?? 0)),
      );
      final svc = await ref.read(syncServiceProvider.future);
      final made = await svc.addEventDistance(delta, now, facts);
      _eventSentM = sentM;
      if (_disposed) return;
      final keep = rules.eventOffScreenCards;
      state = state.copyWith(
        flushes: state.flushes + 1,
        cards: made.isEmpty || keep <= 0
            ? null
            : made.sublist(math.max(0, made.length - keep)),
        cardSeq: made.isEmpty || keep <= 0 ? null : state.cardSeq + 1,
      );
    } catch (e) {
      debugPrint('길 위 이벤트 계산 실패: $e');
    } finally {
      _eventBusy = false;
    }
  }

  /// 동기화하고 이 물감 길의 health 기록을 새로 낸다. 앱이 뒤에 있으면 하지 않는다 (건강 앱을 뒤에서 못 읽는다).
  /// 겹쳐 돌지 않는다
  Future<void> _refresh({bool force = false}) async {
    if (_refreshing || _disposed) return;
    if (!force && !ref.read(appForegroundProvider)) return;
    final start = state.start;
    if (start == null) return;
    _refreshing = true;
    final now = _now();
    _refreshAt = now;
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.sync(now);
      final record = await svc.walkRecord(start, now, live: live?.minutes ?? const []);
      if (_disposed) return;
      ref.invalidate(snapshotProvider);
      // 걷기가 인정되면 이야기 진행이 는다 (펼침 카드의 동행 줄)
      ref.invalidate(companionsViewProvider);
      if (state.start == start) {
        state = state.copyWith(record: () => record, refreshes: state.refreshes + 1);
        // health 값이 더 크면 화면에 보이는 그 값을 알림에도 (간격 규칙은 그대로)
        final summary = summaryAt(_now());
        if (summary != null && !(_walker?.hidden ?? false)) {
          _pushNotice(summary.steps, summary.distanceM, isRunning: _isRunning(summary));
        }
      }
    } catch (e) {
      debugPrint('물감 길 동기화 실패: $e');
    } finally {
      _refreshing = false;
    }
  }

  bool _isRunning(WalkSummary? s) => s != null && s.lastSteps > 0 && s.lastGait == Gait.run;

  /// 센서를 읽을 수 있으면 상시 알림을 시작한다 (센서 권한이 없으면 안드로이드 14가
  /// 건강 서비스를 못 띄우게 하므로 시작하지 않는다)
  void _startNotice() {
    if (_noticeOn || !(_walker?.ready ?? false)) return;
    final summary = summaryAt(_now());
    _noticeSteps = summary?.steps ?? 0;
    _noticeDistanceM = summary?.distanceM ?? 0;
    _noticeRunning = _isRunning(summary);
    _noticeAt = _now();
    _noticeOn = true;
    unawaited(_notice?.start(_noticeSteps, _noticeDistanceM, isRunning: _noticeRunning));
  }

  void _stopNotice() {
    if (!_noticeOn) return;
    _noticeOn = false;
    unawaited(_notice?.stop());
  }

  /// 알림의 걸음·거리를 새로 쓴다. 알림 글이 바뀔 때만 (걸음이 다르거나 0.1km 단위 거리가 다르거나
  /// 뛰는 중 제목이 달라질 때), rules.liveNoticeUpdateSec초에 한 번까지. [isRunning]이 없으면 마지막 값
  void _pushNotice(int steps, double distanceM, {bool? isRunning}) {
    final rules = _rules;
    if (!_noticeOn || rules == null) return;
    final running = isRunning ?? _noticeRunning;
    if (steps == _noticeSteps &&
        noticeKm(distanceM) == noticeKm(_noticeDistanceM) &&
        running == _noticeRunning) {
      return;
    }
    final now = _now();
    final last = _noticeAt;
    if (last != null && now.difference(last) < Duration(seconds: rules.liveNoticeUpdateSec)) {
      return;
    }
    _noticeAt = now;
    _noticeSteps = steps;
    _noticeDistanceM = distanceM;
    _noticeRunning = running;
    unawaited(_notice?.update(steps, distanceM, isRunning: running));
  }
}

final paintTrailProvider =
    NotifierProvider<PaintTrailController, PaintTrailState>(PaintTrailController.new);

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
