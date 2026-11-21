import 'package:doobal/app/backup_service.dart';
import 'package:doobal/app/paint_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/day_card.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/trail_pattern.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// T17b 물감 길 무늬 (16장 11/19·11/20, config paintPattern): 구간마다 무늬 저장(고르면 그 순간부터, 색이 바뀌어도
// 무늬는 그대로), 배낭 무늬 줄(가진 것만·0개면 기본 방울 1칸·새 표시), 거리 보상(10·50·100km, 이미 산 무늬 건너뜀,
// 셋 다면 100 럭 gift), 백업 복원 뒤 같은 결과, 지도·엽서 구간 무늬.
// 설치 KST 2026-11-18 09:00, 걷기는 그날 10:00(= _t1)부터. 보폭 걷기 0.7m (분당 100보 = 70m)

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

/// 가는 거리가 60km를 넘는 육지 명소 (걸어서는 도착하지 않는다)
final _farDest = landmarks
    .firstWhere((l) => l.island == Island.mainland && _routeKm(testHome, l.id) > 60)
    .id;

class _Env {
  _Env() : db = AppDb(NativeDatabase.memory()), source = FakeStepSource() {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _landmarks,
      props: props,
      milestones: milestones,
      trailCatalog: trailCatalog,
    );
    paint = PaintService(db, rules, trails: trailCatalog);
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;
  late final PaintService paint;

  Future<List<PatternOwnedRow>> owned() =>
      (db.select(db.patternsOwned)..orderBy([(t) => OrderingTerm(expression: t.patternId)])).get();

  Future<List<CoinLedgerRow>> gifts() =>
      (db.select(db.coinLedger)..where((t) => t.kind.equalsValue(CoinKind.gift))).get();

  /// 물감 길 [id]의 구간 (시작 ms, 색, 무늬)
  Future<List<(int, String, String?)>> segs(int id) async => [
        for (final r in await (db.select(db.paintTrailColors)
              ..where((t) => t.trailId.equals(id))
              ..orderBy([(t) => OrderingTerm(expression: t.fromUtc)]))
            .get())
          (r.fromUtc, r.colorId, r.patternId),
      ];

  /// 상점에서 산 것처럼 무늬를 가진다 (rewardKm null, 수레 T16 buyCartSlot과 같은 줄)
  Future<void> buy(String id) =>
      db.into(db.patternsOwned).insert(PatternsOwnedCompanion.insert(patternId: id, gotUtc: 0));

  /// 지난 날 하루 요약 (물감 길 [trailKm]만큼, 동기화가 다시 계산하지 않는 설치 전 날)
  Future<void> pastTrail(String day, double trailKm) => db.into(db.daySummaries).insert(
        DaySummariesCompanion.insert(
          day: day,
          steps: 0,
          distanceM: trailKm * 1000,
          countedSessions: 0,
          trailM: Value(trailKm * 1000),
        ),
      );
}

Future<_Env> _env() async {
  final e = _Env();
  addTearDown(e.db.close);
  await e.svc.sync(_t0);
  await e.svc.setHome(testHomeName, testHome);
  return e;
}

