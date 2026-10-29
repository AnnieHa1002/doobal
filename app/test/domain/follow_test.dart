import 'package:doobal/domain/follow.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final refresh = rules.walkingRefreshSec.toDouble();

  test('config의 갱신 주기는 30초', () {
    expect(rules.walkingRefreshSec, 30);
  });

  test('걷는 속도가 남은 거리 ÷ 주기보다 크면 걷는 속도로 간다', () {
    // 남은 거리 15m ÷ 30초 = 0.5m/s < 1.2m/s
    expect(followDistance(100, 115, 1.2, 1, refresh), closeTo(101.2, 1e-9));
  });

  test('멈췄다 한꺼번에 들어온 거리는 남은 거리 ÷ 주기 속도로 따라잡는다', () {
    // 남은 거리 60m ÷ 30초 = 2m/s > 1.2m/s
    expect(followDistance(100, 160, 1.2, 1, refresh), closeTo(102, 1e-9));
  });

  test('목표를 넘지 않는다: 한 걸음이 남은 거리보다 크면 목표에서 멈춘다', () {
    expect(followDistance(100, 100.5, 1.2, 1, refresh), 100.5);
    expect(followDistance(100, 101, 1.2, 10, refresh), 101);
  });

  test('목표가 보이는 거리 이하면 가만히 있고 뒤로 가지 않는다', () {
    expect(followDistance(100, 100, 1.2, 1, refresh), 100);
    expect(followDistance(100, 90, 1.2, 1, refresh), 100);
    expect(followDistance(100, 0, 1.2, 1, refresh), 100);
  });

  test('시간이 0이거나 음수면 그대로', () {
    expect(followDistance(100, 200, 1.2, 0, refresh), 100);
    expect(followDistance(100, 200, 1.2, -1, refresh), 100);
  });

  test('멈췄을 때(걷던 속도가 남아 있다): 한 주기 안에 목표에 닿는다', () {
    // 걷다가 멈춘 사용자: 마지막 속도 1.2m/s, 아직 못 보인 거리 30m
    var shown = 0.0;
    const target = 30.0;
    for (var t = 0.0; t < refresh; t += 0.1) {
      final next = followDistance(shown, target, 1.2, 0.1, refresh);
      expect(next, greaterThanOrEqualTo(shown));
      expect(next, lessThanOrEqualTo(target));
      shown = next;
    }
    expect(shown, target);
  });

  test('속도 0이어도 뒤로 가거나 넘지 않고 계속 가까워진다 (주기마다 약 63%씩 줄어든다)', () {
    var shown = 0.0;
    const target = 30.0;
    var prevGap = target;
    for (var t = 0.0; t < refresh; t += 0.1) {
      shown = followDistance(shown, target, 0, 0.1, refresh);
      expect(target - shown, lessThan(prevGap));
      expect(shown, lessThan(target));
      prevGap = target - shown;
    }
    // 한 주기 뒤 남은 거리 ≈ e^-1
    expect((target - shown) / target, closeTo(0.368, 0.02));
  });

  test('목표가 계속 늘어도 보이는 거리는 줄지 않는다', () {
    var shown = 0.0;
    var target = 0.0;
    for (var i = 0; i < 600; i++) {
      if (i % 300 == 0) target += 40;
      final next = followDistance(shown, target, 1.2, 0.1, refresh);
      expect(next, greaterThanOrEqualTo(shown));
      expect(next, lessThanOrEqualTo(target));
      shown = next;
    }
  });
}
