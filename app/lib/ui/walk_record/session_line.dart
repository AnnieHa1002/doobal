import '../../app/sync_service.dart';
import '../../domain/rules.dart';
import '../common/format.dart';

/// 걷기 기록의 "걷기 1번" 줄.
/// 인정된 구간이 있으면 오늘 몇 번째인지, 기준을 넘은 구간이 있어도 하루 최대를 채워 못 쳤으면 안내,
/// 기준을 넘은 구간이 없으면 기준을 알려 준다 (숫자는 config에서)
String sessionLine(WalkRecord record, Rules rules) {
  final max = rules.sessionMaxPerDay;
  if (record.sessions.any((s) => s.counted)) {
    return '오늘 ${record.countedToday}/$max번째 걷기 1번';
  }
  if (record.sessions.any((s) => s.qualified)) {
    return '오늘은 $max/$max번을 다 채웠어요';
  }
  return '${rules.sessionMinMin}분 이상, ${formatInt(rules.sessionMinSteps)}보 이상 '
      '이어 걸으면 1번으로 쳐요';
}
