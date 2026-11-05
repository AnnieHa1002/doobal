import 'package:doobal/app/companion_providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/companion/companion_screen.dart';
import 'package:doobal/ui/debug/debug_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

// 동행을 걷는 중(캔버스 3-1)·걷기 기록(캔버스 3-3)에 잇는 화면 쪽. 계산은 test/app/companion_sync_test.dart

Landmark _farDest() => landmarks.firstWhere((l) {
      if (l.island != Island.mainland) return false;
      final km = buildRoute(nearGyeongbok, l.latLng, rules).totalEffectiveKm;
      return km >= 40 && km <= 90;
    });

final _sheet = find.byKey(const Key('story-sheet'));
final _opened = find.byKey(const ValueKey('walk-story-opened'));
final _progress = find.byKey(const ValueKey('walk-story-progress'));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> met(UiEnv e, String id, {int walks = 0, int chapter = 0}) =>
      e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
            companionId: id,
            metUtc: 1,
            walksTogether: Value(walks),
            chapter: Value(chapter),
          ));

  /// 처음부터(아래 기록보다 앞서) [id]와 함께 걷는다
  Future<void> withCompanion(UiEnv e, String id) => e.db.into(e.db.companionStints).insert(
      CompanionStintsCompanion.insert(startUtc: const Value(1), companionId: Value(id)));

  /// t1 이후 [day]일째의 인정된 걷기 한 줄 (12분, 그날 낮)
  Future<void> session(UiEnv e, int day) {
    final start = t1.add(Duration(days: day));
    return e.db.into(e.db.walkSessions).insert(WalkSessionsCompanion.insert(
          startUtc: Value(start.millisecondsSinceEpoch),
          endUtc: start.add(const Duration(minutes: 12)).millisecondsSinceEpoch,
          steps: 1200,
          distanceM: 840,
          runRatio: 0,
          qualified: true,
          counted: true,
        ));
  }

  group('걷는 중 펼침 카드', () {
    /// 셋 다 만난 먼 여정의 걷는 중을 열고 펼침 카드를 편다 (첫 칸 만남이 안 끼게)
    Future<UiEnv> openDetail(WidgetTester tester, Future<void> Function(UiEnv e) seed) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney(_farDest().id, t1, useFund: false);
        await seed(e);
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.tap(find.text('출발하기'));
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      expect(find.byType(WalkingScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('walk-pill')));
      await tester.pump(const Duration(milliseconds: 200));
      return e;
    }

    testWidgets('함께 걷는 동행과 다음 장까지의 진행 (퐁이 이야기 2/4)', (tester) async {
      final e = await openDetail(tester, (e) async {
        await met(e, 'bright', walks: 6, chapter: 1);
        await withCompanion(e, 'bright');
        // 동기화가 걷기 수를 기록에서 다시 세므로 기록을 넣는다
        for (var d = 1; d <= 6; d++) {
          await session(e, d - 8);
        }
      });
      await settle(tester, () => find.text('퐁이 이야기 2/4').evaluate().isNotEmpty);
      expect(find.text('혼자 걷는 중'), findsNothing);
      await end(tester, e);
    });

    testWidgets('이야기를 끝까지 열었으면 진행 없이 함께 걷는 동행만', (tester) async {
      final e = await openDetail(tester, (e) async {
        await met(e, 'doctor', chapter: rules.companionChapters);
        await withCompanion(e, 'doctor');
      });
      await settle(tester, () => find.text('심 박사와 함께 걷는 중').evaluate().isNotEmpty);
      await end(tester, e);
    });

    testWidgets('혼자 걷기면 그대로 혼자 걷는 중 (만난 동행이 있어도)', (tester) async {
      final e = await openDetail(tester, (e) => met(e, 'bright', chapter: 2));
      await settle(tester, () => find.text('혼자 걷는 중').evaluate().isNotEmpty);
      expect(find.textContaining('이야기'), findsNothing);
      await end(tester, e);
    });
  });

  testWidgets('동기화로 8장이 열리면 새 소품 토스트가 뜬다 (어느 화면이든)', (tester) async {
    final total = rules.companionChapters * rules.companionWalksPerChapter;
    final e = UiEnv();
    await e.seed(tester, () async {
      await met(e, 'bright', walks: total - 1, chapter: rules.companionChapters - 1);
      await withCompanion(e, 'bright');
      for (var d = -total; d < 0; d++) {
        await session(e, d);
      }
    });
    final prop = props.firstWhere((p) => p.id == companionCatalog.byId('bright')!.finaleProp);
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.text('새 소품을 얻었어요 · ${prop.name}').evaluate().isNotEmpty);
    await end(tester, e);
  });

  group('동행 입구의 점 값', () {
    testWidgets('앱 밖에서 장이 열려도 앱으로 돌아온 동기화 뒤에 켜진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'bright', walks: 3);
        await withCompanion(e, 'bright');
        for (var d = -3; d <= -1; d++) {
          await session(e, d);
        }
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
      final container = ProviderScope.containerOf(tester.element(find.byType(RestScreen)));
      final unread = container.listen(unreadStoryProvider, (_, _) {});
      addTearDown(unread.close);
      await settle(tester, () => false, tries: 4);
      expect(unread.read(), isFalse);

      // 앱을 뒤로 보낸 동안 4번째 걷기가 인정된다
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      e.source.records.add(walkRecord(t1, 12, 100));
      e.now = t1.add(const Duration(minutes: 13));
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await settle(tester, () => unread.read());
      expect(unread.read(), isTrue);
      await end(tester, e);
    });

    testWidgets('개발 화면 입구에 점이 뜬다 (쉼터 입구는 T3)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => met(e, 'bright', walks: 4, chapter: 1));
      await openOnTop(
        tester,
        e,
        const DebugScreen(),
        ready: () => find.byKey(const Key('debug-companion-dot')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('debug-companion-dot')), findsOneWidget);
      await end(tester, e);
    });
  });

  group('걷기 기록', () {
    /// t1에 시작한 12분 걷기의 기록 화면을 연다
    Future<UiEnv> openRecord(
      WidgetTester tester,
      Future<void> Function(UiEnv e) seed, {
      bool review = true,
    }) async {
      final e = UiEnv();
      await e.seed(tester, () => seed(e));
      await openOnTop(
        tester,
        e,
        WalkRecordScreen(
          start: t1,
          end: t1.add(const Duration(minutes: 12)),
          ratioBefore: null,
          review: review,
        ),
        ready: () => find.text('걸음').evaluate().isNotEmpty,
      );
      await settle(tester, () => false, tries: 3);
      return e;
    }

    testWidgets('이 걷기로 장이 열렸으면 읽기 카드, 누르면 그 장이 열린다', (tester) async {
      final e = await openRecord(tester, (e) async {
        await met(e, 'bright', walks: 4, chapter: 1);
        await withCompanion(e, 'bright');
        for (var d = -3; d <= 0; d++) {
          await session(e, d);
        }
      });
      expect(_opened, findsOneWidget);
      expect(find.text('이야기 1장이 열렸어요'), findsOneWidget);
      expect(find.text('함께 걷기 ${rules.companionWalksPerChapter}번째'), findsOneWidget);
      expect(find.text('읽기'), findsOneWidget);
      expect(_progress, findsNothing);

      await tester.tap(_opened);
      await settle(tester, () => _sheet.evaluate().isNotEmpty);
      expect(find.byType(CompanionScreen), findsOneWidget);
      final row = (await tester.runAsync(() => (e.db.select(e.db.companions)
            ..where((t) => t.companionId.equals('bright')))
          .getSingle()))!;
      expect(row.readChapter, 1);
      expect(find.byType(WalkRecordScreen, skipOffstage: false), findsOneWidget,
          reason: '닫으면 걷기 기록으로 돌아온다');
      await end(tester, e);
    });

    testWidgets('마친 걷기로 4번째가 채워지면 동기화 뒤 읽기 카드가 뜨고 시스템 알림은 안 나간다', (tester) async {
      final e = await openRecord(tester, (e) async {
        await met(e, 'bright', walks: 3);
        await withCompanion(e, 'bright');
        for (var d = -3; d <= -1; d++) {
          await session(e, d);
        }
        e.source.records.add(walkRecord(t1, 12, 100));
      }, review: false);
      await settle(tester, () => _opened.evaluate().isNotEmpty);
      expect(find.text('이야기 1장이 열렸어요'), findsOneWidget);
      expect(find.text('오늘 함께 걷기 1/${rules.sessionMaxPerDay}'), findsOneWidget);
      final log = (await tester.runAsync(() => (e.db.select(e.db.notificationLog)
            ..where((t) => t.kind.equalsValue(NoticeKind.n3)))
          .get()))!;
      expect(log.single.refKey, 'bright:1');
      expect(e.notifier.calls.where((c) => c.kind == NoticeKind.n3), isEmpty);
      await end(tester, e);
    });

    testWidgets('아직이면 다음 장까지의 함께 걷기 줄', (tester) async {
      final e = await openRecord(tester, (e) async {
        await met(e, 'rest', walks: 7, chapter: 1);
        await withCompanion(e, 'rest');
        for (var d = -6; d <= 0; d++) {
          await session(e, d);
        }
      });
      expect(_opened, findsNothing);
      expect(find.text('이야기 2장까지 함께 걷기 3/4'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('혼자 걸었으면 이야기 줄이 없다', (tester) async {
      final e = await openRecord(tester, (e) async {
        await met(e, 'rest');
        await session(e, 0);
      });
      expect(_opened, findsNothing);
      expect(_progress, findsNothing);
      await end(tester, e);
    });

    testWidgets('이야기를 끝까지 연 뒤의 걷기면 이야기 줄이 없다', (tester) async {
      final total = rules.companionChapters * rules.companionWalksPerChapter;
      final e = await openRecord(tester, (e) async {
        await met(e, 'doctor', walks: total + 1, chapter: rules.companionChapters);
        await withCompanion(e, 'doctor');
        for (var d = -total; d <= 0; d++) {
          await session(e, d);
        }
      });
      expect(_opened, findsNothing);
      expect(_progress, findsNothing);
      await end(tester, e);
    });

    testWidgets('글자를 키워도 읽기 카드가 넘치지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'bright', walks: 4, chapter: 1);
        await withCompanion(e, 'bright');
        for (var d = -3; d <= 0; d++) {
          await session(e, d);
        }
      });
      await openOnTop(
        tester,
        e,
        MediaQuery.withClampedTextScaling(
          minScaleFactor: 2,
          maxScaleFactor: 2,
          child: WalkRecordScreen(
            start: t1,
            end: t1.add(const Duration(minutes: 12)),
            ratioBefore: null,
            review: true,
          ),
        ),
        width: 320,
        height: 640,
        ready: () => find.text('걸음').evaluate().isNotEmpty,
      );
      await settle(tester, () => _opened.evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
      await end(tester, e);
    });
  });
}
