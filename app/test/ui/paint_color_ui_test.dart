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

// 물감 색·물감 모으기 화면 (16장 11/14·11/15·11/16, M2~M6 v0.20 Y·v0.22 AA, 캔버스 6-1 물감 탭·3-1):
// 배낭 물감 탭(가진 색만, 최근(기본 맨 앞) → 계절 색 → 지역 색, 누르면 바로 쓰는 중, 걷는 중에도 고름),
// 걸으면 고른 색이 줄고 방울에서 그 순간 색(그날 계절)·지역 색 물감 통이 모인다

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

/// 물감 길 1이 열려 있는 것으로 보는 컨트롤러
class _Walking extends PaintTrailController {
  @override
  PaintTrailState build() => PaintTrailState(id: 1, start: t1);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('첫날: 물감 1, 최근 묶음에 기본 한 칸이 쓰는 중 (꼬리표 남은 거리 없음), 계절·지역 묶음 없음', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _openPaints(tester, e);
    expect(find.text('물감 1'), findsOneWidget);
    expect(_key('paint-recent-basic'), findsOneWidget);
    expect(find.descendant(of: _key('paint-recent-basic'), matching: find.text('기본')), findsOneWidget);
    expect(find.descendant(of: _key('paint-recent-basic'), matching: find.text(paintUsingLabel)),
        findsOneWidget);
    expect(find.descendant(of: _key('paint-group-recent'), matching: find.text('최근')), findsOneWidget);
    expect(_key('paint-group-season'), findsNothing);
    expect(_key('paint-group-region'), findsNothing);
    expect(_key('paint-walking-line'), findsNothing);
    await end(tester, e);
  });

  testWidgets('가진 색: 새 색 점 → 탭을 열면 지움, 최근(기본 + 2) → 계절 색(지금 계절부터) → 지역 색, 이름·남은 거리, 누르면 쓰는 중, 접기',
      (tester) async {
    final e = UiEnv();
    int ago(int min) => t1.subtract(Duration(minutes: min)).millisecondsSinceEpoch;
    await e.seed(tester, () async {
      await _stock(e, 'autumn.sunset', 1250, lastGotAt: ago(10), seen: false);
      await _stock(e, 'region.kr.capital', 640, lastGotAt: ago(20));
      await _stock(e, 'summer.rain_run', 900, lastGotAt: ago(30));
      // 1단계(계절 없는 키)는 마지막으로 주운 날(11월 = 가을)의 계절 묶음에, 기준 hex·계절 없는 이름
      await _stock(e, 'night', 1500, lastGotAt: ago(40));
      await _stock(e, 'autumn.day', 2400, lastGotAt: ago(50));
      // 다 쓴 색은 배낭에 없다
      await _stock(e, 'autumn.snow', 0, lastGotAt: ago(5));
    });
    await openOnTop(tester, e, const AlbumScreen(),
        ready: () => _key('tab-paints').evaluate().isNotEmpty);
    await settle(tester, () => find.text('물감 6').evaluate().isNotEmpty);
    expect(_key('paints-tab-dot'), findsOneWidget);

    await tester.tap(_key('tab-paints'));
    await settle(tester, () => find.byType(PaintShelves).evaluate().isNotEmpty);
    await settle(tester, () => _key('paints-tab-dot').evaluate().isEmpty);
    final unseen = await tester.runAsync(
        () => (e.db.select(e.db.paintStock)..where((t) => t.seen.equals(false))).get());
    expect(unseen, isEmpty);

    double x(String k) => tester.getTopLeft(_key(k)).dx;
    double y(String k) => tester.getTopLeft(_key(k)).dy;
    // 묶음 차례: 최근 → 계절 색 → 지역 색
    expect(y('paint-group-recent') < y('paint-group-season') && y('paint-group-season') < y('paint-group-region'),
        isTrue);
    expect(find.descendant(of: _key('paint-group-season'), matching: find.text('계절 색')), findsOneWidget);
    expect(find.descendant(of: _key('paint-group-region'), matching: find.text('지역 색')), findsOneWidget);
    // 최근 3칸 = 기본 + 마지막으로 주운 둘 (가을 노을 10분 전, 수도권 단청 주홍 20분 전)
    expect(x('paint-recent-basic') < x('paint-recent-autumn.sunset') &&
        x('paint-recent-autumn.sunset') < x('paint-recent-region.kr.capital'), isTrue);
    expect(_key('paint-recent-summer.rain_run'), findsNothing);
    // 계절 색: 가을(낮 → 노을 → 밤) → 여름, 3열
    expect(y('paint-season-autumn.day'), y('paint-season-night'));
    expect(x('paint-season-autumn.day') < x('paint-season-autumn.sunset') &&
        x('paint-season-autumn.sunset') < x('paint-season-night'), isTrue);
    expect(y('paint-season-summer.rain_run'), greaterThan(y('paint-season-autumn.day')));
    expect(_key('paint-season-region.kr.capital'), findsNothing);
    expect(_key('paint-season-autumn.snow'), findsNothing);
    // 지역 색은 지역 묶음에만
    expect(_key('paint-region-region.kr.capital'), findsOneWidget);
    // 이름·남은 거리(0.1km 내림)
    expect(find.descendant(of: _key('paint-season-autumn.sunset'), matching: find.text('가을 노을')), findsOneWidget);
    expect(find.descendant(of: _key('paint-season-autumn.sunset'), matching: find.text('1.2 km')), findsOneWidget);
    expect(find.descendant(of: _key('paint-season-summer.rain_run'), matching: find.text('여름 진한 비')),
        findsOneWidget);
    expect(find.descendant(of: _key('paint-season-night'), matching: find.text('밤')), findsOneWidget);
    expect(find.descendant(of: _key('paint-region-region.kr.capital'), matching: find.text('수도권 단청 주홍')),
        findsOneWidget);
    expect(find.descendant(of: _key('paint-region-region.kr.capital'), matching: find.text('0.6 km')),
        findsOneWidget);

    await tester.tap(_key('paint-season-autumn.sunset'));
    await settle(tester, () => find
        .descendant(of: _key('paint-season-autumn.sunset'), matching: find.text(paintUsingLabel))
        .evaluate()
        .isNotEmpty);
    // 최근의 같은 색도 쓰는 중, 기본은 아님
    expect(find.descendant(of: _key('paint-recent-autumn.sunset'), matching: find.text(paintUsingLabel)),
        findsOneWidget);
    expect(find.descendant(of: _key('paint-recent-basic'), matching: find.text(paintUsingLabel)),
        findsNothing);
    final profile = await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle());
    expect(profile!.paintColorId, 'autumn.sunset');

    // 접으면 칸이 사라지고 다시 누르면 보인다 (처음엔 모두 펼침)
    await tester.ensureVisible(_key('paint-fold-season'));
    await tester.tap(_key('paint-fold-season'));
    await tester.pump();
    expect(_key('paint-season-autumn.day'), findsNothing);
    expect(_key('paint-region-region.kr.capital'), findsOneWidget);
    await tester.tap(_key('paint-fold-season'));
    await tester.pump();
    expect(_key('paint-season-autumn.day'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('16장 11/16: 걷는 중(물감 길이 열린 동안)에도 고르고, 그 순간부터 그 물감 길의 새 구간', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _stock(e, 'autumn.sunset', 1200);
      await e.db.into(e.db.paintTrails).insert(PaintTrailsCompanion.insert(
          id: const Value(1), startUtc: t1.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch));
    });
    await _openPaints(tester, e, extra: [paintTrailProvider.overrideWith(_Walking.new)]);
    expect(_key('paint-walking-line'), findsNothing);
    await tester.tap(_key('paint-season-autumn.sunset'));
    await settle(tester, () => find
        .descendant(of: _key('paint-season-autumn.sunset'), matching: find.text(paintUsingLabel))
        .evaluate()
        .isNotEmpty);
    final profile = await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle());
    expect(profile!.paintColorId, 'autumn.sunset');
    final segs = (await tester.runAsync(() => e.db.select(e.db.paintTrailColors).get()))!;
    expect([for (final r in segs) (r.trailId, r.colorId)], [(1, 'autumn.sunset')]);
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
    final segs = (await tester.runAsync(() => e.db.select(e.db.paintTrailColors).get()))!;
    expect([for (final r in segs) r.colorId], ['night', 'basic']);
    expect(segs.first.fromUtc, trail.startUtc);
    final night = (await tester.runAsync(() =>
        (e.db.select(e.db.paintStock)..where((t) => t.colorId.equals('night'))).getSingle()))!;
    expect((night.remainM, night.tubes), (0.0, 0));
    final profile = (await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle()))!;
    expect(profile.paintColorId, isNull);

    // 서버가 없어 날씨를 모르니 시간대 색 (한국 11월 18일 10시대 = 가을 낮), 통은 보상 표대로.
    // 지역 색으로 나온 통은 정령 자리(출발 동네)의 권역 색
    final tubes = (await tester.runAsync(() => e.db.select(e.db.paintTubes).get()))!;
    final drops = [for (var k = 1; k <= 10; k++) if (rollDrop(trail.id, k, rules.paintColor).tube) k];
    // 첫 물감 길(번호 1)의 방울 1~10 중 통이 나오는 방울이 있다 (물감 길·방울 번호로 정한 값)
    expect(drops, isNotEmpty);
    expect([for (final t in tubes) t.dropNo], drops);
    for (final t in tubes) {
      final region = rollDrop(trail.id, t.dropNo, rules.paintColor).region;
      expect(t.colorId, region ? startsWith('region.kr.') : 'autumn.day');
    }
    await end(tester, e);
  });
}
