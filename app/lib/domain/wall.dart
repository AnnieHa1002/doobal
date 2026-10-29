/// 화집 벽에 거는 액자 수 (DB 칸은 0 ~ wallSlots - 1)
const wallSlots = 4;

/// 칸 번호 → 명소 id를 벽 전체로 펴 준다. 안 건 칸은 null, 범위 밖 칸은 버린다
List<String?> wallFromSlots(Map<int, String> bySlot) =>
    [for (var i = 0; i < wallSlots; i++) bySlot[i]];

/// [slot]에 [landmarkId]를 건 새 벽. 그림은 한 점이 한 칸에만 있어서
/// 다른 칸에 있던 같은 그림은 비우고, 그 칸에 있던 다른 그림은 벽에서 내려간다
List<String?> placeOnWall(List<String?> wall, int slot, String landmarkId) {
  if (slot < 0 || slot >= wallSlots) throw RangeError.range(slot, 0, wallSlots - 1, 'slot');
  return [
    for (var i = 0; i < wallSlots; i++)
      if (i == slot) landmarkId else if (wall[i] == landmarkId) null else wall[i],
  ];
}

/// 걸 칸: 이미 걸려 있으면 그 칸, 아니면 첫 빈 칸, 벽이 가득 찼으면 null
int? slotToHang(List<String?> wall, String landmarkId) {
  final at = wall.indexOf(landmarkId);
  if (at >= 0) return at;
  final empty = wall.indexOf(null);
  return empty >= 0 ? empty : null;
}
