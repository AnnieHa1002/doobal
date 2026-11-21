import 'dart:math';

import 'package:doobal/app/decor_providers.dart';
import 'package:doobal/app/screen_providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/decor_place.dart';
import 'package:doobal/ui/rest/decor_drawer.dart';
import 'package:doobal/ui/rest/decor_layer.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

// 쉼터 꾸미기 자유 배치 (T15, 16장 11/18 ③·11/19, M2~M6 AB, config rest.decor, camp_wide decor).
// 탭 바 없이 쉼터만 띄워서 390×844 폰이면 장면 pt = 화면 pt (k 1, 장면 아래 = 화면 아래)

final _stage = DecorStage.of(campTheme, rules.decor.place, screenHeightPx: rules.screenHeightPx)!;

Future<void> _own(UiEnv e, List<String> ids) => e.db.batch((b) => b.insertAll(e.db.decorOwned, [
      for (final (i, id) in ids.indexed) DecorOwnedCompanion.insert(decorId: id, gotUtc: 1000 + i),
    ]));

Future<void> _place(UiEnv e, String id, ScenePoint foot, {bool flipped = false}) {
  final r = _stage.toRatio(foot);
  return e.db.into(e.db.decorPlaced).insert(DecorPlacedCompanion.insert(
        decorId: id,
        xRatio: r.x,
        yRatio: r.y,
        flipped: Value(flipped),
        placedUtc: 1,
      ));
}

Future<void> _open(WidgetTester tester, UiEnv e) async {
  phone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...e.overrides,
      restWiggleProvider.overrideWithValue(const WiggleSpec.off()),
      restSwapRandomProvider.overrideWithValue(Random(5)),
    ],
    child: const MaterialApp(home: RestScreen()),
  ));
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
  await settle(tester, () => find.byKey(const ValueKey('rest-side-decorate')).evaluate().isNotEmpty);
  await tester.pump();
}

Future<DecorPlacedRow?> _row(WidgetTester tester, UiEnv e, String id) => tester.runAsync<DecorPlacedRow?>(
    () => (e.db.select(e.db.decorPlaced)..where((t) => t.decorId.equals(id))).getSingleOrNull());

/// 저장(비동기 DB)이 끝나도록
Future<void> _saved(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// [from]을 길게 눌러 집고 [to]로 끌어 놓는다 (서랍이 열리며 장면이 올라가는 시간도 준다)
Future<void> _drag(WidgetTester tester, Offset from, Offset to, {int steps = 6}) async {
  final g = await tester.startGesture(from);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 300));
  for (var i = 1; i <= steps; i++) {
    await g.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pump();
  await _saved(tester);
  await tester.pump(const Duration(milliseconds: 300));
}

