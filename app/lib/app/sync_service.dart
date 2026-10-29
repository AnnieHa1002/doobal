import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../data/step_source.dart';
import '../domain/bucket.dart';
import '../domain/eta.dart';
import '../domain/gait.dart';
import '../domain/geo.dart';
import '../domain/journey.dart';
import '../domain/landmark.dart';
import '../domain/prop.dart';
import '../domain/route.dart';
import '../domain/rules.dart';
import '../domain/session.dart';
import '../domain/time_kst.dart';
import '../domain/walk_record.dart';

/// 한 번 가져온 결과. 출처별 걸음은 허용 목록을 정하는 실기기 확인용
class SyncReport {
  const SyncReport(this.records, this.dropped, this.stepsBySource, {this.advancedKm = 0});

  final int records;

  /// 수동 입력·허용 목록 밖이라 버린 기록 수
  final int dropped;
  final Map<String, int> stepsBySource;

  /// 이번 동기화로 인정된 거리(km). 진행 중 여정이 있었으면 그 진행 거리의 증가,
  /// 없었으면 여행 경비의 증가(상한에서 멈춤). 같은 기록으로 또 돌리면 0
  final double advancedKm;
}

/// 걷기 마치기 직후 걷기 기록 화면의 내용
class WalkRecord {
  const WalkRecord(this.summary, this.sessions, this.countedToday);

  final WalkSummary summary;

  /// 창과 겹치는 저장된 걷기 구간 (걷기 1번 인정 여부 포함)
  final List<WalkSession> sessions;

  /// 오늘(창이 끝나는 시각의 한국 날짜) 인정된 걷기 1번 수. 하루 최대는 rules.sessionMaxPerDay
  final int countedToday;
}

class JourneyView {
  const JourneyView(this.dest, this.totalKm, this.progress, this.eta);

  final Landmark dest;
  final double totalKm;
  final JourneyProgress progress;
  final DateTime eta;
}

/// 도착했는데 도착 화면을 아직 보여 주지 않은 여정 (앱 밖에서 도착했으면 다음 실행 때 먼저 보여 준다)
class PendingArrival {
  const PendingArrival({
    required this.journeyId,
    required this.dest,
    required this.visitNo,
    required this.prevFrame,
    required this.newFrame,
    required this.journeyKm,
    required this.arrivedAt,
  });

  final String journeyId;
  final Landmark dest;

  /// 몇 번째 방문인지. 1이면 새 그림
  final int visitNo;

  /// 도착 전 액자. 첫 방문이면 null
  final Frame? prevFrame;
  final Frame newFrame;

  /// 이 여정의 환산 거리(km). 액자 등급의 기준
  final double journeyKm;
  final DateTime arrivedAt;

  /// 재방문해서 액자가 올랐는가
  bool get frameUp => prevFrame != null && newFrame.index > prevFrame!.index;
}

/// 화면에 보여 줄 지금 상태
class Snapshot {
  const Snapshot({
    required this.today,
    required this.todaySteps,
    required this.todayDistanceM,
    required this.countedSessions,
    required this.fundKm,
    required this.lastFetched,
    required this.journey,
    required this.totalSteps,
    required this.position,
    required this.onSea,
    required this.pendingArrival,
    required this.unseenProps,
    required this.paintingsCount,
    required this.totalKm,
  });

  final String today;
  final int todaySteps;
  final double todayDistanceM;
  final int countedSessions;
  final double fundKm;
  final DateTime? lastFetched;
  final JourneyView? journey;

  /// 설치 이후 모든 하루 걸음의 합 (방명록 걸음 숫자 기준)
  final int totalSteps;

  /// 장면의 현재 위치. 여정 중이면 경로 위 지점, 아니면 가장 나중에 끝난 여정(도착·멈춤)의
  /// 끝 지점, 끝난 여정이 없으면 rules.fallbackOrigin. 위치 권한은 아직 쓰지 않는다
  final LatLng position;

  /// 배 구간 위인지 (여정 중일 때만 true가 될 수 있다)
  final bool onSea;

  /// 가장 최근에 도착했는데 도착 화면을 아직 안 본 여정
  final PendingArrival? pendingArrival;

  /// 배낭에 새 소품 표시를 띄울 개수 (아직 안 본 소품)
  final int unseenProps;

  /// 얻은 그림 수
  final int paintingsCount;

