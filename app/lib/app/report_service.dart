import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../domain/bucket.dart';
import '../domain/day_card.dart';
import '../domain/gait.dart';
import '../domain/rules.dart';
import '../domain/time_kst.dart';

/// 하루 카드·걷기 리포트 (M1 명세 v0.5 ⑥, M2~M6 v0.17 U). 기기 안 하루 요약·분 걸음·도착 기록만 읽고
/// (서버로 보내지 않는다), 쓰는 것은 하루 카드를 닫은 날(ReportState) 하나뿐이다.
/// 계산은 domain/day_card.dart의 순수 함수가 한다
class ReportService {
  ReportService(this.db, this.rules, {this.story});

  final AppDb db;
  final Rules rules;

  /// 엽서 이야기 (카드 끝날의 여정·칠한 물감 구간, 동기화가 계산한다). 없으면 빈 이야기
  final Future<CardStory> Function(DayRange range)? story;

  /// 첫 기록일(설치한 날, 한국 날짜 키). 아직 동기화한 적이 없으면 null
  Future<String?> firstRecordDay() async =>
      (await (db.select(db.syncState)..where((t) => t.id.equals(1))).getSingleOrNull())
          ?.firstRecordDay;

  /// [now]에 볼 때 하루 카드로 보여 주고 닫은 마지막 날. 닫은 적이 없으면 첫 기록일 전날 (처음 설치한 날에는 카드가 없다).
  /// 하루 카드가 없던 판에서 업데이트한 기기(마이그레이션 17이 날 없이 넣은 행)는 카드 그저께까지 본 것으로 봐서
  /// 첫 카드가 어제 1장이다 (16장 11/15 ②, 첫 기록일 전날보다 앞으로는 가지 않는다). 첫 기록일도 없으면 null
  Future<String?> lastShownDay(DateTime now) async {
    final row = await (db.select(db.reportState)..where((t) => t.id.equals(1))).getSingleOrNull();
    final day = row?.lastShownDay;
    if (day != null) return day;
    final first = await firstRecordDay();
    if (first == null) return null;
    final initial = initialLastShownDay(first);
    if (row == null) return initial;
    final upgraded = addDays(cardToday(now, rules.report), -2);
    return upgraded.compareTo(initial) > 0 ? upgraded : initial;
  }

  /// [now]에 앱을 열 때 보여 줄 하루 카드. 보여 줄 날이 없으면 null
  Future<DayCard?> dueCard(DateTime now) async {
    final last = await lastShownDay(now);
    if (last == null) return null;
    final range = dueCardRange(nowUtc: now, lastShownDay: last, rules: rules.report);
    return range == null ? null : cardFor(range);
  }

  /// [range]의 하루 카드 값 (노트에서 다시 볼 때도 날짜로 다시 계산한다, 따로 저장하지 않는다)
  Future<DayCard> cardFor(DayRange range) async {
    final days = await _dayTotals(dayCardDays(range, rules.report));
    final from = kstDayStartUtc(range.from).millisecondsSinceEpoch;
    final to = kstDayStartUtc(addDays(range.to, 1)).millisecondsSinceEpoch;
    final arrived = await (db.select(db.journeys)
          ..where((t) =>
              t.status.equalsValue(JourneyStatus.arrived) &
              t.arrivedUtc.isBiggerOrEqualValue(from) &
              t.arrivedUtc.isSmallerThanValue(to)))
        .get();
    final story = this.story;
    return buildDayCard(
      range,
      days,
      rules: rules,
      story: story == null ? CardStory.empty : await story(range),
      arrivals: [
        for (final j in arrived)
          (
            landmarkId: j.destId,
            at: DateTime.fromMillisecondsSinceEpoch(j.arrivedUtc!, isUtc: true),
          ),
      ],
    );
  }

  /// 하루 카드를 닫았다: [day](카드 끝날)까지 본 것으로 적는다. 이미 더 뒤의 날까지 봤으면 그대로 둔다
  /// (노트에서 지난 카드를 다시 볼 때는 부르지 않는다)
  Future<void> markShown(String day) => db.transaction(() async {
        final row =
            await (db.select(db.reportState)..where((t) => t.id.equals(1))).getSingleOrNull();
        final last = row?.lastShownDay;
        if (last != null && last.compareTo(day) >= 0) return;
        await db
            .into(db.reportState)
            .insertOnConflictUpdate(ReportStateCompanion.insert(id: Value(1), lastShownDay: Value(day)));
      });

  /// [now] 기준 최근 [days]일의 걷기 리포트 (다 지난 날만, 설치한 날부터). 아직 다 지난 날이 없으면 null
  Future<WalkReport?> report(DateTime now, int days) async {
    final first = await firstRecordDay();
    if (first == null) return null;
    final range = reportRange(nowUtc: now, days: days, firstRecordDay: first, rules: rules.report);
    if (range == null) return null;
    // 걷기/뛰기는 직전 분 상태를 이어 받으니 하루 앞 분부터 나눈다 (노트 걷기 기록과 같은 방식)
    final from = epochMinute(kstDayStartUtc(addDays(range.from, -1)));
    final before = epochMinute(kstDayStartUtc(addDays(range.to, 1)));
    final rows = await (db.select(db.stepMinutes)
          ..where((t) => t.minuteUtc.isBiggerOrEqualValue(from) & t.minuteUtc.isSmallerThanValue(before))
          ..orderBy([(t) => OrderingTerm.asc(t.minuteUtc)]))
        .get();
    final gaits = classifyGait([for (final r in rows) StepMinute(r.minuteUtc, r.steps)], rules);
    return walkReport(
      range: range,
      minutes: gaits,
      days: await _dayTotals(range.dayKeys.toSet()),
      rules: rules.report,
    );
  }

  /// 하루 카드가 생긴 날인가 (카드 어제까지, 노트 날짜 줄을 누를 수 있는가). 오늘 카드는 내일 새벽 5시 뒤에 생긴다
  bool cardReady(String day, DateTime now) =>
      day.compareTo(addDays(cardToday(now, rules.report), -1)) <= 0;

  Future<Map<String, DayTotals>> _dayTotals(Set<String> days) async {
    final rows = await (db.select(db.daySummaries)..where((t) => t.day.isIn(days))).get();
    return {
      for (final r in rows)
        r.day: DayTotals(
            day: r.day, steps: r.steps, actualM: r.distanceM, trailM: r.trailM, coins: r.coins),
    };
  }
}
