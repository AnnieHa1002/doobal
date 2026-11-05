import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/ui/companion/companion_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 동행 화면과 이야기 시트 (캔버스 7-1). 계산은 test/app/companion_sync_test.dart가 본다

Finder _row(String id, int no) => find.byKey(Key('story-row-$id-$no'));
Finder _tile(String id) => find.byKey(Key('companion-tile-$id'));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> met(UiEnv e, String id, {int at = 1, int chapter = 0, int read = 0}) =>
      e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
            companionId: id,
            metUtc: at,
            chapter: Value(chapter),
            readChapter: Value(read),
          ));

  Future<void> walkWith(UiEnv e, String id) => e.db
      .into(e.db.companionStints)
      .insert(CompanionStintsCompanion.insert(startUtc: const Value(1), companionId: Value(id)));

  /// 화면을 열고 이름이나 빈 상태가 뜰 때까지 기다린다
  Future<UiEnv> open(
    WidgetTester tester,
    Future<void> Function(UiEnv e) seed, {
    double width = 390,
    double height = 844,
  }) async {
    final e = UiEnv();
    await e.seed(tester, () => seed(e));
    await openOnTop(
      tester,
      e,
      const CompanionScreen(),
      width: width,
      height: height,
      ready: () => find.byKey(const Key('companion-now')).evaluate().isNotEmpty,
    );
    return e;
  }

  Future<List<CompanionStintRow>> stints(WidgetTester tester, UiEnv e) async =>
      (await tester.runAsync(() => e.db.select(e.db.companionStints).get()))!;

  /// 동행을 바꾸거나 읽은 뒤 화면이 새 값을 받을 때까지
  Future<void> refreshed(WidgetTester tester, bool Function() done) => settle(tester, done);

  group('만난 동행만 보인다', () {
    testWidgets('못 만난 동행의 칸·실루엣·힌트·n / 3이 없다 (16장 11/5)', (tester) async {
      final e = await open(tester, (e) => met(e, 'bright'));
      expect(find.text('만난 동행 1'), findsOneWidget);
      expect(_tile('bright'), findsOneWidget);
      expect(_tile('rest'), findsNothing);
      expect(_tile('doctor'), findsNothing);
      expect(find.text('휴'), findsNothing);
      expect(find.text('심 박사'), findsNothing);
      expect(find.text('???'), findsNothing);
      expect(find.textContaining('걷다 보면'), findsNothing);
      expect(find.textContaining('/ 3'), findsNothing);
      await end(tester, e);
    });

    testWidgets('만남 흐름을 안 끝낸 동행은 아직 안 보인다', (tester) async {
      final e = await open(tester, (e) async {
        await met(e, 'bright');
        await met(e, 'rest', at: 2, read: -1);
      });
      expect(find.text('만난 동행 1'), findsOneWidget);
      expect(_tile('rest'), findsNothing);
      await end(tester, e);
    });

    testWidgets('아무도 안 만났으면 혼자이고 바꾸기·이야기가 없다 (개발 입구로만 온다)', (tester) async {
      final e = await open(tester, (e) async {});
      expect(find.text('혼자 걷는 중'), findsOneWidget);
      expect(find.text('만난 동행 0'), findsOneWidget);
      expect(find.byKey(const Key('companion-toggle')), findsNothing);
      expect(find.textContaining('의 이야기'), findsNothing);
      await end(tester, e);
    });
  });

  group('동행 바꾸기·혼자 걷기', () {
    testWidgets('혼자 걷기 ↔ 함께 걷기: 상태가 바뀌고 줄이 쌓인다', (tester) async {
      final e = await open(tester, (e) async {
        await met(e, 'bright', chapter: 1);
        await walkWith(e, 'bright');
      });
      expect(find.text('지금 함께 걷는 중'), findsOneWidget);
      expect(find.text('혼자 걷기'), findsOneWidget);

      await tester.tap(find.byKey(const Key('companion-toggle')));
      await refreshed(tester, () => find.text('혼자 걷는 중').evaluate().isNotEmpty);
      expect(find.text('혼자 걷는 중'), findsOneWidget);
      expect(find.text('퐁이와 함께 걷기'), findsOneWidget);
      // 혼자여도 마지막 동행의 이야기는 그대로 보인다
      expect(find.text('퐁이의 이야기'), findsOneWidget);
      expect((await stints(tester, e)).last.companionId, isNull);

      await tester.tap(find.byKey(const Key('companion-toggle')));
      await refreshed(tester, () => find.text('지금 함께 걷는 중').evaluate().isNotEmpty);
      expect((await stints(tester, e)).last.companionId, 'bright');
      await end(tester, e);
    });

    testWidgets('칸을 누르면 그 동행과 걷고 그 동행의 이야기가 보인다', (tester) async {
      final e = await open(tester, (e) async {
        await met(e, 'bright');
        await met(e, 'rest', at: 2);
        await walkWith(e, 'bright');
      });
      expect(find.text('만난 동행 2'), findsOneWidget);
      expect(find.text('퐁이의 이야기'), findsOneWidget);

      await tester.tap(_tile('rest'));
      await refreshed(tester, () => find.text('휴의 이야기').evaluate().isNotEmpty);
      expect(find.text('휴의 이야기'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('companion-now'))).data, '휴');
      expect((await stints(tester, e)).last.companionId, 'rest');
      await end(tester, e);
    });

    testWidgets('혼자일 때 칸을 누르면 그 동행과 함께 걷는다', (tester) async {
      final e = await open(tester, (e) => met(e, 'doctor'));
      expect(find.text('혼자 걷는 중'), findsOneWidget);
      expect(find.text('심 박사와 함께 걷기'), findsOneWidget);
      await tester.tap(_tile('doctor'));
      await refreshed(tester, () => find.text('지금 함께 걷는 중').evaluate().isNotEmpty);
      expect((await stints(tester, e)).single.companionId, 'doctor');
      await end(tester, e);
    });
  });

  group('이야기', () {
    testWidgets('열린 장만 줄이 있고, 그림이 있는 장에만 표시가 있다', (tester) async {
      final e = await open(tester, (e) => met(e, 'bright', chapter: 2));
      expect(_row('bright', 0), findsOneWidget);
      expect(_row('bright', 1), findsOneWidget);
      expect(_row('bright', 2), findsOneWidget);
      expect(_row('bright', 3), findsNothing);
      expect(find.text('처음 가 본 곳 목록'), findsNothing, reason: '3장 제목');
      expect(find.text('프롤로그'), findsOneWidget);
      expect(find.text('걷는 게 좋은 이유'), findsOneWidget);
      expect(find.text('그림'), findsOneWidget);
      expect(find.text('이야기 2'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('프롤로그만 열린 동행 칸은 ‘프롤로그’, 장이 열리면 ‘이야기 n’', (tester) async {
      final e = await open(tester, (e) async {
        await met(e, 'bright', chapter: 3);
        await met(e, 'rest', at: 2);
        await walkWith(e, 'bright');
      });
      expect(find.text('이야기 3'), findsOneWidget);
      expect(find.text('이야기 0'), findsNothing);
      await tester.tap(_tile('rest'));
      await refreshed(tester, () => find.text('휴의 이야기').evaluate().isNotEmpty);
      // 칸의 작은 글 + 목록의 프롤로그 줄
      expect(find.text('프롤로그'), findsNWidgets(2));
      expect(_row('rest', 0), findsOneWidget);
      expect(_row('rest', 1), findsNothing);
      await end(tester, e);
    });

    testWidgets('8장까지 열리면 완결이 보이고 그림 표시가 둘이다', (tester) async {
      final e = await open(tester, (e) => met(e, 'bright', chapter: 8));
      await tester.scrollUntilVisible(_row('bright', 8), 200);
      expect(find.text('두 발로 가는 길 (완결)'), findsOneWidget);
      expect(find.text('그림'), findsNWidgets(2));
      await end(tester, e);
    });

    testWidgets('줄을 누르면 시트에 본문이 나오고 읽은 장이 남는다', (tester) async {
      final e = await open(tester, (e) => met(e, 'bright', chapter: 1));
      await tester.tap(_row('bright', 1));
      await refreshed(tester, () => find.byKey(const Key('story-sheet')).evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1장 · 걷는 게 좋은 이유'), findsOneWidget);
      // 지문은 그대로, 말은 말하는 이와 함께 나온다
      expect(find.text('퐁이가 앞서 뛰어갔다 돌아온다'), findsOneWidget);
      expect(find.textContaining('와, 저 모퉁이 돌면 길이 또 바뀌어!', findRichText: true), findsOneWidget);
      expect(find.textContaining('화가한테 딱 맞는 말이네', findRichText: true), findsOneWidget);
      // 그림이 없는 장에는 그림 자리가 없다
      expect(find.byKey(const Key('story-art')), findsNothing);

      final rows = (await tester.runAsync(() => e.db.select(e.db.companions).get()))!;
      expect(rows.single.readChapter, 1);

      await tester.tap(find.byKey(const Key('story-close')));
      await transition(tester);
      expect(find.byKey(const Key('story-sheet')), findsNothing);
      await end(tester, e);
    });

    testWidgets('프롤로그 시트에는 그림 자리가 있다', (tester) async {
      final e = await open(tester, (e) => met(e, 'rest'));
      await tester.tap(_row('rest', 0));
      await refreshed(tester, () => find.byKey(const Key('story-sheet')).evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('프롤로그 · 만남'), findsOneWidget);
      expect(find.byKey(const Key('story-art')), findsOneWidget);
      await end(tester, e);
    });
  });

  group('글자 크기', () {
    testWidgets('작은 폰 + 글자 2배에서 화면과 시트가 넘치지 않는다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final e = await open(
        tester,
        (e) async {
          await met(e, 'bright', chapter: 8);
          await met(e, 'rest', at: 2);
          await met(e, 'doctor', at: 3);
          await walkWith(e, 'doctor');
        },
        width: 320,
        height: 568,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(_tile('bright'));
      await refreshed(tester, () => find.text('퐁이의 이야기').evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(_row('bright', 8), 200);
      await tester.tap(_row('bright', 8));
      await refreshed(tester, () => find.byKey(const Key('story-sheet')).evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await end(tester, e);
    });
  });
}
