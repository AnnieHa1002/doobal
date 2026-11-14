import 'package:doobal/app/providers.dart';
import 'package:doobal/app/shop_providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 상점 프로바이더와 걷는 중 화면의 배 연결

const _day = '2026-11-18';

Future<void> _ownCruise(UiEnv e) async {
  await e.db
      .into(e.db.boatsOwned)
      .insert(BoatsOwnedCompanion.insert(boatId: 'boat_cruise', atUtc: 1));
  await e.db
      .into(e.db.profile)
      .insertOnConflictUpdate(const ProfileCompanion(id: Value(1), boatId: Value('boat_cruise')));
}

void main() {
  testWidgets('프로바이더는 구매 뒤 snapshotProvider를 새로 읽으면 따라온다', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    final c = ProviderContainer(overrides: e.overrides);
    addTearDown(c.dispose);
    await tester.runAsync(() async {
      await e.db.into(e.db.coinLedger).insert(
            CoinLedgerCompanion.insert(day: _day, kind: CoinKind.gift, amount: 5050),
          );
      // 듣는 쪽이 있어야 다시 읽는다 (화면이 watch 하는 것과 같다)
      final subs = [
        c.listen(coinBalanceProvider, (_, _) {}),
        c.listen(shopHeldProvider, (_, _) {}),
        c.listen(ownedBoatIdsProvider, (_, _) {}),
        c.listen(sceneBoatProvider, (_, _) {}),
      ];
      expect(await c.read(coinBalanceProvider.future), 5050);
      expect(await c.read(shopHeldProvider.future), isEmpty);
      expect(await c.read(ownedBoatIdsProvider.future), {'boat_raft'});
      expect((await c.read(sceneBoatProvider.future))!.id, 'boat_raft');

      final svc = await c.read(syncServiceProvider.future);
      await svc.buyItem('fx_shortcut', e.now);
      await svc.buyItem('boat_cruise', e.now);
      await svc.chooseBoat('boat_cruise');
      c.invalidate(snapshotProvider);

      expect(await c.read(coinBalanceProvider.future), 0);
      expect(await c.read(shopHeldProvider.future), {'fx_shortcut': 1});
      expect(await c.read(ownedBoatIdsProvider.future), {'boat_raft', 'boat_cruise'});
      final art = (await c.read(sceneBoatProvider.future))!;
      expect(art.id, 'boat_cruise');
      expect(art.nightOverlay, isNotNull);
      for (final s in subs) {
        s.close();
      }
    });
  });

  testWidgets('걷는 중 화면은 고른 배를 장면에 넘긴다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _ownCruise(e);
      await e.svc.startJourney('kr003', t1);
    });
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await tester.pump();
    await startTrailNow(tester);
    await settle(tester, () => false, tries: 8);
    expect(find.byType(WalkingScreen), findsOneWidget);
    await settle(
      tester,
      () => tester.widget<SceneView>(find.byType(SceneView).last).boat != null,
    );
    expect(tester.widget<SceneView>(find.byType(SceneView).last).boat!.id, 'boat_cruise');
    await end(tester, e);
  });
}
