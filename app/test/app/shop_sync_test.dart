import 'dart:math' as math;

import 'package:doobal/app/backup_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

// 럭·상점·배 엔진 (M4.5). 설치 KST 2026-11-18 09:00, 걷기는 그날 10:00(= _t1)부터.
// 분당 120보는 걷기(0.7m)라 1분에 84m

const _shortcut = 'fx_shortcut';
const _tailwind = 'fx_tailwind';
const _day = '2026-11-18';

final _landmarks = {for (final l in landmarks) l.id: l};

final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

DateTime _at(int minutesAfterT1) => _t1.add(Duration(minutes: minutesAfterT1));

StepRecord _walk(DateTime start, int minutes, {int spm = 120}) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

class _Env {
  _Env({double scale = 1.0})
      : db = AppDb(NativeDatabase.memory()),
        source = FakeStepSource() {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _landmarks,
      props: props,
      milestones: milestones,
      badgeCatalog: badgeCatalog,
      shopCatalog: shopCatalog,
      boatCatalog: boatCatalog,
      distanceScale: scale,
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  Future<void> give(int coins) => db.into(db.coinLedger).insert(
        CoinLedgerCompanion.insert(day: _day, kind: CoinKind.gift, amount: coins),
      );

  Future<DaySummaryRow> day() =>
      (db.select(db.daySummaries)..where((t) => t.day.equals(_day))).getSingle();

  Future<List<ShopUseRow>> uses() => db.select(db.shopUses).get();

  Future<double> progressKm(DateTime now) async =>
      (await svc.snapshot(now)).journey!.progress.progressKm;

  /// 시각에 따라 달라지는 값은 빼고 비교한다
  Future<List<Object?>> dump() async => [
        await db.select(db.daySummaries).get(),
        await db.select(db.shopUses).get(),
        await db.select(db.shopInventory).get(),
        await db.select(db.boatsOwned).get(),
        await db.select(db.propsOwned).get(),
        // 장부 행은 다시 쓰면 번호가 바뀌니 내용만 본다
        {for (final c in await db.select(db.coinLedger).get()) (c.day, c.kind, c.amount, c.refId)},
        (await db.select(db.travelFund).getSingle()).km,
      ];
}

/// 설치하고 출발 동네를 골라 둔 환경
Future<_Env> _env({double scale = 1.0}) async {
  final e = _Env(scale: scale);
  addTearDown(e.db.close);
  await e.svc.sync(_t0);
  await e.svc.setHome(testHomeName, testHome);
  return e;
}

/// 경복궁까지 약 [km]인 자리에서 _t1에 출발한 환경 (경비는 안 쓴다)
Future<_Env> _journey(double km, {double scale = 1.0}) async {
  final e = await _env(scale: scale);
  final dest = _landmarks['kr001']!.latLng;
  final deg = km / (rules.earthRadiusKm * math.pi / 180);
  await placeAt(e.db, LatLng(dest.lat - deg, dest.lng), _t0);
  await e.svc.startJourney('kr001', _t1, useFund: false);
  return e;
}

Matcher _blocked(ShopBlock block) =>
    throwsA(isA<ShopBlocked>().having((b) => b.block, 'block', block));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('럭 잔액', () {
    test('earn·gift·ad − spend', () async {
      final e = await _env();
      expect(await e.svc.coinBalance(), 0);
      await e.db.batch((b) => b.insertAll(e.db.coinLedger, [
            CoinLedgerCompanion.insert(day: _day, kind: CoinKind.earn, amount: 40),
            CoinLedgerCompanion.insert(day: _day, kind: CoinKind.gift, amount: 100),
            CoinLedgerCompanion.insert(day: _day, kind: CoinKind.ad, amount: 40),
            CoinLedgerCompanion.insert(day: _day, kind: CoinKind.spend, amount: 30),
          ]));
      expect(await e.svc.coinBalance(), 150);
    });

    test('다시 계산한 earn이 줄어 쓴 럭보다 적어져도 음수가 아니다', () async {
      final e = await _env();
      await e.db.into(e.db.coinLedger).insert(
            CoinLedgerCompanion.insert(day: _day, kind: CoinKind.spend, amount: 30),
          );
      expect(await e.svc.coinBalance(), 0);
    });

    test('같은 기록 동기화 2번에 럭이 같고, 쓴 줄은 그대로다', () async {
      final e = await _journey(60);
      e.source.records.add(_walk(_at(0), 60));
      await e.svc.sync(_at(60));
      await e.give(100);
      await e.svc.buyItem(_shortcut, _at(60));
      final balance = await e.svc.coinBalance();
      expect(balance, greaterThan(0));

      await e.svc.sync(_at(61));
      await e.svc.sync(_at(62));
      expect(await e.svc.coinBalance(), balance);
      final spends = await (e.db.select(e.db.coinLedger)
            ..where((t) => t.kind.equalsValue(CoinKind.spend)))
          .get();
      expect(spends.map((r) => (r.amount, r.refId)), [(50, _shortcut)]);
    });
  });

