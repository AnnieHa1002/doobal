import 'dart:math';

import 'package:doobal/app/providers.dart';
import 'package:doobal/app/screen_providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/scene/doobal_character.dart';
import 'package:doobal/ui/shop/shop_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

Future<void> _open(WidgetTester tester, UiEnv e, {Random? random}) async {
  phone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...e.overrides,
      restWiggleProvider.overrideWithValue(const WiggleSpec.off()),
      restSwapRandomProvider.overrideWithValue(random ?? Random(5)),
    ],
    child: const MaterialApp(home: RestScreen()),
  ));
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
  await tester.pump();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(RestScreen)));

DoobalCharacter _doobal(WidgetTester tester) =>
    tester.widget<DoobalCharacter>(find.byType(DoobalCharacter));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('쉼터 정령 자세 (config character.rive.restSwap, 16장 11/11)', () {
    testWidgets('처음은 떠 있기 정면, 20~40초마다 떠 있기·앉기 정면·앉기 옆 중 다른 자세로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(_doobal(tester).posePick, 0);
      // 1초씩 4분 동안 지켜보며 바뀐 때와 자세를 적는다
      final changes = <(int, int)>[(0, 0)];
      for (var sec = 1; sec <= 240; sec++) {
        await tester.pump(const Duration(seconds: 1));
        final p = _doobal(tester).posePick!;
        if (p != changes.last.$2) changes.add((sec, p));
      }
      final seen = [for (final c in changes) c.$2];
      expect(changes.length, greaterThanOrEqualTo(6), reason: '4분에 20~40초마다면 6번 이상');
      for (var i = 1; i < changes.length; i++) {
        final gap = changes[i].$1 - changes[i - 1].$1;
        expect(gap, inInclusiveRange(20, 41), reason: '$changes');
        expect([0, 2, 3], contains(changes[i].$2));
      }
      expect(seen.toSet(), {0, 2, 3});
      expect(_doobal(tester).mirrored, isFalse);
      await end(tester, e);
    });

    testWidgets('밤에는 잠들기 + 졸림 (하늘 night 구간)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      // 한국 11월 18일 밤 11시
      e.now = DateTime.utc(2026, 11, 18, 14);
      await _open(tester, e);
      expect((_doobal(tester).posePick, _doobal(tester).expression), (4, 4));
      // 바꾸기 시계가 돌아도 밤에는 잠든 채
      await tester.pump(const Duration(seconds: 45));
      expect((_doobal(tester).posePick, _doobal(tester).expression), (4, 4));
      await end(tester, e);
    });

    testWidgets('쉼터에서 새 소품을 얻으면 정령이 잠깐 놀란다 (palette newProp)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(_doobal(tester).cue, isNull);

      await tester.runAsync(() => e.db.into(e.db.propsOwned).insert(
            PropsOwnedCompanion.insert(propId: 'hat_02', unlockedUtc: 1),
          ));
      _container(tester).invalidate(snapshotProvider);
      await settle(tester, () => _doobal(tester).cue != null);
      expect((_doobal(tester).cue!.expr, _doobal(tester).cue!.holdSec), (2, 2));
      await end(tester, e);
    });
  });

  group('새 소식 점 (config ui.newDot, 16장 11/13)', () {
    Finder cartDot() => find.byKey(const ValueKey('cart-dot'));

    testWidgets('수레 점은 처음에는 없고, 기본 소품을 얻어 색 소품이 새로 들어오면 켜지고, 상점을 열면 꺼진다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      // 첫날: 지금 보이는 상품은 다 본 것
      expect(cartDot(), findsNothing);

      // 여행 모자를 얻으면 색 소품 3개가 상점에 새로 들어온다
      await tester.runAsync(() => e.db.into(e.db.propsOwned).insert(
            PropsOwnedCompanion.insert(propId: 'hat_02', unlockedUtc: 1),
          ));
      _container(tester).invalidate(snapshotProvider);
      await settle(tester, () => cartDot().evaluate().isNotEmpty);
      expect(cartDot(), findsOneWidget);
      expect(_container(tester).read(shopNewsProvider), hasLength(3));

      // 상점을 열고 돌아오면 꺼진다
      final c = _container(tester);
      Navigator.of(tester.element(find.byType(RestScreen))).push(
          MaterialPageRoute<void>(builder: (_) => const ShopScreen()));
      await settle(tester, () => find.byType(ShopScreen).evaluate().isNotEmpty);
      await tester.pump();
      expect(c.read(shopNewsProvider), isEmpty);
      Navigator.of(tester.element(find.byType(ShopScreen))).pop();
      await settle(tester, () => find.byType(ShopScreen).evaluate().isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(cartDot(), findsNothing);
      await end(tester, e);
    });

    testWidgets('노트에는 점이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(find.byKey(const ValueKey('note-dot')), findsNothing);
      await end(tester, e);
    });
  });
}
