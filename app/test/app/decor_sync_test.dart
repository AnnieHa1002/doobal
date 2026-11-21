import 'package:doobal/app/decor_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/decor_place.dart';
import 'package:doobal/domain/journey.dart' show Frame;
import 'package:doobal/domain/shop.dart' show CoinKind;
import 'package:doobal/domain/sketch.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

// 쉼터 꾸밈 물품 얻기·놓기 저장 (T15, 16장 11/19 쉼터·상점 세부, M2~M6 AB, DB 21 decor_owned·decor_placed·decor_paintings).
// 판정은 동기화 끝 소품 해금 자리 (sync_decor.dart)

final _t0 = DateTime.utc(2026, 11, 18, 0);
final _stage = DecorStage.of(campTheme, rules.decor.place, screenHeightPx: rules.screenHeightPx)!;
final _giftAt = _stage.toRatio(_stage.easelStart);

class _Env {
  _Env({bool seed = true}) : db = AppDb(NativeDatabase.memory()) {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: {for (final l in landmarks) l.id: l},
      props: props,
      shopCatalog: shopCatalog,
      boatCatalog: boatCatalog,
      decorSeed: seed
          ? DecorSeed(catalog: decorCatalog, gift: rules.decor.firstSketchGift, giftAt: _giftAt)
          : null,
    );
    store = DecorStore(db);
  }

  final AppDb db;
  final source = FakeStepSource();
  late final SyncService svc;
  late final DecorStore store;

  Future<void> install() async {
    await svc.sync(_t0);
    await completeOnboarding(db);
  }

  /// 그림을 가진 것으로 둔다 ([visits]번 도착)
  Future<void> own(String landmarkId, {int visits = 1}) => db.into(db.paintingsOwned).insertOnConflictUpdate(
        PaintingsOwnedCompanion.insert(
          landmarkId: landmarkId,
          visits: visits,
          frame: Frame.wood,
          bestKm: 1,
          firstArrivedUtc: 1,
          lastArrivedUtc: 1,
        ),
      );

  Future<Set<String>> owned() async => {for (final r in await db.select(db.decorOwned).get()) r.decorId};
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('보상·선물 물품 얻기 (동기화 끝)', () {
    test('첫 그림을 가지면 이젤: 첫 그림을 건 채 테마 첫 자리(camp_wide decor.easelStart)에 놓인다', () async {
      final e = _Env();
      await e.install();
      expect(await e.owned(), isEmpty);
      await e.own(sketchId);
      await e.svc.sync(_t0.add(const Duration(hours: 1)));
      expect(await e.owned(), {'decor_easel'});
      final s = await e.store.load();
      expect(s.placed['decor_easel']!.xRatio, closeTo(_giftAt.x, 1e-12));
      expect(s.placed['decor_easel']!.yRatio, closeTo(_giftAt.y, 1e-12));
      expect(s.placed['decor_easel']!.flipped, isFalse);
      expect(s.paintings['decor_easel'], {0: 'sketch'});
      expect(s.drawer, isEmpty);
    });

    test('첫 그림(내 동네 스케치)에 걸어서 도착한 그 동기화에서 럭 100과 이젤 (config coins.firstSketchGift)', () async {
      final e = _Env();
      await e.install();
      final start = _t0.add(const Duration(hours: 1));
      expect(await e.svc.startSketch(start), isTrue);
      final km = (await e.svc.snapshot(start)).journey!.totalKm;
      final minutes = (km * 1000 / (rules.walkStrideM * 100)).ceil() + 1;
      final walkFrom = start.add(const Duration(minutes: 5));
      e.source.records.add(StepRecord(
        start: walkFrom,
        end: walkFrom.add(Duration(minutes: minutes)),
        steps: minutes * 100,
        sourceId: 'iphone',
        method: RecordingMethod.automatic,
      ));
      final end = walkFrom.add(Duration(minutes: minutes + 30));
      await e.svc.sync(end);
      expect((await e.db.select(e.db.paintingsOwned).get()).map((r) => r.landmarkId), [sketchId]);
      expect(await e.owned(), {'decor_easel'});
      final s = await e.store.load();
      expect(s.placed.keys, ['decor_easel']);
      expect(s.paintings['decor_easel'], {0: 'sketch'});
      final gifts = [
        for (final r in await e.db.select(e.db.coinLedger).get())
          if (r.kind == CoinKind.gift) r.amount,
      ];
      expect(gifts, [rules.coinsWelcomeGift]);
      expect(rules.coinsWelcomeGift, 100);
    });

    test('상점에서 산 물품은 가진 것(decor_owned)이 되고 저절로 놓이지 않는다 (서랍으로, 가안)', () async {
      final e = _Env();
      await e.install();
      await e.db.into(e.db.coinLedger).insert(
          CoinLedgerCompanion.insert(day: '2026-11-18', kind: CoinKind.gift, amount: 1000));
      await e.svc.buyItem('decor_lantern', _t0.add(const Duration(hours: 1)));
      expect(await e.owned(), {'decor_lantern'});
      final s = await e.store.load();
      expect(s.placed, isEmpty);
      expect(s.drawer, ['decor_lantern']);
    });

    test('한 번 받으면 다시 안 준다: 치워도 다음 동기화가 다시 놓지 않는다', () async {
      final e = _Env();
      await e.install();
      await e.own(sketchId);
      await e.svc.sync(_t0.add(const Duration(hours: 1)));
      await e.store.remove('decor_easel');
      await e.svc.sync(_t0.add(const Duration(hours: 2)));
      final s = await e.store.load();
      expect(s.placed, isEmpty);
      expect(s.drawer, ['decor_easel']);
      expect(s.paintings['decor_easel'], {0: 'sketch'}, reason: '건 그림은 남는다');
    });

    test('명소 n곳 = 도착한 서로 다른 명소 수 (스케치 빼고, 재방문 안 셈), 보상 물품은 서랍으로', () async {
      final e = _Env();
      await e.install();
      await e.own('kr001', visits: 3);
      await e.svc.sync(_t0.add(const Duration(hours: 1)));
      expect(await e.owned(), {'decor_hanging_frame'});
      expect((await e.store.load()).placed, isEmpty, reason: '저절로 놓지 않는다');
      for (final id in ['kr002', 'kr003', 'kr004']) {
        await e.own(id);
      }
      await e.svc.sync(_t0.add(const Duration(hours: 2)));
      expect(await e.owned(), {'decor_hanging_frame'}, reason: '4곳 (kr001 세 번은 한 곳)');
      await e.own('kr005');
      await e.own(sketchId);
      await e.svc.sync(_t0.add(const Duration(hours: 3)));
      expect(await e.owned(), {'decor_hanging_frame', 'decor_clothesline', 'decor_easel'});
      for (var i = 6; i <= 10; i++) {
        await e.own('kr${i.toString().padLeft(3, '0')}');
      }
      await e.svc.sync(_t0.add(const Duration(hours: 4)));
      expect(await e.owned(), contains('decor_big_frame'));
      expect((await e.owned()).where((id) => decorCatalog.byId(id)!.price != null), isEmpty,
          reason: '상점 물품은 걸어서 안 생긴다');
    });

    test('꾸미기 데이터가 없으면(decorSeed 없음) 물품을 주지 않는다', () async {
      final e = _Env(seed: false);
      await e.install();
      await e.own(sketchId);
      await e.svc.sync(_t0.add(const Duration(hours: 1)));
      expect(await e.owned(), isEmpty);
    });
  });

  group('DecorStore 놓기·옮기기·뒤집기·치우기·그림 걸기', () {
    Future<_Env> withItems(List<String> ids) async {
      final e = _Env();
      await e.install();
      await e.db.batch((b) => b.insertAll(e.db.decorOwned, [
            for (final (i, id) in ids.indexed) DecorOwnedCompanion.insert(decorId: id, gotUtc: 10 + i),
          ]));
      return e;
    }

    test('놓으면 저장, 옮기면 자리·놓은 시각이 바뀐다. 서랍은 얻은 순서', () async {
      final e = await withItems(['decor_bench', 'decor_pond', 'decor_stump']);
      expect((await e.store.load()).drawer, ['decor_bench', 'decor_pond', 'decor_stump']);
      await e.store.place('decor_pond', xRatio: 0.5, yRatio: 0.2, flipped: false, maxPlaced: 20, now: _t0);
      await e.store.place('decor_pond',
          xRatio: 0.7, yRatio: 0.9, flipped: true, maxPlaced: 20, now: _t0.add(const Duration(seconds: 5)));
      final s = await e.store.load();
      expect(s.placed['decor_pond'],
          PlacedDecor(xRatio: 0.7, yRatio: 0.9, flipped: true, placedUtc: _t0.millisecondsSinceEpoch + 5000));
      expect(s.drawer, ['decor_bench', 'decor_stump']);
      await e.store.flip('decor_pond', false);
      expect((await e.store.load()).placed['decor_pond']!.flipped, isFalse);
    });

    test('쉼터에 이미 최대로 놓였으면 새로 놓기는 막고 옮기기는 된다', () async {
      final e = await withItems(['decor_bench', 'decor_pond']);
      await e.store.place('decor_bench', xRatio: 0.1, yRatio: 0, flipped: false, maxPlaced: 1, now: _t0);
      await expectLater(
        e.store.place('decor_pond', xRatio: 0.5, yRatio: 0, flipped: false, maxPlaced: 1, now: _t0),
        throwsA(isA<DecorRefused>().having((r) => r.why, 'why', DecorRefusal.full)),
      );
      await e.store.place('decor_bench', xRatio: 0.3, yRatio: 0, flipped: false, maxPlaced: 1, now: _t0);
      expect((await e.store.load()).placed.keys, ['decor_bench']);
    });

    test('가지지 않은 물품은 놓을 수도 그림을 걸 수도 없다, 없는 칸도', () async {
      final e = await withItems(['decor_clothesline']);
      await expectLater(
        e.store.place('decor_pond', xRatio: 0, yRatio: 0, flipped: false, maxPlaced: 20, now: _t0),
        throwsA(isA<DecorRefused>().having((r) => r.why, 'why', DecorRefusal.notOwned)),
      );
      await expectLater(e.store.hang('decor_pond', 0, 'kr001', slots: 1), throwsA(isA<DecorRefused>()));
      await expectLater(
        e.store.hang('decor_clothesline', 3, 'kr001', slots: 3),
        throwsA(isA<DecorRefused>().having((r) => r.why, 'why', DecorRefusal.noSlot)),
      );
    });

    test('그림 걸기: 칸마다 하나, 같은 그림을 여러 곳에 걸 수 있고(가안), null이면 내린다', () async {
      final e = await withItems(['decor_clothesline', 'decor_big_frame']);
      await e.store.hang('decor_clothesline', 0, 'kr001', slots: 3);
      await e.store.hang('decor_clothesline', 2, 'kr001', slots: 3);
      await e.store.hang('decor_big_frame', 0, 'kr001', slots: 1);
      await e.store.hang('decor_clothesline', 0, 'kr002', slots: 3);
      var s = await e.store.load();
      expect(s.paintings['decor_clothesline'], {0: 'kr002', 2: 'kr001'});
      expect(s.paintings['decor_big_frame'], {0: 'kr001'});
      await e.store.hang('decor_clothesline', 2, null, slots: 3);
      s = await e.store.load();
      expect(s.paintings['decor_clothesline'], {0: 'kr002'});
    });

    test('놓인 줄이 있어도 가진 물품이 아니면 읽지 않는다 (복원 뒤 어긋남)', () async {
      final e = await withItems([]);
      await e.db.into(e.db.decorPlaced).insert(
          DecorPlacedCompanion.insert(decorId: 'decor_pond', xRatio: 0, yRatio: 0, placedUtc: 1));
      expect((await e.store.load()).placed, isEmpty);
    });
  });
}
