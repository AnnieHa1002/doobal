import 'package:doobal/app/backup_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/shop.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 상점 배 색 저장 (T4c, BoatsOwned.colors, recolorRule.save·price 0)

class _Env {
  _Env() : db = AppDb(NativeDatabase.memory()) {
    svc = SyncService(
      db: db,
      source: FakeStepSource(),
      rules: rules,
      allowedSources: const [],
      landmarks: {for (final l in landmarks) l.id: l},
      props: props,
      milestones: milestones,
      eventCatalog: eventCatalog,
      shopCatalog: shopCatalog,
      boatCatalog: boatCatalog,
    );
  }

  final AppDb db;
  late final SyncService svc;

  Future<void> own(String boatId, [String? colors]) => db
      .into(db.boatsOwned)
      .insert(BoatsOwnedCompanion.insert(boatId: boatId, atUtc: 1, colors: Value(colors)));

  Future<String?> stored(String boatId) async =>
      (await (db.select(db.boatsOwned)..where((t) => t.boatId.equals(boatId))).getSingle()).colors;
}

Future<_Env> _env() async {
  final e = _Env();
  addTearDown(e.db.close);
  await e.svc.sync(DateTime.utc(2026, 11, 18));
  return e;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('색을 바꿀 수 있는 배 = 가진 상점 배 (기본 뗏목·보상 배는 아님)', () async {
    final e = await _env();
    expect(await e.svc.colorableBoats(), isEmpty);
    await e.own('boat_skiff');
    await e.own('boat_canopy');
    await e.own('boat_cruise');
    expect([for (final b in await e.svc.colorableBoats()) b.id], ['boat_cruise', 'boat_canopy']);
  });

  test('저장·읽기: 고른 구역만 JSON, 원래 색으로 돌리면 null, 럭은 그대로 (무료)', () async {
    final e = await _env();
    await e.own('boat_cruise');
    expect(await e.svc.boatColors('boat_cruise'), BoatColors.none);
    const colors = BoatColors({BoatZone.hull: SwatchBodyColor(9), BoatZone.accent: CustomBodyColor('#102030')});
    final before = await e.svc.coinBalance();
    await e.svc.setBoatColors('boat_cruise', colors);
    expect(await e.stored('boat_cruise'),
        '{"hull":{"kind":"swatch","i":9},"accent":{"kind":"custom","hex":"#102030"}}');
    expect(await e.svc.boatColors('boat_cruise'), colors);
    expect(await e.svc.coinBalance(), before);
    await e.svc.setBoatColors('boat_cruise', BoatColors.none);
    expect(await e.stored('boat_cruise'), isNull);
  });

  test('가진 상점 배가 아니면 notOwned, 색 자료가 없는 배(보상 배·뗏목)는 unknownItem', () async {
    final e = await _env();
    const colors = BoatColors({BoatZone.hull: SwatchBodyColor(1)});
    await expectLater(e.svc.setBoatColors('boat_cruise', colors),
        throwsA(isA<ShopBlocked>().having((b) => b.block, 'block', ShopBlock.notOwned)));
    await e.own('boat_skiff');
    await expectLater(e.svc.setBoatColors('boat_skiff', colors),
        throwsA(isA<ShopBlocked>().having((b) => b.block, 'block', ShopBlock.unknownItem)));
    await expectLater(e.svc.setBoatColors('boat_raft', colors),
        throwsA(isA<ShopBlocked>().having((b) => b.block, 'block', ShopBlock.unknownItem)));
  });

  test('저장 글이 틀려도 원래 색으로 읽는다 (배 구간이 멈추지 않게)', () async {
    final e = await _env();
    await e.own('boat_pirate', '{"hull":{"kind":"paint"}}');
    expect(await e.svc.boatColors('boat_pirate'), BoatColors.none);
  });

  test('백업 왕복: 고른 배 색이 같이 간다', () async {
    final e = await _env();
    await e.own('boat_speed', '{"upper":{"kind":"swatch","i":4}}');
    final json = await BackupService(e.db, rules).exportBackup(DateTime.utc(2026, 11, 19));
    final other = _Env();
    addTearDown(other.db.close);
    await BackupService(other.db, rules).restoreBackup(json);
    expect(await other.stored('boat_speed'), '{"upper":{"kind":"swatch","i":4}}');
  });
}
