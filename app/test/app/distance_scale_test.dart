import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

final _landmarks = {for (final l in landmarks) l.id: l};

// 경복궁에서 동쪽으로 약 1km
const _nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

// 설치 KST 2026-11-18 09:00
final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));
final _t2 = _t0.add(const Duration(hours: 3));

/// start부터 minutes분 동안 분당 spm보로 걸은 기록 하나
StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

double _routeKm(LatLng from, String destId) =>
    buildRoute(from, _landmarks[destId]!.latLng, rules).totalEffectiveKm;

/// 출발 동네에서 가는 거리가 60km를 넘는 육지 명소: 배수 10에서도 40분(2.8km → 28km) 걸어서는 도착하지 않는다
final _farDest = landmarks
    .firstWhere((l) => l.island == Island.mainland && _routeKm(testHome, l.id) > 60)
    .id;

class _Env {
  /// [scale]이 null이면 배수를 넘기지 않는다 (기본값)
  _Env(double? scale)
      : db = AppDb(NativeDatabase.memory()),
        source = FakeStepSource() {
    svc = scale == null
        ? SyncService(
            db: db,
            source: source,
            rules: rules,
            allowedSources: const [],
            landmarks: _landmarks,
            props: props,
            milestones: milestones,
          )
        : SyncService(
            db: db,
            source: source,
            rules: rules,
            allowedSources: const [],
            landmarks: _landmarks,
            props: props,
            milestones: milestones,
            distanceScale: scale,
          );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  /// 시각에 따라 달라지는 값(SyncState·fundedUntilUtc)은 빼고 비교한다
  Future<Map<String, Object?>> dump() async => {
        'days': await db.select(db.daySummaries).get(),
        'sessions': await db.select(db.walkSessions).get(),
        'journeys': await db.select(db.journeys).get(),
        'paintings': await db.select(db.paintingsOwned).get(),
        'tickets': await db.select(db.guestbookTickets).get(),
        'fundKm': (await db.select(db.travelFund).getSingle()).km,
      };
}

/// 설치(_t0)하고 출발 동네를 고른 환경 ([scale]배)
Future<_Env> _env(double? scale) async {
  final e = _Env(scale);
  addTearDown(e.db.close);
  await e.svc.sync(_t0);
  await e.svc.setHome(testHomeName, testHome);
  return e;
}

/// 경복궁 근처에서 경복궁으로 출발한 환경 (경비는 안 더한다). 여정 거리는 [_Env.svc]로 읽는다
Future<_Env> _gyeongbokEnv(double? scale) async {
  final e = _Env(scale);
  addTearDown(e.db.close);
  await e.svc.sync(_t0);
  await placeAt(e.db, _nearGyeongbok, _t0);
  await e.svc.startJourney('kr001', _t1, useFund: false);
  return e;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('여정 중: 같은 걸음이면 진행 거리가 배수만큼 크고, 걸음·거리·하루 요약·누적은 그대로', () async {
    final envs = [await _env(1), await _env(10)];
    for (final e in envs) {
      await e.svc.startJourney(_farDest, _t1);
      e.source.records.add(_walk(_t1.add(const Duration(minutes: 10)), 40, 100));
      await e.svc.sync(_t2);
    }
    final s1 = await envs[0].svc.snapshot(_t2);
    final s10 = await envs[1].svc.snapshot(_t2);

    // 40분 × 100보 × 0.7m = 2.8km
    expect(s1.journey!.progress.progressKm, closeTo(2.8, 1e-9));
    expect(s10.journey!.progress.progressKm, closeTo(28, 1e-9));
    expect(s10.journey!.progress.ratio, closeTo(s1.journey!.progress.ratio * 10, 1e-9));
    expect(s10.journey!.progress.arrived, isFalse);
    expect(s10.journey!.progress.remainingKm,
        closeTo(s10.journey!.totalKm - 28, 1e-9));

    // 걸음 숫자와 하루 요약, 누적 거리, 경비는 곱하지 않는다
    expect(s10.todaySteps, 4000);
    expect(s10.todaySteps, s1.todaySteps);
    expect(s10.todayDistanceM, closeTo(2800, 1e-9));
    expect(s10.todayDistanceM, s1.todayDistanceM);
    expect(s10.totalKm, closeTo(2.8, 1e-9));
    expect(s10.totalKm, s1.totalKm);
    expect(s10.fundKm, s1.fundKm);
    expect(s10.countedSessions, s1.countedSessions);
    expect(await envs[1].db.select(envs[1].db.daySummaries).get(),
        await envs[0].db.select(envs[0].db.daySummaries).get());
    expect(await envs[1].db.select(envs[1].db.walkSessions).get(),
        await envs[0].db.select(envs[0].db.walkSessions).get());
  });

  test('여정이 없으면 경비도 그대로 (배수는 경비에 곱하지 않는다)', () async {
    final funds = <double>[];
    final advanced = <double>[];
    for (final scale in [1.0, 10.0, 100.0]) {
      final e = await _env(scale);
      e.source.records.add(_walk(_t1, 30, 100));
      advanced.add((await e.svc.sync(_t2)).advancedKm);
      funds.add((await e.svc.snapshot(_t2)).fundKm);
    }
    // 30분 × 100보 × 0.7m
    expect(funds, everyElement(closeTo(2.1, 1e-9)));
    expect(advanced, everyElement(closeTo(2.1, 1e-9)));
  });

  test('1배는 배수를 안 준 것과 같다, 0 이하는 만들 수 없다', () async {
    final a = await _env(1);
    final b = await _env(null);
    for (final e in [a, b]) {
      await e.svc.startJourney(_farDest, _t1);
      e.source.records.add(_walk(_t1.add(const Duration(minutes: 10)), 40, 100));
      await e.svc.sync(_t2);
    }
    expect((await a.svc.snapshot(_t2)).journey!.progress.progressKm,
        (await b.svc.snapshot(_t2)).journey!.progress.progressKm);
    expect(await a.dump(), await b.dump());

    expect(
      () => SyncService(
        db: a.db,
        source: a.source,
        rules: rules,
        allowedSources: const [],
        landmarks: _landmarks,
        props: props,
        distanceScale: 0,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  group('도착', () {
    test('같은 걸음이 1배로는 못 닿고 10배로는 도착해서 그림과 방명록 기회가 생긴다', () async {
      final e1 = await _gyeongbokEnv(1);
      final e10 = await _gyeongbokEnv(10);
      final total = (await e1.svc.snapshot(_t1)).journey!.totalKm;
      // 5분 × 100보 × 0.7m = 0.35km: 전체의 약 3분의 1
      expect(total, inInclusiveRange(0.5, 3.5));
      for (final e in [e1, e10]) {
        e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 5, 100));
        await e.svc.sync(_t2);
      }

      expect(await e1.db.select(e1.db.paintingsOwned).get(), isEmpty);
      expect((await e1.svc.snapshot(_t2)).journey!.progress.arrived, isFalse);

      final owned = await e10.db.select(e10.db.paintingsOwned).get();
      expect(owned.map((r) => r.landmarkId), ['kr001']);
      final arrivalTickets = (await e10.db.select(e10.db.guestbookTickets).get())
          .where((t) => t.kind == TicketKind.arrival);
      expect(arrivalTickets.single.scope, 'kr001');
      expect((await e10.svc.snapshot(_t2)).pendingArrival?.dest.id, 'kr001');
    });

    test('도착 뒤 경비는 실제로 더 걸은 거리: 넘친 거리 ÷ 배수 (하루 요약은 그대로)', () async {
      final e1 = await _gyeongbokEnv(1);
      final e10 = await _gyeongbokEnv(10);
      final total = (await e1.svc.snapshot(_t1)).journey!.totalKm;
      for (final e in [e1, e10]) {
        // 30분 × 100보 × 0.7m = 2.1km
        e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 30, 100));
        await e.svc.sync(_t2);
      }
      Future<double> fund(_Env e) async =>
          (await e.db.select(e.db.travelFund).getSingle()).km;

      // 1배: 2.1km 중 total만큼이 길. 10배: total/10만큼 걸어서 도착하고 나머지가 경비
      expect(await fund(e1), closeTo(2.1 - total, 1e-9));
      expect(await fund(e10), closeTo(2.1 - total / 10, 1e-9));
      expect(await e10.db.select(e10.db.daySummaries).get(),
          await e1.db.select(e1.db.daySummaries).get());
      expect((await e10.svc.snapshot(_t2)).totalKm, closeTo(2.1, 1e-9));
    });

    test('멱등: 10배에서도 같은 기록으로 또 동기화해도 결과가 같다', () async {
      final once = await _gyeongbokEnv(10);
      final twice = await _gyeongbokEnv(10);
      for (final e in [once, twice]) {
        e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 30, 100));
        await e.svc.sync(_t2);
      }
      await twice.svc.sync(_t2);
      await twice.svc.sync(_t2.add(const Duration(minutes: 10)));

      expect(await twice.dump(), await once.dump());
      final r = await twice.svc.sync(_t2.add(const Duration(minutes: 20)));
      expect(r.advancedKm, 0);
    });
  });

  test('멈추면 그 순간 보이던 자리(배수 거리 기준)가 쉬는 자리가 된다', () async {
    final e = await _env(10);
    await e.svc.startJourney(_farDest, _t1);
    e.source.records.add(_walk(_t1.add(const Duration(minutes: 10)), 40, 100));
    await e.svc.sync(_t2);
    final before = (await e.svc.snapshot(_t2)).position!;

    expect(await e.svc.stopJourney(_t2), isTrue);
    final after = await e.svc.snapshot(_t2);
    expect(after.journey, isNull);
    expect(after.position!.lat, closeTo(before.lat, 1e-9));
    expect(after.position!.lng, closeTo(before.lng, 1e-9));
    // 출발지에서 28km 가까이 떨어진 자리다 (1배면 2.8km)
    final moved = haversineKm(testHome, after.position!, rules.earthRadiusKm);
    expect(moved, greaterThan(10));
  });
}
