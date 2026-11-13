import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/rules.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 물감 길 엔진의 동기화 쪽 (M1 명세 v0.5 ①~⑤·⑦): 물감 길 기록, 거리 1종, 하루 요약 trailM, 럭, 거리 소품,
// 앱이 끝난 물감 길 닫기, 걷기 기록, 지도 물감 구간.
// 설치 KST 2026-11-18 09:00, 걷기는 그날 10:00(= _t1)부터. 보폭 걷기 0.7m

final _landmarks = {for (final l in landmarks) l.id: l};

final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

DateTime _at(int minutesAfter10) => _t1.add(Duration(minutes: minutesAfter10));

int _ms(DateTime t) => t.millisecondsSinceEpoch;

StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

double _routeKm(LatLng from, String destId) =>
    buildRoute(from, _landmarks[destId]!.latLng, rules).totalEffectiveKm;

/// 가는 거리가 60km를 넘는 육지 명소: 몇 km를 걸어서는 도착하지 않는다
final _farDest = landmarks
    .firstWhere((l) => l.island == Island.mainland && _routeKm(testHome, l.id) > 60)
    .id;

Rules _rulesWith(void Function(Map<String, dynamic> config) edit) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  edit(j);
  return Rules.fromJson(j);
}

class _Env {
  _Env({Rules? appRules, double scale = 1.0})
      : db = AppDb(NativeDatabase.memory()),
        source = FakeStepSource() {
    svc = SyncService(
      db: db,
      source: source,
      rules: appRules ?? rules,
      allowedSources: const [],
      landmarks: _landmarks,
      props: props,
      milestones: milestones,
      distanceScale: scale,
      eventCatalog: eventCatalog,
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  Future<DaySummaryRow> day([String day = '2026-11-18']) =>
      (db.select(db.daySummaries)..where((t) => t.day.equals(day))).getSingle();

  Future<List<PaintTrailRow>> trails() => db.select(db.paintTrails).get();

  Future<List<CoinLedgerRow>> earns() =>
      (db.select(db.coinLedger)..where((t) => t.kind.equalsValue(CoinKind.earn))).get();
}

/// 설치(_t0)하고 출발 동네를 골라 둔 환경
Future<_Env> _env({Rules? appRules, double scale = 1.0}) async {
  final e = _Env(appRules: appRules, scale: scale);
  addTearDown(e.db.close);
  await e.svc.sync(_t0);
  await e.svc.setHome(testHomeName, testHome);
  return e;
}

/// [_farDest]로 _t1에 출발한 환경 (경비는 안 쓴다)
Future<_Env> _journeyEnv({Rules? appRules, double scale = 1.0}) async {
  final e = await _env(appRules: appRules, scale: scale);
  await e.svc.startJourney(_farDest, _t1, useFund: false);
  return e;
}

/// [from]에 물감 길을 열고 [minutes]분 동안 분당 [spm]보를 걷고 [syncAt]에 동기화한 뒤 [to]에 idle로 닫는다
Future<int> _trailWalk(
  _Env e, {
  required DateTime from,
  required int minutes,
  required int spm,
  required DateTime syncAt,
  DateTime? to,
}) async {
  final id = await e.svc.startPaintTrail(from, from);
  e.source.records.add(_walk(from, minutes, spm));
  await e.svc.sync(syncAt);
  if (to != null) await e.svc.endPaintTrail(id, to, syncAt);
  return id;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('물감 길 기록 (②·⑦)', () {
    test('열면 첫 걸음 분의 열린 행, 닫으면 idle과 끝 시각', () async {
      final e = await _env();
      final id = await e.svc.startPaintTrail(_at(5), _at(6));
      var rows = await e.trails();
      expect(rows.single.id, id);
      expect((rows.single.startUtc, rows.single.endUtc, rows.single.endReason),
          (_ms(_at(5)), null, null));
      expect((await e.svc.openPaintTrail())?.id, id);

      await e.svc.endPaintTrail(id, _at(17), _at(22));
      rows = await e.trails();
      expect((rows.single.endUtc, rows.single.endReason), (_ms(_at(17)), PaintTrailEnd.idle));
      expect(await e.svc.openPaintTrail(), isNull);

      // 이미 닫힌 것은 다시 닫아도 그대로, 없는 번호는 아무 일 없다
      await e.svc.endPaintTrail(id, _at(40), _at(40));
      await e.svc.endPaintTrail(999, _at(40), _at(40));
      expect((await e.trails()).single.endUtc, _ms(_at(17)));
    });

    test('끝이 시작보다 앞서면 시작 시각으로 (길이 0), 시작이 지금보다 늦으면 지금으로', () async {
      final e = await _env();
      final id = await e.svc.startPaintTrail(_at(9), _at(5));
      expect((await e.trails()).single.startUtc, _ms(_at(5)));
      await e.svc.endPaintTrail(id, _at(2), _at(6));
      expect((await e.trails()).single.endUtc, _ms(_at(5)));
    });

    test('열린 채 또 열면 앞의 것을 살아 있던 시각에서 appEnded로 닫는다 (지금보다 늦지 않게)', () async {
      final e = await _env();
      await e.svc.startPaintTrail(_at(0), _at(0));
      await e.svc.saveAlive(_at(8));
      final second = await e.svc.startPaintTrail(_at(10), _at(10));
      final rows = await e.trails();
      expect((rows[0].endUtc, rows[0].endReason), (_ms(_at(8)), PaintTrailEnd.appEnded));
      expect((rows[1].id, rows[1].endUtc), (second, null));

      await e.svc.saveAlive(_at(100));
      await e.svc.startPaintTrail(_at(20), _at(20));
      expect((await e.trails())[1].endUtc, _ms(_at(20)));
    });

    test('33 끝나지 않은 물감 길 + 살아 있던 시각 10:20 → 다음 실행에서 10:20(appEnded)', () async {
      final e = await _env();
      await e.svc.startPaintTrail(_at(0), _at(0));
      await e.svc.saveAlive(_at(20));
      expect(await e.svc.closeOrphanPaintTrails(_at(60)), 1);
      final row = (await e.trails()).single;
      expect((row.endUtc, row.endReason), (_ms(_at(20)), PaintTrailEnd.appEnded));
      expect(await e.svc.closeOrphanPaintTrails(_at(61)), 0);
    });

    test('닫으면 그날 하루 요약이 다시 계산된다: 열린 동안은 지금까지 물감 길, 닫으면 10:06까지만', () async {
      final e = await _env();
      final id = await e.svc.startPaintTrail(_at(0), _at(0));
      e.source.records.add(_walk(_at(0), 12, 100));
      await e.svc.sync(_at(20));
      expect((await e.day()).trailM, closeTo(840, 1e-6));
      await e.svc.endPaintTrail(id, _at(6), _at(20));
      // 동기화 없이도 닫는 순간 다시 계산 (앞 6분 600보 × 0.7)
      expect((await e.day()).trailM, closeTo(420, 1e-6));
    });

    test('백그라운드 동기화 전: 오래 소식이 없으면 닫고, 살아 있으면 둔다', () async {
      final e = await _env();
      await e.svc.startPaintTrail(_at(0), _at(0));
      await e.svc.saveAlive(_at(59));
      const stale = Duration(seconds: 90);
      expect(await e.svc.closeStalePaintTrails(_at(60), stale), 0);
      expect((await e.trails()).single.endUtc, isNull);
      expect(await e.svc.closeStalePaintTrails(_at(70), stale), 1);
      final row = (await e.trails()).single;
      expect((row.endUtc, row.endReason), (_ms(_at(59)), PaintTrailEnd.appEnded));
    });
  });

  group('거리 1종 (①, 27·28)', () {
    test('27 물감 길 12분 × 100보 → 하루 요약 실제 840 = 여행 840, 물감 길 840, 여정 0.84km', () async {
      final e = await _journeyEnv();
      await _trailWalk(e, from: _at(0), minutes: 12, spm: 100, syncAt: _at(20), to: _at(12));
      final d = await e.day();
      expect(d.distanceM, closeTo(840, 1e-6));
      expect(d.travelM, closeTo(840, 1e-6));
      expect(d.trailM, closeTo(840, 1e-6));
      expect((await e.svc.snapshot(_at(20))).journey!.progress.progressKm, closeTo(0.84, 1e-9));
    });

    test('28 앱 밖 12분 × 100보 → 여정 0.84km·누적 거리 0.84km, 물감 길 0, 이벤트 줄 없음', () async {
      final e = await _journeyEnv();
      e.source.records.add(_walk(_at(0), 12, 100));
      await e.svc.sync(_at(20));
      final d = await e.day();
      expect(d.travelM, closeTo(840, 1e-6));
      expect(d.trailM, 0);
      final snap = await e.svc.snapshot(_at(20));
      expect(snap.journey!.progress.progressKm, closeTo(0.84, 1e-9));
      expect(snap.totalKm, closeTo(0.84, 1e-9));
      // 길 위 이벤트는 물감 길 동안 센서 거리로만 생긴다 (동기화는 만들지 않는다)
      expect(await e.db.select(e.db.journeyEvents).get(), isEmpty);
      expect((await e.db.select(e.db.journeys).get()).single.eventM, 0);
    });

    test('여정 없이 걸으면 경비도 실제 거리: 물감 길이든 아니든 0.84km, 한 번만 쌓인다', () async {
      final e = await _env();
      await _trailWalk(e, from: _at(0), minutes: 12, spm: 100, syncAt: _at(20), to: _at(12));
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(0.84, 1e-9));
      await e.svc.sync(_at(21));
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(0.84, 1e-9));
    });

    test('디버그 거리 배수는 여정 진행에만 곱한다', () async {
      final e = await _journeyEnv(scale: 10);
      await _trailWalk(e, from: _at(0), minutes: 12, spm: 100, syncAt: _at(20), to: _at(12));
      expect((await e.svc.snapshot(_at(20))).journey!.progress.progressKm, closeTo(8.4, 1e-9));
      expect((await e.day()).travelM, closeTo(840, 1e-6));
    });
  });