  group('구매', () {
    test('여행 효과: spend 줄과 보관함', () async {
      final e = await _env();
      await e.give(120);
      await e.svc.buyItem(_shortcut, _t1);
      await e.svc.buyItem(_shortcut, _t1);
      expect(await e.svc.coinBalance(), 20);
      expect(await e.svc.shopHeld(), {_shortcut: 2});
      final spends = await (e.db.select(e.db.coinLedger)
            ..where((t) => t.kind.equalsValue(CoinKind.spend)))
          .get();
      expect(spends.map((r) => (r.day, r.amount, r.refId)), [
        (_day, 50, _shortcut),
        (_day, 50, _shortcut),
      ]);
    });

    test('소품·꾸밈 효과: 얻은 소품으로, 두 번째는 막는다', () async {
      final e = await _env();
      await e.give(2000);
      for (final tab in [ShopTab.prop, ShopTab.effect]) {
        final item = shopCatalog.inTab(tab).first;
        await e.svc.buyItem(item.id, _t1);
        expect(await e.svc.ownedPropIds(), contains(item.propId), reason: item.id);
        final balance = await e.svc.coinBalance();
        await expectLater(e.svc.buyItem(item.id, _t1), _blocked(ShopBlock.owned));
        expect(await e.svc.coinBalance(), balance);
      }
      expect(await e.svc.shopHeld(), isEmpty);
    });

    test('상점 배: 얻은 배로, 두 번째는 막고, 자동으로 갈아타지 않는다', () async {
      final e = await _env();
      await e.give(5000);
      await e.svc.buyItem('boat_cruise', _t1);
      expect(await e.svc.coinBalance(), 0);
      expect(await e.svc.ownedBoatIds(), containsAll(['boat_raft', 'boat_cruise']));
      expect((await e.svc.selectedBoat())!.id, 'boat_raft');
      await e.give(5000);
      await expectLater(e.svc.buyItem('boat_cruise', _t1), _blocked(ShopBlock.owned));
    });

    test('잔액 부족이면 막고 아무것도 안 바뀐다', () async {
      final e = await _env();
      await e.give(49);
      final before = await e.dump();
      await expectLater(e.svc.buyItem(_shortcut, _t1), _blocked(ShopBlock.notEnoughCoins));
      expect(await e.dump(), before);
    });

    test('보관 10번째 구매를 막는다', () async {
      final e = await _env();
      await e.give(1000);
      for (var i = 0; i < rules.shopMaxHoldPerItem; i++) {
        await e.svc.buyItem(_shortcut, _t1);
      }
      final balance = await e.svc.coinBalance();
      await expectLater(e.svc.buyItem(_shortcut, _t1), _blocked(ShopBlock.holdFull));
      expect(await e.svc.coinBalance(), balance);
      expect((await e.svc.shopHeld())[_shortcut], rules.shopMaxHoldPerItem);
    });

    test('모르는 상품과 파는 물건이 아닌 기본 배는 막는다', () async {
      final e = await _env();
      await e.give(100000);
      await expectLater(e.svc.buyItem('nope', _t1), _blocked(ShopBlock.unknownItem));
      await expectLater(e.svc.buyItem('boat_raft', _t1), _blocked(ShopBlock.unknownItem));
    });

    test('동시에 눌러도 잔액을 넘겨 사지 못한다', () async {
      final e = await _env();
      await e.give(50);
      final results = await Future.wait([
        for (var i = 0; i < 3; i++)
          e.svc.buyItem(_shortcut, _t1).then((_) => true, onError: (_) => false),
      ]);
      expect(results.where((ok) => ok), hasLength(1));
      expect(await e.svc.coinBalance(), 0);
    });
  });