ProviderContainer _c(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(RestScreen)));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('옆 버튼 ‘꾸미기’가 서랍을 열고 닫는다: 가진 물품 중 안 놓은 것만, 비면 안내 한 줄', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, ['decor_easel', 'decor_lantern', 'decor_bench']);
      await _place(e, 'decor_easel', _stage.easelStart);
    });
    await _open(tester, e);
    final side = find.byKey(const ValueKey('rest-side-decorate'));
    expect(side, findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('쉼터 꾸미기'), findsOneWidget);
    semantics.dispose();
    expect(find.byKey(const ValueKey('decor-drawer-list')), findsNothing);

    await tester.tap(side);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('decor-drawer-decor_lantern')), findsOneWidget);
    expect(find.byKey(const ValueKey('decor-drawer-decor_bench')), findsOneWidget);
    expect(find.byKey(const ValueKey('decor-drawer-decor_easel')), findsNothing, reason: '놓은 것은 서랍에 없다');
    // 서랍은 화면 아래 (탭 바가 없으면 화면 맨 아래)
    final drawer = tester.getRect(find.byKey(const ValueKey('decor-drawer-list')));
    expect(drawer.bottom, closeTo(844, 1));

    await tester.tap(find.byKey(const ValueKey('decor-drawer-done')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('decor-drawer-list')), findsNothing);

    await tester.tap(side);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(side);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('decor-drawer-list')), findsNothing, reason: '한 번 더 누르면 닫힌다');
    await end(tester, e);
  });

  testWidgets('가진 물품이 없으면 서랍에 안내 한 줄, 다 놓았으면 다른 한 줄', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _open(tester, e);
    await tester.tap(find.byKey(const ValueKey('rest-side-decorate')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('아직 가진 쉼터 물품이 없어요'), findsOneWidget);
    await tester.runAsync(() async {
      await _own(e, ['decor_easel']);
      await _place(e, 'decor_easel', _stage.easelStart);
    });
    _c(tester).invalidate(decorProvider);
    await _saved(tester);
    expect(find.text('가진 물품을 모두 놓았어요'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('놓인 물품은 저장한 비율 자리에 그림 없는 자리표시(점선 + 이름)로, 발이 아래 가운데', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, ['decor_easel', 'decor_pond']);
      await _place(e, 'decor_easel', const ScenePoint(300, 700));
      await _place(e, 'decor_pond', const ScenePoint(400, 790), flipped: true);
    });
    await _open(tester, e);
    final easel = tester.getRect(find.byKey(const ValueKey('decor-decor_easel')));
    // 216×330 화면 px ÷ 3 = 72×110pt, 발 (300, 700)
    expect(easel.left, closeTo(264, 0.5));
    expect(easel.top, closeTo(590, 0.5));
    expect(easel.width, closeTo(72, 0.5));
    expect(easel.bottom, closeTo(700, 0.5));
    expect(find.text('이젤'), findsOneWidget);
    expect(find.text('작은 연못'), findsOneWidget);
    expect(find.byKey(const ValueKey('decor-placeholder')), findsNWidgets(2));
    // 발 y가 정령 발(725)보다 아래인 연못은 정령 앞 층, 이젤은 뒤 층
    final views = tester.widgetList<DecorPiece>(find.byType(DecorPiece)).map((p) => p.view.id).toList();
    expect(views, ['decor_easel', 'decor_pond']);
    expect(_stage.frontOfSpirit(const ScenePoint(400, 790)), isTrue);
    await end(tester, e);
  });

  testWidgets('서랍 칸을 누르면 보이는 장면 가운데(막혔으면 옆)에 놓이고 저장된다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => _own(e, ['decor_bench']));
    await _open(tester, e);
    await tester.tap(find.byKey(const ValueKey('rest-side-decorate')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('decor-drawer-decor_bench')));
    await _saved(tester);
    final row = await _row(tester, e, 'decor_bench');
    expect(row, isNotNull);
    final foot = _stage.fromRatio(row!.xRatio, row.yRatio);
    expect(_stage.blockedAt(decorCatalog.byId('decor_bench')!, foot), isNull);
    expect(foot.y, closeTo(725, 0.5), reason: '땅 띠 가운데 높이');
    expect(find.byKey(const ValueKey('decor-drawer-decor_bench')), findsNothing);
    expect(find.byKey(const ValueKey('decor-decor_bench')), findsOneWidget);
    // 고른 물품 위에 뒤집기 버튼
    expect(find.byKey(const ValueKey('decor-flip-button')), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('길게 눌러 집고 끌어 놓으면 그 자리로 저장 (편집 모드 없음, 서랍이 저절로 열림)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, ['decor_easel']);
      await _place(e, 'decor_easel', const ScenePoint(300, 700));
    });
    await _open(tester, e);
    final start = tester.getCenter(find.byKey(const ValueKey('decor-decor_easel')));
    final g = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    // 집은 물품은 맨 위에 따로 그리고, 서랍이 열린다
    expect(find.byKey(const ValueKey('decor-held')), findsOneWidget);
    expect(find.byKey(const ValueKey('decor-drawer-list')), findsNothing, reason: '서랍에 남은 물품이 없다');
    expect(find.text('가진 물품을 모두 놓았어요'), findsOneWidget);
    // 장면이 올라가도 그대로 놓으면 제자리
    await g.up();
    await _saved(tester);
    var row = await _row(tester, e, 'decor_easel');
    expect(_stage.fromRatio(row!.xRatio, row.yRatio).x, closeTo(300, 0.01));
    expect(_stage.fromRatio(row.xRatio, row.yRatio).y, closeTo(700, 0.01));

    // 오른쪽으로 40pt, 아래로 40pt (화면 끝 40pt 안으로는 안 들어감)
    final now = tester.getCenter(find.byKey(const ValueKey('decor-decor_easel')));
    await _drag(tester, now, now + const Offset(40, 40));
    row = await _row(tester, e, 'decor_easel');
    final foot = _stage.fromRatio(row!.xRatio, row.yRatio);
    expect(foot.x, closeTo(340, 1));
    expect(foot.y, closeTo(740, 1));
    expect(find.byKey(const ValueKey('decor-held')), findsNothing);
    await end(tester, e);
  });

  testWidgets('땅 띠 밖으로 끌면 띠 끝에 맞춰지고, 정령·모닥불·수레 상자에 놓으면 튕겨 원래 자리로 (글 없음)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, ['decor_flower_pot']);
      await _place(e, 'decor_flower_pot', const ScenePoint(300, 700));
    });
    await _open(tester, e);
    final pot = find.byKey(const ValueKey('decor-decor_flower_pot'));
    // 위로 200pt (띠 위 끝 650에서 멈춤)
    var at = tester.getCenter(pot);
    await _drag(tester, at, at + const Offset(0, -200));
    var row = await _row(tester, e, 'decor_flower_pot');
    expect(_stage.fromRatio(row!.xRatio, row.yRatio).y, closeTo(650, 0.5));

    // 정령 쪽으로 (발 x 92)
    at = tester.getCenter(pot);
    final before = (row.xRatio, row.yRatio);
    await _drag(tester, at, at + const Offset(-208, 60));
    await tester.pump(const Duration(milliseconds: 400));
    row = await _row(tester, e, 'decor_flower_pot');
    expect((row!.xRatio, row.yRatio), before, reason: '못 놓는 자리라 저장하지 않는다');
    expect(find.byKey(const ValueKey('decor-held')), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await end(tester, e);
  });

  testWidgets('놓인 물품을 서랍으로 끌어 넣으면 치운다 (건 그림은 남음)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, ['decor_easel']);
      await _place(e, 'decor_easel', const ScenePoint(300, 700));
      await e.db.into(e.db.decorPaintings).insert(
          DecorPaintingsCompanion.insert(decorId: 'decor_easel', slot: 0, paintingKey: 'sketch'));
    });
    await _open(tester, e);
    final at = tester.getCenter(find.byKey(const ValueKey('decor-decor_easel')));
    await _drag(tester, at, const Offset(195, 800));
    expect(await _row(tester, e, 'decor_easel'), isNull);
    expect(find.byKey(const ValueKey('decor-drawer-decor_easel')), findsOneWidget);
    final hung = await tester.runAsync(() => e.db.select(e.db.decorPaintings).get());
    expect(hung, hasLength(1));
    await end(tester, e);
  });

  testWidgets('서랍에서 길게 눌러 끌어 놓기, 이미 최대로 놓였으면 서랍 칸이 흐리고 집히지 않는다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => _own(e, ['decor_stump']));
    await _open(tester, e);
    await tester.tap(find.byKey(const ValueKey('rest-side-decorate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final cell = tester.getCenter(find.byKey(const ValueKey('decor-drawer-decor_stump')));
    // 서랍이 열려 장면이 올라가 있다: 땅 띠 아래 끝(800)이 서랍 위 8pt에 오게
    // 장면 (330, 760) = 화면 (330, 760 − 올린 만큼)
    const lift = 800 + 8 - (844 - DecorDrawer.height);
    expect(_liftOf(tester), closeTo(lift, 0.5));
    const up = 760 - lift;
    await _drag(tester, cell, Offset(330, up));
    final row = await _row(tester, e, 'decor_stump');
    expect(row, isNotNull);
    final foot = _stage.fromRatio(row!.xRatio, row.yRatio);
    expect(foot.x, closeTo(330, 1));
    expect(foot.y, closeTo(760, 1));
    await end(tester, e);
  });

  testWidgets('뒤집기 버튼: 고른 물품을 좌우로 뒤집어 바로 저장, 빈 장면을 누르면 고르기가 풀린다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, ['decor_easel']);
      await _place(e, 'decor_easel', const ScenePoint(300, 700));
    });
    await _open(tester, e);
    // 꾸미기 중이 아니면 짧게 눌러도 고르지 않는다
    await tester.tap(find.byKey(const ValueKey('decor-decor_easel')));
    await tester.pump();
    expect(find.byKey(const ValueKey('decor-flip-button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rest-side-decorate')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('decor-decor_easel')));
    await tester.pump();
    expect(find.byKey(const ValueKey('decor-flip-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('decor-flip-button')));
    await _saved(tester);
    expect((await _row(tester, e, 'decor_easel'))!.flipped, isTrue);
    await tester.tap(find.byKey(const ValueKey('decor-flip-button')));
    await _saved(tester);
    expect((await _row(tester, e, 'decor_easel'))!.flipped, isFalse);
    // 빈 하늘을 누르면 고르기가 풀린다
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('decor-flip-button')), findsNothing);
    await end(tester, e);
  });

  testWidgets('화면 오른쪽 끝 40pt 안으로 끌고 있으면 장면이 밀리고, 놓으면 그 자리 (장면 오른쪽)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, ['decor_flower_pot']);
      await _place(e, 'decor_flower_pot', const ScenePoint(300, 760));
    });
    await _open(tester, e);
    final at = tester.getCenter(find.byKey(const ValueKey('decor-decor_flower_pot')));
    final g = await tester.startGesture(at);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await g.moveTo(Offset(375, at.dy));
    // 1초 동안 끝에 머문다 (초당 240pt, 밀 수 있는 끝은 585 − 390 = 195pt)
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await _saved(tester);
    await tester.pump(const Duration(seconds: 1));
    final row = await _row(tester, e, 'decor_flower_pot');
    final foot = _stage.fromRatio(row!.xRatio, row.yRatio);
    // 손가락 375 + 장면이 민 195 = 장면 x 570 근처 (화분 폭 37pt, 띠 오른쪽 끝 577)
    expect(foot.x, greaterThan(540));
    expect(foot.x, lessThanOrEqualTo(577));
    await end(tester, e);
  });
}

/// 서랍이 열려 장면을 올린 만큼 (장면 상자 위 끝 = − 올린 만큼)
double _liftOf(WidgetTester tester) {
  final scene = find.byType(Transform).evaluate().map((el) => el.widget as Transform).where((t) {
    final m = t.transform.getTranslation();
    return m.x == 0 && m.y < 0;
  });
  return scene.isEmpty ? 0 : -scene.first.transform.getTranslation().y;
}
