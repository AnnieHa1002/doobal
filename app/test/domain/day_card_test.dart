import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/day_card.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 한국 시각 → UTC
DateTime kst(int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(2026, m, d, h, min).subtract(const Duration(hours: 9));

ReportRules reportWith(void Function(Map<String, dynamic> report) edit) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  edit(j['report'] as Map<String, dynamic>);
  return Rules.fromJson(j).report;
}

DayTotals day(String d, int steps, {double? actualM, double trailM = 0}) =>
    DayTotals(day: d, steps: steps, actualM: actualM ?? steps * 0.7, trailM: trailM);

/// 걷기로 판정한 분 하나 (한국 시각)
GaitMinute walkAt(int m, int d, int h, int steps, [Gait gait = Gait.walk]) =>
    GaitMinute(epochMinute(kst(m, d, h)), steps, gait);

void main() {
  final report = rules.report;

  group('config report', () {
    test('값을 읽는다 (16장 11/13: 05시, 밀린 날 30일 가안, 주 월~일, 리포트 7·30일, 공유 1080×1350)', () {
      expect(report.dayStartHour, 5);
      expect(report.maxMergeDays, 30);
      expect(report.weekStartsMonday, isTrue);
      expect(report.detailDays, [7, 30]);
      expect(report.defaultDetailDays, 7);
      expect((report.shareImageWidthPx, report.shareImageHeightPx), (1080, 1350));
    });

    test('틀린 값은 FormatException', () {
      expect(() => reportWith((r) => r['dayStartHour'] = 24), throwsFormatException);
      expect(() => reportWith((r) => (r['maxMergeDays'] as Map)['days'] = 0), throwsFormatException);
      expect(() => reportWith((r) => (r['detailDays'] as Map)['default'] = 14), throwsFormatException);
      expect(() => reportWith((r) => (r['shareImagePx'] as Map)['size'] = [1080]),
          throwsFormatException);
    });
  });

  group('하루 카드 날 (M1 v0.5 ⑥, 테스트 34)', () {
    DayRange? due(DateTime now, String last) =>
        dueCardRange(nowUtc: now, lastShownDay: last, rules: report);

    test('오늘 04:59 열기 → 없음, 05:00 → 어제 1장', () {
      expect(due(kst(11, 20, 4, 59), '2026-11-18'), isNull);
      expect(due(kst(11, 20, 5), '2026-11-18'), const DayRange.single('2026-11-19'));
    });

    test('3일 만에 열기 → ‘지난 3일’ 1장', () {
      final r = due(kst(11, 20, 6), '2026-11-16')!;
      expect(r, const DayRange('2026-11-17', '2026-11-19'));
      expect((r.days, r.single), (3, false));
    });

    test('같은 날 두 번째 열기 → 없음 (닫으면 lastShownDay = 카드 끝날)', () {
      expect(due(kst(11, 20, 21), '2026-11-19'), isNull);
      // 자정을 넘겨도 05:00 전이면 아직 없다
      expect(due(kst(11, 21, 0, 30), '2026-11-19'), isNull);
      expect(due(kst(11, 21, 5), '2026-11-19'), const DayRange.single('2026-11-20'));
    });

    test('05:00 전에 열면 어제는 아직 안 들어간다 (그저께까지)', () {
      expect(due(kst(11, 20, 3), '2026-11-17'), const DayRange.single('2026-11-18'));
    });

    test('처음 설치한 날에는 카드가 없다 (lastShownDay = 설치 전날)', () {
      final first = initialLastShownDay('2026-11-18');
      expect(first, '2026-11-17');
      expect(due(kst(11, 18, 23), first), isNull);
      expect(due(kst(11, 19, 4), first), isNull);
      expect(due(kst(11, 19, 5), first), const DayRange.single('2026-11-18'));
    });

    test('밀린 날이 config maxMergeDays(30)보다 많으면 어제까지 30일만', () {
      final r = due(kst(11, 20, 6), '2026-10-01')!;
      expect(r, const DayRange('2026-10-21', '2026-11-19'));
      expect(r.days, 30);
      // 딱 30일이면 그대로
      expect(due(kst(11, 20, 6), '2026-10-20'), const DayRange('2026-10-21', '2026-11-19'));
    });

    test('cardToday: 한국 05:00에 날이 바뀐다 (기기 시간대와 상관없이)', () {
      expect(cardToday(kst(11, 20, 4, 59), report), '2026-11-19');
      expect(cardToday(kst(11, 20, 5), report), '2026-11-20');
    });
  });

  group('이번 주 7일', () {
    test('월~일: 수요일(11/18)이 든 주는 11/16(월)~11/22(일)', () {
      expect(weekOf('2026-11-18', report), [
        '2026-11-16', '2026-11-17', '2026-11-18', '2026-11-19',
        '2026-11-20', '2026-11-21', '2026-11-22',
      ]);
      expect(weekOf('2026-11-16', report).first, '2026-11-16');
      expect(weekOf('2026-11-22', report).last, '2026-11-22');
    });

    test('weekStartsMonday false면 일~토', () {
      final sunday = reportWith((r) => (r['weekStartsMonday'] as Map)['value'] = false);
      expect(weekOf('2026-11-18', sunday).first, '2026-11-15');
      expect(weekOf('2026-11-22', sunday).first, '2026-11-22');
    });
  });

  group('하루 카드 값', () {
    test('하루: 걸음·거리·물감 길·방울, 막대는 카드 날 뒤가 빈 칸, 그날 그림만 도착 순서로', () {
      final c = buildDayCard(
        const DayRange.single('2026-11-18'),
        {
          '2026-11-16': day('2026-11-16', 8350),
          '2026-11-17': day('2026-11-17', 6104),
          '2026-11-18': day('2026-11-18', 7912, actualM: 5600, trailM: 3750),
          // 오늘(카드 날 뒤)의 기록은 막대에 안 나온다
          '2026-11-19': day('2026-11-19', 3000),
        },
        rules: rules,
        arrivals: [
          (landmarkId: 'kr002', at: kst(11, 18, 18)),
          (landmarkId: 'kr001', at: kst(11, 18, 9)),
          (landmarkId: 'kr003', at: kst(11, 17, 20)),
          (landmarkId: 'kr004', at: kst(11, 19, 0, 10)),
        ],
      );
      expect((c.steps, c.actualM, c.trailM), (7912, 5600.0, 3750.0));
      // 방울 = 내림(3,750 ÷ 100)
      expect(c.drops, 37);
      expect(c.best, isNull);
      expect([for (final b in c.week) b.steps], [8350, 6104, 7912, null, null, null, null]);
      expect([for (final b in c.week) b.inCard], [false, false, true, false, false, false, false]);
      expect(c.paintings, ['kr001', 'kr002']);
    });

    test('기록이 없는 날은 0, 카드 날 앞의 이번 주 날도 0', () {
      final c = buildDayCard(const DayRange.single('2026-11-17'), const {}, rules: rules);
      expect((c.steps, c.actualM, c.trailM, c.drops), (0, 0.0, 0.0, 0));
      expect([for (final b in c.week) b.steps], [0, 0, null, null, null, null, null]);
    });

    test('지난 3일: 합계·하루 평균·가장 많이 걸은 날(같으면 앞 날), 방울은 날마다 내림한 합', () {
      final c = buildDayCard(
        const DayRange('2026-11-16', '2026-11-18'),
        {
          '2026-11-16': day('2026-11-16', 8350, trailM: 150),
          '2026-11-17': day('2026-11-17', 6104, trailM: 150),
          '2026-11-18': day('2026-11-18', 8350),
        },
        rules: rules,
      );
      expect(c.steps, 22804);
      expect(c.avgSteps, 7601); // 22,804 ÷ 3 = 7,601.3
      expect(c.avgM, closeTo(22804 * 0.7 / 3, 1e-9));
      expect((c.best!.day, c.best!.steps), ('2026-11-16', 8350));
      // 150m + 150m: 하루마다 1개씩 (300m를 한 번에 내림하면 3개)
      expect(c.drops, 2);
      expect([for (final b in c.week) b.inCard], [true, true, true, false, false, false, false]);
    });

    test('지난 n일이 모두 0보면 가장 많이 걸은 날은 없다', () {
      final c = buildDayCard(const DayRange('2026-11-16', '2026-11-17'), const {}, rules: rules);
      expect(c.best, isNull);
      expect(c.avgSteps, 0);
    });

    test('dayCard: 보여 줄 날이 없으면 null, 있으면 그 날의 값', () {
      final days = {'2026-11-19': day('2026-11-19', 5000)};
      expect(
          dayCard(days: days, nowUtc: kst(11, 20, 4), lastShownDay: '2026-11-18', rules: rules),
          isNull);
      final c =
          dayCard(days: days, nowUtc: kst(11, 20, 7), lastShownDay: '2026-11-18', rules: rules)!;
      expect((c.range, c.steps), (const DayRange.single('2026-11-19'), 5000));
    });

    test('dayCardDays: 카드 날과 이번 주 날', () {
      expect(dayCardDays(const DayRange('2026-11-14', '2026-11-17'), report), {
        '2026-11-14', '2026-11-15', '2026-11-16', '2026-11-17', '2026-11-18', '2026-11-19',
        '2026-11-20', '2026-11-21', '2026-11-22',
      });
    });
  });

  group('걷기 리포트 기간', () {
    test('카드 어제까지 최근 7일·30일 (다 지난 날만)', () {
      expect(
          reportRange(
              nowUtc: kst(11, 30, 12), days: 7, firstRecordDay: '2026-10-01', rules: report),
          const DayRange('2026-11-23', '2026-11-29'));
      expect(
          reportRange(
              nowUtc: kst(11, 30, 4), days: 7, firstRecordDay: '2026-10-01', rules: report),
          const DayRange('2026-11-22', '2026-11-28'));
      expect(
          reportRange(
                  nowUtc: kst(11, 30, 12), days: 30, firstRecordDay: '2026-10-01', rules: report)!
              .days,
          30);
    });

    test('설치한 날보다 앞은 자르고, 다 지난 날이 없으면 null', () {
      expect(
          reportRange(
              nowUtc: kst(11, 20, 12), days: 7, firstRecordDay: '2026-11-18', rules: report),
          const DayRange('2026-11-18', '2026-11-19'));
      expect(
          reportRange(
              nowUtc: kst(11, 18, 12), days: 7, firstRecordDay: '2026-11-18', rules: report),
          isNull);
    });
  });

  group('걷기 리포트 값 (캔버스 6-4)', () {
    const range = DayRange('2026-11-16', '2026-11-22');

    test('시간대별 걸음(한국 시각 24칸)·걷기/달리기·기간 밖 분은 뺀다', () {
      final r = walkReport(
        range: range,
        minutes: [
          walkAt(11, 16, 7, 100),
          walkAt(11, 16, 18, 120),
          walkAt(11, 17, 18, 80, Gait.run),
          walkAt(11, 22, 23, 50),
          // 기간 밖 (11/15 23시, 11/23 0시)
          walkAt(11, 15, 23, 999),
          walkAt(11, 23, 0, 999),
          walkAt(11, 18, 9, 0),
        ],
        days: const {},
        rules: report,
      );
      expect(r.hourSteps[7], 100);
      expect(r.hourSteps[18], 200);
      expect(r.hourSteps[23], 50);
      expect(r.hourSteps[0], 0);
      expect(r.hourSteps.fold(0, (a, b) => a + b), 350);
      expect((r.walkSteps, r.runSteps), (270, 80));
      expect(r.runRatio, closeTo(80 / 350, 1e-9));
      expect(r.peakHours, [18, 7]);
    });

    test('가장 많은 두 시: 같으면 이른 시, 걸음이 없으면 빈 목록', () {
      final r = walkReport(
        range: range,
        minutes: [walkAt(11, 16, 19, 50), walkAt(11, 16, 6, 50), walkAt(11, 16, 12, 10)],
        days: const {},
        rules: report,
      );
      expect(r.peakHours, [6, 19]);
      final empty = walkReport(range: range, minutes: const [], days: const {}, rules: report);
      expect(empty.peakHours, isEmpty);
      expect((empty.runRatio, empty.trailRatio, empty.peakWeekday), (0.0, 0.0, null));
    });

    test('하루 평균·물감 길 비율·요일별 하루 평균 (기록 없는 날은 0으로 센다)', () {
      final r = walkReport(
        range: const DayRange('2026-11-16', '2026-11-29'),
        minutes: const [],
        days: {
          '2026-11-16': day('2026-11-16', 8000, actualM: 5600, trailM: 2800),
          '2026-11-23': day('2026-11-23', 4000, actualM: 2800, trailM: 0),
          '2026-11-21': day('2026-11-21', 9120, actualM: 6384, trailM: 6384),
        },
        rules: report,
      );
      expect(r.steps, 21120);
      expect(r.avgSteps, 1509); // 21,120 ÷ 14 = 1,508.6
      expect(r.avgM, closeTo(14784 / 14, 1e-9));
      expect(r.trailRatio, closeTo(9184 / 14784, 1e-9));
      // 월: (8,000 + 4,000) ÷ 2, 토: 9,120 ÷ 2
      expect(r.weekdaySteps, [6000, 0, 0, 0, 0, 4560, 0]);
      expect(r.peakWeekday, 0);
    });

    test('물감 길 비율은 1을 넘지 않는다', () {
      final r = walkReport(
        range: range,
        minutes: const [],
        days: {'2026-11-16': day('2026-11-16', 100, actualM: 70, trailM: 80)},
        rules: report,
      );
      expect(r.trailRatio, 1.0);
    });
  });
}
