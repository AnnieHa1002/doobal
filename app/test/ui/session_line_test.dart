import 'package:doobal/app/sync_service.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/session.dart';
import 'package:doobal/domain/walk_record.dart';
import 'package:doobal/ui/walk_record/session_line.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

final _t0 = DateTime.utc(2026, 11, 18, 1);

WalkSession _session({required bool qualified, required bool counted}) => WalkSession(
      start: _t0,
      end: _t0.add(const Duration(minutes: 15)),
      steps: 1500,
      distanceM: 1050,
      runRatio: 0,
      qualified: qualified,
      counted: counted,
    );

WalkRecord _record(List<WalkSession> sessions, int countedToday) => WalkRecord(
      const WalkSummary(
        steps: 1500,
        distanceM: 1050,
        activeMinutes: 15,
        runSteps: 0,
        lastSteps: 100,
        lastGait: Gait.walk,
      ),
      sessions,
      countedToday,
    );

void main() {
  test('인정된 구간이 있으면 오늘 n/3번째 걷기 1번 (3은 config)', () {
    expect(rules.sessionMaxPerDay, 3);
    expect(sessionLine(_record([_session(qualified: true, counted: true)], 1), rules),
        '오늘 1/3번째 걷기 1번');
    expect(sessionLine(_record([_session(qualified: true, counted: true)], 3), rules),
        '오늘 3/3번째 걷기 1번');
  });

  test('기준을 넘은 구간이 없으면 기준을 알려 준다 (10분, 1,000보는 config)', () {
    const text = '10분 이상, 1,000보 이상 이어 걸으면 1번으로 쳐요';
    expect(sessionLine(_record(const [], 0), rules), text);
    expect(sessionLine(_record([_session(qualified: false, counted: false)], 2), rules), text);
  });

  test('기준을 넘었지만 하루 최대를 채워 인정 못 받으면 n/n번을 다 채웠어요', () {
    expect(sessionLine(_record([_session(qualified: true, counted: false)], 3), rules),
        '오늘은 3/3번을 다 채웠어요');
  });

  test('구간이 여럿이고 하나라도 인정됐으면 인정 문구', () {
    final r = _record([
      _session(qualified: true, counted: false),
      _session(qualified: true, counted: true),
    ], 3);
    expect(sessionLine(r, rules), '오늘 3/3번째 걷기 1번');
  });
}