  group('여행 효과 사용', () {
    test('여정 없을 때 막고 효과를 줄이지 않는다', () async {
      final e = await _env();
      await e.give(50);
      await e.svc.buyItem(_shortcut, _t1);
      await expectLater(e.svc.useTravelEffect(_shortcut, _t1), _blocked(ShopBlock.noJourney));
      expect(await e.svc.shopHeld(), {_shortcut: 1});
      expect(await e.uses(), isEmpty);
    });

    test('가지고 있지 않으면 막는다', () async {
      final e = await _journey(60);
      await expectLater(e.svc.useTravelEffect(_shortcut, _at(1)), _blocked(ShopBlock.notOwned));
    });

    test('지름길: 바로 +1km, 보관함이 줄고, ShopUses·하루 요약에 들어간다', () async {
      final e = await _journey(60);
      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(1));
      final before = await e.progressKm(_at(1));
      await e.svc.useTravelEffect(_shortcut, _at(1));

      expect(await e.progressKm(_at(1)), closeTo(before + 1, 1e-9));
      expect(await e.svc.shopHeld(), isEmpty);
      final use = (await e.uses()).single;
      expect((use.itemId, use.day, use.km, use.appWalkId), (_shortcut, _day, 1.0, null));
      final day = await e.day();
      expect(day.shopM, 1000);
      expect(day.travelM, 1000);
      expect(day.distanceM, 0);
    });

    test('지름길은 하루 2장, 다음 날은 다시 쓴다', () async {
      final e = await _journey(60);
      await e.give(150);
      for (var i = 0; i < 3; i++) {
        await e.svc.buyItem(_shortcut, _at(1));
      }
      await e.svc.useTravelEffect(_shortcut, _at(1));
      await e.svc.useTravelEffect(_shortcut, _at(2));
      await expectLater(e.svc.useTravelEffect(_shortcut, _at(3)), _blocked(ShopBlock.dailyLimit));
      expect((await e.svc.shopHeld())[_shortcut], 1);

      final tomorrow = _at(24 * 60);
      await e.svc.useTravelEffect(_shortcut, tomorrow);
      expect(await e.svc.shopHeld(), isEmpty);
      expect(await e.progressKm(tomorrow), closeTo(3, 1e-9));
    });

    test('순풍: 걷는 중이 아니면 막는다', () async {
      final e = await _journey(60);
      await e.give(40);
      await e.svc.buyItem(_tailwind, _at(1));
      await expectLater(e.svc.useTravelEffect(_tailwind, _at(1)), _blocked(ShopBlock.noWalk));
      expect((await e.svc.shopHeld())[_tailwind], 1);
    });

    test('순풍: 이번 걷는 중의 실제 거리 20%, 창 밖 걸음은 안 친다, 하루 1번', () async {
      final e = await _journey(60);
      await e.give(80);
      await e.svc.buyItem(_tailwind, _at(0));
      await e.svc.buyItem(_tailwind, _at(0));
      // 창 앞에서 10분, 창 안에서 50분 (4,200m), 창 뒤에서 10분
      e.source.records.addAll([
        _walk(_at(0), 10),
        _walk(_at(20), 50),
        _walk(_at(80), 10),
      ]);
      final id = await e.svc.startAppWalk(_at(20));
      await e.svc.useTravelEffect(_tailwind, _at(21));
      final use = (await e.uses()).single;
      expect(use.appWalkId, id);
      await expectLater(e.svc.useTravelEffect(_tailwind, _at(22)), _blocked(ShopBlock.dailyLimit));

      await e.svc.finishAppWalk(id, _at(70));
      await e.svc.sync(_at(95));
      final km = (await e.uses()).single.km;
      expect(km, closeTo(4.2 * 0.2, 1e-9));
      final day = await e.day();
      expect(day.shopM, closeTo(840, 1e-9));
      expect(day.travelM, closeTo(day.distanceM + day.bonusM + 840, 1e-9));
    });

    test('순풍을 걷기 끝 무렵에 켜도 이번 걷는 중 전체를 본다', () async {
      final e = await _journey(60);
      await e.give(40);
      await e.svc.buyItem(_tailwind, _at(0));
      e.source.records.add(_walk(_at(0), 50));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.sync(_at(50));
      await e.svc.useTravelEffect(_tailwind, _at(50));
      expect((await e.uses()).single.km, closeTo(4.2 * 0.2, 1e-9));
      await e.svc.finishAppWalk(id, _at(50));
    });

    test('하루 3km 상한: 지름길 2 + 순풍 5km 걷기 → 2 + 1 = 3', () async {
      final e = await _journey(60);
      await e.give(140);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_tailwind, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      // 60분 5,040m → 1.008km인데 상한에서 1km로 잘린다
      e.source.records.add(_walk(_at(0), 60));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.finishAppWalk(id, _at(60));
      await e.svc.sync(_at(61));

      final km = {for (final u in await e.uses()) u.id: u.km}.values.toList()..sort();
      expect(km, [1.0, 1.0, 1.0]);
      final day = await e.day();
      expect(day.shopM, closeTo(3000, 1e-9));
      expect(day.travelM, closeTo(day.distanceM + day.bonusM + 3000, 1e-9));
    });

    test('순풍이 상한을 다 채웠으면 지름길을 막고, 조금 남았으면 남은 만큼만 더한다', () async {
      final e = await _journey(60);
      await e.give(90);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_tailwind, _at(0));
      // 155분 13,020m → 순풍 2.604km
      e.source.records.add(_walk(_at(0), 155));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.finishAppWalk(id, _at(155));
      await e.svc.sync(_at(156));
      expect((await e.uses()).single.km, closeTo(2.604, 1e-9));

      await e.svc.useTravelEffect(_shortcut, _at(156));
      final byItem = {for (final u in await e.uses()) u.itemId: u.km};
      expect(byItem[_shortcut], closeTo(3 - 2.604, 1e-9));
      expect(byItem[_tailwind], closeTo(2.604, 1e-9));
      expect((await e.day()).shopM, closeTo(3000, 1e-9));

      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(157));
      await expectLater(e.svc.useTravelEffect(_shortcut, _at(157)), _blocked(ShopBlock.dailyCap));
      expect((await e.svc.shopHeld())[_shortcut], 1);
    });

    test('다시 계산해도 같은 값이다', () async {
      final e = await _journey(60);
      await e.give(140);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_tailwind, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      e.source.records.add(_walk(_at(0), 60));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.finishAppWalk(id, _at(60));
      await e.svc.sync(_at(61));
      final before = await e.dump();
      final progress = await e.progressKm(_at(61));

      await e.svc.sync(_at(62));
      await e.svc.sync(_at(63));
      expect(await e.dump(), before);
      expect(await e.progressKm(_at(63)), closeTo(progress, 1e-9));
    });

    test('건강 기록이 늦게 들어오면 순풍이 따라 늘어난다', () async {
      final e = await _journey(60);
      await e.give(40);
      await e.svc.buyItem(_tailwind, _at(0));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.finishAppWalk(id, _at(50));
      await e.svc.sync(_at(51));
      expect((await e.uses()).single.km, 0);

      e.source.records.add(_walk(_at(0), 50));
      await e.svc.sync(_at(52));
      expect((await e.uses()).single.km, closeTo(0.84, 1e-9));
      expect((await e.day()).shopM, closeTo(840, 1e-9));
    });

    test('걸음이 빠진 기록으로 다시 동기화해도 순풍이 줄지 않는다', () async {
      final e = await _journey(60);
      await e.give(40);
      await e.svc.buyItem(_tailwind, _at(0));
      e.source.records.add(_walk(_at(0), 50));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.finishAppWalk(id, _at(50));
      await e.svc.sync(_at(51));
      expect((await e.uses()).single.km, closeTo(0.84, 1e-9));
      final progress = await e.progressKm(_at(51));

      e.source.records.clear();
      await e.svc.sync(_at(52));
      expect((await e.uses()).single.km, closeTo(0.84, 1e-9));
      expect((await e.day()).shopM, closeTo(840, 1e-9));
      // 걸은 거리는 줄어도 효과 몫은 남는다
      expect(await e.progressKm(_at(52)), closeTo(0.84, 1e-9));
      expect(progress, greaterThan(0.84));
    });

    test('순풍은 여정이 끝난 뒤의 걸음을 치지 않는다', () async {
      final e = await _journey(60);
      await e.give(40);
      await e.svc.buyItem(_tailwind, _at(0));
      e.source.records.add(_walk(_at(0), 50));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.sync(_at(25));
      expect(await e.svc.stopJourney(_at(25)), isTrue);
      final atStop = (await e.uses()).single.km;
      expect(atStop, closeTo(84 * 25 * 0.2 / 1000, 1e-9));

      await e.svc.finishAppWalk(id, _at(50));
      await e.svc.sync(_at(51));
      expect((await e.uses()).single.km, closeTo(atStop, 1e-9));
    });
  });

  group('여정 진행', () {
    test('효과로 도착하면 쓰는 자리에서 바로 도착을 처리한다', () async {
      final e = await _journey(0.5);
      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(1));
      await e.svc.useTravelEffect(_shortcut, _at(1));
      final journeys = await e.db.select(e.db.journeys).get();
      expect(journeys.last.status, JourneyStatus.arrived);
      expect((await e.svc.snapshot(_at(1))).journey, isNull);
      expect(await e.svc.paintings(), hasLength(1));
    });

    test('도착해 버렸으면 효과를 쓰지 않고 막는다', () async {
      final e = await _journey(1);
      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(0));
      e.source.records.add(_walk(_at(0), 20));
      await expectLater(e.svc.useTravelEffect(_shortcut, _at(30)), _blocked(ShopBlock.noJourney));
      expect(await e.svc.shopHeld(), {_shortcut: 1});
    });

    test('효과로 넘친 거리는 경비에 안 더하고, 걸어서 넘친 거리만 더한다', () async {
      final e = await _journey(10);
      final total = (await e.svc.snapshot(_at(0))).journey!.totalKm;
      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));

      // 걷기만으로는 도착하지 못하고 효과를 더해 넘친다: 경비 0
      final minutes = ((total - 0.5) * 1000 / 84).floor();
      e.source.records.add(_walk(_at(1), minutes));
      await e.svc.sync(_at(1 + minutes + 1));
      expect((await e.svc.snapshot(_at(1 + minutes + 1))).journey, isNull);
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(0, 1e-9));
    });

    test('걸어서도 넘치면 걸어서 넘친 만큼은 경비로 간다', () async {
      final e = await _journey(10);
      final total = (await e.svc.snapshot(_at(0))).journey!.totalKm;
      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));

      final minutes = ((total + 0.5) * 1000 / 84).ceil();
      e.source.records.add(_walk(_at(1), minutes));
      await e.svc.sync(_at(1 + minutes + 1));
      final walkedKm = minutes * 84 / 1000;
      expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(walkedKm - total, 1e-6));
    });

    test('디버그 거리 배수는 효과에 안 곱하고, 넘친 거리는 효과를 뺀 뒤 되돌린다', () async {
      final e = await _journey(10, scale: 10);
      final total = (await e.svc.snapshot(_at(0))).journey!.totalKm;
      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      expect(await e.progressKm(_at(0)), closeTo(1, 1e-9));

      // 걸은 거리 × 10이 전체를 넘게: 넘친 거리 = 걸은 거리 × 10 + 효과 1 − 전체
      final minutes = ((total + 1) * 1000 / 84 / 10).ceil();
      e.source.records.add(_walk(_at(1), minutes));
      await e.svc.sync(_at(minutes + 2));
      final scaledKm = minutes * 84 / 1000 * 10;
      expect((await e.svc.snapshot(_at(minutes + 2))).journey, isNull);
      expect(
        (await e.db.select(e.db.travelFund).getSingle()).km,
        closeTo((scaledKm - total) / 10, 1e-6),
      );
    });

    test('멈춘 자리는 효과까지 간 자리이고, 새 여정에는 효과가 이어지지 않는다', () async {
      final e = await _journey(60);
      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(1));
      await e.svc.useTravelEffect(_shortcut, _at(1));
      final j = (await e.svc.snapshot(_at(1))).position!;
      await e.svc.stopJourney(_at(2));
      final stopped = (await e.svc.snapshot(_at(2))).position!;
      expect(stopped.lat, closeTo(j.lat, 1e-9));

      await e.svc.startJourney('kr003', _at(3), useFund: false);
      expect(await e.progressKm(_at(3)), closeTo(0, 1e-9));
    });
  });

  group('효과가 안 들어가는 곳', () {
    test('액자: 효과로 도착해도 실제 거리로 가린다', () async {
      final e = await _journey(21);
      final total = (await e.svc.snapshot(_at(0))).journey!.totalKm;
      expect(total, closeTo(21, 0.2));
      expect(rules.frameSilverKm, 20);
      await e.give(100);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));

      // 실제 거리는 20km 아래인데 효과 2km를 더해 도착한다
      final minutes = ((total - 2 + 0.2) * 1000 / 84).ceil();
      expect(minutes * 84 / 1000, lessThan(20));
      e.source.records.add(_walk(_at(1), minutes));
      await e.svc.sync(_at(minutes + 2));
      final painting = (await e.svc.paintings()).single;
      expect(painting.frame, Frame.wood);
    });

    group('도장 한 여정 100km', () {
      const badge = 'b_journey_100';

      Future<bool> has(_Env e) async =>
          (await e.db.select(e.db.badgesOwned).get()).any((r) => r.badgeId == badge);

      /// 여정을 [fundKm]까지 가 있게 둔다
      Future<void> fundTo(_Env e, double fundKm) =>
          (e.db.update(e.db.journeys)..where((t) => t.status.equalsValue(JourneyStatus.active)))
              .write(JourneysCompanion(fundKm: Value(fundKm)));

      Future<void> useShortcut(_Env e) async {
        await e.give(50);
        await e.svc.buyItem(_shortcut, _at(0));
        await e.svc.useTravelEffect(_shortcut, _at(0));
      }

      test('진행 중: 효과를 빼면 100km가 안 되면 안 준다', () async {
        final e = await _journey(150);
        await fundTo(e, 99.5);
        await useShortcut(e);
        expect(await e.progressKm(_at(1)), closeTo(100.5, 1e-9));
        await e.svc.sync(_at(1));
        expect(await has(e), isFalse);
      });

      test('멈춤: 멈춘 지점까지의 길이에서 효과를 뺀다', () async {
        final e = await _journey(150);
        await fundTo(e, 99.5);
        await useShortcut(e);
        await e.svc.stopJourney(_at(1));
        await e.svc.sync(_at(2));
        expect(await has(e), isFalse);
      });

      test('도착: 여정 환산 거리에서 효과를 뺀다', () async {
        final e = await _journey(100.4);
        final total = (await e.svc.snapshot(_at(0))).journey!.totalKm;
        expect(total, inExclusiveRange(100, 101));
        await fundTo(e, total - 0.5);
        await useShortcut(e);
        expect((await e.svc.snapshot(_at(1))).journey, isNull);
        await e.svc.sync(_at(2));
        expect(await has(e), isFalse);
      });

      test('효과 없이 100km면 진행 중·도착 모두 준다', () async {
        final walking = await _journey(150);
        await fundTo(walking, 100.5);
        await walking.svc.sync(_at(1));
        expect(await has(walking), isTrue);

        final arrived = await _journey(100.4);
        final total = (await arrived.svc.snapshot(_at(0))).journey!.totalKm;
        await fundTo(arrived, total);
        await arrived.svc.sync(_at(1));
        expect(await has(arrived), isTrue);
      });

      test('효과가 거리보다 커도 0 아래로 내려가지 않는다', () async {
        final e = await _journey(0.5);
        await e.give(50);
        await e.svc.buyItem(_shortcut, _at(0));
        await e.svc.useTravelEffect(_shortcut, _at(0));
        expect((await e.svc.snapshot(_at(1))).journey, isNull);
        expect(await has(e), isFalse);
        expect((await e.db.select(e.db.travelFund).getSingle()).km, closeTo(0, 1e-9));
      });
    });

    test('액자 기준에는 효과를 안 더한다 (같은 걸음이면 효과가 있어도 같은 등급)', () async {
      // 실제 20km를 넘겨 은 액자, 효과로 금 액자가 되지 않는다
      final e = await _journey(50.5);
      final total = (await e.svc.snapshot(_at(0))).journey!.totalKm;
      await e.give(100);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      final minutes = ((total - 1.5) * 1000 / 84).ceil();
      expect(minutes * 84 / 1000, lessThan(rules.frameGoldKm));
      e.source.records.add(_walk(_at(1), minutes));
      await e.svc.sync(_at(minutes + 2));
      expect((await e.svc.paintings()).single.frame, Frame.silver);
    });

    test('걷기 기록·누적 거리·걸음·소품 거리·럭에 안 들어간다', () async {
      final e = await _journey(60);
      e.source.records.add(_walk(_at(0), 60));
      await e.svc.sync(_at(60));
      final before = await e.day();
      final coinsBefore = before.coins;
      final record = await e.svc.walkRecord(_at(0), _at(60));
      final snapBefore = await e.svc.snapshot(_at(60));

      await e.give(50);
      await e.svc.buyItem(_shortcut, _at(60));
      await e.svc.useTravelEffect(_shortcut, _at(60));

      final after = await e.day();
      expect(after.shopM, 1000);
      expect(after.travelM, closeTo(before.travelM + 1000, 1e-9));
      expect(after.distanceM, before.distanceM);
      expect(after.steps, before.steps);
      expect(after.walkTravelM, before.walkTravelM);
      expect(after.coins, coinsBefore);
      final again = await e.svc.walkRecord(_at(0), _at(60));
      expect(again.travelM, record.travelM);
      final snap = await e.svc.snapshot(_at(60));
      expect(snap.totalKm, snapBefore.totalKm);
      expect(snap.totalSteps, snapBefore.totalSteps);
      expect(snap.walkTravelKm, snapBefore.walkTravelKm);
      // 방명록 걸음 숫자 기회도 그대로
      expect(snap.guestbookTicket?.id, snapBefore.guestbookTicket?.id);
    });
  });

  group('보상 배', () {
    Future<void> own(_Env e, String landmarkId) =>
        e.db.into(e.db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
              landmarkId: landmarkId,
              visits: 1,
              frame: Frame.wood,
              bestKm: 1,
              firstArrivedUtc: 1,
              lastArrivedUtc: 1,
            ));

    test('육지 명소·내 동네 스케치로는 받지 않는다', () async {
      final e = await _env();
      await own(e, 'kr001');
      await own(e, sketchId);
      final report = await e.svc.sync(_t1);
      expect(report.newBoats, isEmpty);
      expect(await e.db.select(e.db.boatsOwned).get(), isEmpty);
    });

    test('제주 도착 동기화에서 조각배, 울릉까지 가면 돛단배, 한 번 받으면 끝', () async {
      final e = await _env();
      final seen = <List<Boat>>[];
      final sub = e.svc.newBoats.listen(seen.add);
      addTearDown(sub.cancel);

      await e.svc.startJourney('kr009', _t1, useFund: false);
      await (e.db.update(e.db.journeys)..where((t) => t.destId.equals('kr009')))
          .write(const JourneysCompanion(fundKm: Value(1000)));
      final first = await e.svc.sync(_at(1));
      expect(first.newBoats.map((b) => b.id), ['boat_skiff']);
      expect((await e.svc.selectedBoat())!.id, 'boat_raft');

      final again = await e.svc.sync(_at(2));
      expect(again.newBoats, isEmpty);

      await own(e, 'kr089');
      final second = await e.svc.sync(_at(3));
      expect(second.newBoats.map((b) => b.id), ['boat_voyage']);
      expect(await e.svc.ownedBoatIds(), containsAll(['boat_raft', 'boat_skiff', 'boat_voyage']));

      await pumpEventQueue();
      expect(seen.map((b) => b.map((x) => x.id).toList()), [
        ['boat_skiff'],
        ['boat_voyage'],
      ]);
    });

    test('제주 두 곳은 돛단배가 아니다', () async {
      final e = await _env();
      await own(e, 'kr009');
      await own(e, 'kr010');
      final report = await e.svc.sync(_t1);
      expect(report.newBoats.map((b) => b.id), ['boat_skiff']);
    });
  });

  group('배 고르기', () {
    test('처음은 기본 배, 가진 배만 고른다', () async {
      final e = await _env();
      expect((await e.svc.selectedBoat())!.id, shopCatalog.defaultBoat);
      await expectLater(e.svc.chooseBoat('boat_cruise'), _blocked(ShopBlock.notOwned));

      await e.give(5000);
      await e.svc.buyItem('boat_cruise', _t1);
      await e.svc.chooseBoat('boat_cruise');
      expect((await e.svc.selectedBoat())!.id, 'boat_cruise');
      final profile = await e.db.select(e.db.profile).getSingle();
      expect(profile.boatId, 'boat_cruise');
      expect(profile.homeName, testHomeName);

      await e.svc.chooseBoat('boat_raft');
      expect((await e.svc.selectedBoat())!.id, 'boat_raft');
    });

    test('데이터에 없는 배가 적혀 있으면 기본 배로 그린다', () async {
      final e = await _env();
      await e.db
          .into(e.db.profile)
          .insertOnConflictUpdate(const ProfileCompanion(id: Value(1), boatId: Value('gone')));
      expect((await e.svc.selectedBoat())!.id, shopCatalog.defaultBoat);
    });

    test('상점 데이터가 없으면 배도 없다', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final svc = SyncService(
        db: db,
        source: FakeStepSource(),
        rules: rules,
        allowedSources: const [],
        landmarks: _landmarks,
        props: props,
      );
      expect(await svc.selectedBoat(), isNull);
      expect(await svc.ownedBoatIds(), isEmpty);
      await expectLater(svc.buyItem(_shortcut, _t1), _blocked(ShopBlock.unknownItem));
      final report = await svc.sync(_t1);
      expect(report.newBoats, isEmpty);
    });
  });

  group('백업', () {
    Future<_Env> restored(_Env from, DateTime now) async {
      final text = await BackupService(from.db, rules).exportBackup(now);
      final other = _Env();
      addTearDown(other.db.close);
      await BackupService(other.db, rules).restoreBackup(text);
      return other;
    }

    test('왕복: 잔액·보관함·사용 기록·배·고른 배·진행 거리가 그대로다', () async {
      final e = await _journey(60);
      await e.give(5500);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.buyItem(_tailwind, _at(0));
      await e.svc.buyItem('boat_cruise', _at(0));
      await e.svc.chooseBoat('boat_cruise');
      await e.svc.useTravelEffect(_shortcut, _at(0));
      e.source.records.add(_walk(_at(0), 60));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.finishAppWalk(id, _at(60));
      await e.svc.sync(_at(65));
      final progress = await e.progressKm(_at(65));
      final uses = await e.uses();
      final shopM = (await e.day()).shopM;
      expect(uses.map((u) => u.km), [1.0, closeTo(5.04 * 0.2, 1e-9)]);

      final other = await restored(e, _at(65));
      Future<void> same() async {
        expect(await other.svc.coinBalance(), await e.svc.coinBalance());
        expect(await other.svc.shopHeld(), {_shortcut: 1});
        expect(await other.svc.ownedBoatIds(), await e.svc.ownedBoatIds());
        expect((await other.svc.selectedBoat())!.id, 'boat_cruise');
        expect(await other.uses(), uses);
        expect((await other.day()).shopM, shopM);
        expect(await other.progressKm(_at(70)), closeTo(progress, 1e-6));
      }

      await same();
      // 새 기기의 건강 앱에 기록이 없어도 복원한 날의 효과가 줄지 않고, 두 번 돌려도 같다
      await other.svc.sync(_at(70));
      await same();
      await other.svc.sync(_at(71));
      await same();
    });

    test('복원으로 걸음 분이 비어도 순풍이 줄지 않고, 다시 들어온 기록으로 두 번 세지 않는다', () async {
      final e = await _journey(60);
      await e.give(40);
      await e.svc.buyItem(_tailwind, _at(0));
      e.source.records.add(_walk(_at(0), 60));
      final id = await e.svc.startAppWalk(_at(0));
      await e.svc.useTravelEffect(_tailwind, _at(1));
      await e.svc.finishAppWalk(id, _at(60));
      await e.svc.sync(_at(65));
      final km = (await e.uses()).single.km;
      expect(km, closeTo(5.04 * 0.2, 1e-9));
      final progress = await e.progressKm(_at(65));

      final other = await restored(e, _at(65));
      expect(await other.db.select(other.db.stepMinutes).get(), isEmpty);
      Future<void> same(DateTime now) async {
        expect((await other.uses()).single.km, km);
        expect((await other.day()).shopM, closeTo(km * 1000, 1e-9));
        expect(await other.progressKm(now), closeTo(progress, 1e-6));
      }

      // 새 기기의 건강 앱에 기록이 없을 때
      await other.svc.sync(_at(70));
      await same(_at(70));
      // 일부만 있을 때
      other.source.records.add(_walk(_at(0), 30));
      await other.svc.sync(_at(71));
      await same(_at(71));
      // 모두 다시 들어왔을 때
      other.source.records
        ..clear()
        ..add(_walk(_at(0), 60));
      await other.svc.sync(_at(72));
      await same(_at(72));
    });

    test('복원한 뒤 산 것과 쓴 것은 이어서 쌓인다', () async {
      final e = await _journey(60);
      await e.give(100);
      await e.svc.buyItem(_shortcut, _at(0));
      await e.svc.useTravelEffect(_shortcut, _at(0));
      final other = await restored(e, _at(1));
      await other.svc.sync(_at(2));
      await other.svc.buyItem(_shortcut, _at(3));
      await other.svc.useTravelEffect(_shortcut, _at(3));
      expect(await other.svc.coinBalance(), 0);
      expect((await other.day()).shopM, 2000);
      expect(await other.progressKm(_at(3)), closeTo(2, 1e-6));
    });
  });

  test('경로 도우미: 약 N km 자리에서 출발한다', () async {
    final dest = _landmarks['kr001']!.latLng;
    final deg = 21 / (rules.earthRadiusKm * math.pi / 180);
    final total = buildRoute(LatLng(dest.lat - deg, dest.lng), dest, rules).totalEffectiveKm;
    expect(total, closeTo(21, 0.2));
  });
}
