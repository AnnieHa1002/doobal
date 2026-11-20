import 'look.dart';
import 'map_album_rules.dart';

// 화집 소품 탭 바로 입기 (16장 11/19, config album.propsTab, 캔버스 6-1): 누르면 그 칸에 바로 입고(같은 칸은 바뀜),
// 입은 것을 다시 누르면 벗는다(옷은 벗지 않음). 저장은 꾸미기와 같은 착용 상태(Profile.look)

enum WearChange { worn, removed }

/// [look]에서 [slot] 칸의 소품 [propId]를 눌렀을 때 바뀐 모습과 무엇을 했는지. 바뀌는 게 없으면 null
/// (입은 옷을 다시 누름, 다시 눌러 벗기가 꺼짐, 바로 입기가 꺼짐)
({Look look, WearChange change})? tapToWear(
  Look look,
  String slot,
  String propId,
  PropsTabRules rules,
) {
  if (!rules.tapToWear) return null;
  if (look.slots[slot] != propId) {
    return (look: look.withSlot(slot, propId), change: WearChange.worn);
  }
  if (!rules.tapAgainRemoves || rules.neverRemove.contains(slot) || slot == alwaysWornSlot) {
    return null;
  }
  return (look: look.withSlot(slot, null), change: WearChange.removed);
}

/// 바로 입기 한 줄 토스트 (캔버스 6-1: ‘베레모 썼어요’·‘여행복 입었어요’·‘갈색 신발 신었어요’·‘큰 붓 멨어요’·
/// ‘종이새와 함께해요’·‘… 벗었어요’). 얼굴 소품·손·둥실·효과는 캔버스에 없어 가안
String wearToast(String name, String slot, WearChange change) {
  if (change == WearChange.removed) return '$name 벗었어요';
  return switch (slot) {
    'hat' || 'face' => '$name 썼어요',
    'shoe' => '$name 신었어요',
    'bag' => '$name 멨어요',
    'hand' => '$name 들었어요',
    'pet' || 'float' => '$name${_withParticle(name)} 함께해요',
    'effect' => '$name 달았어요',
    _ => '$name 입었어요',
  };
}

/// ‘와/과’: 마지막 글자에 받침이 있으면 과
String _withParticle(String name) {
  if (name.isEmpty) return '와';
  final c = name.codeUnitAt(name.length - 1) - 0xAC00;
  if (c < 0 || c > 11171) return '와';
  return c % 28 == 0 ? '와' : '과';
}
