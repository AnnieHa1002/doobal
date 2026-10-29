import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/ui/album/prop_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

Prop _prop(String id) => props.firstWhere((p) => p.id == id);

String? _howTo(String id, {double km = 0, int steps = 0, Set<String> visited = const {}}) =>
    propHowTo(_prop(id),
        totalKm: km, totalSteps: steps, progress: regionProgress(visited, landmarks));

void main() {
  test('거리: `누적 150km · 지금 87km`, 지금 거리는 버림', () {
    expect(_howTo('hand_03', km: 87), '누적 150km · 지금 87km');
    expect(_howTo('hand_03', km: 87.9), '누적 150km · 지금 87km');
    expect(_howTo('hand_03'), '누적 150km · 지금 0km');
  });

  test('거리 천 단위는 쉼표', () {
    expect(_howTo('hat_03', km: 120.4), '누적 1,000km · 지금 120km');
  });

  test('걸음: `누적 1,000,000보 · 지금 8,500보`', () {
    expect(_howTo('cloth_04', steps: 8500), '누적 1,000,000보 · 지금 8,500보');
  });

  test('권역: `전라 0/21` → 다녀온 만큼', () {
    expect(_howTo('hat_04'), '전라 0/21');
    final jeolla = [for (final l in landmarks) if (l.region == 'jeolla') l.id];
    expect(_howTo('hat_04', visited: jeolla.take(3).toSet()), '전라 3/21');
    expect(_howTo('pet_05'), '울릉 0/1');
    expect(_howTo('pet_02'), '수도권 0/12');
  });

  test('동료 소품: `동행 이야기 완결`', () {
    expect(_howTo('hat_10'), '동행 이야기 완결');
    expect(_howTo('hat_11'), '동행 이야기 완결');
    expect(_howTo('hand_09'), '동행 이야기 완결');
  });

  test('기본 소품은 방법이 없다', () {
    expect(_howTo('hat_01'), isNull);
  });

  test('MVP 27개 모두 기본이 아니면 한 줄이 나온다', () {
    for (final p in props) {
      final text = propHowTo(p, totalKm: 0, totalSteps: 0, progress: const {});
      expect(text == null, p.kind == PropUnlockKind.initial, reason: p.id);
    }
  });
}
