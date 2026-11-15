import 'package:doobal/app/paint_trail_controller.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/paint_color.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_paints.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart' show rules;
import 'ui_env.dart';

// 물감 색·물감 모으기 화면 (16장 11/14·11/15, M2~M6 v0.20 Y, 캔버스 6-1 물감 탭·3-1):
// 배낭 물감 탭(가진 색만, 기본 맨 앞, 누르면 바로 쓰는 중, 걷는 중에는 안 고름), 걸으면 고른 색이 줄고
// 방울에서 그 순간 색 물감 통이 모인다

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _stock(UiEnv e, String id, double remainM, {int lastGotAt = 0, bool seen = true}) =>
    e.db.into(e.db.paintStock).insert(PaintStockCompanion.insert(
        colorId: id,
        tubes: 1,
        remainM: remainM,
        firstGotAt: lastGotAt,
        lastGotAt: lastGotAt,
        seen: Value(seen)));

Future<void> _openPaints(WidgetTester tester, UiEnv e, {List<Override> extra = const []}) async {
  await openOnTop(tester, e, const AlbumScreen(),
      ready: () => _key('tab-paints').evaluate().isNotEmpty, extra: extra);
  await tester.tap(_key('tab-paints'));
  await settle(tester, () => find.byType(PaintShelves).evaluate().isNotEmpty);
}

