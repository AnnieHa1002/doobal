import 'package:doobal/app/paint_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// M1 명세 v0.7 ⑦·⑧·⑨·v0.8 ⑬의 보관 쪽 (스키마 18·20): 고르기, 물감 길 색 구간(걷는 중에도 바꾸면 새 구간,
// 16장 11/16), 칠하면 줄고 다 쓰면 기본 물감, 방울마다 물감 통(계절 키·지역 색), 같은 방울은 한 번만, 999통 상한,
// 럭 장부는 그대로, 그날 날씨 저장

final _t = DateTime.utc(2026, 11, 18, 1);

/// 짝수 방울은 통(양 = 770 + 내림(u × 771)), 홀수는 없음
double _evenTubes(int trail, int drop, String slot) =>
    slot == 'reward' ? (drop.isEven ? 0.0 : 0.9) : 0.5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDb db;
  late PaintService paint;

  setUp(() {
    db = AppDb(NativeDatabase.memory());
    paint = PaintService(db, rules, random: _evenTubes);
  });
  tearDown(() => db.close());

  Future<int> openTrail([DateTime? at]) =>
      db.into(db.paintTrails).insert(PaintTrailsCompanion.insert(
          startUtc: (at ?? _t).millisecondsSinceEpoch));

  Future<void> stock(String id, double remainM, {int tubes = 1}) =>
      db.into(db.paintStock).insert(PaintStockCompanion.insert(
          colorId: id,
          tubes: tubes,
          remainM: remainM,
          firstGotAt: 0,
          lastGotAt: 0));

  Future<PaintStockRow?> row(String id) =>
      (db.select(db.paintStock)..where((t) => t.colorId.equals(id))).getSingleOrNull();

  /// 물감 길 [id]의 색 구간 (시작 ms, 색)
  Future<List<(int, String)>> segs(int id) async => [
        for (final r in await (db.select(db.paintTrailColors)
              ..where((t) => t.trailId.equals(id))
              ..orderBy([(t) => OrderingTerm(expression: t.fromUtc)]))
            .get())
          (r.fromUtc, r.colorId),
      ];

  int ms(DateTime t) => t.millisecondsSinceEpoch;

  test('고르기: 기본은 늘 되고, 가진 적 없거나 다 쓴 색은 안 된다. 물감 길을 열면 그때 색이 첫 구간', () async {
    expect(await paint.currentColor(), 'basic');
    expect(await paint.choose('sunset'), isFalse);
    await stock('sunset', 0, tubes: 0);
    expect(await paint.choose('sunset'), isFalse);
    await (db.update(db.paintStock)..where((t) => t.colorId.equals('sunset')))
        .write(const PaintStockCompanion(remainM: Value(900), tubes: Value(1)));
    expect(await paint.choose('sunset'), isTrue);
    expect(await paint.currentColor(), 'sunset');

    final id = await openTrail();
    await paint.beginTrail(id);
    expect(await segs(id), [(ms(_t), 'sunset')]);
    expect(await paint.trailColor(id), 'sunset');
    // 다시 불러도 첫 구간은 그대로. 물감 길을 알리지 않고 고르면 프로필만 바뀐다
    await paint.choose('basic');
    await paint.beginTrail(id);
    expect(await segs(id), [(ms(_t), 'sunset')]);
    final next = await openTrail(_t.add(const Duration(hours: 1)));
    await paint.beginTrail(next);
    expect(await segs(next), [(ms(_t.add(const Duration(hours: 1))), 'basic')]);
  });

  test('16장 11/16: 걷는 중에 고르면 그 순간부터 새 구간, 같은 색이면 그대로, 닫힌 물감 길은 안 바뀜', () async {
    await stock('autumn.sunset', 1000);
    await stock('region.kr.capital', 1000);
    final id = await openTrail();
    await paint.beginTrail(id);
    final t1 = _t.add(const Duration(minutes: 2));
    expect(await paint.choose('autumn.sunset', openTrailId: id, now: t1), isTrue);
    // 같은 색을 다시 고르면 구간이 늘지 않는다
    await paint.choose('autumn.sunset', openTrailId: id, now: t1.add(const Duration(seconds: 30)));
    final t2 = _t.add(const Duration(minutes: 4));
    await paint.addPaint(trailId: id, fromM: 0, toM: 100, now: t2, momentColor: 'autumn.day');
    expect((await row('autumn.sunset'))!.remainM, 900);
    await paint.choose('region.kr.capital', openTrailId: id, now: t2);
    await paint.addPaint(trailId: id, fromM: 100, toM: 250, now: t2, momentColor: 'autumn.day');
    expect((await row('region.kr.capital'))!.remainM, 850);
    // 지역 색에서 기본으로 바꾸면 그 뒤는 아무것도 줄지 않는다 (지역 색 남은 양 그대로)
    final t3 = _t.add(const Duration(minutes: 6));
    await paint.choose('basic', openTrailId: id, now: t3);
    await paint.addPaint(trailId: id, fromM: 250, toM: 400, now: t3, momentColor: 'autumn.day');
    expect((await row('autumn.sunset'))!.remainM, 900);
    expect((await row('region.kr.capital'))!.remainM, 850);
    expect(await segs(id), [
      (ms(_t), 'basic'),
      (ms(t1), 'autumn.sunset'),
      (ms(t2), 'region.kr.capital'),
      (ms(t3), 'basic'),
    ]);
    // 닫힌 물감 길에는 구간을 더하지 않는다 (프로필만)
    await (db.update(db.paintTrails)..where((t) => t.id.equals(id)))
        .write(PaintTrailsCompanion(endUtc: Value(ms(t3) + 1000)));
    await paint.choose('autumn.sunset', openTrailId: id, now: t3.add(const Duration(minutes: 1)));
    expect(await segs(id), hasLength(4));
    expect(await paint.currentColor(), 'autumn.sunset');
  });

  test('⑦ 남은 300m로 500m 칠하면 300m에서 기본 물감 구간으로 (고른 물감 비움, 다시 줍어도 저절로 안 고름), 남은 0', () async {
    await stock('day_run', 300);
    await paint.choose('day_run');
    final id = await openTrail();
    await paint.beginTrail(id);

    final now1 = _t.add(const Duration(minutes: 3));
    await paint.addPaint(trailId: id, fromM: 0, toM: 200, now: now1, momentColor: 'day');
    expect((await row('day_run'))!.remainM, 100);
    expect(await segs(id), [(ms(_t), 'day_run')]);

    final now2 = _t.add(const Duration(minutes: 6));
    await paint.addPaint(trailId: id, fromM: 200, toM: 500, now: now2, momentColor: 'day');
    final r = (await row('day_run'))!;
    expect((r.remainM, r.tubes), (0.0, 0));
    expect(await segs(id), [(ms(_t), 'day_run'), (ms(now2), 'basic')]);
    expect(await paint.currentColor(), 'basic');
    final profile = await (db.select(db.profile)..where((t) => t.id.equals(1))).getSingle();
    expect(profile.paintColorId, isNull);
    // 다 쓴 색은 배낭에 없다 (기본만 남음 + 방울에서 받은 낮)
    final shelf = await paint.shelf();
    expect([for (final c in shelf.colors) c.colorId], ['basic', 'day']);
    expect(shelf.current, 'basic');
    // 같은 색 통을 다시 주워도 저절로 다시 고르지 않는다 (config choose.reselectOnRefill false)
    await paint.addPaint(trailId: id, fromM: 500, toM: 700, now: now2, momentColor: 'day_run');
    expect((await row('day_run'))!.remainM, greaterThan(0));
    expect(await paint.currentColor(), 'basic');
    expect(await paint.trailColor(id), 'basic');
  });

  test('방울마다 보상: 새로 넘은 방울만, 통은 그 순간 색으로, 같은 방울을 다시 넘겨도 한 번', () async {
    final id = await openTrail();
    await paint.beginTrail(id);
    // 0 → 450m: 방울 1~4, 짝수 2·4에서 통 (양 770 + 385 = 1,155m)
    final got = await paint.addPaint(
        trailId: id, fromM: 0, toM: 450, now: _t, momentColor: 'rain');
    expect([for (final t in got) t.dropNo], [2, 4]);
    var r = (await row('rain'))!;
    expect((r.tubes, r.remainM, r.seen), (2, 2310.0, false));
    // 450 → 620m: 방울 5·6 → 6만 통, 이번엔 노을
    await paint.addPaint(trailId: id, fromM: 450, toM: 620, now: _t, momentColor: 'sunset');
    expect((await row('sunset'))!.tubes, 1);
    // 같은 구간을 다시 넘기면(판정기를 새로 만들었다) 더 받지 않는다
    expect(await paint.addPaint(trailId: id, fromM: 0, toM: 620, now: _t, momentColor: 'rain'), isEmpty);
    r = (await row('rain'))!;
    expect((r.tubes, r.remainM), (2, 2310.0));
    expect(await paint.unseenColors(), 2);
    await paint.markSeen();
    expect(await paint.unseenColors(), 0);
    // 기본 물감으로 칠한 물감 길은 아무것도 줄지 않는다
    expect(await paint.trailColor(id), 'basic');
  });

  test('M1 v0.8: 지역 색으로 나온 통은 지금 권역의 지역 색, 지역을 모르면 그 순간 색. ⑬ 같은 색 다른 계절은 다른 칸', () async {
    // 짝수 방울은 통이고, 4의 배수 방울은 지역 색
    final p = PaintService(db, rules,
        random: (trail, drop, slot) => switch (slot) {
              'reward' => drop.isEven ? 0.0 : 0.9,
              'region' => drop % 4 == 0 ? 0.0 : 0.9,
              _ => 0.5,
            });
    final id = await openTrail();
    await p.beginTrail(id);
    final got = await p.addPaint(
        trailId: id,
        fromM: 0,
        toM: 800,
        now: _t,
        momentColor: 'autumn.sunset',
        regionColor: 'region.kr.jeju');
    expect([for (final t in got) (t.dropNo, t.colorId)], [
      (2, 'autumn.sunset'),
      (4, 'region.kr.jeju'),
      (6, 'autumn.sunset'),
      (8, 'region.kr.jeju'),
    ]);
    // 지역을 모르면(지점·명소 없음) 지역 색 통도 그 순간 색
    final more = await p.addPaint(trailId: id, fromM: 800, toM: 1200, now: _t, momentColor: 'autumn.sunset');
    expect([for (final t in more) t.colorId], everyElement('autumn.sunset'));
    // ⑬ 겨울에 주운 노을은 가을 노을과 다른 칸
    await p.addPaint(trailId: id, fromM: 1200, toM: 1400, now: _t, momentColor: 'winter.sunset');
    expect((await row('autumn.sunset'))!.tubes, 4);
    expect((await row('winter.sunset'))!.tubes, 1);
    expect((await row('region.kr.jeju'))!.tubes, 2);
  });

  test('그날 날씨는 sync_state에 둔다 (스키마 20, 행이 없으면 적지 않음)', () async {
    await paint.saveWeather('2026-11-18', 'rain');
    expect(await paint.savedWeather(), isNull);
    await db.into(db.syncState).insert(
        SyncStateCompanion.insert(id: const Value(1), firstRecordDay: '2026-11-18', installUtc: 0));
    expect(await paint.savedWeather(), isNull);
    await paint.saveWeather('2026-11-18', 'rain');
    expect(await paint.savedWeather(), (day: '2026-11-18', kind: 'rain'));
  });

  test('통 수 = 주운 차례로 쓴 뒤 다 안 쓴 통: 2통(1,155m씩) 중 1,200m를 쓰면 1통', () async {
    final a = await openTrail();
    await paint.beginTrail(a);
    await paint.addPaint(trailId: a, fromM: 0, toM: 400, now: _t, momentColor: 'night');
    expect((await row('night'))!.tubes, 2);
    await paint.choose('night');
    final b = await openTrail(_t.add(const Duration(hours: 2)));
    await paint.beginTrail(b);
    await paint.addPaint(trailId: b, fromM: 0, toM: 1200, now: _t, momentColor: 'night');
    final r = (await row('night'))!;
    // 1,200m 동안 방울 짝수 6개에서 통 6개가 더 들어왔다: 8통 × 1,155 − 1,200
    expect(r.remainM, closeTo(8 * 1155 - 1200, 1e-9));
    expect(r.tubes, 7);
  });

  test('⑧ 그 색 통이 999면 그 색 통은 안 나온다 (다른 색은 나온다)', () async {
    await stock('snow', 5000, tubes: 999);
    final id = await openTrail();
    await paint.beginTrail(id);
    expect(await paint.canGetTube('snow'), isFalse);
    expect(await paint.addPaint(trailId: id, fromM: 0, toM: 200, now: _t, momentColor: 'snow'),
        isEmpty);
    expect((await row('snow'))!.tubes, 999);
    expect(await paint.canGetTube('day'), isTrue);
    expect(await paint.addPaint(trailId: id, fromM: 200, toM: 400, now: _t, momentColor: 'day'),
        hasLength(1));
  });

  test('⑨ 럭 장부는 건드리지 않는다 (럭은 물감 길 거리로 동기화가 센다)', () async {
    final id = await openTrail();
    await paint.beginTrail(id);
    await paint.addPaint(trailId: id, fromM: 0, toM: 3000, now: _t, momentColor: 'day');
    expect(await db.select(db.coinLedger).get(), isEmpty);
    expect((await db.select(db.paintTubes).get()).length, 15);
  });

  test('기본 무작위(물감 길·방울 번호)로는 DB를 새로 만들어 다시 넘겨도 같은 통·같은 양', () async {
    Future<List<(int, double)>> run() async {
      final d = AppDb(NativeDatabase.memory());
      final p = PaintService(d, rules);
      final id = await d.into(d.paintTrails).insert(PaintTrailsCompanion.insert(startUtc: 0));
      await p.beginTrail(id);
      await p.addPaint(trailId: id, fromM: 0, toM: 5000, now: _t, momentColor: 'day');
      final tubes = await d.select(d.paintTubes).get();
      await d.close();
      return [for (final t in tubes) (t.dropNo, t.amountM)];
    }

    final a = await run();
    expect(a, await run());
    for (final (_, m) in a) {
      expect(m, inInclusiveRange(770, 1540));
    }
  });
}
