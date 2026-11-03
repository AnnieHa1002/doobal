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

  group('CountFollower: 걸음 숫자를 부드럽게 따라 올린다', () {
    /// 60fps로 [sec]초 동안 [target]을 따라간다
    void run(CountFollower f, int target, double sec) {
      for (var t = 0.0; t < sec - 1e-9; t += 1 / 60) {
        f.step(target, 1 / 60);
      }
    }

    test('한꺼번에 7보가 들어와도 바로 뛰지 않고 1.5초 동안 고르게 올라 다 따라간다', () {
      final f = CountFollower()..snap(9);
      f.step(16, 1 / 60);
      expect(f.shown, 9);
      run(f, 16, 0.75);
      expect(f.shown, 12);
      run(f, 16, 0.75);
      expect(f.shown, 16);
    });

    test('한 걸음씩 들어오면(초당 2.5보) 늦지 않고 바로바로 따라간다 (초당 3보보다 느리지 않다)', () {
      final f = CountFollower();
      for (var n = 1; n <= 10; n++) {
        run(f, n, 0.4);
        expect(f.shown, n, reason: '$n');
      }
    });

    test('큰 차이(500보)도 1.5초 안이고, 다 따라잡은 뒤 다시 몰려 오면 빠르기를 새로 잰다', () {
      final f = CountFollower();
      run(f, 500, 1.5);
      expect(f.shown, 500);
      // 500보 때의 빠르기(초당 333보)로 7보를 한 번에 넘기지 않는다
      f.step(507, 1 / 60);
      expect(f.shown, 500);
      run(f, 507, 1.5);
      expect(f.shown, 507);
    });

    test('목표를 넘지 않고 뒤로 가지 않는다. snap은 바로 맞춘다', () {
      final f = CountFollower()..snap(20);
      f.step(16, 1);
      expect(f.shown, 20);
      f.step(30, 0);
      expect(f.shown, 20);
      f.snap(40);
      expect(f.shown, 40);
      f.snap(10);
      expect(f.shown, 40);
    });
  });
}