/// 물감 길이 열려 있는 것으로 보는 컨트롤러 (걷는 중 고르기 막힘)
class _Walking extends PaintTrailController {
  @override
  PaintTrailState build() => PaintTrailState(id: 1, start: t1);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('첫날: 물감 1, 기본 한 칸이 쓰는 중 (꼬리표 남은 거리 없음)', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _openPaints(tester, e);
    expect(find.text('물감 1'), findsOneWidget);
    expect(_key('paint-all-basic'), findsOneWidget);
    expect(find.descendant(of: _key('paint-all-basic'), matching: find.text('기본')), findsOneWidget);
    expect(find.descendant(of: _key('paint-all-basic'), matching: find.text(paintUsingLabel)),
        findsOneWidget);
    // 최근 칸은 색이 많을 때만, 접기도 기본 하나면 없다
    expect(_key('paint-group-recent'), findsNothing);
    expect(_key('paint-fold-all'), findsNothing);
    await end(tester, e);
  });

  testWidgets('가진 색: 새 색 점 → 탭을 열면 지움, 이름·남은 거리, 누르면 바로 쓰는 중, 최근 3칸, 접기', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _stock(e, 'sunset', 1200, lastGotAt: 40, seen: false);
      await _stock(e, 'rain_run', 900, lastGotAt: 30);
      await _stock(e, 'night', 1500, lastGotAt: 20);
      await _stock(e, 'day', 2400, lastGotAt: 10);
      // 다 쓴 색은 배낭에 없다
      await _stock(e, 'snow', 0, lastGotAt: 50);
    });
    await openOnTop(tester, e, const AlbumScreen(),
        ready: () => _key('tab-paints').evaluate().isNotEmpty);
    await settle(tester, () => find.text('물감 5').evaluate().isNotEmpty);
    expect(_key('paints-tab-dot'), findsOneWidget);

    await tester.tap(_key('tab-paints'));
    await settle(tester, () => find.byType(PaintShelves).evaluate().isNotEmpty);
    await settle(tester, () => _key('paints-tab-dot').evaluate().isEmpty);
    final unseen = await tester.runAsync(
        () => (e.db.select(e.db.paintStock)..where((t) => t.seen.equals(false))).get());
    expect(unseen, isEmpty);

    // 모은 색: 기본 → 16색 차례(낮 → 노을 → 밤 → 진한 비)
    expect(find.descendant(of: _key('paint-all-sunset'), matching: find.text('노을')), findsOneWidget);
    expect(find.descendant(of: _key('paint-all-sunset'), matching: find.text('1.2 km')), findsOneWidget);
    expect(find.descendant(of: _key('paint-all-rain_run'), matching: find.text('진한 비')),
        findsOneWidget);
    expect(_key('paint-all-snow'), findsNothing);
    double x(String k) => tester.getTopLeft(_key(k)).dx;
    double y(String k) => tester.getTopLeft(_key(k)).dy;
    // 3열 선반: 기본·낮·노을 / 밤·진한 비
    expect(y('paint-all-basic'), y('paint-all-sunset'));
    expect(x('paint-all-basic') < x('paint-all-day') && x('paint-all-day') < x('paint-all-sunset'), isTrue);
    expect(y('paint-all-night'), greaterThan(y('paint-all-basic')));
    // 최근 3칸: 노을(40) → 진한 비(30) → 밤(20)
    expect(_key('paint-group-recent'), findsOneWidget);
    expect(_key('paint-recent-sunset'), findsOneWidget);
    expect(_key('paint-recent-night'), findsOneWidget);
    expect(_key('paint-recent-day'), findsNothing);
    expect(x('paint-recent-sunset'), lessThan(x('paint-recent-rain_run')));

    await tester.tap(_key('paint-all-sunset'));
    await settle(tester, () => find
        .descendant(of: _key('paint-all-sunset'), matching: find.text(paintUsingLabel))
        .evaluate()
        .isNotEmpty);
    expect(find.descendant(of: _key('paint-all-basic'), matching: find.text(paintUsingLabel)),
        findsNothing);
    final profile = await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle());
    expect(profile!.paintColorId, 'sunset');

    // 접으면 칸이 사라지고 다시 누르면 보인다
    await tester.ensureVisible(_key('paint-fold-all'));
    await tester.tap(_key('paint-fold-all'));
    await tester.pump();
    expect(_key('paint-all-day'), findsNothing);
    await tester.tap(_key('paint-fold-all'));
    await tester.pump();
    expect(_key('paint-all-day'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('걷는 중(물감 길이 열린 동안)에는 고르지 않는다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => _stock(e, 'sunset', 1200));
    await _openPaints(tester, e, extra: [paintTrailProvider.overrideWith(_Walking.new)]);
    expect(_key('paint-walking-line'), findsOneWidget);
    await tester.tap(_key('paint-all-sunset'));
    await settle(tester, () => false, tries: 4);
    expect(find.descendant(of: _key('paint-all-basic'), matching: find.text(paintUsingLabel)),
        findsOneWidget);
    final profile = await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle());
    expect(profile!.paintColorId, isNull);
    await end(tester, e);
  });

  testWidgets('걸으면 고른 색이 줄다 다 쓰면 기본 물감, 방울마다 그 순간 색(낮) 물감 통', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await e.startSketch();
      await _stock(e, 'night', 300);
      await e.db.into(e.db.profile).insertOnConflictUpdate(
          const ProfileCompanion(id: Value(1), paintColorId: Value('night')));
    });
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty, tries: 80);
    await settle(tester, () => false, tries: 8);

    // 30초마다 50보(분당 100보 걷기): 1,500보 = 1,050m
    var total = 50000;
    e.live.push(total);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 30; i++) {
      e.now = e.now.add(const Duration(seconds: 30));
      total += 50;
      e.live.push(total);
      await tester.pump(paintTrailTick);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(find.byType(WalkingScreen), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      e.now = e.now.add(const Duration(seconds: 5));
      await tester.pump(paintTrailTick);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }

    final trail = (await tester.runAsync(() => e.db.select(e.db.paintTrails).getSingle()))!;
    expect(trail.colorId, 'night');
    expect(trail.colorEndUtc, isNotNull);
    final night = (await tester.runAsync(() =>
        (e.db.select(e.db.paintStock)..where((t) => t.colorId.equals('night'))).getSingle()))!;
    expect((night.remainM, night.tubes), (0.0, 0));
    final profile = (await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle()))!;
    expect(profile.paintColorId, isNull);

    // 서버가 없어 날씨를 모르니 시간대 색 (한국 11월 18일 10시대 = 낮), 통은 보상 표대로
    final tubes = (await tester.runAsync(() => e.db.select(e.db.paintTubes).get()))!;
    final drops = [for (var k = 1; k <= 10; k++) if (rollDrop(trail.id, k, rules.paintColor).tube) k];
    // 첫 물감 길(번호 1)의 방울 1~10 중 통이 나오는 방울이 있다 (물감 길·방울 번호로 정한 값)
    expect(drops, isNotEmpty);
    expect([for (final t in tubes) t.dropNo], drops);
    expect(tubes.every((t) => t.colorId == 'day'), isTrue);
    await end(tester, e);
  });
}
