import 'package:doobal/app/paint_trail_controller.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/ui/album/album_paints.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 배낭 물감 탭 맨 위 무늬 줄 (T17b, config paintPattern.choose, 16장 11/19·11/20 ②, 개발인계_20261120 4장):
// 기본 방울 + 가진 무늬만(0개면 기본 방울 1칸, 안 가진 칸·예시·잠긴 칸 없음), 누르면 바로 쓰는 중, 새 무늬 표시,
// 걷는 중에도 고르면 그 순간부터 새 구간

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _own(UiEnv e, String id, {bool seen = false, int? rewardKm}) =>
    e.db.into(e.db.patternsOwned).insert(PatternsOwnedCompanion.insert(
        patternId: id, gotUtc: 0, seen: Value(seen), rewardKm: Value(rewardKm)));

Future<void> _openPaints(WidgetTester tester, UiEnv e, {List<Override> extra = const []}) async {
  await openOnTop(tester, e, const AlbumScreen(),
      ready: () => _key('tab-paints').evaluate().isNotEmpty, extra: extra);
  await tester.tap(_key('tab-paints'));
  await settle(tester, () => _key('pattern-row').evaluate().isNotEmpty);
}

Finder _in(String cell, Finder f) => find.descendant(of: _key(cell), matching: f);

/// 물감 길 1이 열려 있는 것으로 보는 컨트롤러
class _Walking extends PaintTrailController {
  @override
  PaintTrailState build() => PaintTrailState(id: 1, start: t1);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('무늬가 하나도 없으면 무늬 줄은 기본 방울 1칸만, 쓰는 중 (가진 것만, 0개면 defaultOnly)', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _openPaints(tester, e);
    expect(_in('pattern-row', find.text(patternRowTitle)), findsOneWidget);
    expect(_key('pattern-drops'), findsOneWidget);
    expect(_in('pattern-drops', find.text('방울')), findsOneWidget);
    expect(_in('pattern-drops', find.text(paintUsingLabel)), findsOneWidget);
    expect(_in('pattern-drops', _key('pattern-drops-art')), findsOneWidget);
    for (final id in ['trail_01', 'trail_02', 'trail_03']) {
      expect(_key('pattern-$id'), findsNothing);
    }
    // 무늬 줄이 물감 묶음보다 위
    expect(tester.getTopLeft(_key('pattern-row')).dy, lessThan(tester.getTopLeft(_key('paint-group-recent')).dy));
    await end(tester, e);
  });

  testWidgets('가진 무늬만 표 차례로, 새 무늬 점(탭 점도), 누르면 바로 쓰는 중 (저절로 안 고름)', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _own(e, 'trail_03');
      await _own(e, 'trail_01', seen: true, rewardKm: 10);
    });
    await openOnTop(tester, e, const AlbumScreen(), ready: () => _key('tab-paints').evaluate().isNotEmpty);
    // 안 본 무늬가 있으면 물감 탭에 점
    await settle(tester, () => _key('paints-tab-dot').evaluate().isNotEmpty);
    await tester.tap(_key('tab-paints'));
    await settle(tester, () => _key('pattern-row').evaluate().isNotEmpty);
    await settle(tester, () => _key('paints-tab-dot').evaluate().isEmpty);

    double x(String k) => tester.getTopLeft(_key(k)).dx;
    expect(x('pattern-drops') < x('pattern-trail_01') && x('pattern-trail_01') < x('pattern-trail_03'), isTrue);
    expect(_key('pattern-trail_02'), findsNothing);
    expect(_in('pattern-row', find.text('3')), findsOneWidget);
    // 새로 얻은 별가루만 새 표시 (이번 방문 동안 남는다), 칸은 무늬 아이콘 그림 (11/22 받음, 없으면 점선 칸 + 이름)
    expect(_in('pattern-trail_03', _key('pattern-new')), findsOneWidget);
    expect(_in('pattern-trail_01', _key('pattern-new')), findsNothing);
    expect(_in('pattern-trail_03', _asset('ui_trail_star_icon')), findsOneWidget);
    expect(_in('pattern-trail_03', _key('item-placeholder')), findsNothing);
    // 얻었어도 지금 무늬는 기본 방울
    expect(_in('pattern-drops', find.text(paintUsingLabel)), findsOneWidget);
    final unseen = await tester.runAsync(
        () => (e.db.select(e.db.patternsOwned)..where((t) => t.seen.equals(false))).get());
    expect(unseen, isEmpty);

    await tester.tap(_key('pattern-trail_03'));
    await settle(tester, () => _in('pattern-trail_03', find.text(paintUsingLabel)).evaluate().isNotEmpty);
    expect(_in('pattern-drops', find.text(paintUsingLabel)), findsNothing);
    final profile = await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle());
    expect(profile!.paintPatternId, 'trail_03');
    // 다시 읽으면 새 표시는 없다
    expect(_in('pattern-trail_03', _key('pattern-new')), findsNothing);

    // 쓰는 중인 칸은 다시 눌러도 그대로, 기본 방울을 누르면 기본(null)
    await tester.tap(_key('pattern-drops'));
    await settle(tester, () => _in('pattern-drops', find.text(paintUsingLabel)).evaluate().isNotEmpty);
    final back = await tester.runAsync(
        () => (e.db.select(e.db.profile)..where((t) => t.id.equals(1))).getSingle());
    expect(back!.paintPatternId, isNull);
    await end(tester, e);
  });

  testWidgets('걷는 중에도 고르면 그 순간부터 새 구간 (색 그대로), 칠한 구간은 그대로', (tester) async {
    final e = UiEnv();
    final start = t1.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;
    await e.seed(tester, () async {
      await _own(e, 'trail_02', seen: true);
      await e.db.into(e.db.paintTrails).insert(PaintTrailsCompanion.insert(id: const Value(1), startUtc: start));
      await e.db.into(e.db.paintTrailColors).insert(PaintTrailColorRow(trailId: 1, fromUtc: start, colorId: 'basic'));
    });
    await _openPaints(tester, e, extra: [paintTrailProvider.overrideWith(_Walking.new)]);
    await tester.tap(_key('pattern-trail_02'));
    await settle(tester, () => _in('pattern-trail_02', find.text(paintUsingLabel)).evaluate().isNotEmpty);
    final segs = await tester.runAsync(() => (e.db.select(e.db.paintTrailColors)
          ..where((t) => t.trailId.equals(1))
          ..orderBy([(t) => OrderingTerm(expression: t.fromUtc)]))
        .get());
    expect(segs!.map((r) => (r.fromUtc, r.colorId, r.patternId)), [
      (start, 'basic', null),
      (t1.millisecondsSinceEpoch, 'basic', 'trail_02'),
    ]);
    await end(tester, e);
  });
}

/// 이름에 [stem]이 든 앱 그림 (Image.asset, cacheWidth면 ResizeImage 안)
Finder _asset(String stem) => find.byWidgetPredicate((w) {
      if (w is! Image) return false;
      var p = w.image;
      if (p is ResizeImage) p = p.imageProvider;
      return p is AssetImage && p.assetName.contains(stem);
    });
