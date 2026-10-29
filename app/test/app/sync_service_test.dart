import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

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
        'fundKm': (await db.select(db.travelFund).getSingle()).km,
      };
}

_Env _env() {
  final e = _Env();
  addTearDown(e.db.close);
  return e;
}

void main() {
  // 테스트마다 따로 여는 메모리 DB라 같은 파일을 두 번 여는 경우가 아니다
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('#26 멱등: 같은 기록으로 한 번 / 여러 번 동기화한 결과가 같다', () {
    test('여정 없음 → 경비가 한 번만 쌓인다', () async {
      final once = _env();
      final twice = _env();
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
      final once = _env();
      final twice = _env();
      final t1 = _t0.add(const Duration(hours: 1));
      final t2 = _t0.add(const Duration(hours: 3));
      for (final e in [once, twice]) {
        await e.svc.sync(_t0);
        await e.svc.startJourney('kr003', rules.fallbackOrigin, t1);
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
    final e = _env();
    final t1 = _t0.add(const Duration(hours: 1));
    await e.svc.sync(_t0);
    await e.svc.startJourney('kr001', _nearGyeongbok, t1);
    e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
    await e.svc.sync(_t0.add(const Duration(hours: 3)));

    final total = buildRoute(_nearGyeongbok, _landmarks['kr001']!.latLng, rules).totalEffectiveKm;
    final j = await e.db.select(e.db.journeys).getSingle();
    expect(j.status, JourneyStatus.arrived);
    expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(2.1 - total, 1e-9));
  });

  test('경비는 상한에서 멈춘다', () async {
    final e = _env();
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
      final e = _env();
      expect((await e.svc.sync(_t0)).advancedKm, 0);
      e.source.records.add(_walk(t1, 30, 100));
      // 3000보 × 0.7m
      expect((await e.svc.sync(t2)).advancedKm, closeTo(2.1, 1e-9));
      expect((await e.svc.sync(t2)).advancedKm, 0);
      expect((await e.svc.sync(t2.add(const Duration(minutes: 10)))).advancedKm, 0);
    });

    test('여정 중: 진행 거리가 는 만큼', () async {
      final e = _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', rules.fallbackOrigin, t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 40, 100));
      final r = await e.svc.sync(t2);
      final p = (await e.svc.snapshot(t2)).journey!.progress;
      expect(r.advancedKm, closeTo(2.8, 1e-9));
      expect(r.advancedKm, closeTo(p.progressKm, 1e-9));
      expect((await e.svc.sync(t2)).advancedKm, 0);
    });

    test('여정 중 두 번째 동기화는 그 사이 늘어난 만큼만', () async {
      final e = _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', rules.fallbackOrigin, t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 20, 100));
      await e.svc.sync(t1.add(const Duration(minutes: 40)));
      e.source.records.add(_walk(t1.add(const Duration(minutes: 60)), 10, 100));
      // 10분 × 100보 × 0.7m
      expect((await e.svc.sync(t2)).advancedKm, closeTo(0.7, 1e-9));
    });

    test('도착한 동기화도 걸은 거리 그대로 (넘친 거리를 또 더하지 않는다)', () async {
      final e = _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr001', _nearGyeongbok, t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      final r = await e.svc.sync(t2);

      final total =
          buildRoute(_nearGyeongbok, _landmarks['kr001']!.latLng, rules).totalEffectiveKm;
      expect((await e.db.select(e.db.journeys).getSingle()).status, JourneyStatus.arrived);
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(2.1 - total, 1e-9));
      expect(r.advancedKm, closeTo(2.1, 1e-9));
      expect((await e.svc.sync(t2)).advancedKm, 0);
    });

    test('경비가 상한에 닿으면 그 뒤로는 늘지 않아 0', () async {
      final e = _env();
      await e.svc.sync(_t0);
      // 250분 × 100보 = 17.5km → 상한까지만
      e.source.records.add(_walk(_t0.add(const Duration(minutes: 30)), 250, 100));
      final r = await e.svc.sync(_t0.add(const Duration(hours: 6)));
      expect(r.advancedKm, rules.travelFundCapKm);
      e.source.records.add(_walk(_t0.add(const Duration(hours: 7)), 30, 100));
      expect((await e.svc.sync(_t0.add(const Duration(hours: 9)))).advancedKm, 0);
    });

    test('inspect는 저장하지 않으니 0', () async {
      final e = _env();
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
      final e = _env();
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
      final e = _env();
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
      final e = _env();
      await e.svc.sync(_t0);
      e.source.records.add(_walk(t1, 15, 100));
      await e.svc.sync(t2);

      final r = await e.svc.walkRecord(t1, t1.add(const Duration(minutes: 9, seconds: 30)));
      expect(r.summary.steps, 1000);
    });

    test('짧은 걷기는 인정되지 않고 오늘 0/3', () async {
      final e = _env();
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
      final e = _env();
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
      final e = _env();
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
      final e = _env();
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
      final e = _env();
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

    test('여정도 도착한 적도 없으면 기본 출발지', () async {
      final e = _env();
      final s = await e.svc.snapshot(_t0);
      expect(s.position, rules.fallbackOrigin);
      expect(s.onSea, isFalse);
      expect(s.journey, isNull);
    });

    test('여정 중(땅): 경로 위 진행 지점', () async {
      final e = _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr003', rules.fallbackOrigin, t1);
      // 시작 직후는 출발지
      expect((await e.svc.snapshot(t1)).position, rules.fallbackOrigin);

      e.source.records.add(_walk(t1.add(const Duration(minutes: 10)), 40, 100));
      await e.svc.sync(t2);
      final s = await e.svc.snapshot(t2);
      final route = buildRoute(rules.fallbackOrigin, _landmarks['kr003']!.latLng, rules);
      final expected = positionAt(route, s.journey!.progress.progressKm);
      expect(s.position, expected.latLng);
      expect(s.position, isNot(rules.fallbackOrigin));
      expect(s.onSea, isFalse);
    });

    test('여정 중(배 구간): onSea, 위치는 완도항과 제주항 사이', () async {
      final e = _env();
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      final wando = rules.ports['wando']!;
      final port = rules.ports['jeju']!;
      await e.svc.sync(_t0);
      // 완도항에서 제주로: 첫 다리가 배 (환산 약 30km)
      await e.svc.startJourney(jeju.id, wando, t1);
      expect((await e.svc.snapshot(t1)).onSea, isTrue);

      // 143분 × 100보 × 0.7m = 10.01km (환산 거리) → 아직 배 위
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 143, 100));
      await e.svc.sync(t1.add(const Duration(hours: 4)));
      final s = await e.svc.snapshot(t1.add(const Duration(hours: 4)));
      expect(s.onSea, isTrue);
      expect(s.position.lat, inInclusiveRange(port.lat, wando.lat));
      expect(s.position, isNot(wando));
    });

    test('배 구간을 지나면 onSea가 꺼지고 제주 땅 위 지점', () async {
      final e = _env();
      final jeju = _landmarks.values.firstWhere((l) => l.island == Island.jeju);
      await e.svc.sync(_t0);
      await e.svc.startJourney(jeju.id, rules.ports['wando']!, t1);
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
      final e = _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr001', _nearGyeongbok, t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.sync(t2);

      final s = await e.svc.snapshot(t2);
      expect(s.journey, isNull);
      expect(s.position, _landmarks['kr001']!.latLng);
      expect(s.onSea, isFalse);
    });

    test('여러 번 도착했으면 가장 최근에 도착한 곳', () async {
      final e = _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr001', _nearGyeongbok, t1);
      e.source.records.add(_walk(t1.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.sync(t2);

      // 두 번째: 인천 차이나타운 옆에서 출발해 도착
      final kr002 = _landmarks['kr002']!.latLng;
      final t3 = t2.add(const Duration(hours: 1));
      await e.svc.startJourney('kr002', LatLng(kr002.lat, kr002.lng + 0.0113), t3, useFund: false);
      e.source.records.add(_walk(t3.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.sync(t3.add(const Duration(hours: 2)));

      final arrived = await (e.db.select(e.db.journeys)
            ..where((t) => t.status.equalsValue(JourneyStatus.arrived)))
          .get();
      expect(arrived, hasLength(2));
      final s = await e.svc.snapshot(t3.add(const Duration(hours: 2)));
      expect(s.position, kr002);
    });

    test('멈춘(stopped) 여정은 위치에 쓰지 않는다', () async {
      final e = _env();
      await e.svc.sync(_t0);
      await e.svc.startJourney('kr001', _nearGyeongbok, t1);
      // 새 여정을 시작하면 앞 여정은 멈춘다. 둘 다 도착하지 않았으니 활성 여정의 출발지
      await e.svc.startJourney('kr003', rules.fallbackOrigin, t2);
      final stopped = await (e.db.select(e.db.journeys)
            ..where((t) => t.status.equalsValue(JourneyStatus.stopped)))
          .get();
      expect(stopped, hasLength(1));
      expect((await e.svc.snapshot(t2)).position, rules.fallbackOrigin);
    });
  });
}
