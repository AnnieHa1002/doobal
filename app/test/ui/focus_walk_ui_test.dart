import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 본격 걷기의 앱 쪽 연결: 걷는 중 화면이 앱 걷기 창을 열고 닫는다, AutoSync가 앱이 살아 있다고 적고
// 켠 직후에 끝나지 않은 창을 닫는다.

int _ms(DateTime t) => t.millisecondsSinceEpoch;

/// 앱이 백그라운드로 간다 (실제로는 inactive → hidden → paused 순서로 온다)
void _toBackground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

Future<List<AppWalkRow>> _walks(WidgetTester tester, UiEnv e) async =>
    (await tester.runAsync(() => (e.db.select(e.db.appWalks)
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get()))!;

Future<int?> _alive(WidgetTester tester, UiEnv e) async =>
    (await tester.runAsync(() => e.db.select(e.db.syncState).getSingle()))!.lastAliveUtc;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// 앱을 켜서 쉼터까지 띄운다
  Future<void> openApp(WidgetTester tester, UiEnv e, {Future<void> Function()? seed}) async {
    await e.seed(tester, seed);
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await tester.pump();
  }

  group('걷는 중 화면 ↔ 앱 걷기 창', () {
    Future<void> openWalking(WidgetTester tester, UiEnv e) async {
      await openApp(tester, e, seed: () => e.svc.startJourney('kr003', t1));
      await tester.tap(find.text('출발하기'));
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      expect(find.byType(WalkingScreen), findsOneWidget);
    }

    testWidgets('열면 지금 시각에 열린 창이 생긴다', (tester) async {
      final e = UiEnv();
      await openWalking(tester, e);
      await settle(tester, () => false, tries: 4);
      final walk = (await _walks(tester, e)).single;
      expect((walk.startUtc, walk.endUtc, walk.endReason), (_ms(t1), null, null));
      await end(tester, e);
    });

    testWidgets('걷기 마치기를 누르면 그 시각에 finish로 닫는다 (한 번만)', (tester) async {
      final e = UiEnv();
      await openWalking(tester, e);
      await settle(tester, () => false, tries: 4);

      e.now = t1.add(const Duration(minutes: 12));
      await tester.tap(find.text('걷기 마치기'));
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      final walk = (await _walks(tester, e)).single;
      expect((walk.startUtc, walk.endUtc, walk.endReason),
          (_ms(t1), _ms(e.now), AppWalkEnd.finish));
      await end(tester, e);
    });

    testWidgets('마치기 없이 화면이 사라져도(되돌아가기) 그 시각에 finish로 닫는다', (tester) async {
      final e = UiEnv();
      await openWalking(tester, e);
      await settle(tester, () => false, tries: 4);

      e.now = t1.add(const Duration(minutes: 3));
      Navigator.of(tester.element(find.byType(WalkingScreen))).pop();
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      expect(find.byType(WalkingScreen), findsNothing);
      expect(find.byType(RestScreen), findsOneWidget);
      final walk = (await _walks(tester, e)).single;
      expect((walk.endUtc, walk.endReason), (_ms(e.now), AppWalkEnd.finish));
      await end(tester, e);
    });
  });

  group('AutoSync: 살아 있던 시각과 끝나지 않은 창', () {
    testWidgets('앱을 켜면 앞 실행에서 끝나지 않은 창을 살아 있던 시각에 appEnded로 닫고, 지금 살아 있다고 적는다',
        (tester) async {
      final e = UiEnv();
      final lastAlive = t0.add(const Duration(minutes: 20));
      await openApp(tester, e, seed: () async {
        await e.db.into(e.db.appWalks).insert(AppWalksCompanion.insert(startUtc: _ms(t0)));
        await e.db.update(e.db.syncState).write(
            SyncStateCompanion(lastAliveUtc: Value(_ms(lastAlive))));
      });
      await settle(tester, () => false, tries: 6);

      final walk = (await _walks(tester, e)).single;
      expect((walk.endUtc, walk.endReason), (_ms(lastAlive), AppWalkEnd.appEnded));
      // 닫은 뒤에 지금(t1)을 살아 있던 시각으로 적는다
      expect(await _alive(tester, e), _ms(t1));
      await end(tester, e);
    });

    testWidgets('백그라운드로 갈 때 살아 있던 시각을 적는다', (tester) async {
      final e = UiEnv();
      await openApp(tester, e);
      await settle(tester, () => false, tries: 4);
      expect(await _alive(tester, e), _ms(t1));

      e.now = t1.add(const Duration(minutes: 7));
      _toBackground(tester);
      await settle(tester, () => false, tries: 8);
      expect(await _alive(tester, e), _ms(e.now));
      await end(tester, e);
    });

    testWidgets('살아 있는 동안 config sync.aliveSaveSec(30초)마다 적는다', (tester) async {
      final e = UiEnv();
      await openApp(tester, e);
      await settle(tester, () => false, tries: 4);
      expect(e.appRules.aliveSaveSec, 30);
      expect(await _alive(tester, e), _ms(t1));

      // 30초가 되기 전에는 그대로
      e.now = t1.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
      await settle(tester, () => false, tries: 4);
      expect(await _alive(tester, e), _ms(t1));

      // 30초 주기가 오면 그 시각을 적는다
      e.now = t1.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 11));
      await settle(tester, () => false, tries: 8);
      expect(await _alive(tester, e), _ms(e.now));

      // 한 주기 더
      e.now = t1.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 30));
      await settle(tester, () => false, tries: 8);
      expect(await _alive(tester, e), _ms(e.now));
      await end(tester, e);
    });
  });
}