  /// 설치 이후 실제로 걸은 거리(km). 하루 거리의 합이라 배 환산이 아니다 (소품 거리 기준)
  final double totalKm;
}

/// 수집 → 저장 → 계산 (M1 명세 6장). 같은 데이터로 여러 번 돌려도 결과가 같다
class SyncService {
  SyncService({
    required this.db,
    required this.source,
    required this.rules,
    required this.allowedSources,
    required this.landmarks,
    required this.props,
  });

  final AppDb db;
  final StepSource source;
  final Rules rules;
  final List<String> allowedSources;
  final Map<String, Landmark> landmarks;

  /// MVP 소품 (props.json의 mvp)
  final List<Prop> props;

  Future<SyncReport> sync(DateTime now) async {
    final state = await _ensureState(now);
    final install = _utc(state.installUtc);
    final last = state.lastFetchedUtc;
    final from = last == null
        ? install
        : _later(_utc(last).subtract(Duration(hours: rules.refetchHours)), install);
    final to = now.toUtc();

    final raw = await source.fetch(from, to);
    final kept = filterRecords(raw, allowedSources);
    final fromMin = epochMinute(from);
    final toMin = epochMinute(to);
    final minutes = toMinutes(kept)
        .where((m) => m.minute >= fromMin && m.minute <= toMin)
        .toList();

    var advancedKm = 0.0;
    await db.transaction(() async {
      final activeBefore = await _activeJourney();
      final before = await _creditedKm(activeBefore);
      await (db.delete(db.stepMinutes)
            ..where((t) => t.minuteUtc.isBetweenValues(fromMin, toMin)))
          .go();
      await db.batch((b) => b.insertAll(db.stepMinutes, [
            for (final m in minutes)
              StepMinutesCompanion.insert(minuteUtc: Value(m.minute), steps: m.steps),
          ]));
      await _recomputeDays(kstDayKey(from), kstDayKey(to));
      await _advanceJourney(to);
      await _unlockProps(to);
      await (db.update(db.syncState)..where((t) => t.id.equals(1)))
          .write(SyncStateCompanion(lastFetchedUtc: Value(to.millisecondsSinceEpoch)));
      // 도착한 여정은 더 이상 active가 아니라서 id로 다시 읽는다
      final journeyAfter = activeBefore == null
          ? null
          : await (db.select(db.journeys)..where((t) => t.id.equals(activeBefore.id)))
              .getSingle();
      advancedKm = math.max(0.0, await _creditedKm(journeyAfter) - before);
    });
    return _report(raw, kept, advancedKm: advancedKm);
  }

  /// 저장하지 않고 출처만 본다 (허용 목록을 정할 때)
  Future<SyncReport> inspect(DateTime fromUtc, DateTime toUtc) async {
    final raw = await source.fetch(fromUtc, toUtc);
    return _report(raw, filterRecords(raw, allowedSources));
  }

  /// 그때까지의 거리를 경비로 넣은 뒤, 지금 자리에서 출발한다.
  /// 출발지는 진행 중인 여정이 있으면 그 여정의 지금 지점(그 여정은 멈춘다), 없으면 쉬는 자리.
  /// [useFund]가 true면 여행 경비를 모두 더한다 (더한 만큼 경비는 줄어든다)
  Future<void> startJourney(String destId, DateTime now, {bool useFund = true}) async {
    await sync(now);
    final dest = landmarks[destId]!;
    await db.transaction(() async {
      final active = await _activeJourney();
      final origin = active == null ? await _restingPosition() : await _stop(active, now);
      final route = buildRoute(origin, dest.latLng, rules);
      // 지금 있는 명소로는 출발하지 않는다 (거리 0이라 바로 도착해 방문 수만 오른다). 멈춤도 되돌린다
      if (route.totalEffectiveKm == 0) throw StateError('이미 ${dest.name}에 있어요');
      final fund = await _fund();
      final used = useFund ? fund.km : 0.0;
      final at = now.toUtc().millisecondsSinceEpoch;
      await db.into(db.journeys).insert(JourneysCompanion.insert(
            id: 'j$at',
            originLat: origin.lat,
            originLng: origin.lng,
            destId: destId,
            // 앞 여정을 멈춘 분은 그 여정의 걸음이라 새 여정은 다음 분부터 센다
            startUtc: math.max(at, fund.fundedUntilUtc),
            fundKm: used,
            totalEffectiveKm: route.totalEffectiveKm,
            status: JourneyStatus.active,
          ));
      await (db.update(db.travelFund)..where((t) => t.id.equals(1)))
          .write(TravelFundCompanion(km: Value(fund.km - used)));
    });
  }

