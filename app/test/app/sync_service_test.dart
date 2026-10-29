import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

final _landmarks = {
  for (final l in (jsonDecode(File('assets/data/landmarks.json').readAsStringSync())
          as Map<String, dynamic>)['landmarks'] as List)
    l['id'] as String: Landmark.fromJson(l as Map<String, dynamic>),
};

// 경복궁에서 동쪽으로 약 1km
const _nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

// 설치 KST 2026-11-18 09:00
final _t0 = DateTime.utc(2026, 11, 18, 0);

/// start부터 minutes분 동안 분당 spm보로 걸은 기록 하나
StepRecord _walk(DateTime start, int minutes, int spm, {String source = 'iphone'}) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: source,
      method: RecordingMethod.automatic,
    );

class _Env {
  _Env() : db = AppDb(NativeDatabase.memory()), source = FakeStepSource() {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _landmarks,
      props: props,
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  /// 동기화 시각에 따라 달라지는 SyncState·fundedUntilUtc는 빼고 비교한다
  Future<Map<String, Object?>> dump() async => {
        'minutes': await db.select(db.stepMinutes).get(),
        'days': await db.select(db.daySummaries).get(),
        'sessions': await db.select(db.walkSessions).get(),
        'journeys': await db.select(db.journeys).get(),
        'paintings': await db.select(db.paintingsOwned).get(),
        'props': await db.select(db.propsOwned).get(),
        'fundKm': (await db.select(db.travelFund).getSingle()).km,
      };
}

/// [startJourney]를 부른 시각으로 찾은 여정 (placeAt이 넣은 자리 기록과 구분한다)
Future<JourneyRow> _startedAt(AppDb db, DateTime at) => (db.select(db.journeys)
      ..where((t) => t.id.equals('j${at.millisecondsSinceEpoch}')))
    .getSingle();

/// 걷는 거리가 [km] 이상이 되는 기록 (분당 100보, 모자라지 않게 1분 더)
StepRecord _walkKm(DateTime start, double km) =>
    _walk(start, (km * 1000 / (rules.walkStrideM * 100)).ceil() + 1, 100);

double _routeKm(LatLng from, String destId) =>
    buildRoute(from, _landmarks[destId]!.latLng, rules).totalEffectiveKm;

/// [from]에서 가면 액자가 [frame]이 되는 육지 명소(없으면 null). 거리는 데이터로 계산해서 고른다
Landmark? _findDest(LatLng from, Frame frame, {String? not}) =>
    _landmarks.values.where((l) =>
        l.island == Island.mainland &&
        l.id != not &&
        _routeKm(from, l.id) > 1 &&
        frameFor(_routeKm(from, l.id), rules) == frame).firstOrNull;

Landmark _destFor(LatLng from, Frame frame, {String? not}) =>
    _findDest(from, frame, not: not)!;

/// [destId]로 [start]에 출발해(경비는 안 더한다) 도착할 때까지 걷고 동기화한다.
/// 도착을 동기화한 시각을 돌려준다
Future<DateTime> _trip(_Env e, String destId, DateTime start) async {
  await e.svc.startJourney(destId, start, useFund: false);
  final km = (await e.svc.snapshot(start)).journey!.totalKm;
  final record = _walkKm(start.add(const Duration(minutes: 5)), km);
  e.source.records.add(record);
  final end = record.end.add(const Duration(minutes: 30));
  await e.svc.sync(end);
  return end;
}

Future<void> _seedPaintings(AppDb db, Iterable<String> ids) =>
    db.batch((b) => b.insertAll(db.paintingsOwned, [
          for (final id in ids)
            PaintingsOwnedCompanion.insert(
              landmarkId: id,
              visits: 1,
              frame: Frame.wood,
              bestKm: 1,
              firstArrivedUtc: 0,
              lastArrivedUtc: 0,
            ),
        ]));

Future<Set<String>> _propIds(AppDb db) async =>
    {for (final r in await db.select(db.propsOwned).get()) r.propId};

int _ms(DateTime t) => t.millisecondsSinceEpoch;

/// [home]이 true면 출발 동네를 testHome으로 골라 둔다 (여정을 시작하려면 쉬는 자리가 있어야 한다)
Future<_Env> _env({bool home = true}) async {
  final e = _Env();
  addTearDown(e.db.close);
  if (home) await e.svc.setHome(testHomeName, testHome);
  return e;
}

/// 도착 화면 값까지 채운 도착한 여정 한 줄을 DB에 직접 넣는다
Future<void> _insertArrival(
  AppDb db,
  String id,
  String destId,
  DateTime arrivedAt, {
  int visitNo = 1,
  Frame frame = Frame.wood,
  Frame? prevFrame,
  double km = 10,
  bool withVisitNo = true,
}) {
  return db.into(db.journeys).insert(JourneysCompanion.insert(
        id: id,
        originLat: 38,
        originLng: 128,
        destId: destId,
        startUtc: arrivedAt.millisecondsSinceEpoch - 1000,
        fundKm: 0,
        totalEffectiveKm: km,
        status: JourneyStatus.arrived,
        arrivedUtc: Value(arrivedAt.millisecondsSinceEpoch),
        visitNo: Value(withVisitNo ? visitNo : null),
        prevFrame: Value(prevFrame),
        newFrame: Value(frame),
      ));
}

Future<void> _insertDay(AppDb db, String day, int steps) => db.into(db.daySummaries).insert(
    DaySummariesCompanion.insert(day: day, steps: steps, distanceM: 0, countedSessions: 0));

void main() {
  // 테스트마다 따로 여는 메모리 DB라 같은 파일을 두 번 여는 경우가 아니다
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('#26 멱등: 같은 기록으로 한 번 / 여러 번 동기화한 결과가 같다', () {
    test('여정 없음 → 경비가 한 번만 쌓인다', () async {
      final once = await _env();
      final twice = await _env();
      final t2 = _t0.add(const Duration(hours: 3));
      for (final e in [once, twice]) {
        await e.svc.sync(_t0);
        e.source.records.addAll([
          _walk(_t0.add(const Duration(hours: 1)), 30, 100),
          _walk(_t0.add(const Duration(hours: 1)), 30, 95, source: 'watch'),
        ]);
        await e.svc.sync(t2);
      }
      await twice.svc.sync(t2);
      await twice.svc.sync(t2.add(const Duration(minutes: 10)));

      final a = await once.dump();
      expect(await twice.dump(), a);
      // 출처 둘은 합이 아니라 큰 쪽: 30분 × 100보 × 0.7m
      expect(a['fundKm'], closeTo(2.1, 1e-9));
      final day = (a['days'] as List<DaySummaryRow>).single;
      expect(day.steps, 3000);
      expect(day.countedSessions, 1);
    });

    test('여정 중 → 진행이 같다', () async {
      final once = await _env();
      final twice = await _env();
      final t1 = _t0.add(const Duration(hours: 1));
      final t2 = _t0.add(const Duration(hours: 3));
      for (final e in [once, twice]) {
        await e.svc.sync(_t0);
        await e.svc.startJourney('kr003', t1);
        e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 40, 100));
        await e.svc.sync(t2);
      }
      await twice.svc.sync(t2);

      expect(await twice.dump(), await once.dump());
      final s1 = await once.svc.snapshot(t2);
      final s2 = await twice.svc.snapshot(t2);
      expect(s2.journey!.progress.progressKm, s1.journey!.progress.progressKm);
      expect(s1.journey!.progress.progressKm, closeTo(2.8, 1e-9));
      expect(s1.journey!.progress.arrived, isFalse);
    });
  });

  test('도착하면 넘친 거리가 경비로 간다', () async {
    final e = await _env();
    final t1 = _t0.add(const Duration(hours: 1));
    await e.svc.sync(_t0);
    await placeAt(e.db, _nearGyeongbok, _t0);
    await e.svc.startJourney('kr001', t1);
    e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
    await e.svc.sync(_t0.add(const Duration(hours: 3)));

    final total = buildRoute(_nearGyeongbok, _landmarks['kr001']!.latLng, rules).totalEffectiveKm;
    final j = await _startedAt(e.db, t1);
    expect(j.status, JourneyStatus.arrived);
    expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(2.1 - total, 1e-9));
  });

  test('경비는 상한에서 멈춘다', () async {
    final e = await _env();
    await e.svc.sync(_t0);
    // 250분 × 100보 = 17.5km
    e.source.records.add(_walk(_t0.add(const Duration(minutes: 30)), 250, 100));
    await e.svc.sync(_t0.add(const Duration(hours: 6)));
    expect((await e.db.select(e.db.travelFund).getSingle()).km, rules.travelFundCapKm);
  });

  group('SyncReport.advancedKm', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final t2 = _t0.add(const Duration(hours: 3));

    test('여정 없음: 경비가 늘어난 만큼, 같은 기록으로 또 돌리면 0', () async {
      final e = await _env();
      expect((await e.svc.sync(_t0)).advancedKm, 0);
      e.source.records.add(_walk(t1, 30, 100));
      // 3000보 × 0.7m
      expect((await e.svc.sync(t2)).advancedKm, closeTo(2.1, 1e-9));
      expect((await e.svc.sync(t2)).advancedKm, 0);
      expect((await e.svc.sync(t2.add(const Duration(minutes: 10)))).advancedKm, 0);
    });

    test('여정 중: 진행 거리가 는 만큼', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 40, 100));
      final r = await e.svc.sync(t2);
      final p = (await e.svc.snapshot(t2)).journey!.progress;
      expect(r.advancedKm, closeTo(2.8, 1e-9));
      expect(r.advancedKm, closeTo(p.progressKm, 1e-9));
      expect((await e.svc.sync(t2)).advancedKm, 0);
    });

    test('여정 중 두 번째 동기화는 그 사이 늘어난 만큼만', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 20, 100));
      await e.svc.sync(t1.add(const Duration(minutes: 40)));
      e.source.records.add(_walk(t1.add(const Duration(minutes: 60)), 10, 100));
      // 10분 × 100보 × 0.7m
      expect((await e.svc.sync(t2)).advancedKm, closeTo(0.7, 1e-9));
    });

    test('도착한 동기화도 걸은 거리 그대로 (넘친 거리를 또 더하지 않는다)', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await placeAt(e.db, _nearGyeongbok, _t0);
      await e.svc.startJourney('kr001', t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      final r = await e.svc.sync(t2);

      final total =
          buildRoute(_nearGyeongbok, _landmarks['kr001']!.latLng, rules).totalEffectiveKm;
      expect((await _startedAt(e.db, t1)).status, JourneyStatus.arrived);
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(2.1 - total, 1e-9));
      expect(r.advancedKm, closeTo(2.1, 1e-9));
      expect((await e.svc.sync(t2)).advancedKm, 0);
    });

    test('경비가 상한에 닿으면 그 뒤로는 늘지 않아 0', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 250분 × 100보 = 17.5km → 상한까지만
      e.source.records.add(_walk(_t0.add(const Duration(minutes: 30)), 250, 100));
      final r = await e.svc.sync(_t0.add(const Duration(hours: 6)));
      expect(r.advancedKm, rules.travelFundCapKm);
      e.source.records.add(_walk(_t0.add(const Duration(hours: 7)), 30, 100));
      expect((await e.svc.sync(_t0.add(const Duration(hours: 9)))).advancedKm, 0);
    });

    test('inspect는 저장하지 않으니 0', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walk(t1, 30, 100));
      expect((await e.svc.inspect(_t0, t2)).advancedKm, 0);
    });
  });

  group('walkRecord', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final t2 = _t0.add(const Duration(hours: 3));
    DateTime at(int minutes) => t1.add(Duration(minutes: minutes));

    test('걸음·거리·뛴 비율과 걷기 1번 인정, 오늘 1/3', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 100보 10분 → 150보 5분
      e.source.records.addAll([
        _walk(t1, 10, 100),
        _walk(at(10), 5, 150),
      ]);
      await e.svc.sync(t2);

      final r = await e.svc.walkRecord(t1, at(15));
      expect(r.summary.steps, 1750);
      expect(r.summary.distanceM, closeTo(1450, 1e-9));
      expect(r.summary.activeMinutes, 15);
      expect(r.summary.runRatio, closeTo(750 / 1750, 1e-12));
      final s = r.sessions.single;
      expect(s.start, t1);
      expect(s.end, at(15));
      expect(s.qualified, isTrue);
      expect(s.counted, isTrue);
      expect(r.countedToday, 1);
    });

    test('창 밖은 뺀다: 앞뒤를 자르면 걸음이 줄고, 걷기 구간은 겹치면 그대로 나온다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walk(t1, 15, 100));
      await e.svc.sync(t2);

      final mid = await e.svc.walkRecord(at(5), at(10));
      expect(mid.summary.steps, 500);
      expect(mid.sessions, hasLength(1));

      final after = await e.svc.walkRecord(at(20), at(30));
      expect(after.summary.steps, 0);
      expect(after.sessions, isEmpty);
      expect(after.countedToday, 1);
    });

    test('끝 시각이 분 중간이면 그 분까지 포함한다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walk(t1, 15, 100));
      await e.svc.sync(t2);

      final r = await e.svc.walkRecord(t1, t1.add(const Duration(minutes: 9, seconds: 30)));
      expect(r.summary.steps, 1000);
    });

    test('짧은 걷기는 인정되지 않고 오늘 0/3', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walk(t1, 5, 100));
      await e.svc.sync(t2);

      final r = await e.svc.walkRecord(t1, at(5));
      expect(r.summary.steps, 500);
      expect(r.sessions.single.qualified, isFalse);
      expect(r.sessions.single.counted, isFalse);
      expect(r.countedToday, 0);
    });

    test('하루 전체 창은 저장된 하루 합계와 같다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.addAll([
        _walk(t1, 10, 100),
        _walk(t1.add(const Duration(minutes: 10)), 5, 150),
        _walk(t1.add(const Duration(minutes: 20)), 5, 135),
      ]);
      await e.svc.sync(t2);

      final start = kstDayStartUtc(kstDayKey(t1));
      final r = await e.svc.walkRecord(start, start.add(const Duration(days: 1)));
      final day = (await e.db.select(e.db.daySummaries).get()).single;
      expect(r.summary.steps, day.steps);
      expect(r.summary.distanceM, closeTo(day.distanceM, 1e-9));
    });

    test('창이 직전 뛰기 상태를 이어 받는다 (창 앞 150보 → 창 안 135보도 뛰기)', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.addAll([
        _walk(t1, 5, 150),
        _walk(t1.add(const Duration(minutes: 5)), 5, 135),
      ]);
      await e.svc.sync(t2);

      final r = await e.svc.walkRecord(at(5), at(10));
      expect(r.summary.steps, 675);
      expect(r.summary.runRatio, 1.0);
      expect(r.summary.distanceM, closeTo(675, 1e-9));
    });

    test('자정을 넘어도 전날 분까지 불러 상태를 이어 본다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 한국 23:58~00:00 150보, 00:00~00:05 135보
      final midnight = kstDayStartUtc('2026-11-19');
      e.source.records.addAll([
        _walk(midnight.subtract(const Duration(minutes: 2)), 2, 150),
        _walk(midnight, 5, 135),
      ]);
      await e.svc.sync(midnight.add(const Duration(hours: 1)));

      final r = await e.svc.walkRecord(midnight, midnight.add(const Duration(minutes: 5)));
      expect(r.summary.steps, 675);
      expect(r.summary.runSteps, 675);
    });
  });
  group('Snapshot: totalSteps·position·onSea', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final t2 = _t0.add(const Duration(hours: 3));

    test('totalSteps는 모든 하루 걸음의 합 (설치 이후 여러 날)', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      expect((await e.svc.snapshot(_t0)).totalSteps, 0);
      // 첫날 30분 × 100보, 이틀 뒤 20분 × 120보
      final day3 = _t0.add(const Duration(days: 2, hours: 1));
      e.source.records.addAll([_walk(t1, 30, 100), _walk(day3, 20, 120)]);
      await e.svc.sync(_t0.add(const Duration(days: 2, hours: 3)));

      final s = await e.svc.snapshot(_t0.add(const Duration(days: 2, hours: 3)));
      expect(s.totalSteps, 3000 + 2400);
      final days = await e.db.select(e.db.daySummaries).get();
      expect(days.fold(0, (sum, d) => sum + d.steps), s.totalSteps);
      expect(s.todaySteps, 2400);
    });

    test('여정도 도착한 적도 없으면 출발 동네', () async {
      final e = await _env();
      final s = await e.svc.snapshot(_t0);
      expect(s.position, testHome);
      expect(s.home!.name, testHomeName);
      expect(s.onSea, isFalse);
      expect(s.journey, isNull);
    });

    test('여정 중(땅): 경로 위 진행 지점', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      // 시작 직후는 출발지
      expect((await e.svc.snapshot(t1)).position, testHome);

      e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 40, 100));
      await e.svc.sync(t2);
      final s = await e.svc.snapshot(t2);
      final route = buildRoute(testHome, _landmarks['kr003']!.latLng, rules);
      final expected = positionAt(route, s.journey!.progress.progressKm);
      expect(s.position, expected.latLng);
      expect(s.position, isNot(testHome));
      expect(s.onSea, isFalse);
    });

    test('여정 중(배 구간): onSea, 위치는 완도항과 제주항 사이', () async {
      final e = await _env();
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      final wando = rules.ports['wando']!;
      final port = rules.ports['jeju']!;
      await e.svc.sync(_t0);
      // 완도항에서 제주로: 첫 다리가 배 (환산 약 30km)
      await placeAt(e.db, wando, _t0);
      await e.svc.startJourney(jeju.id, t1);
      expect((await e.svc.snapshot(t1)).onSea, isTrue);

      // 143분 × 100보 × 0.7m = 10.01km (환산 거리) → 아직 배 위
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 143, 100));
      await e.svc.sync(t1.add(const Duration(hours: 4)));
      final s = await e.svc.snapshot(t1.add(const Duration(hours: 4)));
      expect(s.onSea, isTrue);
      expect(s.position!.lat, inInclusiveRange(port.lat, wando.lat));
      expect(s.position, isNot(wando));
    });

    test('배 구간을 지나면 onSea가 꺼지고 제주 땅 위 지점', () async {
      final e = await _env();
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      await e.svc.sync(_t0);
      await placeAt(e.db, rules.ports['wando']!, _t0);
      await e.svc.startJourney(jeju.id, t1);
      // 443분 × 100보 × 0.7m = 31.01km: 배 구간 환산(약 30km)을 막 넘겼다
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 443, 100));
      final end = t1.add(const Duration(hours: 9));
      await e.svc.sync(end);
      final s = await e.svc.snapshot(end);
      final route = buildRoute(rules.ports['wando']!, jeju.latLng, rules);
      expect(route.legs.first.kind, LegKind.sea);
      expect(s.journey!.progress.progressKm, greaterThan(route.legs.first.effectiveKm));
      expect(s.onSea, isFalse);
      expect(s.position, positionAt(route, s.journey!.progress.progressKm).latLng);
    });

    test('도착하면 여정이 없어도 도착한 명소가 위치', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await placeAt(e.db, _nearGyeongbok, _t0);
      await e.svc.startJourney('kr001', t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.sync(t2);

      final s = await e.svc.snapshot(t2);
      expect(s.journey, isNull);
      expect(s.position, _landmarks['kr001']!.latLng);
      expect(s.onSea, isFalse);
    });

    test('여러 번 도착했으면 가장 최근에 도착한 곳', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await placeAt(e.db, _nearGyeongbok, _t0);
      await e.svc.startJourney('kr001', t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.sync(t2);

      // 두 번째: 인천 차이나타운 옆에서 출발해 도착
      final kr002 = _landmarks['kr002']!.latLng;
      final t3 = t2.add(const Duration(hours: 1));
      await placeAt(
          e.db, LatLng(kr002.lat, kr002.lng + 0.0113), t3.subtract(const Duration(minutes: 1)));
      await e.svc.startJourney('kr002', t3, useFund: false);
      e.source.records.add(_walk(t3.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.sync(t3.add(const Duration(hours: 2)));

      final arrived = await (e.db.select(e.db.journeys)
            ..where((t) => t.status.equalsValue(JourneyStatus.arrived)))
          .get();
      expect(arrived, hasLength(2));
      final s = await e.svc.snapshot(t3.add(const Duration(hours: 2)));
      expect(s.position, kr002);
    });
  });

  group('출발 동네', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final t2 = _t0.add(const Duration(hours: 3));
    const noHome = '출발 동네를 먼저 골라 주세요';

    test('안 골랐고 여행한 적도 없으면 position이 null, 출발은 StateError이고 아무것도 바꾸지 않는다', () async {
      final e = await _env(home: false);
      // 모든 표의 행 수 (설치 전이라 동기화 상태·경비 행도 아직 없다)
      Future<List<int>> counts() async => [
            (await e.db.select(e.db.stepMinutes).get()).length,
            (await e.db.select(e.db.daySummaries).get()).length,
            (await e.db.select(e.db.walkSessions).get()).length,
            (await e.db.select(e.db.journeys).get()).length,
            (await e.db.select(e.db.paintingsOwned).get()).length,
            (await e.db.select(e.db.propsOwned).get()).length,
            (await e.db.select(e.db.travelFund).get()).length,
            (await e.db.select(e.db.syncState).get()).length,
            (await e.db.select(e.db.profile).get()).length,
          ];

      // 동기화를 했다면 분 걸음과 상태 행이 생겼을 기록. 던지면서 동기화도 하지 않는다
      e.source.records.add(_walk(t1, 30, 100));
      expect(await counts(), everyElement(0));
      await expectLater(
          e.svc.startJourney('kr003', t2),
          throwsA(isA<StateError>().having((x) => x.message, 'message', noHome)));
      expect(await counts(), everyElement(0));

      final s = await e.svc.snapshot(t2);
      expect(s.position, isNull);
      expect(s.home, isNull);
      expect(s.onSea, isFalse);
      expect(s.journey, isNull);
      expect(await e.svc.home(), isNull);

      // 동기화 상태가 생긴 뒤에도 마찬가지: 마지막 동기화 시각도 그대로
      await e.svc.sync(_t0);
      final dumpBefore = await e.dump();
      final fetched = (await e.db.select(e.db.syncState).getSingle()).lastFetchedUtc;
      await expectLater(e.svc.startJourney('kr003', t2), throwsStateError);
      expect(await e.dump(), dumpBefore);
      expect((await e.db.select(e.db.syncState).getSingle()).lastFetchedUtc, fetched);
    });

    test('setHome 뒤에는 position이 출발 동네, 출발지도 거기다', () async {
      final e = await _env(home: false);
      await e.svc.setHome('종로구', _nearGyeongbok);
      final home = (await e.svc.home())!;
      expect(home.name, '종로구');
      expect(home.latLng, _nearGyeongbok);
      final s = await e.svc.snapshot(_t0);
      expect(s.position, _nearGyeongbok);
      expect(s.home!.name, '종로구');
      expect(s.onSea, isFalse);

      await e.svc.startJourney('kr003', t1);
      final j = await _startedAt(e.db, t1);
      expect(j.originLat, _nearGyeongbok.lat);
      expect(j.originLng, _nearGyeongbok.lng);
      expect(j.totalEffectiveKm, closeTo(_routeKm(_nearGyeongbok, 'kr003'), 1e-9));
      // 막 출발했으니 장면 위치는 아직 출발 동네
      expect((await e.svc.snapshot(t1)).position, _nearGyeongbok);
    });

    test('setHome을 또 부르면 한 행이 바뀐다', () async {
      final e = await _env(home: false);
      await e.svc.setHome('종로구', _nearGyeongbok);
      await e.svc.setHome(testHomeName, testHome);
      final rows = await e.db.select(e.db.profile).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.homeName, testHomeName);
      expect((await e.svc.home())!.latLng, testHome);
      expect((await e.svc.snapshot(_t0)).position, testHome);
    });

    test('쉬는 자리는 가장 나중에 끝난 여정이 출발 동네보다 먼저', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      expect((await e.svc.snapshot(_t0)).position, testHome);

      await placeAt(e.db, _nearGyeongbok, _t0);
      var s = await e.svc.snapshot(t1);
      expect(s.position, _nearGyeongbok);
      // 출발 동네는 그대로 남아 있고, 바꿔도 쉬는 자리는 여정 쪽
      expect(s.home!.latLng, testHome);
      await e.svc.setHome('종로구', _landmarks['kr002']!.latLng);
      s = await e.svc.snapshot(t1);
      expect(s.position, _nearGyeongbok);
      expect(s.home!.name, '종로구');

      // 그 자리에서 출발하면 출발지도 여정 쪽
      await e.svc.startJourney('kr003', t2);
      final j = await _startedAt(e.db, t2);
      expect(j.originLat, _nearGyeongbok.lat);
      expect(j.originLng, _nearGyeongbok.lng);
    });

    test('진행 중인 여정이 있으면 출발 동네가 없어도 목적지를 바꿀 수 있다', () async {
      final e = await _env(home: false);
      // 출발 동네를 고르는 기능이 생기기 전에 시작한 여정 (출발 동네 행은 없다)
      await e.db.into(e.db.journeys).insert(JourneysCompanion.insert(
            id: 'j1',
            originLat: testHome.lat,
            originLng: testHome.lng,
            destId: 'kr003',
            startUtc: _ms(t1),
            fundKm: 0,
            totalEffectiveKm: _routeKm(testHome, 'kr003'),
            status: JourneyStatus.active,
          ));
      expect(await e.svc.home(), isNull);
      expect((await e.svc.snapshot(t1)).position, testHome);

      await e.svc.startJourney('kr001', t2);
      expect((await e.svc.snapshot(t2)).journey!.dest.id, 'kr001');
      expect((await (e.db.select(e.db.journeys)..where((t) => t.id.equals('j1'))).getSingle())
              .status,
          JourneyStatus.stopped);
    });
  });

  group('여정 바꾸기·멈추기', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final t2 = _t0.add(const Duration(hours: 3));
    final t3 = _t0.add(const Duration(hours: 4));

    test('여정 중 목적지를 바꾸면: 새 출발지는 그 순간 경로 위 지점, 앞 여정은 거기서 멈춤', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      // 40분 × 100보 × 0.7m = 2.8km
      e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 40, 100));
      await e.svc.startJourney('kr001', t3);

      final here = positionAt(
              buildRoute(testHome, _landmarks['kr003']!.latLng, rules), 2.8)
          .latLng;
      final old = await _startedAt(e.db, t1);
      expect(old.status, JourneyStatus.stopped);
      expect(old.endLat, closeTo(here.lat, 1e-9));
      expect(old.endLng, closeTo(here.lng, 1e-9));
      expect(old.endedUtc, _ms(t3));
      expect(old.arrivedUtc, isNull);

      final now = await _startedAt(e.db, t3);
      expect(now.status, JourneyStatus.active);
      expect(now.originLat, old.endLat);
      expect(now.originLng, old.endLng);
      expect(now.destId, 'kr001');
      expect(now.totalEffectiveKm, closeTo(_routeKm(here, 'kr001'), 1e-6));
      // 막 바꾼 쪽은 아직 출발지 그대로
      final s = await e.svc.snapshot(t3);
      expect(s.position!.lat, closeTo(here.lat, 1e-9));
      expect(s.journey!.progress.progressKm, 0);
      expect(s.journey!.totalKm, closeTo(_routeKm(here, 'kr001'), 1e-6));
    });

    test('바꾼 뒤 액자 거리는 새 출발지부터 센다 (같은 목적지를 다시 골라도 처음부터)', () async {
      final e = await _env();
      final kr001 = _landmarks['kr001']!.latLng;
      await placeAt(e.db, LatLng(kr001.lat, kr001.lng + 0.0339), _t0);
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr001', t1);
      final first = (await e.svc.snapshot(t1)).journey!.totalKm;
      // 15분 × 100보 × 0.7m = 1.05km 걷고 같은 곳을 다시 고른다
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 15, 100));
      await e.svc.startJourney('kr001', t2);
      final second = (await e.svc.snapshot(t2)).journey!.totalKm;
      expect(second, closeTo(first - 1.05, 0.01));

      final record = _walkKm(t2.add(const Duration(minutes: 5)), second);
      e.source.records.add(record);
      await e.svc.sync(record.end.add(const Duration(minutes: 30)));
      final p = await e.db.select(e.db.paintingsOwned).getSingle();
      expect(p.landmarkId, 'kr001');
      expect(p.bestKm, closeTo(second, 1e-9));
      expect(p.bestKm, lessThan(first));
    });

    test('지금 있는 명소로는 출발할 수 없고, 진행 중 여정은 멈추지 않는다', () async {
      final e = await _env();
      await placeAt(e.db, _landmarks['kr001']!.latLng, _t0);
      await e.svc.sync(_t0);
      await expectLater(e.svc.startJourney('kr001', t1), throwsStateError);
      expect((await e.svc.snapshot(t1)).journey, isNull);

      // kr003으로 가는 중이지만 아직 안 걸어서 지금 자리는 kr001
      await e.svc.startJourney('kr003', t1);
      await expectLater(e.svc.startJourney('kr001', t2), throwsStateError);
      expect((await e.svc.snapshot(t2)).journey!.dest.id, 'kr003');
    });

    test('멈춘 분은 앞 여정의 걸음이고, 새 여정은 다음 분부터 센다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      // 30분 × 100보 기록이 t1부터. 10분 30초 지점에서 바꾼다: 0~10분(11분)은 앞 여정
      e.source.records.add(_walk(t1, 30, 100));
      final change = t1.add(const Duration(minutes: 10, seconds: 30));
      await e.svc.startJourney('kr001', change);

      final old = await _startedAt(e.db, t1);
      final here = positionAt(
              buildRoute(testHome, _landmarks['kr003']!.latLng, rules), 0.77)
          .latLng;
      expect(old.endLat, closeTo(here.lat, 1e-9));
      // 새 여정의 시작은 다음 분(11분째)
      final fresh = await _startedAt(e.db, change);
      expect(fresh.startUtc, _ms(t1.add(const Duration(minutes: 11))));

      // 나머지 19분 × 70m = 1.33km만 새 여정으로
      await e.svc.sync(t2);
      expect((await e.svc.snapshot(t2)).journey!.progress.progressKm, closeTo(1.33, 1e-9));
    });

    test('같은 분 안에서 두 번 바꿔도 되고, 둘 다 같은 분 경계에서 시작한다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      await e.svc.startJourney('kr001', t1.add(const Duration(seconds: 10)));
      await e.svc.startJourney('kr002', t1.add(const Duration(seconds: 20)));
      final rows = await e.db.select(e.db.journeys).get();
      expect(rows.map((r) => r.status).toList(),
          [JourneyStatus.stopped, JourneyStatus.stopped, JourneyStatus.active]);
      expect((await e.svc.snapshot(t1.add(const Duration(seconds: 20)))).journey!.dest.id, 'kr002');
    });

    test('출발할 때 경비를 더하면 fundKm에 들어가고 경비는 줄어든다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 30분 × 100보 = 2.1km → 경비
      e.source.records.add(_walk(t1, 30, 100));
      await e.svc.startJourney('kr003', t2);

      final j = await _startedAt(e.db, t2);
      expect(j.fundKm, closeTo(2.1, 1e-9));
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(0, 1e-12));
      expect((await e.svc.snapshot(t2)).journey!.progress.progressKm, closeTo(2.1, 1e-9));
    });

    test('useFund: false면 경비를 그대로 둔다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walk(t1, 30, 100));
      await e.svc.startJourney('kr003', t2, useFund: false);

      expect((await _startedAt(e.db, t2)).fundKm, 0);
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(2.1, 1e-9));
      expect((await e.svc.snapshot(t2)).journey!.progress.progressKm, 0);
    });

    test('멈추면 그 자리가 쉬는 자리, 이후 걸음은 경비로 간다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      // 30분 × 100보 = 2.1km 걷고 멈춘다
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.stopJourney(t2);

      final here = positionAt(
              buildRoute(testHome, _landmarks['kr003']!.latLng, rules), 2.1)
          .latLng;
      final j = await _startedAt(e.db, t1);
      expect(j.status, JourneyStatus.stopped);
      expect(j.endLat, closeTo(here.lat, 1e-9));
      expect(j.endLng, closeTo(here.lng, 1e-9));
      expect(j.endedUtc, _ms(t2));
      var s = await e.svc.snapshot(t2);
      expect(s.journey, isNull);
      expect(s.position!.lat, closeTo(here.lat, 1e-9));
      expect(s.position!.lng, closeTo(here.lng, 1e-9));
      expect((await e.db.select(e.db.travelFund).getSingle()).km, 0);

      // 멈춘 뒤 20분 × 100보 = 1.4km가 경비로
      e.source.records.add(_walk(t2.add(const Duration(minutes: 10)), 20, 100));
      await e.svc.sync(t3);
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(1.4, 1e-9));
      s = await e.svc.snapshot(t3);
      expect(s.fundKm, closeTo(1.4, 1e-9));
      // 쉬는 자리는 여전히 멈춘 곳
      expect(s.position!.lat, closeTo(here.lat, 1e-9));
      // 같은 기록으로 또 돌려도 늘지 않는다
      await e.svc.sync(t3);
      await e.svc.sync(t3.add(const Duration(minutes: 10)));
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(1.4, 1e-9));
    });

    test('멈춘 분에 걸친 기록은 잃지도 두 번 세지도 않는다 (여정 11분 + 경비 19분 = 30분)', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      e.source.records.add(_walk(t1, 30, 100));
      // 10분 30초에 멈춤: 0~10분(11분)은 여정, 11~29분(19분)은 경비
      await e.svc.stopJourney(t1.add(const Duration(minutes: 10, seconds: 30)));
      // 같은 분 안에서 또 동기화해도 그 분을 경비로 세지 않는다
      await e.svc.sync(t1.add(const Duration(minutes: 10, seconds: 50)));
      await e.svc.sync(t2);

      final j = await _startedAt(e.db, t1);
      final stop = positionAt(
              buildRoute(testHome, _landmarks['kr003']!.latLng, rules), 0.77)
          .latLng;
      expect(j.endLat, closeTo(stop.lat, 1e-9));
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(1.33, 1e-9));
      final day = (await e.db.select(e.db.daySummaries).get()).single;
      expect(day.distanceM / 1000, closeTo(0.77 + 1.33, 1e-9));
    });

    test('진행 중인 여정이 없을 때 멈추기는 동기화만 한다', () async {
      final e = await _env();
      await e.svc.stopJourney(t1);
      expect(await e.db.select(e.db.journeys).get(), isEmpty);
      expect((await e.svc.snapshot(t1)).position, testHome);
    });

    test('쉬는 자리에서 출발하면 그 자리가 출발지 (멈춘 곳, 도착한 곳 중 나중 것)', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.stopJourney(t2);
      final stop = await _startedAt(e.db, t1);

      await e.svc.startJourney('kr001', t3);
      final j = await _startedAt(e.db, t3);
      expect(j.originLat, stop.endLat);
      expect(j.originLng, stop.endLng);
    });

    test('옛 도착 여정(끝 지점이 안 적힌 것)은 목적지 명소가 쉬는 자리', () async {
      final e = await _env();
      await e.db.into(e.db.journeys).insert(JourneysCompanion.insert(
            id: 'j1',
            originLat: testHome.lat,
            originLng: testHome.lng,
            destId: 'kr003',
            startUtc: _ms(_t0),
            fundKm: 0,
            totalEffectiveKm: 1,
            status: JourneyStatus.arrived,
            arrivedUtc: Value(_ms(t1)),
            arrivalShown: const Value(true),
          ));
      expect((await e.svc.snapshot(t2)).position, _landmarks['kr003']!.latLng);
      expect((await e.svc.snapshot(t2)).pendingArrival, isNull);
    });
  });

  group('도착 → 그림·액자', () {
    final t1 = _t0.add(const Duration(hours: 1));

    for (final frame in Frame.values) {
      test('첫 도착: ${frame.name} 액자 (거리로 정해진다)', () async {
        final e = await _env();
        await e.svc.sync(_t0);
        final dest = _destFor(testHome, frame);
        final km = _routeKm(testHome, dest.id);
        final end = await _trip(e, dest.id, t1);

        final p = await e.db.select(e.db.paintingsOwned).getSingle();
        expect(p.landmarkId, dest.id);
        expect(p.visits, 1);
        expect(p.frame, frame);
        expect(p.bestKm, closeTo(km, 1e-9));
        expect(p.firstArrivedUtc, _ms(end));
        expect(p.lastArrivedUtc, _ms(end));

        final j = await _startedAt(e.db, t1);
        expect(j.status, JourneyStatus.arrived);
        expect(j.arrivedUtc, _ms(end));
        expect(j.endLat, dest.latLng.lat);
        expect(j.endLng, dest.latLng.lng);
        expect(j.visitNo, 1);
        expect(j.prevFrame, isNull);
        expect(j.newFrame, frame);
        expect(j.arrivalShown, isFalse);
      });
    }

    test('재방문이 더 길면 액자가 오른다: 방문 2, 이전·새 액자가 여정에 남는다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final a = _destFor(testHome, Frame.wood);
      final b = _destFor(a.latLng, Frame.silver, not: a.id);
      final end1 = await _trip(e, a.id, t1);
      final end2 = await _trip(e, b.id, end1.add(const Duration(hours: 1)));
      final start3 = end2.add(const Duration(hours: 1));
      final end3 = await _trip(e, a.id, start3);

      final pa = await (e.db.select(e.db.paintingsOwned)..where((t) => t.landmarkId.equals(a.id)))
          .getSingle();
      expect(pa.visits, 2);
      expect(pa.frame, Frame.silver);
      expect(pa.bestKm, closeTo(_routeKm(b.latLng, a.id), 1e-9));
      expect(pa.firstArrivedUtc, _ms(end1));
      expect(pa.lastArrivedUtc, _ms(end3));
      expect(await e.db.select(e.db.paintingsOwned).get(), hasLength(2));

      final j = await _startedAt(e.db, start3);
      expect(j.visitNo, 2);
      expect(j.prevFrame, Frame.wood);
      expect(j.newFrame, Frame.silver);
      final pending = (await e.svc.snapshot(end3)).pendingArrival!;
      expect(pending.visitNo, 2);
      expect(pending.frameUp, isTrue);
    });

    test('재방문이 더 짧으면 액자는 그대로, 방문만 는다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 출발 동네에서는 금 액자이면서, 가까이(20km 안)에 다른 명소가 있는 곳
      final a = _landmarks.values.firstWhere((l) =>
          l.island == Island.mainland &&
          frameFor(_routeKm(testHome, l.id), rules) == Frame.gold &&
          _findDest(l.latLng, Frame.wood, not: l.id) != null);
      final b = _destFor(a.latLng, Frame.wood, not: a.id);
      final end1 = await _trip(e, a.id, t1);
      final goldKm = _routeKm(testHome, a.id);
      final end2 = await _trip(e, b.id, end1.add(const Duration(hours: 1)));
      final start3 = end2.add(const Duration(hours: 1));
      final end3 = await _trip(e, a.id, start3);

      final pa = await (e.db.select(e.db.paintingsOwned)..where((t) => t.landmarkId.equals(a.id)))
          .getSingle();
      expect(pa.visits, 2);
      expect(pa.frame, Frame.gold);
      expect(pa.bestKm, closeTo(goldKm, 1e-9));
      expect(pa.lastArrivedUtc, _ms(end3));

      final j = await _startedAt(e.db, start3);
      expect(j.visitNo, 2);
      expect(j.prevFrame, Frame.gold);
      expect(j.newFrame, Frame.gold);
      expect((await e.svc.snapshot(end3)).pendingArrival!.frameUp, isFalse);
    });

    test('같은 기록으로 또 동기화해도 그림·소품·방문 수가 그대로 (멱등)', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final dest = _destFor(testHome, Frame.silver);
      final end = await _trip(e, dest.id, t1);
      final before = await e.dump();
      expect((before['paintings'] as List), hasLength(1));
      expect((before['props'] as List), isNotEmpty);

      await e.svc.sync(end);
      await e.svc.sync(end.add(const Duration(minutes: 10)));
      await e.svc.sync(end.add(const Duration(hours: 5)));
      expect(await e.dump(), before);
      expect((await e.svc.snapshot(end)).paintingsCount, 1);
    });

    test('도착한 분은 여정의 걸음: 넘친 거리 + 이후 경비 = 걸은 거리 − 여정 거리', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await placeAt(e.db, _nearGyeongbok, _t0);
      await e.svc.startJourney('kr001', t1);
      final total = (await e.svc.snapshot(t1)).journey!.totalKm;
      // 30분 × 100보 = 2.1km 기록. 20분 30초에 동기화하면 도착 (0~20분 = 21분 × 70m)
      e.source.records.add(_walk(t1, 30, 100));
      await e.svc.sync(t1.add(const Duration(minutes: 20, seconds: 30)));
      expect((await _startedAt(e.db, t1)).status, JourneyStatus.arrived);
      await e.svc.sync(t1.add(const Duration(hours: 2)));
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(2.1 - total, 1e-9));
    });

    test('도착 대기: 도착하면 생기고 markArrivalShown 하면 사라진다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      expect((await e.svc.snapshot(_t0)).pendingArrival, isNull);
      final dest = _destFor(testHome, Frame.wood);
      final km = _routeKm(testHome, dest.id);
      final end = await _trip(e, dest.id, t1);

      final pending = (await e.svc.snapshot(end)).pendingArrival!;
      expect(pending.dest.id, dest.id);
      expect(pending.visitNo, 1);
      expect(pending.prevFrame, isNull);
      expect(pending.newFrame, Frame.wood);
      expect(pending.frameUp, isFalse);
      expect(pending.journeyKm, closeTo(km, 1e-9));
      expect(pending.arrivedAt, end);

      // 앱을 다시 열어 동기화해도 (도착 화면을 아직 안 봤으면) 그대로 남는다
      await e.svc.sync(end.add(const Duration(hours: 1)));
      expect((await e.svc.snapshot(end)).pendingArrival!.journeyId, pending.journeyId);

      await e.svc.markArrivalShown(pending.journeyId);
      expect((await e.svc.snapshot(end)).pendingArrival, isNull);
      expect((await _startedAt(e.db, t1)).arrivalShown, isTrue);
    });
  });

  group('소품', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final defaults = {for (final p in props) if (p.kind == PropUnlockKind.initial) p.id};

    test('첫 동기화에 기본 6개를 얻고, 처음부터 가진 것이라 새 소품 표시는 켜지 않는다', () async {
      final e = await _env();
      expect(defaults, hasLength(6));
      await e.svc.sync(_t0);
      expect(await _propIds(e.db), defaults);
      final rows = await e.db.select(e.db.propsOwned).get();
      expect(rows.every((r) => r.unlockedUtc == _ms(_t0) && r.seen), isTrue);
      expect((await e.svc.snapshot(_t0)).unseenProps, 0);
    });

    test('누적 10km를 넘으면 hand_02, 얻은 소품은 다시 안 들어온다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walkKm(t1, 9));
      await e.svc.sync(_t0.add(const Duration(hours: 4)));
      expect(await _propIds(e.db), defaults);

      // 거리 소품은 여정이 없어도(경비로 가는 걸음) 센서로 잰 거리를 센다
      final t3 = _t0.add(const Duration(hours: 6));
      e.source.records.add(_walkKm(_t0.add(const Duration(hours: 5)), 2));
      await e.svc.sync(t3);
      expect(await _propIds(e.db), {...defaults, 'hand_02'});
      final row = await (e.db.select(e.db.propsOwned)..where((t) => t.propId.equals('hand_02')))
          .getSingle();
      expect(row.unlockedUtc, _ms(t3));
      expect(row.seen, isFalse);
      expect((await e.svc.snapshot(t3)).totalKm, greaterThan(10));

      final before = await e.dump();
      await e.svc.sync(t3);
      await e.svc.sync(t3.add(const Duration(hours: 1)));
      expect(await e.dump(), before);
    });

    test('새로 얻은 소품만 표시가 켜지고, markPropsSeen으로 지워진다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walkKm(t1, 11));
      await e.svc.sync(_t0.add(const Duration(hours: 5)));
      final s = await e.svc.snapshot(_t0.add(const Duration(hours: 5)));
      expect(s.unseenProps, 1);
      expect(s.totalKm, greaterThanOrEqualTo(11));

      await e.svc.markPropsSeen();
      expect((await e.svc.snapshot(_t0.add(const Duration(hours: 5)))).unseenProps, 0);
    });

    test('누적 거리는 여정이 있어도 실제로 걸은 거리 (배 환산이 아니다)', () async {
      final e = await _env();
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      await placeAt(e.db, rules.ports['wando']!, _t0);
      await e.svc.sync(_t0);
      await e.svc.startJourney(jeju.id, t1);
      // 70분 × 100보 × 0.7m = 4.9km, 배 구간이라 진행(환산)은 같은 4.9km지만 경로 총 거리는 환산값
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 70, 100));
      await e.svc.sync(t1.add(const Duration(hours: 3)));
      final s = await e.svc.snapshot(t1.add(const Duration(hours: 3)));
      expect(s.totalKm, closeTo(4.9, 1e-9));
      expect(s.onSea, isTrue);
    });

    test('권역 완료: 수도권 12곳을 다 가면 pet_02, 11곳이면 없다', () async {
      final e = await _env();
      final capital = landmarks.where((l) => l.region == 'capital').map((l) => l.id).toList();
      expect(capital, hasLength(12));
      await _seedPaintings(e.db, capital.take(11));
      await e.svc.sync(_t0);
      expect(await _propIds(e.db), isNot(contains('pet_02')));

      await _seedPaintings(e.db, capital.skip(11));
      final t = _t0.add(const Duration(hours: 1));
      await e.svc.sync(t);
      expect(await _propIds(e.db), {...defaults, 'pet_02'});
      final row = await (e.db.select(e.db.propsOwned)..where((x) => x.propId.equals('pet_02')))
          .getSingle();
      expect(row.unlockedUtc, _ms(t));
    });

    test('울릉도는 명소가 한 곳이라 그림 하나로 pet_05', () async {
      final e = await _env();
      final ulleung = landmarks.singleWhere((l) => l.region == 'ulleung');
      await e.svc.sync(_t0);
      expect(await _propIds(e.db), isNot(contains('pet_05')));
      await _seedPaintings(e.db, [ulleung.id]);
      await e.svc.sync(_t0.add(const Duration(hours: 1)));
      expect(await _propIds(e.db), {...defaults, 'pet_05'});
    });

    test('실제로 도착해서 권역을 채워도 소품이 같은 동기화에서 들어온다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 제주(2곳) 중 한 곳은 미리 가 봤고, 남은 한 곳에 도착한다. 출발지는 제주 안
      final jeju = landmarks.where((l) => l.region == 'jeju').toList();
      await _seedPaintings(e.db, [jeju[0].id]);
      final near = jeju[1].latLng;
      await placeAt(e.db, LatLng(near.lat, near.lng + 0.0113), _t0);
      await _trip(e, jeju[1].id, t1);
      expect(await _propIds(e.db), contains('pet_04'));
      expect((await e.svc.snapshot(t1.add(const Duration(days: 1)))).paintingsCount, 2);
    });
  });

  group('mapData·preview (지도)', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final t2 = _t0.add(const Duration(hours: 3));
    final t3 = _t0.add(const Duration(hours: 5));
    const noHome = '출발 동네를 먼저 골라 주세요';

    /// 도착 화면 값만 빼고 채운, 도착했지만 끝 지점이 안 적힌 옛 여정 (또는 끝이 적힌 여정)
    Future<void> insertArrived(_Env e, String id, LatLng origin, String destId, DateTime at,
        {LatLng? end}) {
      return e.db.into(e.db.journeys).insert(JourneysCompanion.insert(
            id: id,
            originLat: origin.lat,
            originLng: origin.lng,
            destId: destId,
            startUtc: _ms(at),
            fundKm: 0,
            totalEffectiveKm: 100,
            status: JourneyStatus.arrived,
            arrivedUtc: Value(_ms(at.add(const Duration(hours: 1)))),
            endLat: Value(end?.lat),
            endLng: Value(end?.lng),
          ));
    }

    test('여정도 도착도 없으면 길·명소·목적지가 없고 위치는 출발 동네', () async {
      final e = await _env();
      final d = await e.svc.mapData(_t0);
      expect(d.paths, isEmpty);
      expect(d.visited, isEmpty);
      expect(d.destId, isNull);
      expect(d.position, testHome);
      expect(d.fundKm, 0);
    });

    test('멈춘 여정 + 진행 중 여정: 길은 출발지 → 멈춘 곳, 멈춘 곳 → 지금 위치', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1, useFund: false);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 40, 100));
      await e.svc.stopJourney(t2);
      final stopAt = (await e.svc.snapshot(t2)).position!;
      expect(stopAt, isNot(testHome));

      await e.svc.startJourney('kr001', t2, useFund: false);
      e.source.records.add(_walk(t2.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.sync(t3);
      final snap = await e.svc.snapshot(t3);
      expect(snap.position, isNot(stopAt));

      final d = await e.svc.mapData(t3);
      expect(d.paths, [
        [testHome, stopAt],
        [stopAt, snap.position!],
      ]);
      expect(d.destId, 'kr001');
      expect(d.position, snap.position);
      expect(d.visited, isEmpty);
      expect(d.fundKm, snap.fundKm);
    });

    test('도착한 명소는 액자와 함께 visited, 길은 도착지까지. 거리 0인 자리 기록은 길이 아니다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await placeAt(e.db, _nearGyeongbok, _t0);
      final end = await _trip(e, 'kr001', t1);

      final d = await e.svc.mapData(end);
      expect(d.visited, {'kr001': Frame.wood});
      expect(d.destId, isNull);
      expect(d.position, _landmarks['kr001']!.latLng);
      expect(d.paths, [
        [_nearGyeongbok, _landmarks['kr001']!.latLng],
      ]);
    });

    test('끝 지점이 안 적힌 옛 도착 여정은 목적지 명소까지', () async {
      final e = await _env();
      await insertArrived(e, 'old', testHome, 'kr003', t1);
      final d = await e.svc.mapData(t2);
      final kr003 = _landmarks['kr003']!.latLng;
      expect(d.paths, [
        [testHome, kr003],
      ]);
      expect(d.position, kr003);
    });

    test('바다를 건넌 여정의 길은 완도항·제주항을 거친다', () async {
      final e = await _env();
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      await insertArrived(e, 'sea', testHome, jeju.id, t1, end: jeju.latLng);
      final d = await e.svc.mapData(t2);
      expect(d.paths.single, [
        testHome,
        rules.ports['wando']!,
        rules.ports['jeju']!,
        jeju.latLng,
      ]);
    });

    test('배 위에서 진행 중인 여정의 길도 완도항을 거쳐 지금 위치까지', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final wando = rules.ports['wando']!;
      // 완도항 북쪽 약 1.1km에서 제주로. 4,000보(2.8km)면 항구를 지나 바다 위
      final origin = LatLng(wando.lat + 0.01, wando.lng);
      await placeAt(e.db, origin, _t0);
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      await e.svc.startJourney(jeju.id, t1, useFund: false);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 40, 100));
      await e.svc.sync(t2);
      final snap = await e.svc.snapshot(t2);
      expect(snap.onSea, isTrue);

      final d = await e.svc.mapData(t2);
      expect(d.paths.single, [origin, wando, snap.position!]);
    });

    test('여정은 시작 순서대로 길이 되고, 행이 먼저 들어간 순서와 상관없다', () async {
      final e = await _env();
      final near = _landmarks['kr001']!.latLng;
      await insertArrived(e, 'b', testHome, 'kr003', t2, end: _landmarks['kr003']!.latLng);
      await insertArrived(e, 'a', testHome, 'kr001', t1, end: near);
      final d = await e.svc.mapData(t3);
      expect(d.paths.map((p) => p.last), [near, _landmarks['kr003']!.latLng]);
    });

    test('preview: 쉬는 자리에서 가는 환산 거리, 일수는 하루 평균 4.9km 기준', () async {
      final e = await _env();
      final p = await e.svc.preview('kr003', _t0);
      final km = buildRoute(testHome, _landmarks['kr003']!.latLng, rules).totalEffectiveKm;
      expect(p.totalKm, km);
      expect(p.etaDays, (km / rules.defaultDailyKm - 1e-9).ceil());
      expect(p.etaDays, greaterThan(1));
    });

    test('preview: 섬이면 배 환산이 들어간다', () async {
      final e = await _env();
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      final p = await e.svc.preview(jeju.id, _t0);
      expect(p.totalKm, _routeKm(testHome, jeju.id));
      final raw = buildRoute(testHome, jeju.latLng, rules).legs.fold(0.0, (s, l) => s + l.rawKm);
      expect(p.totalKm, lessThan(raw));
    });

    test('preview: 어제까지의 하루 평균이 있으면 그걸로 일수를 센다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 첫날 100분 × 100보 × 0.7m = 7.0km
      e.source.records.add(_walk(t1, 100, 100));
      final next = _t0.add(const Duration(days: 1, hours: 1));
      await e.svc.sync(next);
      final p = await e.svc.preview('kr003', next);
      expect(p.etaDays, (p.totalKm / 7.0 - 1e-9).ceil());
    });

    test('preview: 진행 중이면 그 여정의 지금 지점에서 센다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1, useFund: false);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 40, 100));
      await e.svc.sync(t2);
      final snap = await e.svc.snapshot(t2);

      final p = await e.svc.preview('kr001', t2);
      expect(p.totalKm, _routeKm(snap.position!, 'kr001'));
      expect(p.totalKm, isNot(_routeKm(testHome, 'kr001')));
    });

    test('preview: 지금 가는 목적지는 스냅숏의 남은 거리·도착 예정일과 같다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1, useFund: false);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 40, 100));
      await e.svc.sync(t2);
      final snap = await e.svc.snapshot(t2);

      final p = await e.svc.preview('kr003', t2);
      expect(p.totalKm, closeTo(snap.journey!.progress.remainingKm, 0.05));
      expect(p.etaDays, snap.journey!.eta.difference(dayFromKey(snap.today)).inDays);
    });

    test('preview: 지금 있는 명소는 거리 0이어도 일수는 최소 1', () async {
      final e = await _env();
      await placeAt(e.db, _landmarks['kr001']!.latLng, _t0);
      final p = await e.svc.preview('kr001', _t0);
      expect(p.totalKm, 0);
      expect(p.etaDays, 1);
    });

    test('preview: 출발 동네도 여행도 없으면 StateError, 저장은 그대로', () async {
      final e = await _env(home: false);
      await e.svc.snapshot(_t0);
      final before = await e.dump();
      await expectLater(
        e.svc.preview('kr003', _t0),
        throwsA(isA<StateError>().having((x) => x.message, 'message', noHome)),
      );
      expect(await e.dump(), before);
    });

    test('preview·mapData는 저장을 바꾸지 않는다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      final before = await e.dump();
      await e.svc.preview('kr001', t2);
      await e.svc.mapData(t2);
      expect(await e.dump(), before);
    });
  });

  group('arrivalView (도착 화면)', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final hour = const Duration(hours: 1);

    test('첫 방문: 방문 1, 액자 전후, 여정 거리, 도착 시각, 그날 걸음, 지난번·권역 소품 없음', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final dest = _destFor(testHome, Frame.wood);
      final km = _routeKm(testHome, dest.id);
      final end = await _trip(e, dest.id, t1);
      final steps = e.source.records.single.steps;
      // 같은 한국 날짜 안에서 걸었으니 그날 걸음은 이 기록의 걸음
      expect(kstDayKey(t1), kstDayKey(end));

      final id = (await _startedAt(e.db, t1)).id;
      final v = await e.svc.arrivalView(id);
      expect(v.journeyId, id);
      expect(v.dest.id, dest.id);
      expect(v.visitNo, 1);
      expect(v.prevFrame, isNull);
      expect(v.newFrame, Frame.wood);
      expect(v.frameUp, isFalse);
      expect(v.journeyKm, closeTo(km, 1e-9));
      expect(v.arrivedAt, end);
      expect(v.daySteps, steps);
      expect(v.prevBestKm, isNull);
      expect(v.regionProp, isNull);
    });

    test('그날 걸음은 도착한 시각의 한국 날짜 하루 요약 (UTC 날짜가 아니다)', () async {
      final e = await _env();
      await _insertDay(e.db, '2026-11-18', 111);
      await _insertDay(e.db, '2026-11-19', 222);
      await _insertDay(e.db, '2026-11-20', 333);
      // UTC 2026-11-18 15:30 = 한국 11-19 00:30
      await _insertArrival(e.db, 'j1', 'kr001', DateTime.utc(2026, 11, 18, 15, 30));
      // UTC 2026-11-19 14:59 = 한국 11-19 23:59
      await _insertArrival(e.db, 'j2', 'kr002', DateTime.utc(2026, 11, 19, 14, 59));
      expect((await e.svc.arrivalView('j1')).daySteps, 222);
      expect((await e.svc.arrivalView('j2')).daySteps, 222);
    });

    test('하루 요약이 없는 날은 그날 걸음 0', () async {
      final e = await _env();
      await _insertArrival(e.db, 'j1', 'kr001', DateTime.utc(2026, 12, 1));
      expect((await e.svc.arrivalView('j1')).daySteps, 0);
    });

    test('2번째 방문에서 액자가 오르면: 지난번 거리는 첫 도착의 거리', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final a = _destFor(testHome, Frame.wood);
      final b = _destFor(a.latLng, Frame.silver, not: a.id);
      final end1 = await _trip(e, a.id, t1);
      final end2 = await _trip(e, b.id, end1.add(hour));
      final start3 = end2.add(hour);
      await _trip(e, a.id, start3);

      final v = await e.svc.arrivalView((await _startedAt(e.db, start3)).id);
      expect(v.visitNo, 2);
      expect(v.prevFrame, Frame.wood);
      expect(v.newFrame, Frame.silver);
      expect(v.frameUp, isTrue);
      expect(v.journeyKm, closeTo(_routeKm(b.latLng, a.id), 1e-9));
      expect(v.prevBestKm, closeTo(_routeKm(testHome, a.id), 1e-9));
      expect(v.regionProp, isNull);
    });

    test('2·3번째 방문: 지난번 거리는 가장 최근이 아니라 가장 먼 거리', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      // 출발 동네에서는 금 액자이면서, 가까이에 다른 명소가 있는 곳
      final a = _landmarks.values.firstWhere((l) =>
          l.island == Island.mainland &&
          frameFor(_routeKm(testHome, l.id), rules) == Frame.gold &&
          _findDest(l.latLng, Frame.wood, not: l.id) != null);
      final b = _destFor(a.latLng, Frame.wood, not: a.id);
      final goldKm = _routeKm(testHome, a.id);
      final shortKm = _routeKm(b.latLng, a.id);
      expect(shortKm, lessThan(goldKm));

      final end1 = await _trip(e, a.id, t1);
      final end2 = await _trip(e, b.id, end1.add(hour));
      final start3 = end2.add(hour);
      final end3 = await _trip(e, a.id, start3);
      final end4 = await _trip(e, b.id, end3.add(hour));
      final start5 = end4.add(hour);
      await _trip(e, a.id, start5);

      final v2 = await e.svc.arrivalView((await _startedAt(e.db, start3)).id);
      expect(v2.visitNo, 2);
      expect(v2.newFrame, Frame.gold);
      expect(v2.frameUp, isFalse);
      expect(v2.journeyKm, closeTo(shortKm, 1e-9));
      expect(v2.prevBestKm, closeTo(goldKm, 1e-9));

      final v3 = await e.svc.arrivalView((await _startedAt(e.db, start5)).id);
      expect(v3.visitNo, 3);
      expect(v3.journeyKm, closeTo(shortKm, 1e-9));
      // 2번째가 더 짧았으니 지난번 최고는 첫 도착 그대로
      expect(v3.prevBestKm, closeTo(goldKm, 1e-9));
    });

    test('옛 도착이라 지난번 기록이 없는 재방문: 지난번 거리는 null', () async {
      final e = await _env();
      await _insertArrival(e.db, 'j1', 'kr001', DateTime.utc(2026, 11, 20),
          visitNo: 2, prevFrame: Frame.wood);
      expect((await e.svc.arrivalView('j1')).prevBestKm, isNull);
    });

    test('다른 명소의 도착과 멈춘 여정은 지난번에 들어가지 않는다', () async {
      final e = await _env();
      await _insertArrival(e.db, 'j1', 'kr001', DateTime.utc(2026, 11, 18), km: 40);
      await _insertArrival(e.db, 'j2', 'kr002', DateTime.utc(2026, 11, 19), km: 90);
      await _insertArrival(e.db, 'j3', 'kr001', DateTime.utc(2026, 11, 20),
          visitNo: 2, prevFrame: Frame.silver, frame: Frame.silver, km: 10);
      // 나중 도착 (다시 본 화면이 아니라 이 도착 뒤에 생긴 일)
      await _insertArrival(e.db, 'j4', 'kr001', DateTime.utc(2026, 11, 25),
          visitNo: 3, prevFrame: Frame.silver, frame: Frame.gold, km: 70);
      await placeAt(e.db, testHome, DateTime.utc(2026, 11, 19));
      expect((await e.svc.arrivalView('j3')).prevBestKm, 40);
      expect((await e.svc.arrivalView('j4')).prevBestKm, 40);
    });

    test('울릉(명소 1곳)에 도착하면 첫 방문이 권역을 채워서 괭이갈매기', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final ulleung = _landmarks['kr089']!;
      // 울릉도 안에서 약 1km 북쪽
      await placeAt(e.db, LatLng(ulleung.latLng.lat + 0.009, ulleung.latLng.lng), _t0);
      await _trip(e, ulleung.id, t1);
      final v = await e.svc.arrivalView((await _startedAt(e.db, t1)).id);
      expect(v.visitNo, 1);
      expect(v.regionProp?.id, 'pet_05');
      expect(v.regionProp?.name, '괭이갈매기');
    });

    test('제주(2곳)는 둘째 그림에서 돌하르방, 첫째에서는 없다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final jeju = landmarks.where((l) => l.region == 'jeju').toList();
      expect(jeju, hasLength(2));
      await placeAt(e.db, LatLng(jeju[0].latLng.lat, jeju[0].latLng.lng + 0.0113), _t0);
      final end1 = await _trip(e, jeju[0].id, t1);
      final first = await e.svc.arrivalView((await _startedAt(e.db, t1)).id);
      expect(first.visitNo, 1);
      expect(first.regionProp, isNull);

      final start2 = end1.add(hour);
      await _trip(e, jeju[1].id, start2);
      final second = await e.svc.arrivalView((await _startedAt(e.db, start2)).id);
      expect(second.visitNo, 1);
      expect(second.regionProp?.id, 'pet_04');
    });

    test('재방문은 권역이 이미 차 있어도 소품이 없다', () async {
      final e = await _env();
      final ulleung = _landmarks['kr089']!;
      await _seedPaintings(e.db, [ulleung.id]);
      await _insertArrival(e.db, 'j1', ulleung.id, DateTime.utc(2026, 11, 20),
          visitNo: 2, prevFrame: Frame.wood);
      expect((await e.svc.arrivalView('j1')).regionProp, isNull);
    });

    test('권역 소품은 그 도착까지의 그림으로 본다 (뒤에 채운 권역을 앞 도착에 붙이지 않는다)', () async {
      final e = await _env();
      final jeju = landmarks.where((l) => l.region == 'jeju').toList();
      await e.db.batch((b) => b.insertAll(e.db.paintingsOwned, [
            for (final (i, l) in jeju.indexed)
              PaintingsOwnedCompanion.insert(
                landmarkId: l.id,
                visits: 1,
                frame: Frame.wood,
                bestKm: 1,
                firstArrivedUtc: 100 + i * 100,
                lastArrivedUtc: 100 + i * 100,
              ),
          ]));
      DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      await _insertArrival(e.db, 'j1', jeju[0].id, at(100));
      await _insertArrival(e.db, 'j2', jeju[1].id, at(200));
      expect((await e.svc.arrivalView('j1')).regionProp, isNull);
      expect((await e.svc.arrivalView('j2')).regionProp?.id, 'pet_04');
    });

    test('도착한 여정이 아니거나 없으면 StateError', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', t1);
      final active = (await _startedAt(e.db, t1)).id;
      await expectLater(e.svc.arrivalView(active), throwsStateError);
      await expectLater(e.svc.arrivalView('없는-id'), throwsStateError);
      // 옛 도착 여정 (도착 화면 값이 없다)
      await _insertArrival(e.db, 'old', 'kr001', DateTime.utc(2026, 11, 20), withVisitNo: false);
      await expectLater(e.svc.arrivalView('old'), throwsStateError);
      await e.svc.stopJourney(t1.add(const Duration(minutes: 5)));
      await expectLater(e.svc.arrivalView(active), throwsStateError);
    });

    test('읽기만 한다: 도착 대기도 저장도 그대로', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final dest = _destFor(testHome, Frame.wood);
      final end = await _trip(e, dest.id, t1);
      final before = await e.dump();
      await e.svc.arrivalView((await _startedAt(e.db, t1)).id);
      expect(await e.dump(), before);
      expect((await e.svc.snapshot(end)).pendingArrival, isNotNull);
    });
  });

  group('화집 벽', () {
    final ids = ['kr001', 'kr002', 'kr003', 'kr004', 'kr005', 'kr006'];

    Future<_Env> envWithPaintings() async {
      final e = await _env();
      await _seedPaintings(e.db, ids);
      return e;
    }

    test('처음엔 4칸이 모두 비어 있다', () async {
      final e = await _env();
      expect(await e.svc.wall(), [null, null, null, null]);
    });

    test('setWall: 칸에 건다. 4칸은 늘 유지된다', () async {
      final e = await envWithPaintings();
      await e.svc.setWall(2, 'kr001');
      expect(await e.svc.wall(), [null, null, 'kr001', null]);
      await e.svc.setWall(0, 'kr002');
      expect(await e.svc.wall(), ['kr002', null, 'kr001', null]);
    });

    test('setWall: 다른 칸에 걸린 그림을 옮기면 원래 칸은 비고, 한 그림은 한 칸에만 있다', () async {
      final e = await envWithPaintings();
      await e.svc.setWall(0, 'kr001');
      await e.svc.setWall(1, 'kr002');
      await e.svc.setWall(3, 'kr001');
      expect(await e.svc.wall(), [null, 'kr002', null, 'kr001']);
      expect((await e.db.select(e.db.wallSlots).get()), hasLength(2));
    });

    test('setWall: 걸려 있던 자리에 새 그림을 걸면 바뀐다 (이전 그림은 벽에서 내려간다)', () async {
      final e = await envWithPaintings();
      await e.svc.setWall(1, 'kr001');
      await e.svc.setWall(1, 'kr002');
      expect(await e.svc.wall(), [null, 'kr002', null, null]);
      await e.svc.setWall(1, 'kr002');
      expect(await e.svc.wall(), [null, 'kr002', null, null]);
    });

    test('setWall: 칸 번호가 범위 밖이면 RangeError, 얻지 않은 그림이면 StateError, 둘 다 저장 그대로', () async {
      final e = await envWithPaintings();
      await e.svc.setWall(0, 'kr001');
      await expectLater(e.svc.setWall(4, 'kr002'), throwsRangeError);
      await expectLater(e.svc.setWall(-1, 'kr002'), throwsRangeError);
      await expectLater(e.svc.setWall(1, 'kr050'), throwsStateError);
      expect(await e.svc.wall(), ['kr001', null, null, null]);
    });

    test('hangOnWall: 첫 빈 칸에 걸고 그 칸을 돌려준다', () async {
      final e = await envWithPaintings();
      expect(await e.svc.hangOnWall('kr001'), 0);
      expect(await e.svc.hangOnWall('kr002'), 1);
      // 빈 칸이 가운데에 생기면 거기부터 채운다
      await e.svc.setWall(3, 'kr003');
      await e.svc.setWall(0, 'kr004');
      expect(await e.svc.wall(), ['kr004', 'kr002', null, 'kr003']);
      expect(await e.svc.hangOnWall('kr005'), 2);
      expect(await e.svc.wall(), ['kr004', 'kr002', 'kr005', 'kr003']);
    });

    test('hangOnWall: 이미 걸려 있으면 그 칸을 돌려주고 그대로 둔다', () async {
      final e = await envWithPaintings();
      await e.svc.setWall(2, 'kr001');
      expect(await e.svc.hangOnWall('kr001'), 2);
      expect(await e.svc.wall(), [null, null, 'kr001', null]);
    });

    test('hangOnWall: 벽이 가득 차면 null이고 아무것도 바꾸지 않는다 (이미 걸린 그림은 그 칸)', () async {
      final e = await envWithPaintings();
      for (var i = 0; i < 4; i++) {
        await e.svc.setWall(i, ids[i]);
      }
      expect(await e.svc.hangOnWall('kr005'), isNull);
      expect(await e.svc.wall(), ['kr001', 'kr002', 'kr003', 'kr004']);
      expect(await e.svc.hangOnWall('kr003'), 2);
    });

    test('hangOnWall: 얻지 않은 그림이면 StateError', () async {
      final e = await envWithPaintings();
      await expectLater(e.svc.hangOnWall('kr050'), throwsStateError);
      expect(await e.svc.wall(), [null, null, null, null]);
    });

    test('벽은 동기화·도착과 상관없이 남는다', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final dest = _destFor(testHome, Frame.wood);
      final end = await _trip(e, dest.id, _t0.add(const Duration(hours: 1)));
      expect(await e.svc.hangOnWall(dest.id), 0);
      await e.svc.sync(end.add(const Duration(hours: 2)));
      expect(await e.svc.wall(), [dest.id, null, null, null]);
    });
  });

  group('paintings·visits·ownedPropIds (화집)', () {
    final t1 = _t0.add(const Duration(hours: 1));
    final hour = const Duration(hours: 1);

    test('paintings: 처음 얻은 순서, 명소·방문·액자·가장 먼 거리·처음/마지막 도착', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final a = _destFor(testHome, Frame.wood);
      final b = _destFor(a.latLng, Frame.silver, not: a.id);
      final end1 = await _trip(e, a.id, t1);
      final end2 = await _trip(e, b.id, end1.add(hour));
      final end3 = await _trip(e, a.id, end2.add(hour));

      final list = await e.svc.paintings();
      expect([for (final p in list) p.landmark.id], [a.id, b.id]);
      final pa = list[0];
      expect(pa.landmark.name, a.name);
      expect(pa.visits, 2);
      expect(pa.frame, Frame.silver);
      expect(pa.bestKm, closeTo(_routeKm(b.latLng, a.id), 1e-9));
      expect(pa.firstArrivedAt, end1);
      expect(pa.lastArrivedAt, end3);
      final pb = list[1];
      expect((pb.visits, pb.frame, pb.firstArrivedAt, pb.lastArrivedAt),
          (1, Frame.silver, end2, end2));
    });

    test('paintings: 얻은 그림이 없으면 빈 목록, 처음 얻은 시각이 같으면 명소 id 순', () async {
      final e = await _env();
      expect(await e.svc.paintings(), isEmpty);
      await _seedPaintings(e.db, ['kr003', 'kr001', 'kr002']);
      expect([for (final p in await e.svc.paintings()) p.landmark.id], ['kr001', 'kr002', 'kr003']);
    });

    test('visits: 그 명소에 도착한 여정만 도착 순서대로 (몇 번째·거리·도착 시각)', () async {
      final e = await _env();
      await e.svc.sync(_t0);
      final a = _destFor(testHome, Frame.wood);
      final b = _destFor(a.latLng, Frame.silver, not: a.id);
      final end1 = await _trip(e, a.id, t1);
      final end2 = await _trip(e, b.id, end1.add(hour));
      final end3 = await _trip(e, a.id, end2.add(hour));
      // 멈춘 여정은 방문이 아니다
      await e.svc.startJourney(b.id, end3.add(hour), useFund: false);
      await e.svc.stopJourney(end3.add(hour * 2));

      final va = await e.svc.visits(a.id);
      expect([for (final v in va) v.visitNo], [1, 2]);
      expect(va[0].km, closeTo(_routeKm(testHome, a.id), 1e-9));
      expect(va[1].km, closeTo(_routeKm(b.latLng, a.id), 1e-9));
      expect([for (final v in va) v.arrivedAt], [end1, end3]);
      final vb = await e.svc.visits(b.id);
      expect([for (final v in vb) (v.visitNo, v.arrivedAt)], [(1, end2)]);
      expect(await e.svc.visits('kr050'), isEmpty);
    });

    test('visits: 몇 번째인지 안 적힌 옛 기록은 도착 순서', () async {
      final e = await _env();
      await _insertArrival(e.db, 'j2', 'kr001', DateTime.utc(2026, 11, 20),
          withVisitNo: false, km: 7);
      await _insertArrival(e.db, 'j1', 'kr001', DateTime.utc(2026, 11, 19),
          withVisitNo: false, km: 5);
      final v = await e.svc.visits('kr001');
      expect([for (final x in v) (x.visitNo, x.km)], [(1, 5.0), (2, 7.0)]);
    });

    test('ownedPropIds: 기본 소품부터, 새로 얻으면 늘어난다', () async {
      final e = await _env();
      expect(await e.svc.ownedPropIds(), isEmpty);
      await e.svc.sync(_t0);
      final defaults = {for (final p in props) if (p.kind == PropUnlockKind.initial) p.id};
      expect(await e.svc.ownedPropIds(), defaults);
      e.source.records.add(_walkKm(_t0.add(const Duration(hours: 1)), 11));
      await e.svc.sync(_t0.add(const Duration(hours: 5)));
      expect(await e.svc.ownedPropIds(), {...defaults, 'hand_02'});
    });
  });
}
