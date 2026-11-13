import 'dart:math' as math;

import 'package:doobal/app/companion_providers.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/shop.dart';
import 'package:doobal/ui/companion/companion_screen.dart';
import 'package:doobal/ui/companion/companion_slot.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/rest/rest_slots.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart' show shopCatalog;
import 'ui_env.dart';

// 쉼터 불 옆 동행 (캔버스 2-2 → 7-1): 함께 걷는 동행만, 안 읽은 장 점, 흔들림 우선, 늦은 도착

final _entry = find.byKey(const ValueKey('camp-object-companion'));
final _art = find.byKey(const ValueKey('rest-companion-art'));
final _dot = find.byKey(const ValueKey('companion-dot'));

/// 정해 둔 값을 차례로 돌려주는 난수 (다 쓰면 마지막 값을 되풀이한다)
class _ScriptedRandom implements math.Random {
  _ScriptedRandom(this.ints);

  final List<int> ints;
  var _i = 0;

  @override
  int nextInt(int max) => ints[math.min(_i++, ints.length - 1)].clamp(0, max - 1);

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}

/// 물건 [id]의 지금 기울기(라디안)
double _tilt(WidgetTester tester, String id) {
  final t = tester.widget<Transform>(find
      .descendant(of: find.byKey(ValueKey('wiggle-$id')), matching: find.byType(Transform))
      .first);
  return math.asin(t.transform.storage[1]);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> met(UiEnv e, String id, {int chapter = 0, int read = 0}) =>
      e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
            companionId: id,
            metUtc: 1,
            chapter: Value(chapter),
            readChapter: Value(read),
          ));

  /// [id]와 함께 걷는다 (null이면 혼자)
  Future<void> walkWith(UiEnv e, String? id) => e.db.into(e.db.companionStints).insert(
      CompanionStintsCompanion.insert(startUtc: const Value(1), companionId: Value(id)));

  Future<void> open(
    WidgetTester tester,
    UiEnv e, {
    WiggleSpec wiggle = const WiggleSpec.off(),
    List<Override> more = const [],
  }) async {
    phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [...e.overrides, restWiggleProvider.overrideWithValue(wiggle), ...more],
      child: const MaterialApp(home: RestScreen()),
    ));
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await settle(tester, () => false, tries: 4);
  }

  group('입구', () {
    testWidgets('함께 걷는 동행이 있으면 불 옆 자리에 서고, 누르면 동행 화면', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'bright');
        await walkWith(e, 'bright');
      });
      await open(tester, e);
      expect(tester.getRect(_entry), const Rect.fromLTWH(236, 612, 69, 106));
      // 그림은 테마 artW×artH(69×90) 상자의 아래 가운데
      expect(tester.getRect(_art).bottom, 612 + 90);
      expect(find.text('동행'), findsOneWidget);
      expect(_dot, findsNothing);
      await tester.tap(_entry);
      await transition(tester);
      expect(find.byType(CompanionScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('만났어도 혼자 걷기면 빈자리', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'rest', chapter: 1);
        await walkWith(e, null);
      });
      await open(tester, e);
      expect(_entry, findsNothing);
      expect(_art, findsNothing);
      await end(tester, e);
    });

    testWidgets('아무도 안 만났으면(첫날) 빈자리', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await open(tester, e);
      expect(_entry, findsNothing);
      await end(tester, e);
    });

    test('상품이 없어 수레가 없어도 동행은 선다 (상품 없음 갈래)', () async {
      final slot = RestObjectSlot(art: (_) => const SizedBox(), onTap: (_) {});
      final c = ProviderContainer(overrides: [
        shopCatalogProvider.overrideWith(
          (ref) => ShopCatalog(tabLabels: const {}, defaultBoat: 'boat_raft', items: const []),
        ),
        companionRestSlotProvider.overrideWithValue(slot),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(restSlotsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(shopCatalogProvider.future);
      expect(c.read(restSlotsProvider).cart, isNull);
      expect(c.read(restSlotsProvider).gem.onTap, isNull);
      expect(c.read(restSlotsProvider).companion, same(slot));
    });

    test('상품이 있으면 수레·보석과 동행이 함께', () async {
      final slot = RestObjectSlot(art: (_) => const SizedBox(), onTap: (_) {});
      final c = ProviderContainer(overrides: [
        shopCatalogProvider.overrideWith((ref) => shopCatalog),
        companionRestSlotProvider.overrideWithValue(slot),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(restSlotsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(shopCatalogProvider.future);
      expect(c.read(restSlotsProvider).cart, isNotNull);
      expect(c.read(restSlotsProvider).companion, same(slot));
    });
  });

  group('안 읽은 장 점', () {
    testWidgets('열렸는데 안 읽은 장이 있으면 점, 읽고 돌아오면 꺼진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'bright', chapter: 1);
        await walkWith(e, 'bright');
      });
      await open(tester, e);
      expect(_dot, findsOneWidget);

      await tester.tap(_entry);
      await transition(tester);
      final row = find.byKey(const Key('story-row-bright-1'));
      await settle(tester, () => row.evaluate().isNotEmpty);
      await tester.tap(row);
      await settle(tester, () => find.byKey(const Key('story-sheet')).evaluate().isNotEmpty);
      await transition(tester);
      await tester.tap(find.byKey(const Key('story-close')));
      await transition(tester);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await settle(tester, () => _dot.evaluate().isEmpty);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(_entry, findsOneWidget);
      expect(_dot, findsNothing);
      await end(tester, e);
    });

    testWidgets('다른 동행의 장이라도 안 읽었으면 점 (지금 걷는 동행 자리에)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'bright', chapter: 2, read: 2);
        await met(e, 'rest', chapter: 1);
        await walkWith(e, 'bright');
      });
      await open(tester, e);
      expect(_dot, findsOneWidget);
      await end(tester, e);
    });
  });

  group('흔들림', () {
    /// 1초마다 0.6초 흔든다
    WiggleSpec spec(List<int> ints) => WiggleSpec(
          minGap: const Duration(seconds: 1),
          maxGap: const Duration(seconds: 1),
          random: _ScriptedRandom(ints),
        );

    Future<void> nextWiggle(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 70));
    }

    testWidgets('알림 점 있는 동행이 먼저 흔들린다 (다른 물건에 점이 없으면 동행만)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 여정이 있어야 지도에 점이 없다 (여정이 없으면 지도 점, 16장 11/13)
        await e.svc.startJourney('kr003', t1, useFund: false);
        await met(e, 'bright', chapter: 1);
        await walkWith(e, 'bright');
      });
      // 어느 칸을 골라도 알림 물건은 동행 하나뿐
      await open(tester, e, wiggle: spec([2, 0]));
      expect(_dot, findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await nextWiggle(tester);
        expect(_tilt(tester, 'companion').abs(), greaterThan(1e-9));
        for (final id in ['map', 'backpack', 'note']) {
          expect(_tilt(tester, id), 0, reason: id);
        }
        await tester.pump(const Duration(milliseconds: 700));
      }
      await end(tester, e);
    });

    testWidgets('점이 없으면 동행은 흔들림에 들지 않는다 (캔버스는 둥실)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.svc.startJourney('kr003', t1, useFund: false);
        await met(e, 'bright', chapter: 1, read: 1);
        await walkWith(e, 'bright');
      });
      // 마지막 칸을 골라도 동행이 아니라 노트
      await open(tester, e, wiggle: spec([9]));
      expect(_dot, findsNothing);
      await nextWiggle(tester);
      expect(_tilt(tester, 'note').abs(), greaterThan(1e-9));
      expect(_tilt(tester, 'companion'), 0);
      await tester.pump(const Duration(milliseconds: 700));
      await end(tester, e);
    });
  });

  group('늦은 도착', () {
    testWidgets('걷기를 늦게 마친 동행은 lateSec 동안 빈자리였다가 그 뒤 앉는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'rest');
        await walkWith(e, 'rest');
      });
      await open(tester, e);
      expect(_entry, findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(RestScreen)));

      container.read(campArrivalProvider.notifier).finishWalk(e.now, 120);
      await tester.pump();
      expect(_entry, findsNothing);

      // 1분 뒤: 아직 오는 중
      e.now = e.now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 60));
      expect(_entry, findsNothing);

      // 2분이 지나면 (시계가 바뀐 뒤 다시 읽는다) 불 옆에 앉는다
      e.now = e.now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(_entry, findsOneWidget);
      await end(tester, e);
    });

    testWidgets('뒤처지지 않았으면(0초) 바로 앉아 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await met(e, 'rest');
        await walkWith(e, 'rest');
      });
      await open(tester, e);
      final container = ProviderScope.containerOf(tester.element(find.byType(RestScreen)));
      container.read(campArrivalProvider.notifier).finishWalk(e.now, 0);
      await tester.pump();
      expect(_entry, findsOneWidget);
      expect(container.read(companionSeatedProvider), isTrue);
      await end(tester, e);
    });
  });

  test('늦은 도착은 앱 안에만 있다 (처음에는 없음 = 앉아 있음)', () {
    final c = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => t1)]);
    addTearDown(c.dispose);
    expect(c.read(campArrivalProvider), isNull);
    expect(c.read(companionSeatedProvider), isTrue);
  });
}
