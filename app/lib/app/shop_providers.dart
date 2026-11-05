import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/boat.dart';
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

/// 배 구간 장면이 읽을 그림 경로와 자리
final sceneBoatProvider = FutureProvider<BoatArt?>((ref) async {
  final boat = await ref.watch(selectedBoatProvider.future);
  if (boat == null) return null;
  return (await ref.watch(boatCatalogProvider.future)).artOf(boat);
});
