import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../domain/session.dart';
import '../domain/time_kst.dart';
import '../domain/walk_history.dart';

/// 나의 정보·노트가 읽는 모음 쿼리. 읽기만 하고 쓰지 않는다
/// (걸음·여정 계산은 SyncService, 프로필은 ProfileService)
class StatsService {
  StatsService(this.db);

  final AppDb db;

  /// [today](한국 날짜)까지 최근 [days]일의 하루 걸음, 오래된 날부터. 기록이 없는 날은 0
  Future<List<DayBar>> recentDays(String today, {int days = recentDaysCount}) async {
    final from = addDays(today, 1 - days);
    final rows = await (db.select(db.daySummaries)
          ..where((t) => t.day.isBiggerOrEqualValue(from) & t.day.isSmallerOrEqualValue(today)))
        .get();
    return recentDayBars({for (final r in rows) r.day: r.steps}, today, days: days);
  }

  /// 감지된 걷기 전부, 최신순
  Future<List<WalkSession>> walkSessions() async {
    final rows = await (db.select(db.walkSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startUtc)]))
        .get();
    return [for (final r in rows) _sessionOf(r)];
  }

  /// [start]에 시작한 걷기가 그날(시작의 한국 날짜) 인정된 걷기 1번 중 몇 번째인지.
  /// 인정되지 않은 걷기여도 그 앞에서 인정된 수를 센다
  Future<int> countedNth(DateTime start) async {
    final dayStart = kstDayStartUtc(kstDayKey(start)).millisecondsSinceEpoch;
    final rows = await (db.select(db.walkSessions)
          ..where((t) =>
              t.counted.equals(true) &
              t.startUtc.isBiggerOrEqualValue(dayStart) &
              t.startUtc.isSmallerOrEqualValue(start.millisecondsSinceEpoch)))
        .get();
    return rows.length;
  }

  WalkSession _sessionOf(WalkSessionRow r) => WalkSession(
        start: DateTime.fromMillisecondsSinceEpoch(r.startUtc, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(r.endUtc, isUtc: true),
        steps: r.steps,
        distanceM: r.distanceM,
        runRatio: r.runRatio,
        qualified: r.qualified,
        counted: r.counted,
      );
}