  /// 그때까지의 거리를 반영한 뒤, 진행 중인 여정을 지금 지점에서 멈춘다.
  /// 이후 걸음은 여행 경비로 간다. 진행 중인 여정이 없으면 동기화만 한다
  Future<void> stopJourney(DateTime now) async {
    await sync(now);
    await db.transaction(() async {
      final active = await _activeJourney();
      if (active != null) await _stop(active, now);
    });
  }

  /// 진행 중인 여정을 멈춘 것으로 닫고 멈춘 지점을 돌려준다. 방금 동기화한 상태여야 한다.
  /// 멈춘 분까지는 이 여정의 걸음(진행 거리에 이미 들어 있다)이라, 경비는 다음 분부터 센다
  Future<LatLng> _stop(JourneyRow active, DateTime now) async {
    final j = _toJourney(active);
    final p = progress(j, await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
    final at = positionAt(j.route, p.progressKm).latLng;
    await (db.update(db.journeys)..where((t) => t.id.equals(active.id))).write(JourneysCompanion(
      status: const Value(JourneyStatus.stopped),
      endLat: Value(at.lat),
      endLng: Value(at.lng),
      endedUtc: Value(now.toUtc().millisecondsSinceEpoch),
    ));
    await (db.update(db.travelFund)..where((t) => t.id.equals(1)))
        .write(TravelFundCompanion(fundedUntilUtc: Value(_nextMinuteMs(now))));
    return at;
  }

  /// 소장한 그림을 더하고 도착 화면에 쓸 값을 여정에 적는다 (도착 화면은 아직 안 보여 줌)
  Future<void> _arrive(JourneyRow active, DateTime to) async {
    final dest = landmarks[active.destId]!;
    final owned = await (db.select(db.paintingsOwned)
          ..where((t) => t.landmarkId.equals(dest.id)))
        .getSingleOrNull();
    final out = paintingAfterArrival(
      owned == null ? null : OwnedPainting(owned.visits, owned.frame, owned.bestKm),
      _toJourney(active).route.totalEffectiveKm,
      rules,
    );
    final at = to.toUtc().millisecondsSinceEpoch;
    final p = out.painting;
    await db.into(db.paintingsOwned).insertOnConflictUpdate(PaintingsOwnedCompanion.insert(
          landmarkId: dest.id,
          visits: p.visits,
          frame: p.frame,
          bestKm: p.bestKm,
          firstArrivedUtc: owned?.firstArrivedUtc ?? at,
          lastArrivedUtc: at,
        ));
    await (db.update(db.journeys)..where((t) => t.id.equals(active.id))).write(JourneysCompanion(
      status: const Value(JourneyStatus.arrived),
      arrivedUtc: Value(at),
      endLat: Value(dest.latLng.lat),
      endLng: Value(dest.latLng.lng),
      visitNo: Value(p.visits),
      prevFrame: Value(out.prevFrame),
      newFrame: Value(p.frame),
    ));
  }

  /// 새로 얻은 소품을 더한다 (한 번 얻은 소품은 없어지지 않는다).
  /// 누적 거리·걸음은 하루 요약의 합, 권역은 그림을 얻은 명소로 센다
  Future<void> _unlockProps(DateTime now) async {
    final days = await db.select(db.daySummaries).get();
    final visited = {for (final r in await db.select(db.paintingsOwned).get()) r.landmarkId};
    final earned = earnedPropIds(
      props,
      days.fold(0.0, (sum, d) => sum + d.distanceM) / 1000,
      days.fold(0, (sum, d) => sum + d.steps),
      completedRegions(visited, landmarks.values.toList()),
    );
    final owned = {for (final r in await db.select(db.propsOwned).get()) r.propId};
    final initial = {for (final p in props) if (p.kind == PropUnlockKind.initial) p.id};
    final at = now.toUtc().millisecondsSinceEpoch;
    // 기본 소품은 처음부터 가진 것이라 새 소품 표시를 켜지 않는다
    await db.batch((b) => b.insertAll(db.propsOwned, [
          for (final id in earned)
            if (!owned.contains(id))
              PropsOwnedCompanion.insert(
                  propId: id, unlockedUtc: at, seen: Value(initial.contains(id))),
        ]));
  }

  /// 도착 화면을 보여 줬다고 적는다
  Future<void> markArrivalShown(String journeyId) =>
      (db.update(db.journeys)..where((t) => t.id.equals(journeyId)))
          .write(const JourneysCompanion(arrivalShown: Value(true)));

  /// 배낭의 새 소품 표시를 지운다
  Future<void> markPropsSeen() => (db.update(db.propsOwned)..where((t) => t.seen.equals(false)))
      .write(const PropsOwnedCompanion(seen: Value(true)));

  /// 걷기 기록: [fromUtc, toUtc)와 겹치는 분의 걸음·거리·걷기/달리기와 걷기 1번 인정 여부.
  /// 동기화는 하지 않는다. 부른 쪽이 먼저 sync 한다.
  /// 하루 계산(_recomputeDays)처럼 전날 0시부터 불러 걷기/뛰기 상태를 이어 판정한다
  Future<WalkRecord> walkRecord(DateTime fromUtc, DateTime toUtc) async {
    final fromMin = epochMinute(fromUtc);
    // 끝 시각이 걸친 분도 포함 (올림)
    final toMin = (toUtc.millisecondsSinceEpoch + Duration.millisecondsPerMinute - 1) ~/
        Duration.millisecondsPerMinute;
    final minutes = await _minutesFrom(
      epochMinute(kstDayStartUtc(addDays(kstDayKey(fromUtc), -1))),
      beforeMinute: toMin,
    );
    final summary = summarizeWalk(classifyGait(minutes, rules), fromMin, toMin, rules);

    final fromMs = fromMin * Duration.millisecondsPerMinute;
    final toMs = toMin * Duration.millisecondsPerMinute;
    final rows = await (db.select(db.walkSessions)
          ..where((t) => t.startUtc.isSmallerThanValue(toMs) & t.endUtc.isBiggerThanValue(fromMs))
          ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
        .get();
    final today = await (db.select(db.daySummaries)
          ..where((t) => t.day.equals(kstDayKey(toUtc))))
        .getSingleOrNull();

    return WalkRecord(summary, [for (final r in rows) _sessionOf(r)], today?.countedSessions ?? 0);
  }

  Future<Snapshot> snapshot(DateTime now) async {
    final state = await _ensureState(now);
    final today = kstDayKey(now);
    final day = await (db.select(db.daySummaries)..where((t) => t.day.equals(today)))
        .getSingleOrNull();
    final fund = await _fund();

    final days = await db.select(db.daySummaries).get();
    JourneyView? view;
    LatLng position;
    var onSea = false;
    final active = await _activeJourney();
    if (active == null) {
      position = await _restingPosition();
    } else {
      final j = _toJourney(active);
      final p = progress(j, await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
      final daily = {for (final d in days) d.day: d.distanceM / 1000};
      final eta = etaDate(p.remainingKm, daily, today, state.firstRecordDay, rules);
      view = JourneyView(landmarks[active.destId]!, j.route.totalEffectiveKm, p, eta);
      final at = positionAt(j.route, p.progressKm);
      position = at.latLng;
      onSea = at.onSea;
    }

    return Snapshot(
      today: today,
      todaySteps: day?.steps ?? 0,
      todayDistanceM: day?.distanceM ?? 0,
      countedSessions: day?.countedSessions ?? 0,
      fundKm: fund.km,
      lastFetched: state.lastFetchedUtc == null ? null : _utc(state.lastFetchedUtc!),
      journey: view,
      totalSteps: days.fold(0, (sum, d) => sum + d.steps),
      position: position,
      onSea: onSea,
      pendingArrival: await _pendingArrival(),
      unseenProps: (await (db.select(db.propsOwned)..where((t) => t.seen.equals(false))).get())
          .length,
      paintingsCount: (await db.select(db.paintingsOwned).get()).length,
      totalKm: days.fold(0.0, (sum, d) => sum + d.distanceM) / 1000,
    );
  }

  Future<PendingArrival?> _pendingArrival() async {
    final row = await (db.select(db.journeys)
          ..where((t) =>
              t.status.equalsValue(JourneyStatus.arrived) &
              t.arrivalShown.equals(false) &
              t.visitNo.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.arrivedUtc)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return PendingArrival(
      journeyId: row.id,
      dest: landmarks[row.destId]!,
      visitNo: row.visitNo!,
      prevFrame: row.prevFrame,
      newFrame: row.newFrame!,
      journeyKm: row.totalEffectiveKm,
      arrivedAt: _utc(row.arrivedUtc!),
    );
  }

  /// 여정이 없을 때 장면의 위치: 가장 나중에 끝난 여정(도착·멈춤)의 끝 지점, 없으면 기본 출발지.
  /// 끝 지점이 안 적힌 옛 도착 여정은 목적지 명소로 본다
  Future<LatLng> _restingPosition() async {
    final row = await (db.select(db.journeys)
          ..where((t) =>
              t.endLat.isNotNull() | t.status.equalsValue(JourneyStatus.arrived))
          ..orderBy([
            (t) => OrderingTerm.desc(coalesce([t.arrivedUtc, t.endedUtc])),
            (t) => OrderingTerm.desc(t.startUtc),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return rules.fallbackOrigin;
    return row.endLat == null
        ? landmarks[row.destId]!.latLng
        : LatLng(row.endLat!, row.endLng!);
  }

  Future<SyncStateRow> _ensureState(DateTime now) async {
    final at = now.toUtc().millisecondsSinceEpoch;
    await db.into(db.syncState).insert(
          SyncStateCompanion.insert(
            id: const Value(1),
            firstRecordDay: kstDayKey(now),
            installUtc: at,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.travelFund).insert(
          TravelFundCompanion.insert(id: const Value(1), km: 0, fundedUntilUtc: at),
          mode: InsertMode.insertOrIgnore,
        );
    return (db.select(db.syncState)..where((t) => t.id.equals(1))).getSingle();
  }

  /// 영향받은 날의 하루 요약·걷기 1번을 다시 계산한다.
  /// 전날 0시부터 불러서 자정을 넘는 구간과 직전 걷기/뛰기 상태를 이어 본다
  Future<void> _recomputeDays(String firstDay, String lastDay) async {
    final days = <String>[];
    for (var d = firstDay; d.compareTo(lastDay) <= 0; d = addDays(d, 1)) {
      days.add(d);
    }
    final minutes =
        await _minutesFrom(epochMinute(kstDayStartUtc(addDays(firstDay, -1))));
    final gaits = classifyGait(minutes, rules);
    final sessions = detectSessions(minutes, rules)
        .where((s) => days.contains(kstDayKey(s.start)))
        .toList();

    final steps = {for (final d in days) d: 0};
    final dist = {for (final d in days) d: 0.0};
    for (final g in gaits) {
      final d = kstDayKey(StepMinute(g.minute, 0).startUtc);
      if (!steps.containsKey(d)) continue;
      steps[d] = steps[d]! + g.steps;
      dist[d] = dist[d]! + distanceM([g], rules);
    }

    final rangeFrom = kstDayStartUtc(firstDay).millisecondsSinceEpoch;
    final rangeTo = kstDayStartUtc(addDays(lastDay, 1)).millisecondsSinceEpoch;
    await (db.delete(db.walkSessions)
          ..where((t) =>
              t.startUtc.isBiggerOrEqualValue(rangeFrom) &
              t.startUtc.isSmallerThanValue(rangeTo)))
        .go();
    await db.batch((b) {
      for (final d in days) {
        b.insert(
          db.daySummaries,
          DaySummariesCompanion.insert(
            day: d,
            steps: steps[d]!,
            distanceM: dist[d]!,
            countedSessions: sessions.where((s) => s.counted && kstDayKey(s.start) == d).length,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      b.insertAll(db.walkSessions, [
        for (final s in sessions)
          WalkSessionsCompanion.insert(
            startUtc: Value(s.start.millisecondsSinceEpoch),
            endUtc: s.end.millisecondsSinceEpoch,
            steps: s.steps,
            distanceM: s.distanceM,
            runRatio: s.runRatio,
            qualified: s.qualified,
            counted: s.counted,
          ),
      ]);
    });
  }

  /// 여정이 있으면 진행·도착을 계산하고 넘친 거리를 경비로, 없으면 그동안 걸은 거리를 경비로 (상한 있음)
  Future<void> _advanceJourney(DateTime to) async {
    final fund = await _fund();
    final toMin = epochMinute(to);
    var km = fund.km;
    var fundedUntil = to.millisecondsSinceEpoch;

    final active = await _activeJourney();
    if (active != null) {
      final p = progress(_toJourney(active),
          await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
      if (p.arrived) {
        await _arrive(active, to);
        km = addToFund(km, p.overflowKm, rules);
        // 도착한 분까지는 여정의 걸음(넘친 거리에 들어 있다)이라 경비는 다음 분부터
        fundedUntil = _nextMinuteMs(to);
      }
    } else {
      // 다 끝난 분만 센다. 지금 분은 다음 동기화 때 들어간다
      km = addToFund(
          km, await _distanceKmFrom(_minuteOf(fund.fundedUntilUtc), beforeMinute: toMin), rules);
    }
    // 멈춤으로 앞서 둔 다음 분 경계는 되돌리지 않는다 (같은 분 안에서 또 동기화해도 두 번 세지 않게)
    await (db.update(db.travelFund)..where((t) => t.id.equals(1))).write(TravelFundCompanion(
        km: Value(km), fundedUntilUtc: Value(math.max(fundedUntil, fund.fundedUntilUtc))));
  }

  Future<List<StepMinute>> _minutesFrom(int fromMinute, {int? beforeMinute}) async {
    final q = db.select(db.stepMinutes)
      ..where((t) => t.minuteUtc.isBiggerOrEqualValue(fromMinute))
      ..orderBy([(t) => OrderingTerm(expression: t.minuteUtc)]);
    if (beforeMinute != null) q.where((t) => t.minuteUtc.isSmallerThanValue(beforeMinute));
    return [for (final r in await q.get()) StepMinute(r.minuteUtc, r.steps)];
  }

  Future<double> _distanceKmFrom(int fromMinute, {int? beforeMinute}) async {
    final minutes = await _minutesFrom(fromMinute, beforeMinute: beforeMinute);
    return distanceM(classifyGait(minutes, rules), rules) / 1000;
  }

  /// 동기화 전후로 비교하는 값: 여정이 있으면 그 진행 거리(도착 뒤에도 넘친 만큼 포함),
  /// 없으면 여행 경비. 여정이 있는 동안 경비는 도착할 때 넘친 거리만 늘고 그건 진행 거리에
  /// 이미 들어 있으니, 둘을 더하면 두 번 세게 된다
  Future<double> _creditedKm(JourneyRow? journey) async {
    if (journey == null) return (await _fund()).km;
    final walked = await _distanceKmFrom(_minuteOf(journey.startUtc));
    return progress(_toJourney(journey), walked, rules).progressKm;
  }

  Future<TravelFundRow> _fund() =>
      (db.select(db.travelFund)..where((t) => t.id.equals(1))).getSingle();

  Future<JourneyRow?> _activeJourney() => (db.select(db.journeys)
        ..where((t) => t.status.equalsValue(JourneyStatus.active)))
      .getSingleOrNull();

  Journey _toJourney(JourneyRow r) {
    final origin = LatLng(r.originLat, r.originLng);
    return Journey(
      id: r.id,
      origin: origin,
      destId: r.destId,
      startAt: _utc(r.startUtc),
      fundKm: r.fundKm,
      route: buildRoute(origin, landmarks[r.destId]!.latLng, rules),
    );
  }

  WalkSession _sessionOf(WalkSessionRow r) => WalkSession(
        start: _utc(r.startUtc),
        end: _utc(r.endUtc),
        steps: r.steps,
        distanceM: r.distanceM,
        runRatio: r.runRatio,
        qualified: r.qualified,
        counted: r.counted,
      );

  SyncReport _report(List<StepRecord> raw, List<StepRecord> kept, {double advancedKm = 0}) {
    final bySource = <String, int>{};
    for (final r in raw) {
      bySource[r.sourceId] = (bySource[r.sourceId] ?? 0) + r.steps;
    }
    return SyncReport(raw.length, raw.length - kept.length, bySource, advancedKm: advancedKm);
  }
}

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

int _minuteOf(int ms) => ms ~/ Duration.millisecondsPerMinute;

/// [t]가 속한 분의 다음 분 시작 (epoch ms)
int _nextMinuteMs(DateTime t) => (epochMinute(t) + 1) * Duration.millisecondsPerMinute;

DateTime _later(DateTime a, DateTime b) =>
    _utc(math.max(a.millisecondsSinceEpoch, b.millisecondsSinceEpoch));
