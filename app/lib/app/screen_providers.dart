import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_db.dart';
import '../domain/shop_news.dart';
import 'providers.dart';

/// 화면 세부(T11)·쉼터 정령 자세(T5)가 쓰는 무작위. 시험은 고정 값으로 바꿔 끼운다

/// [count]개 중 하나(0부터)를 고른다
typedef PickOne = int Function(int count);

/// 정령 만들기에서 처음 골라져 있는 여행복 시작 색(props cloth_02.startColors 4색 중 무작위, 16장 11/15 A안)
final startClothPickProvider = Provider<PickOne>((ref) {
  final random = Random();
  return random.nextInt;
});

/// 쉼터 정령 자세 바꾸기(config character.rive.restSwap)의 무작위: 다음 자세·간격
final restSwapRandomProvider = Provider<Random>((ref) => Random());

/// 아직 안 본 새 상품 id (수레 알림 점, config ui.newDot.cartWhen newShopItem). 기본 소품을 얻어 색 소품이
/// 새로 보이게 되면 생기고, 상점을 열면 없어진다 ([markShopSeen]). 본 시각은 DB 19 `sync_state.shop_seen_utc`
/// (없으면 설치 시각)라 앱을 껐다 켜도 남는다. 동기화(snapshot)마다 다시 읽는다
final shopNewsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final db = ref.watch(dbProvider);
  await ref.watch(snapshotProvider.future);
  final props = await ref.watch(propsProvider.future);
  final owned = {for (final r in await db.select(db.propsOwned).get()) r.propId: r.unlockedUtc};
  final sync = await (db.select(db.syncState)..where((t) => t.id.equals(1))).getSingleOrNull();
  return newShopItems(props, owned, sync?.shopSeenUtc ?? sync?.installUtc);
});

/// 상점에 보이는 새 상품을 본 것으로 적는다 (상점 화면이 열려 있는 동안, 지금 시각)
Future<void> markShopSeen(WidgetRef ref) async {
  final news = ref.read(shopNewsProvider).value;
  if (news == null || news.isEmpty) return;
  final db = ref.read(dbProvider);
  final now = ref.read(clockProvider)();
  await (db.update(db.syncState)..where((t) => t.id.equals(1)))
      .write(SyncStateCompanion(shopSeenUtc: Value(now.toUtc().millisecondsSinceEpoch)));
  ref.invalidate(shopNewsProvider);
}
