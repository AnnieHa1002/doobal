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
import '../domain/route.dart';
import '../domain/rules.dart';
import '../domain/session.dart';
import '../domain/time_kst.dart';

/// 한 번 가져온 결과. 출처별 걸음은 허용 목록을 정하는 실기기 확인용
class SyncReport {
  const SyncReport(this.records, this.dropped, this.stepsBySource);

  final int records;

  /// 수동 입력·허용 목록 밖이라 버린 기록 수
  final int dropped;
  final Map<String, int> stepsBySource;
}

class JourneyView {
  const JourneyView(this.dest, this.totalKm, this.progress, this.eta);

  final Landmark dest;
  final double totalKm;
  final JourneyProgress progress;
  final DateTime eta;
}

/// 디버그 화면에 보여 줄 지금 상태
class Snapshot {
  const Snapshot({
    required this.today,
    required this.todaySteps,
    required this.todayDistanceM,
    required this.countedSessions,
    required this.fundKm,
    required this.lastFetched,
    required this.journey,
  });

  final String today;
  final int todaySteps;
  final double todayDistanceM;
  final int countedSessions;
  final double fundKm;
  final DateTime? lastFetched;
  final JourneyView? journey;
}

/// 수집 → 저장 → 계산 (M1 명세 6장). 같은 데이터로 여러 번 돌려도 결과가 같다
class SyncService {
  SyncService({
    required this.db,
    required this.source,
    required this.rules,
    required this.allowedSources,
    required this.landmarks,
  });

  final AppDb db;
  final StepSource source;
  final Rules rules;
  final List<String> allowedSources;
  final Map<String, Landmark> landmarks;

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

    await db.transaction(() async {
      await (db.delete(db.stepMinutes)
            ..where((t) => t.minuteUtc.isBetweenValues(fromMin, toMin)))
          .go();
      await db.batch((b) => b.insertAll(db.stepMinutes, [
            for (final m in minutes)
              StepMinutesCompanion.insert(minuteUtc: Value(m.minute), steps: m.steps),
          ]));
      await _recomputeDays(kstDayKey(from), kstDayKey(to));
      await _advanceJourney(to);
      await (db.update(db.syncState)..where((t) => t.id.equals(1)))
          .write(SyncStateCompanion(lastFetchedUtc: Value(to.millisecondsSinceEpoch)));
    });
    return _report(raw, kept);
  }

  /// 저장하지 않고 출처만 본다 (허용 목록을 정할 때)
  Future<SyncReport> inspect(DateTime fromUtc, DateTime toUtc) async {
    final raw = await source.fetch(fromUtc, toUtc);
    return _report(raw, filterRecords(raw, allowedSources));
  }

  /// 그때까지의 거리를 경비로 넣은 뒤 출발한다. 진행 중 여정은 멈춘다
  Future<void> startJourney(
    String destId,
    LatLng origin,
    DateTime now, {
    bool useFund = true,
  }) async {
    await sync(now);
    final dest = landmarks[destId]!;
    final route = buildRoute(origin, dest.latLng, rules);
    await db.transaction(() async {
      await (db.update(db.journeys)..where((t) => t.status.equalsValue(JourneyStatus.active)))
          .write(const JourneysCompanion(status: Value(JourneyStatus.stopped)));
      final fund = await _fund();
      final used = useFund ? fund.km : 0.0;
      final at = now.toUtc().millisecondsSinceEpoch;
      await db.into(db.journeys).insert(JourneysCompanion.insert(
            id: 'j$at',
            originLat: origin.lat,
            originLng: origin.lng,
            destId: destId,
            startUtc: at,
            fundKm: used,
            totalEffectiveKm: route.totalEffectiveKm,
            status: JourneyStatus.active,
          ));
      await (db.update(db.travelFund)..where((t) => t.id.equals(1)))
          .write(TravelFundCompanion(km: Value(fund.km - used)));
    });
  }

  Future<Snapshot> snapshot(DateTime now) async {
    final state = await _ensureState(now);
    final today = kstDayKey(now);
    final day = await (db.select(db.daySummaries)..where((t) => t.day.equals(today)))
        .getSingleOrNull();
    final fund = await _fund();

    JourneyView? view;
    final active = await _activeJourney();
    if (active != null) {
      final j = _toJourney(active);
      final p = progress(j, await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
      final daily = {
        for (final d in await db.select(db.daySummaries).get()) d.day: d.distanceM / 1000,
      };
      final eta = etaDate(p.remainingKm, daily, today, state.firstRecordDay, rules);
      view = JourneyView(landmarks[active.destId]!, j.route.totalEffectiveKm, p, eta);
    }

    return Snapshot(
      today: today,
      todaySteps: day?.steps ?? 0,
      todayDistanceM: day?.distanceM ?? 0,
      countedSessions: day?.countedSessions ?? 0,
      fundKm: fund.km,
      lastFetched: state.lastFetchedUtc == null ? null : _utc(state.lastFetchedUtc!),
      journey: view,
    );
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

    final active = await _activeJourney();
    if (active != null) {
      final p = progress(_toJourney(active),
          await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
      if (p.arrived) {
        await (db.update(db.journeys)..where((t) => t.id.equals(active.id))).write(
            JourneysCompanion(
                status: const Value(JourneyStatus.arrived),
                arrivedUtc: Value(to.millisecondsSinceEpoch)));
        km = addToFund(km, p.overflowKm, rules);
      }
    } else {
      // 다 끝난 분만 센다. 지금 분은 다음 동기화 때 들어간다
      km = addToFund(
          km, await _distanceKmFrom(_minuteOf(fund.fundedUntilUtc), beforeMinute: toMin), rules);
    }
    await (db.update(db.travelFund)..where((t) => t.id.equals(1))).write(
        TravelFundCompanion(km: Value(km), fundedUntilUtc: Value(to.millisecondsSinceEpoch)));
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

  SyncReport _report(List<StepRecord> raw, List<StepRecord> kept) {
    final bySource = <String, int>{};
    for (final r in raw) {
      bySource[r.sourceId] = (bySource[r.sourceId] ?? 0) + r.steps;
    }
    return SyncReport(raw.length, raw.length - kept.length, bySource);
  }
}

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

int _minuteOf(int ms) => ms ~/ Duration.millisecondsPerMinute;

DateTime _later(DateTime a, DateTime b) =>
    _utc(math.max(a.millisecondsSinceEpoch, b.millisecondsSinceEpoch));
