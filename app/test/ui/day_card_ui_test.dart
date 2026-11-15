import 'dart:typed_data';

import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/day_card/walk_report_screen.dart';
import 'package:doobal/ui/note/note_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 하루 카드 (캔버스 2-3·2-4)·걷기 리포트 (6-4)·노트 다시 보기 (6-3). 설치는 한국 11월 18일(수) 09:00

/// 한국 시각 → UTC
DateTime _kst(int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(2026, m, d, h, min).subtract(const Duration(hours: 9));

final _card = find.byKey(const ValueKey('rest-day-card'));
Finder _key(String k) => find.byKey(ValueKey(k));

/// PNG 머리말의 가로·세로(IHDR). PNG가 아니면 null
(int, int)? _pngSize(Uint8List b) {
  if (b.length < 24 || b[1] != 0x50 || b[2] != 0x4E || b[3] != 0x47) return null;
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

/// 11월 18일 10:05부터 30분 × 100보 = 3,000보 (2.1km)를 걷고 동기화해 둔다
Future<void> _walkOn18(UiEnv e) async {
  e.source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), 30, 100));
  await e.svc.sync(t1.add(const Duration(hours: 2)));
}

Future<String?> _lastShown(WidgetTester tester, UiEnv e) async =>
    (await tester.runAsync(() => e.db.select(e.db.reportState).getSingleOrNull()))?.lastShownDay;

