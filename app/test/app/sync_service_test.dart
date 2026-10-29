import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/route.dart';
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
}
