import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:doobal/domain/blink.dart';
import 'package:flutter_test/flutter_test.dart';

/// 정해진 값을 차례로 돌려주는 가짜 난수
class _Seq implements Random {
  _Seq(this.values);
  final List<double> values;
  int _i = 0;
  @override
  double nextDouble() => values[_i++];
  @override
  bool nextBool() => throw UnimplementedError();
  @override
  int nextInt(int max) => throw UnimplementedError();
}

void main() {
  final rule = BlinkRule.fromConfig(
    jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('config.json 값 그대로 (3~6초, 연속 15%, 연속 간격 0.3초)', () {
    expect(rule.minGapSec, 3);
    expect(rule.maxGapSec, 6);
    expect(rule.doubleChance, 0.15);
    expect(rule.doubleGapSec, 0.3);
  });

  test('간격은 min~max를 난수로 고른다: 0 → 3초, 0.5 → 4.5초', () {
    expect(nextBlinks(rule, _Seq([0, 0.99])), [const Duration(seconds: 3)]);
    expect(nextBlinks(rule, _Seq([0.5, 0.99])), [const Duration(milliseconds: 4500)]);
  });

  test('두 번째 난수가 연속 확률보다 작으면 0.3초 뒤 한 번 더', () {
    expect(nextBlinks(rule, _Seq([0, 0.1])), [
      const Duration(seconds: 3),
      const Duration(milliseconds: 3300),
    ]);
  });

  test('경계: 연속 확률과 같은 값이면 한 번만', () {
    expect(nextBlinks(rule, _Seq([0, 0.15])), hasLength(1));
  });

  test('실제 난수 1,000번: 모두 3~6초, 연속은 대략 15% (5~25% 안)', () {
    final rng = Random(1);
    var doubles = 0;
    for (var i = 0; i < 1000; i++) {
      final b = nextBlinks(rule, rng);
      expect(b.first.inMicroseconds, inInclusiveRange(3000000, 6000000));
      if (b.length == 2) doubles++;
    }
    expect(doubles, inInclusiveRange(50, 250));
  });
}