  group('럭 (③, 30)', () {
    test('30 물감 길 밖 2km + 안 1km → 30 + 10 = 40, 동기화 2번에도 40 (장부 한 행)', () async {
      // 거리를 딱 맞추려고 걷기 보폭을 1.0m로 둔 규칙
      final e = await _env(appRules: _rulesWith((j) => (j['gait'] as Map)['walkStrideM'] = 1.0));
      e.source.records.add(_walk(_at(0), 20, 100)); // 밖 2,000m
      final id = await e.svc.startPaintTrail(_at(30), _at(30));
      e.source.records.add(_walk(_at(30), 10, 100)); // 안 1,000m
      await e.svc.sync(_at(50));
      await e.svc.endPaintTrail(id, _at(40), _at(50));
      final d = await e.day();
      expect(d.distanceM, closeTo(3000, 1e-6));
      expect(d.trailM, closeTo(1000, 1e-6));
      expect(d.coins, 40);
      await e.svc.sync(_at(51));
      await e.svc.sync(_at(52));
      expect((await e.earns()).single.amount, 40);
    });

    test('하루 상한 400', () async {
      final e = await _env();
      final id = await e.svc.startPaintTrail(_at(0), _at(0));
      // 뛰기 150보/분 × 200분 = 30km, 전부 물감 길 → 300 + 300 → 400
      e.source.records.add(_walk(_at(0), 200, 150));
      await e.svc.sync(_at(220));
      await e.svc.endPaintTrail(id, _at(200), _at(220));
      expect((await e.day()).coins, 400);
    });
  });

