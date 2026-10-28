import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/rules.dart';

/// 테스트도 실제 config.json 값으로 돈다 (flutter test는 app/에서 실행)
final Rules rules = Rules.fromJson(
  jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>,
);

/// start부터 1분 간격으로 걸음을 채운 분 목록 (0도 그대로 넣는다)
List<StepMinute> minutesFrom(DateTime startUtc, List<int> steps) {
  final first = epochMinute(startUtc);
  return [for (var i = 0; i < steps.length; i++) StepMinute(first + i, steps[i])];
}
