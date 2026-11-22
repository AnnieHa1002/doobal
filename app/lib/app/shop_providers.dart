import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/boat.dart';
import '../domain/shop_cart.dart';
import 'boat_providers.dart';
import 'providers.dart';
import 'sync_service.dart';

// 상점 트랙의 프로바이더. 모두 snapshotProvider를 따라 새로 읽으니, 구매·사용·배 고르기 뒤에는
// snapshotProvider를 invalidate 한다

/// 가진 럭
final coinBalanceProvider = FutureProvider<int>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.coinBalance();
});

/// 보관한 여행 효과 (상품 id → 개수)
final shopHeldProvider = FutureProvider<Map<String, int>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.shopHeld();
});

/// 가진 배 id (기본 배 포함)
final ownedBoatIdsProvider = FutureProvider<Set<String>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.ownedBoatIds();
});

/// 지금 타는 배
final selectedBoatProvider = FutureProvider<Boat?>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.selectedBoat();
});

/// 배 구간 장면이 읽을 그림 경로와 자리. 상점 배는 고른 색을 싣는다 (T4c, BoatsOwned.colors → 몸 색 견본으로 색)
final sceneBoatProvider = FutureProvider<BoatArt?>((ref) async {
  final boat = await ref.watch(selectedBoatProvider.future);
  if (boat == null) return null;
  final catalog = await ref.watch(boatCatalogProvider.future);
  if (boat.recolor == null) return catalog.artOf(boat);
  final colors = await ref.watch(boatColorsProvider(boat.id).future);
  final palette = (await ref.watch(spiritPaletteProvider.future)).body;
  return catalog.artOf(boat, colors: colors, argb: boatZoneArgb(colors, palette.argbOf));
});

/// 지금 수레 날 키 (config shop.cart.refreshHour, 한국 시간 새벽 5시에 바뀐다). 분마다 시계를 보지만 값은 날이
/// 바뀔 때만 달라져서, 이것을 읽는 수레는 새벽에 한 번 새로 읽는다
final cartDayProvider = Provider.autoDispose<String?>((ref) {
  final rules = ref.watch(rulesProvider).value;
  if (rules == null) return null;
  final now = ref.watch(minuteClockProvider).value ?? ref.read(clockProvider)();
  return rules.shopCart.dayOf(now);
});

/// 그날 수레 (상점 화면·쉼터 수레 위 물건·새 상품 점). 그날 줄이 없으면 이때 정해 저장한다.
/// 동기화(snapshot)마다 다시 읽어서 걸어서 얻은 물건의 칸도 팔림이 된다. 사기 뒤에는 snapshotProvider를 invalidate
final todayCartProvider = FutureProvider.autoDispose<TodayCart>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  ref.watch(cartDayProvider);
  return svc.todayCart(ref.read(clockProvider)());
});

/// 상점을 본 것으로 적는다 (새 상품 점이 꺼진다, 상점 화면이 열려 있는 동안 지금 시각). 상점을 열 때마다 적는다:
/// 연출 ③이 이 시각 뒤에 팔린 칸·열린 칸만 움직이게 (T19, 전에는 새 상품이 있을 때만 적었다)
Future<void> markShopSeen(WidgetRef ref) async {
  final svc = await ref.read(syncServiceProvider.future);
  await svc.markShopSeen(ref.read(clockProvider)());
  ref.invalidate(todayCartProvider);
}
