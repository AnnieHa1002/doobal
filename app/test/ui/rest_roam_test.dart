import 'dart:math';

import 'package:doobal/app/decor_providers.dart';
import 'package:doobal/app/screen_providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/ui/companion/companion_screen.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

// 완결 동행 쉼터 돌아다니기·말풍선 (T15 5단계, 16장 11/18 ④·11/19 ②, config companions.finaleRoam,
// companions.json restLines)

Future<void> _meet(UiEnv e, String id, {required int read}) => e.db.into(e.db.companions).insert(
      CompanionsCompanion.insert(
        companionId: id,
        metUtc: 1,
        chapter: Value(rules.companionChapters),
        readChapter: Value(read),
      ),
    );

Future<void> _open(WidgetTester tester, UiEnv e) async {
  phone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...e.overrides,
      restWiggleProvider.overrideWithValue(const WiggleSpec.off()),
      restSwapRandomProvider.overrideWithValue(Random(5)),
      finaleRoamRandomProvider.overrideWithValue(Random(7)),
    ],
    child: const MaterialApp(home: RestScreen()),
  ));
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('이야기 마지막 장(8장)까지 읽은 동행만 쉼터에 나온다 (동행마다 따로)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _meet(e, 'bright', read: rules.companionChapters);
      await _meet(e, 'rest', read: rules.companionChapters - 1);
    });
    await _open(tester, e);
    expect(find.byKey(const ValueKey('rest-roam-bright')), findsOneWidget);
    expect(find.byKey(const ValueKey('rest-roam-rest')), findsNothing, reason: '7장까지 읽음');
    // 정령 키의 절반 (걷기 탭 동행과 같은 비율)
    final r = tester.getRect(find.byKey(const ValueKey('rest-roam-hit-bright')));
    expect(r.height, closeTo(campTheme.character.heightPt * 0.5, 0.5));
    // 발은 땅 띠 안
    final band = campTheme.decor!.band;
    expect(r.bottom, inInclusiveRange(band.footYMin - 0.5, band.footYMax + 0.5));
    await end(tester, e);
  });

  testWidgets('천천히 걷다 멈춘다: 멈춤(4~10초)이 끝나면 자리가 바뀐다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => _meet(e, 'doctor', read: rules.companionChapters));
    await _open(tester, e);
    final hit = find.byKey(const ValueKey('rest-roam-hit-doctor'));
    final before = tester.getRect(hit).bottomCenter;
    for (var i = 0; i < 15 * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final after = tester.getRect(hit).bottomCenter;
    expect((after - before).distance, greaterThan(1));
    // 15초에 많아야 12pt/초 × (15 − 4)초
    expect((after - before).distance, lessThanOrEqualTo(12 * 11 + 1));
    await end(tester, e);
  });

  testWidgets('누르면 말풍선 한 줄 3초 (restLines 3줄 중), 떠 있을 때 한 번 더 누르면 동행 화면', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => _meet(e, 'bright', read: rules.companionChapters));
    await _open(tester, e);
    final lines = {for (final l in companionCatalog.byId('bright')!.restLines) l.text};
    expect(lines, hasLength(3));
    final tap = find.byKey(const ValueKey('rest-roam-tap-bright'));
    await tester.tap(tap);
    await tester.pump();
    final bubble = find.byKey(const ValueKey('rest-roam-bubble'));
    expect(bubble, findsOneWidget);
    final text = tester.widget<Text>(find.descendant(of: bubble, matching: find.byType(Text))).data;
    expect(lines, contains(text));
    // 3초 뒤 사라진다
    for (var i = 0; i < 31; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(bubble, findsNothing);
    // 다시 누르면 다른 줄 (바로 앞 줄은 안 반복)
    await tester.tap(tap);
    await tester.pump();
    final second = tester.widget<Text>(find.descendant(of: bubble, matching: find.byType(Text))).data;
    expect(second, isNot(text));
    // 떠 있을 때 한 번 더 누르면 동행 화면
    await tester.tap(tap);
    await transition(tester);
    await settle(tester, () => find.byType(CompanionScreen).evaluate().isNotEmpty);
    expect(find.byType(CompanionScreen), findsOneWidget);
    await end(tester, e);
  });
}