/// 앱을 [now]에 연다 (쉼터가 뜨고 동기화가 끝날 때까지)
Future<void> _openApp(WidgetTester tester, UiEnv e, DateTime now) async {
  e.now = now;
  await pumpDoobal(tester, e, const DoobalApp());
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
  await settle(tester, () => _card.evaluate().isNotEmpty, tries: 20);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('쉼터 위 하루 카드 (2-3)', () {
    testWidgets('설치한 날에는 카드가 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walkOn18(e));
      await _openApp(tester, e, t1.add(const Duration(hours: 3)));

      expect(_card, findsNothing);
      await end(tester, e);
    });

    testWidgets('다음 날 05:00 전에 열면 아직 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walkOn18(e));
      await _openApp(tester, e, _kst(11, 19, 4, 59));

      expect(_card, findsNothing);
      await end(tester, e);
    });

    testWidgets('다음 날 05:00 뒤 처음 열면 어제 카드: 날짜·걸음·거리·물감 길·방울·이번 주 막대', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walkOn18(e));
      await _openApp(tester, e, _kst(11, 19, 7));

      expect(_card, findsOneWidget);
      expect(find.text('11월 18일 수요일'), findsOneWidget);
      expect(find.text('어제'), findsOneWidget);
      for (final t in ['걸음', '3,000보', '거리', '2.1km', '물감 길', '0.0km', '물감 방울', '0개']) {
        expect(find.descendant(of: _card, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.text('이번 주'), findsOneWidget);
      expect(find.text('자세히 보기 ›'), findsOneWidget);
      expect(_key('day-card-share'), findsOneWidget);
      // 그림이 없는 날은 정령만
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('day-card-painting-')), findsNothing);
      // 막대: 수요일(카드 날)은 테라코타, 목요일(오늘)부터는 점선 바닥
      final wed = tester.widget<Container>(_key('week-bar-2026-11-18'));
      expect((wed.decoration! as BoxDecoration).color, const Color(0xFFA4502F));
      expect(tester.getSize(_key('week-bar-2026-11-18')).height, 64);
      expect(tester.getSize(_key('week-bar-2026-11-19')).height, 1.5);
      await end(tester, e);
    });

    testWidgets('닫으면 카드 끝날까지 본 것으로 적고, 다시 앞으로 와도 그날은 안 뜬다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walkOn18(e));
      await _openApp(tester, e, _kst(11, 19, 7));
      expect(_card, findsOneWidget);
      expect(await _lastShown(tester, e), isNull);

      await tester.tap(_key('day-card-close'));
      await settle(tester, () => false, tries: 4);
      expect(_card, findsNothing);
      expect(await _lastShown(tester, e), '2026-11-18');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      e.now = _kst(11, 19, 22);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester, () => false, tries: 16);
      expect(_card, findsNothing);
      await end(tester, e);
    });

    testWidgets('뒤로 가기는 카드를 닫는다 (앱을 나가지 않는다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walkOn18(e));
      await _openApp(tester, e, _kst(11, 19, 7));

      await tester.binding.handlePopRoute();
      await settle(tester, () => false, tries: 4);
      expect(_card, findsNothing);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(await _lastShown(tester, e), '2026-11-18');
      await end(tester, e);
    });

    testWidgets('며칠 만에 열면 밀린 날을 한 장: ‘지난 n일’ 합계·하루 평균·가장 많이 걸은 날', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _walkOn18(e);
        // 11월 20일(금) 40분 × 100보 = 4,000보
        e.source.records.add(walkRecord(_kst(11, 20, 10), 40, 100));
        await e.svc.sync(_kst(11, 20, 12));
      });
      await _openApp(tester, e, _kst(11, 22, 8));

      expect(find.text('지난 4일'), findsOneWidget);
      expect(find.text('11월 18일 ~ 21일'), findsOneWidget);
      // 3,000 + 4,000 = 7,000보, 4.9km, 하루 평균 1,750보, 가장 많이 걸은 날 금요일
      for (final t in ['7,000보', '4.9km', '하루 평균', '1,750보', '가장 많이 걸은 날', '금 4,000보']) {
        expect(find.descendant(of: _card, matching: find.text(t)), findsOneWidget, reason: t);
      }
      await tester.tap(_key('day-card-close'));
      await settle(tester, () => false, tries: 4);
      expect(await _lastShown(tester, e), '2026-11-21');
      await end(tester, e);
    });

    testWidgets('그림 받은 날은 그림을 붙이고, 공유하면 1080×1350 PNG를 공유 창에 올린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.arriveAtGyeongbok();
        await (e.db.update(e.db.journeys)).write(const JourneysCompanion(arrivalShown: Value(true)));
      });
      await _openApp(tester, e, _kst(11, 19, 7));

      expect(_key('day-card-painting-kr001'), findsOneWidget);
      await tester.tap(_key('day-card-share'));
      await settle(tester, () => e.sharer.calls.isNotEmpty, tries: 200);
      final c = e.sharer.calls.single;
      expect(_pngSize(c.png), (1080, 1350));
      expect(c.fileName, 'doobal_2026-11-18.png');
      expect(c.text, '두발 · 11월 18일 3,000보');
      // 공유해도 카드는 그대로 (닫아야 본 것으로)
      await settle(tester, () => false, tries: 4);
      expect(_card, findsOneWidget);
      expect(await _lastShown(tester, e), isNull);
      await end(tester, e);
    });

    testWidgets('공유 창을 못 열면 알리고 카드는 그대로', (tester) async {
      final e = UiEnv();
      e.sharer.fail = true;
      await e.seed(tester, () => _walkOn18(e));
      await _openApp(tester, e, _kst(11, 19, 7));

      await tester.tap(_key('day-card-share'));
      await settle(tester, () => find.text('공유하지 못했어요').evaluate().isNotEmpty, tries: 200);
      expect(find.text('공유하지 못했어요'), findsOneWidget);
      expect(_card, findsOneWidget);
      await end(tester, e);
    });

    testWidgets('‘자세히 보기 ›’는 걷기 리포트, 뒤로 오면 카드가 그대로', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walkOn18(e));
      await _openApp(tester, e, _kst(11, 19, 7));

      await tester.tap(_key('day-card-detail'));
      await transition(tester);
      expect(find.byType(WalkReportScreen), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(WalkReportScreen), findsNothing);
      expect(_card, findsOneWidget);
      await end(tester, e);
    });
  });

  group('걷기 리포트 (6-4)', () {
    /// 11월 18일(수) 18:00 30분 × 100보 걷기, 11월 19일(목) 07:00 20분 × 150보 뛰기
    Future<UiEnv> seeded(WidgetTester tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        e.source.records
          ..add(walkRecord(_kst(11, 18, 18), 30, 100))
          ..add(walkRecord(_kst(11, 19, 7), 20, 150));
        await e.svc.sync(_kst(11, 19, 12));
      });
      e.now = _kst(11, 21, 9);
      return e;
    }

    testWidgets('설치한 날부터 다 지난 날까지: 하루 평균·걷는 때·걷기/달리기·물감 길·요일', (tester) async {
      final e = await seeded(tester);
      await openOnTop(tester, e, const WalkReportScreen(),
          height: 1200, ready: () => find.text('하루 평균').evaluate().isNotEmpty);
      await tester.pump();

      expect(find.text('7일'), findsOneWidget);
      expect(find.text('30일'), findsOneWidget);
      // 11/18~11/20 사흘: (3,000 + 3,000) ÷ 3, 거리 (2,100 + 3,000)m ÷ 3
      expect(find.text('2,000보'), findsOneWidget);
      expect(find.text('1.7km'), findsOneWidget);
      // 7시·18시가 같아서 이른 7시, 둘이 이웃하지 않아 한 시만
      expect(find.text('아침 7~8시'), findsOneWidget);
      expect(find.text('걷기 50%'), findsOneWidget);
      expect(find.text('달리기 50%'), findsOneWidget);
      expect(find.text('0.0km / 5.1km'), findsOneWidget);
      expect(find.text('물감 길 0%'), findsOneWidget);
      expect(find.text('연필 선 100%'), findsOneWidget);
      expect(find.text('수요일'), findsOneWidget);
      // 가장 많은 두 칸은 테라코타
      final h7 = tester.widget<Container>(_key('hour-bar-7'));
      expect((h7.decoration! as BoxDecoration).color, const Color(0xFFA4502F));
      expect(tester.getSize(_key('hour-bar-7')).height, 70);
      expect(tester.getSize(_key('hour-bar-3')).height, 2);

      await tester.tap(_key('report-tab-30'));
      await settle(tester, () => false, tries: 6);
      expect(find.text('2,000보'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('설치한 날에는 아직 리포트가 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openOnTop(tester, e, const WalkReportScreen(),
          ready: () => find.text('아직 걷기 기록이 없어요').evaluate().isNotEmpty);
      expect(find.text('아직 걷기 기록이 없어요'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('노트 걷기 기록 (6-3)', () {
    testWidgets('맨 위 리포트 줄, 날짜 줄을 누르면 그날 카드(본 날로 적지 않음), 오늘 줄은 아직 못 누른다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _walkOn18(e);
        e.source.records.add(walkRecord(_kst(11, 21, 8), 10, 100));
        await e.svc.sync(_kst(11, 21, 9));
      });
      e.now = _kst(11, 21, 9);
      await openOnTop(tester, e, const NoteScreen(),
          height: 1200, ready: () => find.text('내 방명록').evaluate().isNotEmpty);
      await tester.tap(_key('tab-walks'));
      await settle(tester, () => find.text('11월 18일').evaluate().isNotEmpty);
      await tester.pump();

      expect(_key('walk-report-row'), findsOneWidget);
      expect(find.text('3,000보 · 2.1 km'), findsOneWidget);
      // 물감 길이 없어도 걸은 날은 날짜 줄이 있다. 오늘(21일)은 내일 새벽 5시 뒤에 누를 수 있다
      expect(find.text('11월 21일'), findsOneWidget);
      expect(_key('day-2026-11-21'), findsNothing);
      expect(_key('day-2026-11-18'), findsOneWidget);
      expect(
          tester.getTopLeft(_key('walk-report-row')).dy,
          lessThan(tester.getTopLeft(find.text('11월 21일')).dy));

      await tester.tap(_key('day-2026-11-18'));
      await settle(tester, () => _key('day-card-close').evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 1));
      // 어제가 아니라 날짜가 제목, 작은 줄은 요일
      expect(find.text('11월 18일'), findsWidgets);
      expect(find.text('수요일'), findsOneWidget);
      expect(find.text('3,000보'), findsOneWidget);

      await tester.tap(_key('day-card-close'));
      await transition(tester);
      expect(_key('day-card-close'), findsNothing);
      expect(find.byType(NoteScreen), findsOneWidget);
      expect(await _lastShown(tester, e), isNull);

      await tester.tap(_key('walk-report-row'));
      await transition(tester);
      expect(find.byType(WalkReportScreen), findsOneWidget);
      await end(tester, e);
    });
  });
}
