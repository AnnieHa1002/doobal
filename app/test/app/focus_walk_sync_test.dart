import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/eta.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/rules.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

// 본격 걷기 엔진 (M1 명세 v0.3 4.7장): 앱 걷기 창, 이동 거리 vs 실제 거리, 보너스, 럭 장부.
// 설치 KST 2026-11-18 09:00, 걷기는 그날 10:00(= _t1)부터. 보폭 걷기 0.7m, 보너스 ×1.3

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
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  /// 시각에 따라 달라지는 값(SyncState·fundedUntilUtc)은 빼고 비교한다
  Future<Map<String, Object?>> dump() async => {
        'minutes': await db.select(db.stepMinutes).get(),
        'days': await db.select(db.daySummaries).get(),
        'sessions': await db.select(db.walkSessions).get(),
        'journeys': await db.select(db.journeys).get(),
        'paintings': await db.select(db.paintingsOwned).get(),
        'props': await db.select(db.propsOwned).get(),
        'appWalks': await db.select(db.appWalks).get(),
        // 장부 행은 다시 쓰면 번호가 바뀌니 내용만 본다
        'coins': [
          for (final c in await db.select(db.coinLedger).get()) (c.day, c.kind, c.amount, c.refId),
        ],
        'fundKm': (await db.select(db.travelFund).getSingle()).km,
      };

  Future<DaySummaryRow> day([String day = '2026-11-18']) =>
      (db.select(db.daySummaries)..where((t) => t.day.equals(day))).getSingle();

  Future<List<AppWalkRow>> appWalks() => db.select(db.appWalks).get();
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

