import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/boat.dart';
import 'providers.dart';
import 'sync_service.dart' show BoatColorSync;

/// [boatId]에 고른 배 색 (BoatsOwned.colors, 없으면 원래 색). 색 시트에서 저장하면 invalidate
final boatColorsProvider = FutureProvider.autoDispose.family<BoatColors, String>((ref, boatId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.boatColors(boatId);
});

/// 가진 배 중 색을 바꿀 수 있는 배 (상점 배, boats.json recolor)
final colorableBoatsProvider = FutureProvider.autoDispose<List<Boat>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.colorableBoats();
});
