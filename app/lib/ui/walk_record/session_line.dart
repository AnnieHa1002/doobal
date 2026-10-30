import '../../app/sync_service.dart';
import '../../domain/rules.dart';
import '../common/format.dart';

/// 걷기 기록의 "걷기 1번" 줄.
/// 인정된 구간이 있으면 그날 몇 번째 함께 걷기인지, 기준을 넘은 구간이 있어도 하루 최대를 채워
/// 못 쳤으면 안내, 기준을 넘은 구간이 없으면 기준을 알려 준다 (숫자는 config에서).
/// [dayLabel]은 그날을 부르는 말 (다시 볼 때 지난 날이면 '11월 18일'), [nth]는 그날 인정된 몇 번째
/// (기본은 record.countedToday = 방금 마친 걷기가 그날의 마지막 인정이라는 뜻)
String sessionLine(WalkRecord record, Rules rules, {String dayLabel = '오늘', int? nth}) {
  final max = rules.sessionMaxPerDay;
  if (record.sessions.any((s) => s.counted)) {
    return '$dayLabel ${nth ?? record.countedToday}/$max번째 함께 걷기';
  }
  if (record.sessions.any((s) => s.qualified)) {
    return '$dayLabel은 $max/$max번을 다 채웠어요';
  }
  return '${rules.sessionMinMin}분 이상, ${formatInt(rules.sessionMinSteps)}보 이상 '
      '이어 걸으면 1번으로 쳐요';
}