/// [from]에 물감 길을 열고 [minutes]분 동안 분당 100보를 걷고 [syncAt]에 동기화한 뒤 [to]에 닫는다
Future<int> _trailWalk(_Env e,
    {required DateTime from, required int minutes, required DateTime syncAt, DateTime? to}) async {
  final id = await e.svc.startPaintTrail(from, from);
  e.source.records.add(_walk(from, minutes, 100));
  await e.svc.sync(syncAt);
  if (to != null) await e.svc.endPaintTrail(id, to, syncAt);
  return id;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('구간마다 무늬 (paintPattern.segmentKey patternId)', () {
    test('고르기: 기본 방울은 늘 되고(null로 저장), 안 가진 무늬·모르는 id는 안 된다', () async {
      final e = await _env();
      expect(await e.paint.currentPattern(), isNull);
      expect(await e.paint.choosePattern('trail_01'), isFalse);
      expect(await e.paint.choosePattern('stars'), isFalse);
      await e.buy('trail_01');
      expect(await e.paint.choosePattern('trail_01'), isTrue);
      expect(await e.paint.currentPattern(), 'trail_01');
      expect(await e.paint.choosePattern('drops'), isTrue);
      expect(await e.paint.currentPattern(), isNull);
      final profile = await (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle();
      expect(profile.paintPatternId, isNull);
    });

    test('물감 길을 열면 그때 무늬가 첫 구간, 걷는 중에 바꾸면 그 순간부터 새 구간(색 그대로), 칠한 구간은 그대로',
        () async {
      final e = await _env();
      await e.buy('trail_01');
      await e.buy('trail_02');
      await e.paint.choosePattern('trail_01');
      final id = await e.svc.startPaintTrail(_at(0), _at(0));
      await e.paint.beginTrail(id);
      expect(await e.segs(id), [(_ms(_at(0)), 'basic', 'trail_01')]);

      await e.paint.choosePattern('trail_02', openTrailId: id, now: _at(10));
      expect(await e.segs(id), [
        (_ms(_at(0)), 'basic', 'trail_01'),
        (_ms(_at(10)), 'basic', 'trail_02'),
      ]);
      // 같은 무늬를 다시 고르면 그대로, 기본으로 바꾸면 null 구간
      await e.paint.choosePattern('trail_02', openTrailId: id, now: _at(12));
      await e.paint.choosePattern('drops', openTrailId: id, now: _at(15));
      expect((await e.segs(id)).map((s) => s.$3), ['trail_01', 'trail_02', null]);
      expect(await e.paint.trailPattern(id), isNull);

      // 닫힌 물감 길은 바뀌지 않는다 (프로필만)
      await e.svc.endPaintTrail(id, _at(20), _at(20));
      await e.paint.choosePattern('trail_01', openTrailId: id, now: _at(25));
      expect(await e.segs(id), hasLength(3));
      expect(await e.paint.currentPattern(), 'trail_01');
    });

    test('색을 바꾸거나 고른 색을 다 써도 무늬는 이어진다', () async {
      final e = await _env();
      await e.buy('trail_03');
      await e.db.into(e.db.paintStock).insert(PaintStockCompanion.insert(
          colorId: 'autumn.sunset', tubes: 1, remainM: 100, firstGotAt: 0, lastGotAt: 0));
      await e.paint.choosePattern('trail_03');
      final id = await e.svc.startPaintTrail(_at(0), _at(0));
      await e.paint.beginTrail(id);
      await e.paint.choose('autumn.sunset', openTrailId: id, now: _at(5));
      // 노을 100m를 다 쓰면 그 순간부터 기본 물감, 무늬는 별가루 그대로
      await e.paint.addPaint(trailId: id, fromM: 0, toM: 150, now: _at(8), momentColor: 'basic');
      expect(await e.segs(id), [
        (_ms(_at(0)), 'basic', 'trail_03'),
        (_ms(_at(5)), 'autumn.sunset', 'trail_03'),
        (_ms(_at(8)), 'basic', 'trail_03'),
      ]);
    });

    test('스키마 21 전 구간(무늬 null)·고른 뒤 잃은 무늬는 기본 방울', () async {
      final e = await _env();
      await e.buy('trail_01');
      await e.paint.choosePattern('trail_01');
      // 백업 복원 등으로 가진 줄이 없어진 무늬를 고른 채면 기본
      await e.db.delete(e.db.patternsOwned).go();
      expect(await e.paint.currentPattern(), isNull);
      final id = await e.svc.startPaintTrail(_at(0), _at(0));
      await e.paint.beginTrail(id);
      expect((await e.segs(id)).single.$3, isNull);
    });
  });

  group('배낭 무늬 줄 (paintPattern.choose ownedOnly·emptyRow·states)', () {
    test('무늬가 없으면 기본 방울 1칸, 가진 것만 표 차례로, 지금 무늬, 새 표시와 지우기', () async {
      final e = await _env();
      var shelf = await e.paint.shelf();
      expect(shelf.patterns.map((c) => c.id), ['drops']);
      expect(shelf.patterns.single.isDefault, isTrue);
      expect(shelf.currentPattern, 'drops');

      // 별가루를 먼저 사고 발자국을 거리로 얻어도 표 차례(방울·발자국·별가루), 꽃잎은 안 보인다
      await e.buy('trail_03');
      await e.db.into(e.db.patternsOwned).insert(
          PatternsOwnedCompanion.insert(patternId: 'trail_01', gotUtc: 1, rewardKm: const Value(10)));
      shelf = await e.paint.shelf();
      expect(shelf.patterns.map((c) => c.id), ['drops', 'trail_01', 'trail_03']);
      expect(shelf.patterns.map((c) => c.seen), [true, false, false]);
      expect(await e.paint.unseenPatterns(), 2);
      // 새로 얻어도 저절로 안 고른다 (config autoSelectOnGain false)
      expect(shelf.currentPattern, 'drops');

      await e.paint.markSeen();
      expect(await e.paint.unseenPatterns(), 0);
      await e.paint.choosePattern('trail_03');
      shelf = await e.paint.shelf();
      expect(shelf.patterns.every((c) => c.seen), isTrue);
      expect(shelf.currentPattern, 'trail_03');
    });

    test('무늬 목록이 없으면 무늬 줄도 없다', () async {
      final e = await _env();
      final shelf = await PaintService(e.db, rules).shelf();
      expect(shelf.patterns, isEmpty);
      expect(shelf.currentPattern, isNull);
    });
  });

  group('거리 보상 (paintPattern.reward, 물감 길 누적 실제 거리)', () {
    test('10km에 닿으면 발자국(rewardKm 10, 새 표시)을 받고 흘려보낸다, 다시 동기화해도 한 번', () async {
      final e = await _env();
      final got = <List<PatternReward>>[];
      final sub = e.svc.newPatternRewards.listen(got.add);
      addTearDown(sub.cancel);
      // 140분 × 70m = 9.8km: 아직
      await _trailWalk(e, from: _at(0), minutes: 140, syncAt: _at(141));
      expect(await e.owned(), isEmpty);
      expect(await e.svc.paintTrailKm(), closeTo(9.8, 1e-9));
      // 150분 = 10.5km
      e.source.records
        ..clear()
        ..add(_walk(_at(0), 150, 100));
      await e.svc.sync(_at(151));
      final rows = await e.owned();
      expect(rows.map((r) => (r.patternId, r.rewardKm, r.seen)), [('trail_01', 10, false)]);
      await pumpEventQueue();
      expect(got, [
        [const PatternReward.pattern(10, 'trail_01')],
      ]);
      await e.svc.sync(_at(160));
      expect(await e.owned(), hasLength(1));
      await pumpEventQueue();
      expect(got, hasLength(1));
    });

    test('물감 길 밖 걸음은 세지 않는다 (상점 효과는 하루 요약 shopM이라 trailM에 처음부터 안 든다)', () async {
      final e = await _env();
      // 물감 길 없이 12km
      e.source.records.add(_walk(_at(0), 172, 100));
      await e.svc.sync(_at(200));
      expect(await e.svc.paintTrailKm(), 0);
      expect(await e.owned(), isEmpty);
    });

    test('상점에서 이미 산 발자국은 건너뛰고 아직 없는 무늬 중 첫 번째(꽃잎)', () async {
      final e = await _env();
      await e.buy('trail_01');
      await e.pastTrail('2026-11-10', 10.2);
      await e.svc.sync(_at(0));
      expect((await e.owned()).map((r) => (r.patternId, r.rewardKm)), [('trail_01', null), ('trail_02', 10)]);
    });

    test('한 번에 여러 문턱을 넘으면 낮은 문턱부터 차례로, 셋 다 가졌으면 100 럭(gift, 하루 상한 밖)', () async {
      final e = await _env();
      await e.buy('trail_02');
      await e.pastTrail('2026-11-10', 60);
      await e.svc.sync(_at(0));
      // 10km → 발자국, 50km → 별가루 (꽃잎은 이미 가짐)
      expect((await e.owned()).map((r) => (r.patternId, r.rewardKm)),
          [('trail_01', 10), ('trail_02', null), ('trail_03', 50)]);
      expect(await e.gifts(), isEmpty);

      final got = <List<PatternReward>>[];
      final sub = e.svc.newPatternRewards.listen(got.add);
      addTearDown(sub.cancel);
      await e.pastTrail('2026-11-11', 45);
      final before = await e.svc.coinBalance();
      await e.svc.sync(_at(10));
      final gifts = await e.gifts();
      expect(gifts.map((g) => (g.amount, g.refId, g.day)), [(100, patternCoinsRef(100), '2026-11-18')]);
      expect(await e.svc.coinBalance(), before + 100);
      await pumpEventQueue();
      expect(got, [
        [const PatternReward.coins(100, 100)],
      ]);
      // 다시 동기화해도 럭은 한 번
      await e.svc.sync(_at(20));
      expect(await e.gifts(), hasLength(1));
    });

    test('백업 복원 뒤에도 같은 결과: 받은 무늬·럭은 다시 주지 않고, 무늬 줄 없는 옛 백업이면 같은 무늬를 준다',
        () async {
      final a = await _env();
      await a.buy('trail_01');
      await a.pastTrail('2026-11-10', 120);
      await a.svc.sync(_at(0));
      final ownedA = (await a.owned()).map((r) => (r.patternId, r.rewardKm)).toList();
      expect(ownedA, [('trail_01', null), ('trail_02', 10), ('trail_03', 50)]);
      expect((await a.gifts()).map((g) => g.refId), [patternCoinsRef(100)]);
      final text = await BackupService(a.db, rules).exportBackup(_at(1));

      final b = _Env();
      addTearDown(b.db.close);
      await BackupService(b.db, rules).restoreBackup(text);
      await b.svc.sync(_at(30));
      expect((await b.owned()).map((r) => (r.patternId, r.rewardKm)).toList(), ownedA);
      expect((await b.gifts()).where((g) => g.refId == patternCoinsRef(100)), hasLength(1));

      // 무늬 줄·럭 줄이 없는 백업(스키마 21 전 등)이면 하루 요약만으로 같은 무늬를 준다 (산 발자국은 모르니 처음부터)
      final c = _Env();
      addTearDown(c.db.close);
      await BackupService(c.db, rules).restoreBackup(text);
      await c.db.delete(c.db.patternsOwned).go();
      await (c.db.delete(c.db.coinLedger)..where((t) => t.refId.equals(patternCoinsRef(100)))).go();
      await c.svc.sync(_at(30));
      expect((await c.owned()).map((r) => (r.patternId, r.rewardKm)),
          [('trail_01', 10), ('trail_02', 50), ('trail_03', 100)]);
    });
  });

  group('지도·엽서 구간 무늬', () {
    test('지도: 무늬가 바뀌면 줄이 나뉘고 줄마다 무늬, 이어진 줄 표시(연필 사이면 따로)', () async {
      final e = await _env();
      await e.svc.startJourney(_farDest, _t1, useFund: false);
      final id = await _trailWalk(e, from: _at(0), minutes: 20, syncAt: _at(25), to: _at(20));
      await e.db.batch((b) => b.insertAll(e.db.paintTrailColors, [
            PaintTrailColorsCompanion.insert(trailId: id, fromUtc: _ms(_at(0)), colorId: 'basic'),
            PaintTrailColorsCompanion.insert(
                trailId: id, fromUtc: _ms(_at(10)), colorId: 'basic', patternId: const Value('trail_02')),
          ]));
      // 앱 밖 10분(연필) 뒤 다시 물감 길
      e.source.records.add(_walk(_at(30), 10, 100));
      await e.svc.sync(_at(45));
      await _trailWalk(e, from: _at(50), minutes: 10, syncAt: _at(65), to: _at(60));
      final map = await e.svc.mapData(_at(65));
      expect(map.paintLineColors, ['basic', 'basic', 'basic']);
      expect(map.paintLinePatterns, [null, 'trail_02', null]);
      expect(map.paintLineJoined, [false, true, false]);
      final route = buildRoute(testHome, _landmarks[_farDest]!.latLng, rules);
      expect(map.paintLines[1].first.lat, closeTo(positionAt(route, 0.7).latLng.lat, 1e-9));
    });

    test('엽서: 그날 칠한 구간이 색·무늬마다 나뉜다', () async {
      final e = await _env();
      final id = await _trailWalk(e, from: _at(0), minutes: 30, syncAt: _at(35), to: _at(30));
      await e.db.batch((b) => b.insertAll(e.db.paintTrailColors, [
            PaintTrailColorsCompanion.insert(trailId: id, fromUtc: _ms(_at(0)), colorId: 'basic'),
            PaintTrailColorsCompanion.insert(
                trailId: id, fromUtc: _ms(_at(10)), colorId: 'basic', patternId: const Value('trail_01')),
            PaintTrailColorsCompanion.insert(
                trailId: id, fromUtc: _ms(_at(20)), colorId: 'autumn.sunset', patternId: const Value('trail_01')),
          ]));
      final story = await e.svc.cardStory(const DayRange('2026-11-18', '2026-11-18'), _at(35));
      expect(story.strokes, const [
        PaintStroke('basic', 700),
        PaintStroke('basic', 700, 'trail_01'),
        PaintStroke('autumn.sunset', 700, 'trail_01'),
      ]);
    });
  });
}