  group('거리 소품 (①): 설치 뒤 모든 걸음의 실제 거리', () {
    test('앱 밖 걸음만으로 실제 10km를 넘으면 10km 소품이 열린다', () async {
      final e = await _env();
      // 뛰기 150보/분 × 67분 = 10,050m
      e.source.records.add(_walk(_at(0), 67, 150));
      await e.svc.sync(_at(80));
      final first10 = props.firstWhere((p) => p.km == 10);
      expect((await e.svc.ownedPropIds()).contains(first10.id), isTrue);
    });

    test('9.9km면 아직 안 열린다', () async {
      final e = await _env();
      e.source.records.add(_walk(_at(0), 66, 150));
      await e.svc.sync(_at(80));
      final first10 = props.firstWhere((p) => p.km == 10);
      expect((await e.svc.ownedPropIds()).contains(first10.id), isFalse);
    });
  });

  group('액자 (①, 29)', () {
    test('29 여정을 모두 걸어 도착하면 실제 거리로 금 (본격 걷기 ÷1.3 없음)', () async {
      // 경비를 넣어 60km 가까운 여정을 짧게 끝낸다: 경비 15km를 여러 번 넣을 수 없으니 거리 배수로
      final e = await _env(scale: 100);
      final dest = landmarks
          .firstWhere((l) => l.island == Island.mainland && _routeKm(testHome, l.id) > 55)
          .id;
      await e.svc.startJourney(dest, _t1, useFund: false);
      final total = _routeKm(testHome, dest);
      // 배수 100: 필요한 실제 = total / 100 km. 뛰기 1m × 150보/분
      final minutes = (total * 1000 / 100 / 150).ceil() + 1;
      e.source.records.add(_walk(_at(0), minutes, 150));
      await e.svc.sync(_at(minutes + 5));
      final p = (await e.db.select(e.db.paintingsOwned).get()).single;
      expect(p.landmarkId, dest);
      expect(p.frame, total >= 50 ? Frame.gold : Frame.silver);
    });
  });

