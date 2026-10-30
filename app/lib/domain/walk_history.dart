import 'session.dart';
import 'time_kst.dart';

/// 나의 정보의 걸음 막대 수 (최근 14일, 오늘 포함). 화면 구성값이라 config에 두지 않는다
const recentDaysCount = 14;

/// 하루 걸음 하나 (막대 하나). [day]는 한국 날짜 'yyyy-MM-dd'
class DayBar {
  const DayBar(this.day, this.steps);

  final String day;
  final int steps;
}

/// [today]까지 최근 [days]일의 하루 걸음을 오래된 날부터 늘어놓는다.
/// [stepsByDay]에 없는 날(기록이 없는 날)은 0
List<DayBar> recentDayBars(
  Map<String, int> stepsByDay,
  String today, {
  int days = recentDaysCount,
}) {
  return [
    for (var i = days - 1; i >= 0; i--)
      DayBar(addDays(today, -i), stepsByDay[addDays(today, -i)] ?? 0),
  ];
}

/// 한국 날짜 하루의 걷기들 (최신순)
class DayGroup {
  const DayGroup(this.day, this.sessions);

  final String day;
  final List<WalkSession> sessions;
}

/// 최신순으로 정렬된 걷기를 시작 시각의 한국 날짜별로 묶는다. 묶음과 묶음 안 모두 최신순 그대로
List<DayGroup> groupSessionsByDay(List<WalkSession> newestFirst) {
  final groups = <DayGroup>[];
  for (final s in newestFirst) {
    final day = kstDayKey(s.start);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(DayGroup(day, []));
    }
    groups.last.sessions.add(s);
  }
  return groups;
}
