import 'package:drift/drift.dart';

import '../data/db/app_db.dart';

// 쉼터 꾸밈 물품 저장 (스키마 21 decor_owned·decor_placed·decor_paintings, M2~M6 AB 가안, T15).
// 얻기는 동기화(sync_decor.dart)·상점(sync_shop.dart)이 하고, 여기서는 놓기·옮기기·뒤집기·치우기·그림 걸기만

/// 놓인 물품 하나 (장면 비율: x ÷ 장면 폭, 발 y는 땅 띠 안 비율)
class PlacedDecor {
  const PlacedDecor({required this.xRatio, required this.yRatio, this.flipped = false, this.placedUtc = 0});

  final double xRatio;
  final double yRatio;
  final bool flipped;
  final int placedUtc;

  @override
  bool operator ==(Object other) =>
      other is PlacedDecor &&
      other.xRatio == xRatio &&
      other.yRatio == yRatio &&
      other.flipped == flipped &&
      other.placedUtc == placedUtc;

  @override
  int get hashCode => Object.hash(xRatio, yRatio, flipped, placedUtc);
}

/// 쉼터 꾸미기 지금 상태
class DecorState {
  const DecorState({this.owned = const {}, this.placed = const {}, this.paintings = const {}});

  static const empty = DecorState();

  /// 가진 물품 id → 얻은 시각 (epoch ms)
  final Map<String, int> owned;

  /// 놓인 물품 id → 자리. 가졌는데 여기 없으면 서랍에 있다
  final Map<String, PlacedDecor> placed;

  /// 물품 id → 칸 번호 → 건 그림 (landmarkId, 첫 그림은 'sketch')
  final Map<String, Map<int, String>> paintings;

  /// 서랍에 있는 물품 (가졌고 안 놓은 것), 얻은 순서
  List<String> get drawer => [
        for (final e in owned.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
          if (!placed.containsKey(e.key)) e.key,
      ];

  DecorState copyWith({
    Map<String, int>? owned,
    Map<String, PlacedDecor>? placed,
    Map<String, Map<int, String>>? paintings,
  }) =>
      DecorState(
        owned: owned ?? this.owned,
        placed: placed ?? this.placed,
        paintings: paintings ?? this.paintings,
      );
}

/// 꾸미기를 못 하는 까닭
enum DecorRefusal {
  /// 가지지 않은 물품
  notOwned,

  /// 쉼터에 놓은 물품이 이미 최대 (config rest.decor.maxPlaced)
  full,

  /// 그 물품에 없는 칸
  noSlot,
}

class DecorRefused implements Exception {
  const DecorRefused(this.why);

  final DecorRefusal why;

  @override
  String toString() => 'DecorRefused($why)';
}

/// 꾸밈 물품 표 읽고 쓰기
class DecorStore {
  DecorStore(this.db);

  final AppDb db;

  Future<DecorState> load() async {
    final owned = {for (final r in await db.select(db.decorOwned).get()) r.decorId: r.gotUtc};
    final placed = {
      for (final r in await db.select(db.decorPlaced).get())
        if (owned.containsKey(r.decorId))
          r.decorId: PlacedDecor(xRatio: r.xRatio, yRatio: r.yRatio, flipped: r.flipped, placedUtc: r.placedUtc),
    };
    final paintings = <String, Map<int, String>>{};
    for (final r in await db.select(db.decorPaintings).get()) {
      (paintings[r.decorId] ??= {})[r.slot] = r.paintingKey;
    }
    return DecorState(owned: owned, placed: placed, paintings: paintings);
  }

  /// [decorId]를 그 자리에 놓거나 옮긴다 (놓으면 저절로 저장, config rest.decor.save onDrop).
  /// 서랍에서 새로 놓을 때 이미 [maxPlaced]개 놓였으면 [DecorRefused] full
  Future<void> place(
    String decorId, {
    required double xRatio,
    required double yRatio,
    required bool flipped,
    required int maxPlaced,
    required DateTime now,
  }) =>
      db.transaction(() async {
        await _requireOwned(decorId);
        final was = await _placedRow(decorId);
        if (was == null) {
          final count = await db.decorPlaced.count().getSingle();
          if (count >= maxPlaced) throw const DecorRefused(DecorRefusal.full);
        }
        await db.into(db.decorPlaced).insertOnConflictUpdate(DecorPlacedCompanion.insert(
              decorId: decorId,
              xRatio: xRatio,
              yRatio: yRatio,
              flipped: Value(flipped),
              // 옮겨도 놓은 시각은 지금 (같은 발 y면 나중에 놓은 것이 앞)
              placedUtc: now.toUtc().millisecondsSinceEpoch,
            ));
      });

  /// 좌우 뒤집기 (놓인 물품만, 자리·앞뒤는 그대로)
  Future<void> flip(String decorId, bool flipped) =>
      (db.update(db.decorPlaced)..where((t) => t.decorId.equals(decorId)))
          .write(DecorPlacedCompanion(flipped: Value(flipped)));

  /// 서랍으로 치운다. 건 그림은 남겨 두어 다시 놓으면 그대로 걸려 있다
  Future<void> remove(String decorId) =>
      (db.delete(db.decorPlaced)..where((t) => t.decorId.equals(decorId))).go();

  /// [decorId]의 [slot] 칸에 그림 [paintingKey]를 건다. null이면 내린다. [slots]는 그 물품의 칸 수
  Future<void> hang(String decorId, int slot, String? paintingKey, {required int slots}) =>
      db.transaction(() async {
        await _requireOwned(decorId);
        if (slot < 0 || slot >= slots) throw const DecorRefused(DecorRefusal.noSlot);
        final row = db.decorPaintings;
        if (paintingKey == null) {
          await (db.delete(row)..where((t) => t.decorId.equals(decorId) & t.slot.equals(slot))).go();
          return;
        }
        await db.into(row).insertOnConflictUpdate(
            DecorPaintingsCompanion.insert(decorId: decorId, slot: slot, paintingKey: paintingKey));
      });

  Future<DecorPlacedRow?> _placedRow(String decorId) =>
      (db.select(db.decorPlaced)..where((t) => t.decorId.equals(decorId))).getSingleOrNull();

  Future<void> _requireOwned(String decorId) async {
    final row = await (db.select(db.decorOwned)..where((t) => t.decorId.equals(decorId))).getSingleOrNull();
    if (row == null) throw const DecorRefused(DecorRefusal.notOwned);
  }
}
