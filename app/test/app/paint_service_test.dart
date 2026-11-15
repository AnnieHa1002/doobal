import 'package:doobal/app/paint_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// M1 명세 v0.7 ⑦·⑧·⑨의 보관 쪽 (스키마 18): 고르기, 물감 길에 칠한 색, 칠하면 줄고 다 쓰면 기본 물감,
// 방울마다 물감 통, 같은 방울은 한 번만, 999통 상한, 럭 장부는 그대로

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

  Future<PaintTrailRow> trail(int id) =>
      (db.select(db.paintTrails)..where((t) => t.id.equals(id))).getSingle();

  test('고르기: 기본은 늘 되고, 가진 적 없거나 다 쓴 색은 안 된다. 고른 색이 물감 길에 적힌다', () async {
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
    expect((await trail(id)).colorId, 'sunset');
    // 다시 불러도 바뀌지 않는다 (걷는 중에는 안 고름)
    await paint.choose('basic');
    await paint.beginTrail(id);
    expect((await trail(id)).colorId, 'sunset');
    final next = await openTrail(_t.add(const Duration(hours: 1)));
    await paint.beginTrail(next);
    expect((await trail(next)).colorId, 'basic');
  });

  test('⑦ 남은 300m로 500m 칠하면 300m에서 기본 물감으로 (물감 길 colorEndUtc, 고른 물감 비움), 남은 0', () async {
    await stock('day_run', 300);
    await paint.choose('day_run');
    final id = await openTrail();
    await paint.beginTrail(id);

    final now1 = _t.add(const Duration(minutes: 3));
    await paint.addPaint(trailId: id, fromM: 0, toM: 200, now: now1, momentColor: 'day');
    expect((await row('day_run'))!.remainM, 100);
    expect((await trail(id)).colorEndUtc, isNull);

    final now2 = _t.add(const Duration(minutes: 6));
    await paint.addPaint(trailId: id, fromM: 200, toM: 500, now: now2, momentColor: 'day');
    final r = (await row('day_run'))!;
    expect((r.remainM, r.tubes), (0.0, 0));
    expect((await trail(id)).colorEndUtc, now2.millisecondsSinceEpoch);
    expect(await paint.currentColor(), 'basic');
    final profile = await (db.select(db.profile)..where((t) => t.id.equals(1))).getSingle();
    expect(profile.paintColorId, isNull);
    // 다 쓴 색은 배낭에 없다 (기본만 남음 + 방울에서 받은 낮)
    final shelf = await paint.shelf();
    expect([for (final c in shelf.colors) c.colorId], ['basic', 'day']);
    expect(shelf.current, 'basic');
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
    expect((await trail(id)).colorId, 'basic');
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
