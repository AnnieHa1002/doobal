import 'package:doobal/domain/milestones.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('실제 목록은 23개, 오름차순', () {
    expect(milestones, hasLength(23));
    for (var i = 1; i < milestones.length; i++) {
      expect(milestones[i], greaterThan(milestones[i - 1]));
    }
  });

  test('0보 → 첫 숫자 100', () {
    expect(nextMilestone(0, milestones), 100);
  });

  test('숫자와 같으면 그 다음 (strictly greater)', () {
    expect(nextMilestone(99, milestones), 100);
    expect(nextMilestone(100, milestones), 1000);
    expect(nextMilestone(101, milestones), 1000);
    expect(nextMilestone(7777, milestones), 10000);
  });

  test('마지막 직전은 마지막, 마지막 이상은 null', () {
    expect(nextMilestone(1234566, milestones), 1234567);
    expect(nextMilestone(1234567, milestones), isNull);
    expect(nextMilestone(2000000, milestones), isNull);
  });

  test('빈 목록은 null', () {
    expect(nextMilestone(0, const []), isNull);
  });
}
