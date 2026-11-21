import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/decor_place.dart';
import 'decor_service.dart';
import 'providers.dart';
import 'sync_service.dart';

// 쉼터 꾸미기 트랙(T15)의 프로바이더

/// 쉼터 꾸미기 자리 계산 (테마 camp_wide decor + config rest.decor). 테마나 규칙에 꾸미기가 없으면 null
final decorStageProvider = FutureProvider<DecorStage?>((ref) async {
  final rules = await ref.watch(rulesProvider.future);
  final camp = await ref.watch(campThemeProvider.future);
  return DecorStage.of(camp, rules.decor.place, screenHeightPx: rules.screenHeightPx);
});

/// 동기화가 꾸밈 물품을 줄 때 쓰는 값 (첫 그림 선물 자리는 테마의 이젤 첫 자리). 데이터가 없으면 null
final decorSeedProvider = FutureProvider<DecorSeed?>((ref) async {
  final rules = await ref.watch(rulesProvider.future);
  final catalog = await ref.watch(decorCatalogProvider.future);
  final stage = await ref.watch(decorStageProvider.future);
  final gift = rules.decor.firstSketchGift;
  return DecorSeed(
    catalog: catalog,
    gift: gift,
    giftAt: gift == null || stage == null ? null : stage.toRatio(stage.easelStart),
  );
});

final decorStoreProvider = Provider<DecorStore>((ref) => DecorStore(ref.watch(dbProvider)));

/// 가진·놓인 물품과 건 그림. 동기화·구매 뒤(snapshotProvider) 다시 읽는다.
/// 놓기·옮기기·뒤집기·치우기·그림 걸기는 화면에 먼저 보이고(기다리지 않음) 저장한다
final decorProvider = AsyncNotifierProvider<DecorController, DecorState>(DecorController.new);

class DecorController extends AsyncNotifier<DecorState> {
  DecorStore get _store => ref.read(decorStoreProvider);

  @override
  Future<DecorState> build() async {
    await ref.watch(snapshotProvider.future);
    return ref.watch(decorStoreProvider).load();
  }

  DecorState get _now => state.value ?? DecorState.empty;

  /// [decorId]를 [ratio] 자리에 놓거나 옮긴다. 이미 최대로 놓였으면 [DecorRefused]
  Future<void> place(String decorId, DecorRatio ratio, {required bool flipped, required int maxPlaced}) async {
    final now = ref.read(clockProvider)();
    final was = _now;
    if (!was.placed.containsKey(decorId) && was.placed.length >= maxPlaced) {
      throw const DecorRefused(DecorRefusal.full);
    }
    final spot = PlacedDecor(
      xRatio: ratio.x,
      yRatio: ratio.y,
      flipped: flipped,
      placedUtc: now.toUtc().millisecondsSinceEpoch,
    );
    state = AsyncData(was.copyWith(placed: {...was.placed, decorId: spot}));
    await _save(() => _store.place(decorId,
        xRatio: ratio.x, yRatio: ratio.y, flipped: flipped, maxPlaced: maxPlaced, now: now));
  }

  Future<void> flip(String decorId) async {
    final was = _now;
    final p = was.placed[decorId];
    if (p == null) return;
    final next = PlacedDecor(xRatio: p.xRatio, yRatio: p.yRatio, flipped: !p.flipped, placedUtc: p.placedUtc);
    state = AsyncData(was.copyWith(placed: {...was.placed, decorId: next}));
    await _save(() => _store.flip(decorId, next.flipped));
  }

  /// 서랍으로 치운다
  Future<void> remove(String decorId) async {
    final was = _now;
    if (!was.placed.containsKey(decorId)) return;
    state = AsyncData(was.copyWith(placed: {...was.placed}..remove(decorId)));
    await _save(() => _store.remove(decorId));
  }

  /// [decorId]의 [slot] 칸에 [paintingKey]를 건다 (null이면 내림)
  Future<void> hang(String decorId, int slot, String? paintingKey, {required int slots}) async {
    final was = _now;
    final mine = {...?was.paintings[decorId]};
    if (paintingKey == null) {
      mine.remove(slot);
    } else {
      mine[slot] = paintingKey;
    }
    state = AsyncData(was.copyWith(paintings: {...was.paintings, decorId: mine}));
    await _save(() => _store.hang(decorId, slot, paintingKey, slots: slots));
  }

  /// 저장하고, 실패하면 저장된 값으로 되돌린 뒤 다시 던진다
  Future<void> _save(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      state = AsyncData(await _store.load());
      rethrow;
    }
  }
}

/// 꾸밈 물품 목록이 있고 테마·규칙에 꾸미기 자리가 있는가 (쉼터 옆 버튼 ‘쉼터 꾸미기’를 그린다)
final decorEnabledProvider = Provider<bool>((ref) {
  final stage = ref.watch(decorStageProvider).value;
  final catalog = ref.watch(decorCatalogProvider).value;
  return stage != null && catalog != null && catalog.items.isNotEmpty;
});

/// 완결 동행 돌아다니기(가는 곳·멈춤·앉기)와 말풍선 한마디를 고르는 난수. 시험은 씨앗을 준다
final finaleRoamRandomProvider = Provider<math.Random>((ref) => math.Random());
