import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/common/framed_painting.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

final _card = find.byKey(const ValueKey('arrival-card'));
final _day = DateTime.utc(2026, 11, 18, 3);

Finder _inCard(String text) => find.descendant(of: _card, matching: find.text(text));

double _opacity(WidgetTester tester, String key) =>
    tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

/// 도착 화면(여정 [id])을 앱 첫 화면 위에 열고, 값이 와서 카드가 나올 때까지 기다린다
Future<void> _openArrival(WidgetTester tester, UiEnv e, String id) => openOnTop(
      tester,
      e,
      ArrivalScreen(journeyId: id),
      ready: () => _card.evaluate().isNotEmpty,
    );

/// 애니메이션(1.9초)이 끝난 뒤의 화면
Future<void> _afterAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<JourneyRow> _journey(WidgetTester tester, UiEnv e, String id) async {
  final query = e.db.select(e.db.journeys)..where((t) => t.id.equals(id));
  return (await tester.runAsync(query.getSingle))!;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('AutoSync가 도착 화면을 올린다', () {
    testWidgets('앱을 열면 쉼터 위에 한 번 나오고, 닫으면 본 것으로 적혀 다시 나오지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtGyeongbok);
      final journeyId = 'j${t1.millisecondsSinceEpoch}';
      expect((await _journey(tester, e, journeyId)).arrivalShown, isFalse);

      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => _card.evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 2));

      // 쉼터는 아래에 있고 도착 화면이 위에 하나
      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(find.byType(RestScreen, skipOffstage: false), findsOneWidget);
      final km = buildRoute(nearGyeongbok, byId['kr001']!.latLng, rules).totalEffectiveKm;
      expect(_inCard('경복궁'), findsOneWidget);
      expect(_inCard('1번째 방문'), findsOneWidget);
      expect(_inCard('이번 여정 ${formatKm(km)}'), findsOneWidget);
      expect(_inCard('11월 18일'), findsOneWidget);
      expect(_inCard('그날 걸음 3,000보'), findsOneWidget);
      expect(find.text('나무 액자'), findsOneWidget);
      // 첫 방문이라 재방문 줄·권역 소품이 없다. 버튼은 주 방명록 쓰기, 보조 둘
      expect(find.byKey(const ValueKey('arrival-revisit')), findsNothing);
      expect(find.byKey(const ValueKey('arrival-prop')), findsNothing);
      expect(find.text('방명록 쓰기'), findsOneWidget);
      expect(find.text('화집에 걸기'), findsOneWidget);
      expect(find.text('다음 목적지'), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(ArrivalScreen), findsNothing);
      expect(find.textContaining('쉬는 중'), findsOneWidget);
      await settle(tester, () => false, tries: 4);
      expect((await _journey(tester, e, journeyId)).arrivalShown, isTrue);

      // 다시 켜도(백그라운드에서 돌아와도), 상태를 새로 읽어도 나오지 않는다
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final container = ProviderScope.containerOf(tester.element(find.byType(RestScreen)));
      container.invalidate(snapshotProvider);
      await settle(tester, () => false, tries: 12);
      await transition(tester);
      expect(find.byType(ArrivalScreen, skipOffstage: false), findsNothing);
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.pendingArrival, isNull);
      await end(tester, e);
    });

    testWidgets('걷는 중 화면이 새로 읽다가 도착을 알게 되면 그 위에 올라오고, 계속 새로 읽어도 한 번만', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney('kr001', t1, useFund: false);
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.tap(find.text('출발하기'));
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      expect(find.byType(WalkingScreen), findsOneWidget);
      expect(find.byType(ArrivalScreen), findsNothing);

      // 30분 걸어서 도착한 기록이 들어온 채로 다음 갱신 주기가 온다
      e.source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), 30, 100));
      e.now = t1.add(const Duration(hours: 2));
      for (var i = 0; i < 600 && find.byType(ArrivalScreen).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i % 10 == 0) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        }
      }
      expect(find.byType(ArrivalScreen), findsOneWidget);
      await transition(tester);
      expect(find.byType(WalkingScreen, skipOffstage: false), findsOneWidget);

      // 갱신이 몇 번 더 돌아도 같은 여정을 또 올리지 않는다
      for (var i = 0; i < 700; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i % 10 == 0) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        }
      }
      expect(find.byType(ArrivalScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(ArrivalScreen, skipOffstage: false), findsNothing);
      expect(find.byType(WalkingScreen), findsOneWidget);
      await settle(tester, () => false, tries: 4);
      final j = await _journey(tester, e, 'j${t1.millisecondsSinceEpoch}');
      expect(j.arrivalShown, isTrue);
      await end(tester, e);
    });
  });

  group('도착 화면', () {
    testWidgets('그림이 1.5초 동안 번지고, 이어서 액자와 액자 이름이 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day, frame: Frame.silver));
      await _openArrival(tester, e, 'j1');
      await tester.pump();

      // 처음: 그림도 액자도 안 보인다. 흐림이 최대
      expect(_opacity(tester, 'arrival-painting'), 0);
      expect(_opacity(tester, 'arrival-frame'), 0);
      expect(_opacity(tester, 'arrival-frame-label'), 0);
      expect(find.byType(ImageFiltered), findsOneWidget);

      // 0.75초: 그림이 반쯤 나타났고 액자는 아직
      await tester.pump(const Duration(milliseconds: 750));
      expect(_opacity(tester, 'arrival-painting'), inExclusiveRange(0.2, 0.99));
      expect(_opacity(tester, 'arrival-frame'), 0);

      // 1.5초: 그림이 다 나타났고(또렷), 액자는 이제 시작
      await tester.pump(const Duration(milliseconds: 750));
      expect(_opacity(tester, 'arrival-painting'), 1);
      expect(_opacity(tester, 'arrival-frame'), lessThan(0.1));
      expect(find.byType(ImageFiltered), findsNothing);

      // 끝: 액자와 이름
      await tester.pump(const Duration(milliseconds: 500));
      expect(_opacity(tester, 'arrival-frame'), 1);
      expect(_opacity(tester, 'arrival-frame-label'), 1);
      expect(find.text('은 액자'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('그림 자리에 명소 이름이 붙는다 (카드의 이름과 합쳐 둘)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day));
      await _openArrival(tester, e, 'j1');
      await _afterAnimation(tester);
      expect(find.text('경복궁'), findsNWidgets(2));
      expect(find.descendant(of: find.byType(PaintingFace), matching: find.text('경복궁')),
          findsOneWidget);
      await end(tester, e);
    });

    testWidgets('값을 못 읽으면 안내 한 줄', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openOnTop(tester, e, const ArrivalScreen(journeyId: '없는-id'),
          ready: () => find.text('도착 정보를 불러오지 못했어요').evaluate().isNotEmpty);
      expect(find.text('도착 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('화집에 걸기'), findsNothing);
      // 뒤로는 된다
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('열기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('날짜는 한국 날짜, 그날 걸음은 그 한국 날짜의 걸음', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.db.into(e.db.daySummaries).insert(DaySummariesCompanion.insert(
            day: '2026-11-19', steps: 12345, distanceM: 0, countedSessions: 0));
        // UTC 11-18 15:30 = 한국 11-19 00:30
        await e.insertArrival('j1', 'kr001', DateTime.utc(2026, 11, 18, 15, 30));
      });
      await _openArrival(tester, e, 'j1');
      expect(_inCard('11월 19일'), findsOneWidget);
      expect(_inCard('그날 걸음 12,345보'), findsOneWidget);
      await end(tester, e);
    });

    group('재방문 줄', () {
      testWidgets('액자가 올랐으면 `나무 → 금으로 바뀌었어요`', (tester) async {
        final e = UiEnv();
        await e.seed(tester, () async {
          await e.insertArrival('j1', 'kr001', DateTime.utc(2026, 11, 10), km: 5);
          await e.insertArrival('j2', 'kr001', _day,
              visitNo: 2, prevFrame: Frame.wood, frame: Frame.gold, km: 61);
        });
        await _openArrival(tester, e, 'j2');
        expect(_inCard('2번째 방문'), findsOneWidget);
        expect(_inCard('나무 → 금으로 바뀌었어요'), findsOneWidget);
        expect(find.textContaining('액자는 그대로예요'), findsNothing);
        expect(find.byType(ArrivalScreen), findsOneWidget);
        await end(tester, e);
      });

      testWidgets('`은 → 금으로 바뀌었어요`', (tester) async {
        final e = UiEnv();
        await e.seed(tester, () async {
          await e.insertArrival('j1', 'kr001', DateTime.utc(2026, 11, 10),
              frame: Frame.silver, km: 25);
          await e.insertArrival('j2', 'kr001', _day,
              visitNo: 2, prevFrame: Frame.silver, frame: Frame.gold, km: 61);
        });
        await _openArrival(tester, e, 'j2');
        expect(_inCard('은 → 금으로 바뀌었어요'), findsOneWidget);
        await end(tester, e);
      });

      testWidgets('그대로면 `액자는 그대로예요 (지난번 32km)`, 지난번은 가장 먼 거리를 반올림', (tester) async {
        final e = UiEnv();
        await e.seed(tester, () async {
          await e.insertArrival('j1', 'kr001', DateTime.utc(2026, 11, 10),
              frame: Frame.silver, km: 32.4);
          await e.insertArrival('j2', 'kr001', DateTime.utc(2026, 11, 12),
              visitNo: 2, prevFrame: Frame.silver, frame: Frame.silver, km: 21);
          await e.insertArrival('j3', 'kr001', _day,
              visitNo: 3, prevFrame: Frame.silver, frame: Frame.silver, km: 22);
        });
        await _openArrival(tester, e, 'j3');
        expect(_inCard('3번째 방문'), findsOneWidget);
        expect(_inCard('액자는 그대로예요 (지난번 32km)'), findsOneWidget);
        expect(find.textContaining('바뀌었어요'), findsNothing);
        await end(tester, e);
      });
    });

    testWidgets('권역을 채운 첫 방문은 소품 카드: `울릉 완성`과 괭이갈매기', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertArrival('j1', 'kr089', _day));
      await _openArrival(tester, e, 'j1');
      final prop = find.byKey(const ValueKey('arrival-prop'));
      expect(prop, findsOneWidget);
      expect(find.descendant(of: prop, matching: find.text('울릉 완성')), findsOneWidget);
      expect(find.descendant(of: prop, matching: find.text('괭이갈매기')), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('뒤로는 그냥 닫는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day));
      await _openArrival(tester, e, 'j1');
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(ArrivalScreen), findsNothing);
      expect(find.text('열기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('다음 목적지는 지도로 바꿔 열고, 지도에서 뒤로 가면 도착 화면이 아니다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day));
      await _openArrival(tester, e, 'j1');
      await tester.tap(find.text('다음 목적지'));
      await transition(tester);
      await settle(tester, () => find.byType(InteractiveViewer).evaluate().isNotEmpty);
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(ArrivalScreen, skipOffstage: false), findsNothing);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('열기'), findsOneWidget);
      await end(tester, e);
    });

    group('화집에 걸기', () {
      testWidgets('빈 벽이면 첫 칸에 걸고 화집을 연다', (tester) async {
        final e = UiEnv();
        await e.seed(tester, () => e.insertArrival('j1', 'kr001', _day));
        await _openArrival(tester, e, 'j1');
        await tester.tap(find.text('화집에 걸기'));
        await transition(tester);
        await settle(tester, () => find.byKey(const ValueKey('wall-0')).evaluate().isNotEmpty);

        expect(find.byType(AlbumScreen), findsOneWidget);
        expect(find.text('화집'), findsOneWidget);
        expect(find.text('바꿀 액자를 누르세요'), findsNothing);
        expect((await tester.runAsync(e.svc.wall))!, ['kr001', null, null, null]);
        final slot0 = find.descendant(
            of: find.byKey(const ValueKey('wall-0')), matching: find.byType(FramedPainting));
        await settle(tester, () => tester.widget<FramedPainting>(slot0).landmark != null);
        expect(tester.widget<FramedPainting>(slot0).landmark!.id, 'kr001');
        await end(tester, e);
      });

      testWidgets('벽이 가득 차면 바꾸기 모드로 열고, 칸을 누르면 그 자리에 걸고 모드를 끝낸다', (tester) async {
        final e = UiEnv();
        await e.seed(tester, () async {
          await e.ownPaintings({
            'kr002': Frame.wood,
            'kr003': Frame.silver,
            'kr004': Frame.gold,
            'kr005': Frame.wood,
          });
          for (final (i, id) in ['kr002', 'kr003', 'kr004', 'kr005'].indexed) {
            await e.svc.setWall(i, id);
          }
          await e.insertArrival('j1', 'kr001', _day, frame: Frame.gold);
        });
        await _openArrival(tester, e, 'j1');
        await tester.tap(find.text('화집에 걸기'));
        await transition(tester);
        await settle(tester, () => find.text('바꿀 액자를 누르세요').evaluate().isNotEmpty);

        // 벽은 아직 그대로
        expect(find.text('바꿀 액자를 누르세요'), findsOneWidget);
        expect((await tester.runAsync(e.svc.wall))!, ['kr002', 'kr003', 'kr004', 'kr005']);

        await tester.tap(find.byKey(const ValueKey('wall-2')));
        await settle(tester, () => find.text('바꿀 액자를 누르세요').evaluate().isEmpty);
        expect(find.text('바꿀 액자를 누르세요'), findsNothing);
        expect((await tester.runAsync(e.svc.wall))!, ['kr002', 'kr003', 'kr001', 'kr005']);

        // 모드가 끝났으니 또 눌러도 바뀌지 않는다
        await tester.tap(find.byKey(const ValueKey('wall-0')));
        await settle(tester, () => false, tries: 4);
        expect((await tester.runAsync(e.svc.wall))!, ['kr002', 'kr003', 'kr001', 'kr005']);
        await end(tester, e);
      });

      testWidgets('이미 벽에 걸린 그림이면 바꾸기 모드가 아니라 그냥 화집', (tester) async {
        final e = UiEnv();
        await e.seed(tester, () async {
          await e.ownPaintings({'kr002': Frame.wood, 'kr003': Frame.wood, 'kr004': Frame.wood});
          await e.insertArrival('j1', 'kr001', _day);
          for (final (i, id) in ['kr002', 'kr003', 'kr004', 'kr001'].indexed) {
            await e.svc.setWall(i, id);
          }
        });
        await _openArrival(tester, e, 'j1');
        await tester.tap(find.text('화집에 걸기'));
        await transition(tester);
        await settle(tester, () => find.byKey(const ValueKey('wall-0')).evaluate().isNotEmpty);
        expect(find.byType(AlbumScreen), findsOneWidget);
        expect(find.text('바꿀 액자를 누르세요'), findsNothing);
        expect((await tester.runAsync(e.svc.wall))!, ['kr002', 'kr003', 'kr004', 'kr001']);
        await end(tester, e);
      });
    });
  });
}