  group('걷기 기록 (3-3)', () {
    test('물감 길 시간대의 걸음·거리와 물감 길 거리', () async {
      final e = await _env();
      await _trailWalk(e, from: _at(0), minutes: 12, spm: 100, syncAt: _at(20), to: _at(12));
      final r = await e.svc.walkRecord(_at(0), _at(12));
      expect(r.summary.steps, 1200);
      expect(r.actualM, closeTo(840, 1e-6));
      expect(r.trailM, closeTo(840, 1e-6));
    });

    test('물감 길이 아닌 시간대면 물감 길 거리 0', () async {
      final e = await _env();
      e.source.records.add(_walk(_at(0), 12, 100));
      await e.svc.sync(_at(20));
      final r = await e.svc.walkRecord(_at(0), _at(12));
      expect(r.actualM, closeTo(840, 1e-6));
      expect(r.trailM, 0);
    });

    test('노트 목록: 닫힌 물감 길만 최신순, 거리는 health 분 값', () async {
      final e = await _env();
      await _trailWalk(e, from: _at(0), minutes: 12, spm: 100, syncAt: _at(20), to: _at(12));
      await _trailWalk(e, from: _at(30), minutes: 5, spm: 100, syncAt: _at(40), to: _at(35));
      await e.svc.startPaintTrail(_at(50), _at(50));
      final list = await e.svc.paintTrails();
      expect(list.map((t) => t.start), [_at(30), _at(0)]);
      expect(list[0].trailM, closeTo(350, 1e-6));
      expect(list[1].trailM, closeTo(840, 1e-6));
    });
  });

  group('지도 물감 구간 (⑤, 35)', () {
    test('35 앱 밖 걷기 → 물감 길 걷기: 지나온 길(연필) 위에 물감 줄 하나', () async {
      final e = await _journeyEnv();
      e.source.records.add(_walk(_at(0), 30, 100)); // 밖 2.1km
      await e.svc.sync(_at(35));
      await _trailWalk(e, from: _at(40), minutes: 20, spm: 100, syncAt: _at(65), to: _at(60));
      final map = await e.svc.mapData(_at(65));
      expect(map.paths, hasLength(1));
      expect(map.paintLines, hasLength(1));
      final route = buildRoute(testHome, _landmarks[_farDest]!.latLng, rules);
      final from = positionAt(route, 2.1).latLng;
      final to = positionAt(route, 3.5).latLng;
      expect(map.paintLines.single.first.lat, closeTo(from.lat, 1e-9));
      expect(map.paintLines.single.last.lng, closeTo(to.lng, 1e-9));
    });

    test('물감 길이 없으면 물감 줄도 없다', () async {
      final e = await _journeyEnv();
      e.source.records.add(_walk(_at(0), 30, 100));
      await e.svc.sync(_at(35));
      expect((await e.svc.mapData(_at(35))).paintLines, isEmpty);
    });
  });

  group('스키마 16 다시 계산 (⑦)', () {
    test('recomputeFromDay가 있으면 다음 동기화가 그 날부터 다시 계산하고 지운다', () async {
      final e = await _env();
      e.source.records.add(_walk(_at(0), 12, 100));
      await e.svc.sync(_at(20));
      // 나흘 뒤 동기화해 두면 다음 동기화 범위(마지막 동기화 − 48시간)는 18일보다 뒤다
      final later = _t0.add(const Duration(days: 4));
      await e.svc.sync(later);
      // 옛 값처럼 망가뜨린다: 평소 동기화로는 다시 계산되지 않는다
      await (e.db.update(e.db.daySummaries)..where((t) => t.day.equals('2026-11-18')))
          .write(const DaySummariesCompanion(travelM: Value(9999), coins: Value(0)));
      await e.svc.sync(later.add(const Duration(seconds: 30)));
      expect((await e.day()).travelM, 9999);
      await (e.db.update(e.db.syncState)..where((t) => t.id.equals(1)))
          .write(const SyncStateCompanion(recomputeFromDay: Value('2026-11-18')));
      await e.svc.sync(later.add(const Duration(minutes: 1)));
      expect((await e.day()).travelM, closeTo(840, 1e-6));
      expect((await e.db.select(e.db.syncState).getSingle()).recomputeFromDay, isNull);
    });
  });
}
