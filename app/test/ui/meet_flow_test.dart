import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/companion.dart';
import 'package:doobal/domain/companion_engine.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/companion/companion_screen.dart';
import 'package:doobal/ui/companion/meet_flow.dart';
import 'package:doobal/ui/debug/debug_screen.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

// 길 위 만남 (캔버스 3-4): 실루엣 → 다가가기 → 프롤로그 → 함께/혼자, 그리고 걷는 중 화면에 뜨는 것

Companion _c(String id) => companionCatalog.byId(id)!;

Finder _approach() => find.byKey(const Key('meet-approach'));
Finder _line() => find.byKey(const Key('meet-line'));
Finder _together() => find.byKey(const Key('meet-together'));
Finder _solo() => find.byKey(const Key('meet-solo'));

Landmark _farDest() => landmarks.firstWhere((l) {
      if (l.island != Island.mainland) return false;
      final km = buildRoute(nearGyeongbok, l.latLng, rules).totalEffectiveKm;
      return km >= 40 && km <= 90;
    });

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> pumpFlow(
    WidgetTester tester,
    Companion companion, {
    Companion? walkingWith,
    ValueChanged<bool>? onChoose,
    double width = 390,
    double height = 844,
  }) async {
    phone(tester, width: width, height: height);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MeetFlow(
          companion: companion,
          walkingWith: walkingWith,
          rules: rules,
          onChoose: onChoose ?? (_) {},
        ),
      ),
    ));
    await tester.pump();
  }

  /// 프롤로그 대사를 끝까지 넘긴다
  Future<void> throughPrologue(WidgetTester tester, Companion c) async {
    final n = storyBeats(c.chapters.first.lines).length;
    for (var i = 0; i < n; i++) {
      await tester.tap(_line());
      await tester.pump();
    }
  }

  group('흐름', () {
    testWidgets('실루엣: 누구인지 안 나오고 다가가기만 있다', (tester) async {
      await pumpFlow(tester, _c('bright'));
      expect(find.text('길 위 만남'), findsOneWidget);
      expect(find.text('길 앞쪽에 누군가 있어요'), findsOneWidget);
      expect(find.text('다가가 볼까요?'), findsOneWidget);
      expect(find.byKey(const Key('meet-silhouette')), findsOneWidget);
      expect(find.text('퐁이'), findsNothing);
      expect(find.text('퐁'), findsNothing);
      expect(_approach(), findsOneWidget);
    });

    testWidgets('실루엣 크기와 발은 장면과 같은 config 값을 따른다 (정령 키의 절반)', (tester) async {
      // 정령 180pt(540 × 390/1170)의 절반, 길은 화면 아래에서 361 × 390/1170pt
      await pumpFlow(tester, _c('bright'));
      final figure = find.byKey(const Key('meet-silhouette'));
      expect(rules.characterHeightPx, 540);
      expect(tester.getSize(figure).height, closeTo(90, 0.01));
      expect(tester.getBottomLeft(figure).dy, closeTo(844 - 361 * 390 / 1170, 0.01));

      // 작은 폭에서는 장면처럼 같이 줄어든다
      await pumpFlow(tester, _c('bright'), width: 320, height: 568);
      expect(tester.getSize(figure).height, closeTo(540 * 320 / 1170 / 2, 0.01));
    });

    testWidgets('다가가면 프롤로그: 지문·말하는 이·진행, 눌러서 넘긴다', (tester) async {
      await pumpFlow(tester, _c('bright'));
      await tester.tap(_approach());
      await tester.pump();

      final beats = storyBeats(_c('bright').chapters.first.lines);
      expect(find.byKey(const Key('story-art')), findsOneWidget);
      expect(find.text('(${beats[0].direction})'), findsOneWidget);
      expect(find.text('퐁이'), findsOneWidget);
      expect(find.text(beats[0].text), findsOneWidget);
      expect(find.text('1 / ${beats.length} · 눌러서 넘기기'), findsOneWidget);

      await tester.tap(_line());
      await tester.pump();
      expect(find.text('2 / ${beats.length} · 눌러서 넘기기'), findsOneWidget);
      expect(find.text('(${beats[0].direction})'), findsNothing);

      final me = beats.indexWhere((b) => b.who == StorySpeaker.me);
      for (var i = 1; i < me; i++) {
        await tester.tap(_line());
        await tester.pump();
      }
      expect(find.text('나'), findsOneWidget);
      expect(find.text(beats[me].text), findsOneWidget);
    });

    testWidgets('대사가 끝나면 새 동행 카드: 혼자 걷던 중이면 함께 걷기·혼자 걷기', (tester) async {
      final picks = <bool>[];
      await pumpFlow(tester, _c('bright'), onChoose: picks.add);
      await tester.tap(_approach());
      await tester.pump();
      await throughPrologue(tester, _c('bright'));

      expect(find.text('새 동행을 만났어요'), findsOneWidget);
      expect(find.text('퐁이'), findsWidgets);
      expect(find.text('오리'), findsOneWidget);
      expect(find.text('함께 걷기'), findsOneWidget);
      expect(find.text('혼자 걷기'), findsOneWidget);
      await tester.tap(_together());
      await tester.tap(_solo());
      expect(picks, [true, false]);
    });

    testWidgets('새 동행 카드의 종 이름은 데이터(speciesName)에서 읽는다', (tester) async {
      final c = _c('rest');
      final renamed = Companion(
        id: c.id,
        name: c.name,
        species: c.species,
        speciesName: '시험 종',
        terrain: c.terrain,
        pace: c.pace,
        finaleProp: c.finaleProp,
        faces: c.faces,
        chapters: c.chapters,
      );
      await pumpFlow(tester, renamed);
      await tester.tap(_approach());
      await tester.pump();
      await throughPrologue(tester, renamed);
      expect(find.text('시험 종'), findsOneWidget);
      expect(find.text('고양이'), findsNothing);
    });

    testWidgets('다른 동행과 걷던 중이면 버튼에 두 이름이 나온다', (tester) async {
      final picks = <bool>[];
      await pumpFlow(tester, _c('doctor'), walkingWith: _c('rest'), onChoose: picks.add);
      await tester.tap(_approach());
      await tester.pump();
      await throughPrologue(tester, _c('doctor'));

      expect(find.text('심 박사와 함께 걷기'), findsOneWidget);
      expect(find.text('휴와 계속 걷기'), findsOneWidget);
      expect(find.text('산삼'), findsOneWidget);
      await tester.tap(_solo());
      expect(picks, [false]);
    });
  });

  group('글자 크기', () {
    testWidgets('세 동행 모두 작은 폰 + 글자 2배에서 어느 장면도 넘치지 않는다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final c in companionCatalog.companions) {
        await pumpFlow(tester, c, walkingWith: _c('rest'), width: 320, height: 568);
        expect(tester.takeException(), isNull, reason: '${c.id} 실루엣');
        await tester.tap(_approach());
        await tester.pump();
        final n = storyBeats(c.chapters.first.lines).length;
        for (var i = 0; i < n; i++) {
          expect(tester.takeException(), isNull, reason: '${c.id} 대사 $i');
          await tester.tap(_line());
          await tester.pump();
        }
        expect(tester.takeException(), isNull, reason: '${c.id} 고르기');
        expect(_together(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('개발 화면', () {
    testWidgets('길 위 만남을 끝내면 동행 화면에 나오고, 이야기 한 장 더로 다음 장이 열린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openOnTop(
        tester,
        e,
        const DebugScreen(),
        ready: () => find.text('길 위 만남').evaluate().isNotEmpty,
      );
      await tester.ensureVisible(find.text('길 위 만남'));
      await tester.pump();
      await tester.tap(find.text('길 위 만남'));
      await settle(tester, () => _approach().evaluate().isNotEmpty);
      await transition(tester);

      // 칸 없이 catalog의 첫 동행을 만난다
      await tester.tap(_approach());
      await tester.pump();
      await throughPrologue(tester, _c('bright'));
      await tester.tap(_together());
      await settle(tester, () => find.text('이야기 한 장 더').evaluate().isNotEmpty);
      await transition(tester);
      await settle(tester, () => false, tries: 4);

      await tester.ensureVisible(find.text('이야기 한 장 더'));
      await tester.pump();
      await tester.tap(find.text('이야기 한 장 더'));
      await settle(tester, () => false, tries: 6);

      // 동행 화면 입구는 쉼터 불 옆 동행이다 (개발 화면 임시 입구는 지움): 여기서는 바로 연다
      expect(find.text('동행'), findsNothing);
      Navigator.of(tester.element(find.byType(DebugScreen)))
          .push(MaterialPageRoute<void>(builder: (_) => const CompanionScreen()));
      await transition(tester);
      await settle(tester, () => find.byKey(const Key('companion-now')).evaluate().isNotEmpty);
      expect(find.text('지금 함께 걷는 중'), findsOneWidget);
      expect(find.text('만난 동행 1'), findsOneWidget);
      expect(find.text('이야기 1'), findsOneWidget);
      expect(find.text('걷는 게 좋은 이유'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('걷는 중 화면', () {
    /// 먼 여정 중 걷는 중 화면을 연다. 센서 기준값(1,000)도 받아 둔다
    Future<UiEnv> openWalking(WidgetTester tester, {Future<void> Function(UiEnv)? seed}) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney(_farDest().id, t1, useFund: false);
        await seed?.call(e);
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.tap(find.text('출발하기'));
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      expect(find.byType(WalkingScreen), findsOneWidget);
      e.live.push(1000);
      await tester.pump(const Duration(milliseconds: 100));
      return e;
    }

    Future<void> sensorSteps(WidgetTester tester, UiEnv e, int steps) async {
      e.now = e.now.add(const Duration(seconds: 6));
      e.live.push(1000 + steps);
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<List<CompanionRow>> rows(WidgetTester tester, UiEnv e) async =>
        (await tester.runAsync(() => e.db.select(e.db.companions).get()))!;

    Finder finish() => find.text('걷기 마치기');

    testWidgets('첫 실제 여정의 2km: 이정표 카드 대신 길 위 만남, 고르면 걷는 중으로 돌아온다', (tester) async {
      final e = await openWalking(tester);
      expect(finish(), findsOneWidget);

      // 2.1km(2,100보): 칸을 넘는다
      await sensorSteps(tester, e, 2100);
      await settle(tester, () => _approach().evaluate().isNotEmpty);

      expect(find.text('길 앞쪽에 누군가 있어요'), findsOneWidget);
      expect(find.byKey(const Key('walk-event-card')), findsNothing);
      expect(finish(), findsNothing, reason: '만남 동안 HUD는 가린다');
      // 만남 동안 장면은 멈춰 있다 (걸음은 뒤에서 계속 센다)
      SceneView scene() => tester.widget<SceneView>(find.byType(SceneView));
      expect(scene().moving, isFalse);
      expect(scene().running, isFalse);
      final stoppedAt = scene().distanceM;
      await sensorSteps(tester, e, 2300);
      await tester.pump(const Duration(seconds: 1));
      expect(scene().distanceM, stoppedAt);

      final row = (await rows(tester, e)).single;
      expect(row.metK, 1);
      expect(row.readChapter, -1);
      expect((await tester.runAsync(() => e.db.select(e.db.journeyEvents).get()))!, isEmpty);

      final met = _c(row.companionId);
      await tester.tap(_approach());
      await tester.pump();
      await throughPrologue(tester, met);
      await tester.tap(_together());
      await settle(tester, () => finish().evaluate().isNotEmpty);

      expect(finish(), findsOneWidget);
      expect(_together(), findsNothing);
      await settle(tester, () => false, tries: 4);
      expect((await rows(tester, e)).single.readChapter, 0);
      final stints = (await tester.runAsync(() => e.db.select(e.db.companionStints).get()))!;
      expect(stints.single.companionId, met.id);
      await end(tester, e);
    });

    testWidgets('혼자 걷기를 고르면 함께 걷는 줄이 안 생기고, 다음 칸은 이벤트다', (tester) async {
      final e = await openWalking(tester);
      await sensorSteps(tester, e, 2100);
      await settle(tester, () => _approach().evaluate().isNotEmpty);
      final met = _c((await rows(tester, e)).single.companionId);
      await tester.tap(_approach());
      await tester.pump();
      await throughPrologue(tester, met);
      await tester.tap(_solo());
      await settle(tester, () => finish().evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 4);
      expect((await tester.runAsync(() => e.db.select(e.db.companionStints).get()))!, isEmpty);

      // 4.1km: 다음 칸
      await sensorSteps(tester, e, 4100);
      await settle(tester, () => find.byKey(const Key('walk-event-card')).evaluate().isNotEmpty);
      expect(find.text('2km 이정표'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('지난번에 못 끝낸 만남은 다음 걷는 중을 열면 이어서 나온다', (tester) async {
      final e = await openWalking(tester, seed: (e) async {
        await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
              companionId: 'rest',
              metUtc: t1.millisecondsSinceEpoch,
              readChapter: const Value(-1),
            ));
      });
      await settle(tester, () => _approach().evaluate().isNotEmpty);
      expect(find.text('길 앞쪽에 누군가 있어요'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('다른 동행과 걷던 중이면 그 이름이 버튼에 나오고, 계속 걷기면 줄이 안 는다', (tester) async {
      final e = await openWalking(tester, seed: (e) async {
        await e.db
            .into(e.db.companions)
            .insert(CompanionsCompanion.insert(companionId: 'rest', metUtc: 1));
        await e.db.into(e.db.companionStints).insert(CompanionStintsCompanion.insert(
              startUtc: const Value(1),
              companionId: const Value('rest'),
            ));
        await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
              companionId: 'bright',
              metUtc: t1.millisecondsSinceEpoch,
              readChapter: const Value(-1),
            ));
      });
      await settle(tester, () => _approach().evaluate().isNotEmpty);
      await tester.tap(_approach());
      await tester.pump();
      await throughPrologue(tester, _c('bright'));
      expect(find.text('퐁이와 함께 걷기'), findsOneWidget);
      expect(find.text('휴와 계속 걷기'), findsOneWidget);
      await tester.tap(_solo());
      await settle(tester, () => finish().evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 4);
      final stints = (await tester.runAsync(() => e.db.select(e.db.companionStints).get()))!;
      expect(stints.single.companionId, 'rest');
      await end(tester, e);
    });
  });
}
