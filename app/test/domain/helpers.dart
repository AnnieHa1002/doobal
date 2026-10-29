import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/camp_theme.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/rules.dart';

/// 테스트도 실제 config.json 값으로 돈다 (flutter test는 app/에서 실행)
final Rules rules = Rules.fromJson(
  jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 landmarks.json의 명소 101곳
final List<Landmark> landmarks = [
  for (final l in (jsonDecode(File('assets/data/landmarks.json').readAsStringSync())
          as Map<String, dynamic>)['landmarks'] as List)
    Landmark.fromJson(l as Map<String, dynamic>),
];

/// 실제 milestones.json의 방명록 걸음 숫자 23개
final List<int> milestones = ((jsonDecode(File('assets/data/milestones.json').readAsStringSync())
        as Map<String, dynamic>)['stepMilestones'] as List)
    .cast<int>();

/// 실제 themes/camp.json
final CampTheme campTheme = CampTheme.fromJson(
  jsonDecode(File('assets/data/themes/camp.json').readAsStringSync()) as Map<String, dynamic>,
);

/// start부터 1분 간격으로 걸음을 채운 분 목록 (0도 그대로 넣는다)
List<StepMinute> minutesFrom(DateTime startUtc, List<int> steps) {
  final first = epochMinute(startUtc);
  return [for (var i = 0; i < steps.length; i++) StepMinute(first + i, steps[i])];
}
