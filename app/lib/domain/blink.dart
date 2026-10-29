import 'dart:math';

/// 눈 깜빡임 간격 규칙 (config character.blink, 에셋 요구서 v2 3장 시작값).
/// 감은 눈 길이는 Rive 파일의 blink 애니메이션(6F = 0.1초)이 정한다.
class BlinkRule {
  const BlinkRule({
    required this.minGapSec,
    required this.maxGapSec,
    required this.doubleChance,
    required this.doubleGapSec,
  });

  factory BlinkRule.fromJson(Map<String, dynamic> j) => BlinkRule(
        minGapSec: (j['minGapSec'] as num).toDouble(),
        maxGapSec: (j['maxGapSec'] as num).toDouble(),
        doubleChance: (j['doubleChance'] as num).toDouble(),
        doubleGapSec: (j['doubleGapSec'] as num).toDouble(),
      );

  /// config 전체에서 character.blink만 꺼낸다
  factory BlinkRule.fromConfig(Map<String, dynamic> config) => BlinkRule.fromJson(
      (config['character'] as Map<String, dynamic>)['blink'] as Map<String, dynamic>);

  /// 다음 깜빡임까지 기다리는 시간의 범위 (초)
  final double minGapSec;
  final double maxGapSec;

  /// 두 번 연속 깜빡일 확률 (0~1, '가끔'의 가안)
  final double doubleChance;

  /// 연속 깜빡임 사이 간격 (초)
  final double doubleGapSec;
}

/// 다음 깜빡임 묶음: 지금부터 각 깜빡임을 시작할 때까지의 시간.
/// 보통 1개, [BlinkRule.doubleChance] 확률로 2개(두 번째는 첫 번째 + doubleGapSec).
List<Duration> nextBlinks(BlinkRule rule, Random rng) {
  final gap = rule.minGapSec + rng.nextDouble() * (rule.maxGapSec - rule.minGapSec);
  final first = _sec(gap);
  if (rng.nextDouble() >= rule.doubleChance) return [first];
  return [first, first + _sec(rule.doubleGapSec)];
}

Duration _sec(double s) => Duration(microseconds: (s * 1e6).round());
