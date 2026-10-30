import 'package:doobal/domain/session.dart';
import 'package:doobal/domain/walk_history.dart';
import 'package:flutter_test/flutter_test.dart';

WalkSession _walk(DateTime start, {int minutes = 15}) => WalkSession(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * 100,
      distanceM: minutes * 70.0,
      runRatio: 0,
      qualified: true,
      counted: true,
    );

void main() {
  group('recentDayBars', () {
    test('오늘까지 14일을 오래된 날부터, 기록이 없는 날은 0', () {
      final bars = recentDayBars({'2026-11-18': 3000, '2026-11-10': 500}, '2026-11-18');
      expect(bars, hasLength(14));
      expect(bars.first.day, '2026-11-05');
      expect(bars.last.day, '2026-11-18');
      expect(bars.last.steps, 3000);
      expect(bars.firstWhere((b) => b.day == '2026-11-10').steps, 500);
      expect(bars.where((b) => b.steps == 0), hasLength(12));
    });

    test('달을 넘어도 날짜가 이어진다', () {
      final bars = recentDayBars(const {}, '2026-12-03');
      expect(bars.first.day, '2026-11-20');
      expect(bars[10].day, '2026-11-30');
      expect(bars[11].day, '2026-12-01');
    });

    test('범위 밖 날짜는 넣지 않고, 일수는 고를 수 있다', () {
      final bars = recentDayBars({'2026-11-01': 9999, '2026-11-18': 1}, '2026-11-18', days: 3);
      expect([for (final b in bars) b.day], ['2026-11-16', '2026-11-17', '2026-11-18']);
      expect([for (final b in bars) b.steps], [0, 0, 1]);
    });
  });

  group('groupSessionsByDay', () {
    test('한국 날짜별로 묶고 순서는 최신순 그대로', () {
      // 한국 11월 19일 00:30, 11월 18일 23:00, 11월 18일 09:00, 11월 17일 20:00
      final sessions = [
        _walk(DateTime.utc(2026, 11, 18, 15, 30)),
        _walk(DateTime.utc(2026, 11, 18, 14)),
        _walk(DateTime.utc(2026, 11, 18, 0)),
        _walk(DateTime.utc(2026, 11, 17, 11)),
      ];
      final groups = groupSessionsByDay(sessions);
      expect([for (final g in groups) g.day], ['2026-11-19', '2026-11-18', '2026-11-17']);
      expect([for (final g in groups) g.sessions.length], [1, 2, 1]);
      expect(groups[1].sessions.first.start, DateTime.utc(2026, 11, 18, 14));
    });

    test('걷기가 없으면 묶음도 없다', () {
      expect(groupSessionsByDay(const []), isEmpty);
    });
  });
}