/// 열려 있는 앱 걷기 창을 [from]에 열고 [steps]를 걷고 [syncAt]에 동기화한 뒤 [to]에 닫는다.
/// [to]가 null이면 열어 둔다
Future<void> _focusWalk(
  _Env e, {
  required DateTime from,
  required int minutes,
  required int spm,
  required DateTime syncAt,
  DateTime? to,
}) async {
  final id = await e.svc.startAppWalk(from);
  e.source.records.add(_walk(from, minutes, spm));
  await e.svc.sync(syncAt);
  if (to != null) await e.svc.finishAppWalk(id, to);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('앱 걷기 창 기록', () {
    test('열면 시작 시각의 열린 행, 닫으면 finish와 끝 시각', () async {
      final e = await _env();
      final id = await e.svc.startAppWalk(_at(5));
      var rows = await e.appWalks();
      expect(rows.single.id, id);
      expect((rows.single.startUtc, rows.single.endUtc, rows.single.endReason),
          (_ms(_at(5)), null, null));

      await e.svc.finishAppWalk(id, _at(17));
      rows = await e.appWalks();
      expect((rows.single.endUtc, rows.single.endReason), (_ms(_at(17)), AppWalkEnd.finish));

      // 이미 닫힌 창은 다시 닫아도 그대로, 없는 번호는 아무 일 없다
      await e.svc.finishAppWalk(id, _at(40));
      await e.svc.finishAppWalk(999, _at(40));
      rows = await e.appWalks();
      expect(rows, hasLength(1));
      expect(rows.single.endUtc, _ms(_at(17)));
    });

    test('닫는 시각이 시작보다 앞서면 시작 시각으로 (길이 0)', () async {
      final e = await _env();
      final id = await e.svc.startAppWalk(_at(5));
      await e.svc.finishAppWalk(id, _at(2));
      expect((await e.appWalks()).single.endUtc, _ms(_at(5)));
    });

    test('창이 열린 채 또 열면 앞 창을 appEnded로 닫는다 (살아 있던 시각에서, 지금보다 늦지 않게)', () async {
      final e = await _env();
      await e.svc.startAppWalk(_at(0));
      await e.svc.saveAlive(_at(8));
      final second = await e.svc.startAppWalk(_at(10));
      final rows = await e.appWalks();
      expect(rows, hasLength(2));
      expect((rows[0].endUtc, rows[0].endReason), (_ms(_at(8)), AppWalkEnd.appEnded));
      expect((rows[1].id, rows[1].endUtc), (second, null));

      // 살아 있던 시각이 지금보다 앞서지 않는 경우(시계가 거꾸로 감)도 지금보다 늦게 닫지 않는다
      await e.svc.saveAlive(_at(100));
      await e.svc.startAppWalk(_at(20));
      expect((await e.appWalks())[1].endUtc, _ms(_at(20)));
    });

    test('saveAlive: 동기화 상태에 마지막으로 살아 있던 시각을 적고 덮어쓴다', () async {
      final e = _Env();
      addTearDown(e.db.close);
      // 동기화한 적이 없어도(행이 없어도) 쓸 수 있다
      await e.svc.saveAlive(_at(1));
      var state = await e.db.select(e.db.syncState).getSingle();
      expect(state.lastAliveUtc, _ms(_at(1)));
      await e.svc.saveAlive(_at(2));
      state = await e.db.select(e.db.syncState).getSingle();
      expect(state.lastAliveUtc, _ms(_at(2)));
      // 동기화는 이 값을 건드리지 않는다
      await e.svc.sync(_at(3));
      expect((await e.db.select(e.db.syncState).getSingle()).lastAliveUtc, _ms(_at(2)));
    });
  });

  group('끝나지 않은 앱 걷기 닫기 (35)', () {
    test('35: 열린 창 + 마지막으로 살아 있던 시각 10:20 → 다음 실행에서 10:20에 appEnded로 닫는다', () async {
      final e = await _env();
      await e.svc.startAppWalk(_at(0));
      await e.svc.saveAlive(_at(20));

      expect(await e.svc.closeOrphanAppWalks(_at(60)), 1);
      final row = (await e.appWalks()).single;
      expect((row.endUtc, row.endReason), (_ms(_at(20)), AppWalkEnd.appEnded));
      // 다시 불러도 닫을 게 없다
      expect(await e.svc.closeOrphanAppWalks(_at(61)), 0);
    });

    test('마지막으로 살아 있던 시각이 시작보다 앞서거나 없으면 시작 시각에 닫는다 (길이 0)', () async {
      final older = await _env();
      await older.svc.saveAlive(_at(-30));
      await older.svc.startAppWalk(_at(0));
      await older.svc.closeOrphanAppWalks(_at(60));
      expect((await older.appWalks()).single.endUtc, _ms(_at(0)));

      final none = await _env();
      await none.svc.startAppWalk(_at(0));
      await none.svc.closeOrphanAppWalks(_at(60));
      final row = (await none.appWalks()).single;
      expect((row.endUtc, row.endReason), (_ms(_at(0)), AppWalkEnd.appEnded));
    });

    test('닫은 창 만큼 그날의 하루 요약이 다시 계산된다: 열려 있을 땐 지금까지, 닫으면 10:20까지만 보너스', () async {
      final e = await _env();
      await e.svc.startAppWalk(_at(0));
      e.source.records.add(_walk(_at(0), 40, 100));
      await e.svc.sync(_at(45));
      // 창이 열려 있으니 40분 전부: 4,000보 × 0.7 × 0.3
      expect((await e.day()).bonusM, closeTo(840, 1e-9));

      await e.svc.saveAlive(_at(20));
      await e.svc.closeOrphanAppWalks(_at(60));
      final day = await e.day();
      // 20분 × 100보 × 0.7 × 0.3
      expect(day.bonusM, closeTo(420, 1e-9));
      expect(day.distanceM, closeTo(2800, 1e-9));
      expect(day.travelM, closeTo(3220, 1e-9));
      expect((await e.db.select(e.db.walkSessions).getSingle()).bonusM, closeTo(420, 1e-9));
    });

    test('열린 창이 없으면 아무것도 건드리지 않는다 (동기화 상태 행도 안 만든다)', () async {
      final e = _Env();
      addTearDown(e.db.close);
      expect(await e.svc.closeOrphanAppWalks(_at(0)), 0);
      expect(await e.db.select(e.db.syncState).get(), isEmpty);
    });
  });

  group('보너스와 이동 거리 (27~29, 33, 34)', () {
    test('27: 창 안 12분 × 100보 → 하루 요약 실제 840 · 보너스 252 · 이동 1,092, 여정 진행 1.092km', () async {
      final e = await _journeyEnv();
      await _focusWalk(e, from: _at(5), minutes: 12, spm: 100, syncAt: _at(30), to: _at(17));

      final day = await e.day();
      expect(day.steps, 1200);
      expect(day.distanceM, closeTo(840, 1e-9));
      expect(day.bonusM, closeTo(252, 1e-9));
      expect(day.shopM, 0);
      expect(day.travelM, closeTo(1092, 1e-9));
      expect(day.walkTravelM, closeTo(1092, 1e-9));
      expect(day.coins, 16);
      final session = await e.db.select(e.db.walkSessions).getSingle();
      expect(session.qualified, isTrue);
      expect(session.distanceM, closeTo(840, 1e-9));
      expect(session.bonusM, closeTo(252, 1e-9));

      final snap = await e.svc.snapshot(_at(30));
      expect(snap.journey!.progress.progressKm, closeTo(1.092, 1e-9));
      expect(snap.todayDistanceM, closeTo(840, 1e-9));
      expect(snap.totalKm, closeTo(0.84, 1e-9));
      expect(snap.walkTravelKm, closeTo(1.092, 1e-9));
      // 실제 0.84km가 모두 보너스 분이라 8.4 × 2배 = 16럭 (config perKm 10)
      expect((await e.db.select(e.db.coinLedger).getSingle()).amount, 16);
    });

    test('33: 창이 없으면 같은 걸음도 보너스 0 · 앱 걷기 이동 거리 0, 진행은 실제 0.84km', () async {
      final e = await _journeyEnv();
      e.source.records.add(_walk(_at(5), 12, 100));
      await e.svc.sync(_at(30));

      final day = await e.day();
      expect(day.distanceM, closeTo(840, 1e-9));
      expect((day.bonusM, day.walkTravelM), (0, 0));
      expect(day.travelM, closeTo(840, 1e-9));
      expect((await e.svc.snapshot(_at(30))).journey!.progress.progressKm, closeTo(0.84, 1e-9));
    });

    test('28: 창 안 9분 × 150보는 걷기 1번이 아니라 보너스 0 (뛰기 1.0m → 1,350m)', () async {
      final e = await _journeyEnv();
      await _focusWalk(e, from: _at(5), minutes: 9, spm: 150, syncAt: _at(30), to: _at(14));

      final day = await e.day();
      expect(day.distanceM, closeTo(1350, 1e-9));
      expect(day.bonusM, 0);
      expect(day.travelM, closeTo(1350, 1e-9));
      // 인정은 못 받아도 창 안에서 걸은 거리는 앱 걷기 이동 거리다
      expect(day.walkTravelM, closeTo(1350, 1e-9));
      expect((await e.svc.snapshot(_at(30))).journey!.progress.progressKm, closeTo(1.35, 1e-9));
    });

    test('34: 창 10:00~10:06이 10:00~10:12 걷기에 걸치면 앞 6분만 보너스 126m', () async {
      final e = await _journeyEnv();
      await _focusWalk(e, from: _at(0), minutes: 12, spm: 100, syncAt: _at(30), to: _at(6));

      final day = await e.day();
      expect(day.distanceM, closeTo(840, 1e-9));
      expect(day.bonusM, closeTo(126, 1e-9));
      expect(day.travelM, closeTo(966, 1e-9));
      expect((await e.db.select(e.db.walkSessions).getSingle()).bonusM, closeTo(126, 1e-9));
      expect((await e.svc.snapshot(_at(30))).journey!.progress.progressKm, closeTo(0.966, 1e-9));
    });

    test('29: 하루 4번째 인정 걷기(counted false)도 창 안이면 보너스를 받는다', () async {
      final e = await _journeyEnv();
      final id = await e.svc.startAppWalk(_at(0));
      // 10분 × 100보(1,000보) 걷기 4번, 사이는 5분씩 비어서 서로 다른 구간
      for (var i = 0; i < 4; i++) {
        e.source.records.add(_walk(_at(i * 15), 10, 100));
      }
      await e.svc.sync(_at(90));
      await e.svc.finishAppWalk(id, _at(80));

      final day = await e.day();
      expect(day.countedSessions, 3);
      expect(day.bonusM, closeTo(4 * 210, 1e-9));
      final sessions = await (e.db.select(e.db.walkSessions)
            ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
          .get();
      expect(sessions.map((s) => s.counted), [true, true, true, false]);
      expect(sessions.map((s) => s.qualified), [true, true, true, true]);
      expect(sessions.map((s) => s.bonusM), everyElement(closeTo(210, 1e-9)));
    });

    test('소급: 인정 전엔 보너스가 없다가 10분·1,000보를 채우면 첫 분부터 붙는다', () async {
      final e = await _journeyEnv();
      await e.svc.startAppWalk(_at(0));
      e.source.records.add(_walk(_at(0), 8, 100));
      await e.svc.sync(_at(9));
      expect((await e.day()).bonusM, 0);
      expect((await e.svc.snapshot(_at(9))).journey!.progress.progressKm, closeTo(0.56, 1e-9));

      e.source.records.add(_walk(_at(8), 4, 100));
      await e.svc.sync(_at(13));
      // 12분 걷기로 인정: 8분 전에 이미 센 분도 보너스를 받는다
      final day = await e.day();
      expect(day.bonusM, closeTo(252, 1e-9));
      expect(day.travelM, closeTo(1092, 1e-9));
      expect((await e.svc.snapshot(_at(13))).journey!.progress.progressKm, closeTo(1.092, 1e-9));
    });

    test('멱등: 같은 걸음·같은 창으로 몇 번을 다시 동기화해도 결과가 같다', () async {
      final once = await _journeyEnv();
      final twice = await _journeyEnv();
      for (final e in [once, twice]) {
        await _focusWalk(e, from: _at(5), minutes: 12, spm: 100, syncAt: _at(30), to: _at(17));
      }
      await twice.svc.sync(_at(30));
      await twice.svc.sync(_at(50));
      expect(await twice.dump(), await once.dump());
      expect((await twice.svc.sync(_at(60))).advancedKm, 0);
    });

    test('창이 바뀌면 동기화 없이도 그날이 다시 계산된다 (닫기 전·후)', () async {
      final e = await _journeyEnv();
      e.source.records.add(_walk(_at(0), 12, 100));
      await e.svc.sync(_at(30));
      expect((await e.day()).bonusM, 0);

      // 동기화한 뒤에 창을 (지난 시각으로) 열고 닫는다: 하루 요약이 곧바로 바뀐다
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.finishAppWalk(id, _at(12));
      expect((await e.day()).bonusM, closeTo(252, 1e-9));
    });

    test('창 밖에서 걸은 걷기는 인정돼도 보너스가 없다 (앱을 안 연 걸음)', () async {
      final e = await _journeyEnv();
      // 창은 10:30~10:40, 걷기는 10:00~10:12
      await _focusWalk(e, from: _at(30), minutes: 1, spm: 0, syncAt: _at(45), to: _at(40));
      e.source.records.add(_walk(_at(0), 12, 100));
      await e.svc.sync(_at(50));
      final day = await e.day();
      expect(day.bonusM, 0);
      expect(day.walkTravelM, 0);
      expect(day.travelM, closeTo(840, 1e-9));
    });
  });

  group('거리 소품은 앱 걷기 이동 거리로 (walkTravelM 누적)', () {
    test('앱 없이 걸은 11.2km는 소품이 안 열리고, 창 안에서 걸으면 열린다', () async {
      final noApp = await _env();
      noApp.source.records.add(_walk(_at(0), 160, 100));
      await noApp.svc.sync(_at(200));
      expect((await noApp.svc.snapshot(_at(200))).totalKm, closeTo(11.2, 1e-9));
      expect(await noApp.svc.ownedPropIds(), isNot(contains('hand_02')));

      final app = await _env();
      await _focusWalk(app, from: _at(0), minutes: 160, spm: 100, syncAt: _at(200), to: _at(160));
      expect(await app.svc.ownedPropIds(), contains('hand_02'));
    });

    test('실제 7.7km도 보너스 ×1.3이 붙어 앱 걷기 이동 거리 10.01km면 10km 소품이 열린다', () async {
      final e = await _env();
      await _focusWalk(e, from: _at(0), minutes: 110, spm: 100, syncAt: _at(150), to: _at(110));
      final snap = await e.svc.snapshot(_at(150));
      expect(snap.totalKm, closeTo(7.7, 1e-9));
      expect(snap.walkTravelKm, closeTo(10.01, 1e-9));
      expect(await e.svc.ownedPropIds(), contains('hand_02'));
    });

    test('9.1km짜리(실제 7km)는 아직 안 열린다', () async {
      final e = await _env();
      await _focusWalk(e, from: _at(0), minutes: 100, spm: 100, syncAt: _at(150), to: _at(100));
      expect((await e.svc.snapshot(_at(150))).walkTravelKm, closeTo(9.1, 1e-9));
      expect(await e.svc.ownedPropIds(), isNot(contains('hand_02')));
    });
  });

  group('여정 없이 걸으면 경비도 이동 거리로', () {
    test('창 안 12분 × 100보 → 경비 1.092km (창 없이는 0.84km), 한 번만 쌓인다', () async {
      final focus = await _env();
      final plain = await _env();
      await _focusWalk(focus, from: _at(0), minutes: 12, spm: 100, syncAt: _at(60), to: _at(12));
      plain.source.records.add(_walk(_at(0), 12, 100));
      await plain.svc.sync(_at(60));

      expect((await focus.svc.snapshot(_at(60))).fundKm, closeTo(1.092, 1e-9));
      expect((await plain.svc.snapshot(_at(60))).fundKm, closeTo(0.84, 1e-9));
      // 또 동기화해도 같다
      await focus.svc.sync(_at(90));
      expect((await focus.svc.snapshot(_at(90))).fundKm, closeTo(1.092, 1e-9));
    });
  });

  group('도착 예정일은 이동 거리 평균 (32)', () {
    test('32: 전날 보너스가 붙은 거리(1.092km)로 하루 평균을 낸다', () async {
      final e = await _journeyEnv();
      await _focusWalk(e, from: _at(5), minutes: 12, spm: 100, syncAt: _at(30), to: _at(17));
      // 다음 날 낮 (KST 11/19 10:00)
      final next = _t1.add(const Duration(days: 1));
      final snap = await e.svc.snapshot(next);
      final remaining = snap.journey!.progress.remainingKm;

      final byTravel = etaDate(remaining, {'2026-11-18': 1.092}, '2026-11-19', '2026-11-18', rules);
      final byActual = etaDate(remaining, {'2026-11-18': 0.84}, '2026-11-19', '2026-11-18', rules);
      expect(snap.journey!.eta, byTravel);
      expect(byTravel.isBefore(byActual), isTrue);
      // 미리 보기도 같은 평균
      final preview = await e.svc.preview(_farDest, next);
      expect(preview.etaDays, greaterThan(0));
    });
  });

  group('액자는 실제 거리로 (30)', () {
    /// 출발 동네에서 환산 거리가 [min, max]km인 육지 명소
    Landmark? destBetween(double min, double max) => landmarks
        .where((l) =>
            l.island == Island.mainland &&
            _routeKm(testHome, l.id) >= min &&
            _routeKm(testHome, l.id) <= max)
        .firstOrNull;

    test('30: 거의 60km 여정을 전부 본격 걷기로 걸어 도착하면 실제는 ÷1.3이라 은 액자 (앱 없이는 금)', () async {
      final dest = destBetween(52, 64);
      expect(dest, isNotNull, reason: '출발 동네에서 52~64km인 육지 명소');
      final total = _routeKm(testHome, dest!.id);
      // 130보/분(걷기) = 분당 91m. 이동 거리 = 실제 × 1.3이 total에 닿는 분 수
      final focusMinutes = (total * 1000 / 1.3 / (130 * 0.7)).ceil() + 2;
      final plainMinutes = (total * 1000 / (130 * 0.7)).ceil() + 2;

      final focus = await _env();
      await focus.svc.startJourney(dest.id, _t1, useFund: false);
      await _focusWalk(focus,
          from: _at(1), minutes: focusMinutes, spm: 130, syncAt: _at(focusMinutes + 60));
      final paintings = await focus.db.select(focus.db.paintingsOwned).get();
      expect(paintings.single.landmarkId, dest.id);
      expect(paintings.single.frame, Frame.silver);
      expect(paintings.single.bestKm, closeTo(total, 1e-9));
      // 실제로 걸은 거리 < 50km, 이동 거리는 total 이상
      final snap = await focus.svc.snapshot(_at(focusMinutes + 60));
      expect(snap.totalKm, lessThan(rules.frameGoldKm));
      expect(snap.pendingArrival!.newFrame, Frame.silver);

      final plain = await _env();
      await plain.svc.startJourney(dest.id, _t1, useFund: false);
      plain.source.records.add(_walk(_at(1), plainMinutes, 130));
      await plain.svc.sync(_at(plainMinutes + 60));
      expect((await plain.db.select(plain.db.paintingsOwned).get()).single.frame, Frame.gold);
    });

    test('같은 걸음이면 앱 걷기로 더 빨리 도착한다 (거의 같은 시간대의 진행이 1.3배)', () async {
      final focus = await _journeyEnv();
      final plain = await _journeyEnv();
      await _focusWalk(focus, from: _at(1), minutes: 100, spm: 100, syncAt: _at(120));
      plain.source.records.add(_walk(_at(1), 100, 100));
      await plain.svc.sync(_at(120));
      final a = (await focus.svc.snapshot(_at(120))).journey!.progress.progressKm;
      final b = (await plain.svc.snapshot(_at(120))).journey!.progress.progressKm;
      expect(b, closeTo(7.0, 1e-9));
      expect(a, closeTo(9.1, 1e-9));
    });

    test('이미 도착한 여정은 건강 앱 값이나 창이 줄어도 되돌아가지 않는다', () async {
      final e = await _env();
      await placeAt(e.db, const LatLng(37.57761, 126.9769 + 0.0113), _t0);
      await e.svc.startJourney('kr001', _t1, useFund: false);
      final id = await e.svc.startAppWalk(_at(1));
      e.source.records.add(_walk(_at(1), 30, 100));
      await e.svc.sync(_at(60));
      await e.svc.finishAppWalk(id, _at(31));
      final journey = (await e.db.select(e.db.journeys).get())
          .firstWhere((j) => j.status == JourneyStatus.arrived);
      expect(await e.db.select(e.db.paintingsOwned).get(), hasLength(1));

      // 창을 거의 없애고(길이 1분) 건강 기록도 줄여서 다시 동기화한다
      await (e.db.update(e.db.appWalks)..where((t) => t.id.equals(id)))
          .write(AppWalksCompanion(endUtc: Value(_ms(_at(2)))));
      e.source.records
        ..clear()
        ..add(_walk(_at(1), 3, 100));
      await e.svc.sync(_at(90));
      final after = await (e.db.select(e.db.journeys)..where((t) => t.id.equals(journey.id)))
          .getSingle();
      expect(after.status, JourneyStatus.arrived);
      expect(await e.db.select(e.db.paintingsOwned).get(), hasLength(1));
    });
  });

  group('디버그 거리 배수는 이동 거리에 곱한다', () {
    test('창 안 12분이면 진행 = 1.092km × 10, 하루 요약은 그대로', () async {
      final e = await _journeyEnv(scale: 10);
      await _focusWalk(e, from: _at(5), minutes: 12, spm: 100, syncAt: _at(30), to: _at(17));
      final snap = await e.svc.snapshot(_at(30));
      expect(snap.journey!.progress.progressKm, closeTo(10.92, 1e-9));
      final day = await e.day();
      expect(day.travelM, closeTo(1092, 1e-9));
      expect(day.distanceM, closeTo(840, 1e-9));
    });
  });

  group('럭 (31)', () {
    final r10 = _rulesWith((j) => (j['coins'] as Map)['perKm'] = 10);

    test('31: 럭 단가 10: 보너스 밖 실제 2km + 보너스 분 실제 1km → 40, 다시 동기화해도 40 (장부 한 행)', () async {
      final e = await _env(appRules: r10);
      // 15분 × 200보(뛰기 1.0m) = 3km. 10~15분 5분(1km)이 창 안
      e.source.records.add(_walk(_at(0), 15, 200));
      await e.svc.sync(_at(60));
      // 창이 없으면 3km × 10 = 30
      expect((await e.day()).coins, 30);
      expect((await e.db.select(e.db.coinLedger).getSingle()).amount, 30);

      // 창을 (지난 시각으로) 열고 닫으면 곧바로 다시 계산된다
      final id = await e.svc.startAppWalk(_at(10));
      await e.svc.finishAppWalk(id, _at(15));
      var day = await e.day();
      expect(day.distanceM, closeTo(3000, 1e-9));
      expect(day.bonusM, closeTo(300, 1e-9));
      expect(day.coins, 40);
      var ledger = await e.db.select(e.db.coinLedger).get();
      expect(ledger, hasLength(1));
      expect((ledger.single.day, ledger.single.kind, ledger.single.amount, ledger.single.refId),
          ('2026-11-18', CoinKind.earn, 40, null));

      // 같은 걸음으로 또 동기화해도 40, 장부도 한 행
      await e.svc.sync(_at(90));
      await e.svc.sync(_at(120));
      day = await e.day();
      ledger = await e.db.select(e.db.coinLedger).get();
      expect((day.coins, ledger.length, ledger.single.amount), (40, 1, 40));
    });

    test('광고·씀 행은 다시 계산해도 그대로고, 번 행만 하루에 하나씩 다시 쓴다', () async {
      final e = await _env(appRules: r10);
      await e.db.batch((b) => b.insertAll(e.db.coinLedger, [
            CoinLedgerCompanion.insert(
                day: '2026-11-18', kind: CoinKind.ad, amount: 5, refId: const Value('ad-1')),
            CoinLedgerCompanion.insert(
                day: '2026-11-18', kind: CoinKind.spend, amount: 3, refId: const Value('shop-1')),
          ]));
      e.source.records.add(_walk(_at(0), 15, 200));
      await e.svc.sync(_at(60));
      await e.svc.sync(_at(90));

      final rows = await e.db.select(e.db.coinLedger).get();
      expect(rows.map((r) => (r.kind, r.amount, r.refId)), unorderedEquals([
        (CoinKind.ad, 5, 'ad-1'),
        (CoinKind.spend, 3, 'shop-1'),
        (CoinKind.earn, 30, null),
      ]));
    });

    test('걷지 않은 날은 장부 행이 없고, 걸음이 줄면 번 행도 따라 줄어든다', () async {
      final e = await _env(appRules: r10);
      e.source.records.add(_walk(_at(0), 15, 200));
      await e.svc.sync(_at(60));
      expect(await e.db.select(e.db.coinLedger).get(), hasLength(1));

      // 건강 앱 기록이 사라져서 그날 걸음이 0이 되면 번 행이 없어진다
      e.source.records.clear();
      await e.svc.sync(_at(90));
      expect((await e.day()).coins, 0);
      expect(await e.db.select(e.db.coinLedger).get(), isEmpty);
    });

    test('럭 단가가 null이면 걸어도 럭 0, 장부 행 없음', () async {
      final e = await _env(appRules: _rulesWith((j) => (j['coins'] as Map)['perKm'] = null));
      await _focusWalk(e, from: _at(0), minutes: 15, spm: 200, syncAt: _at(60), to: _at(15));
      expect((await e.day()).coins, 0);
      expect(await e.db.select(e.db.coinLedger).get(), isEmpty);
    });
  });

  group('walkRecord: 이번 걷기의 실제·보너스·이동 거리', () {
    test('창 안 12분이면 보너스 252, 이동 1,092, 창이 없으면 보너스 0', () async {
      final e = await _env();
      await _focusWalk(e, from: _at(5), minutes: 12, spm: 100, syncAt: _at(30), to: _at(17));
      final r = await e.svc.walkRecord(_at(5), _at(17));
      expect(r.actualM, closeTo(840, 1e-9));
      expect(r.bonusM, closeTo(252, 1e-9));
      expect(r.travelM, closeTo(1092, 1e-9));
      expect(r.summary.distanceM, closeTo(840, 1e-9));

      // 창 밖 구간만 보면 보너스 없음
      final outside = await e.svc.walkRecord(_at(20), _at(30));
      expect((outside.actualM, outside.bonusM, outside.travelM), (0, 0, 0));
    });

    test('창이 열려 있는 동안(걷는 중)도 지금까지로 센다', () async {
      final e = await _env();
      await e.svc.startAppWalk(_at(5));
      e.source.records.add(_walk(_at(5), 12, 100));
      await e.svc.sync(_at(17));
      final r = await e.svc.walkRecord(_at(5), _at(17));
      expect(r.bonusM, closeTo(252, 1e-9));
    });

    test('아직 인정 전(9분)이면 보너스 0, 창 없이 걸었어도 0', () async {
      final e = await _env();
      await _focusWalk(e, from: _at(5), minutes: 9, spm: 100, syncAt: _at(30), to: _at(14));
      expect((await e.svc.walkRecord(_at(5), _at(14))).bonusM, 0);

      final plain = await _env();
      plain.source.records.add(_walk(_at(5), 12, 100));
      await plain.svc.sync(_at(30));
      final r = await plain.svc.walkRecord(_at(5), _at(17));
      expect(r.bonusM, 0);
      expect(r.travelM, closeTo(840, 1e-9));
    });

    test('센서(live) 걸음이 더 많아 센서 값을 쓰면 보너스도 센서 걸음으로 가린다', () async {
      final e = await _env();
      await e.svc.startAppWalk(_at(5));
      // health 기록은 아직 없고, 센서가 12분 × 100보를 셌다
      final first = _at(5).millisecondsSinceEpoch ~/ 60000;
      final live = [for (var i = 0; i < 12; i++) GaitMinute(first + i, 100, Gait.walk)];
      final r = await e.svc.walkRecord(_at(5), _at(17), live: live);
      expect(r.actualM, closeTo(840, 1e-9));
      expect(r.bonusM, closeTo(252, 1e-9));
      expect(r.travelM, closeTo(1092, 1e-9));
    });
  });
}
