import 'dart:math' as math;

import 'package:doobal/domain/diary.dart' show diaryMonthLabel;
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/ui/album/album_diary.dart';
import 'package:doobal/ui/album/album_flip.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/album/painting_viewer.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

// 연출 ⑤ 화집 종이 넘김 (T19, 16장 11/20 Q008, config ui.motion.albumFlip, 캔버스 6-1 메모 가안):
// 일기·전체를 바꾸면 아래 내용이 오른쪽 끝을 축으로 가로 1 → 0 → 1(0.35초), 앞 절반은 전 보기·뒤 절반은 새 보기,
// 가운데 0.15초 잉크 그림자 18%. 일기에서 달 머리줄이 스크롤로 화면에 들어오면 그 줄이 넘어간다(열 때 보이는 줄은 그대로).
// 움직임 줄이기면 바로 바뀌고 넘기지 않는다

final _f = rules.motion.albumFlip!;
final _day = DateTime.utc(2026, 10, 2, 3);

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Finder _key(String k) => find.byKey(ValueKey(k));

Duration _ms(int ms) => Duration(milliseconds: ms);

/// 일기 4항목 (10월 2·3, 11월 2) + 첫 그림
Future<void> _seedFew(UiEnv e) async {
  await e.insertArrival('j-sketch', sketchId, _day, km: 0.6);
  await e.insertArrival('j-a', 'kr001', _day.add(const Duration(days: 3)), km: 12.4);
  await e.insertArrival('j-b', 'kr002', _day.add(const Duration(days: 6)), km: 5);
  await e.insertArrival('j-c', 'kr022', _day.add(const Duration(days: 33)), km: 8.1);
}

/// 달마다 6항목씩 석 달 (8·9·10월): 첫 달 머리줄만 열 때 보이고 나머지는 한참 아래
Future<void> _seedMonths(UiEnv e) async {
  var n = 0;
  for (final month in [8, 9, 10]) {
    for (var d = 0; d < 6; d++) {
      n++;
      final id = 'kr${(n + 1).toString().padLeft(3, '0')}';
      await e.insertArrival('j$n', id, DateTime.utc(2026, month, 3 + d * 4, 3));
    }
  }
}

Future<void> _openAlbum(WidgetTester tester, UiEnv e) async {
  await openOnTop(tester, e, const AlbumScreen(), ready: () => _key('view-all').evaluate().isNotEmpty);
  await settle(tester, () => find.byType(DiaryItem).evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 4);
}

SliverFlip _flip(WidgetTester tester) => tester.widget<SliverFlip>(_key('album-flip'));

List<String> _cellIds(WidgetTester tester) => [
      for (final w in tester.widgetList(find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith('cell-');
      })))
        (w.key! as ValueKey<String>).value.substring(5),
    ];

/// 그 달 머리줄의 가로 크기 (보이지 않으면 null)
double? _monthScale(WidgetTester tester, String month) {
  final f = find.descendant(of: _key('diary-month-flip-$month'), matching: find.byType(Transform));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Transform>(f.first).transform.entry(0, 0);
}

/// 손가락으로 천천히 [dy]만큼 끌고(16ms마다 조금씩) 놓은 뒤 0.5초 더. 그동안 [month] 머리줄의 가장 작은 가로 크기
Future<double> _scroll(WidgetTester tester, double dy, String month) async {
  var least = 1.0;
  void look() => least = math.min(least, _monthScale(tester, month) ?? 1);
  final g = await tester.startGesture(const Offset(195, 600));
  for (var i = 0; i < 20; i++) {
    await g.moveBy(Offset(0, dy / 20));
    await tester.pump(_ms(16));
    look();
  }
  await g.up();
  for (var i = 0; i < 30; i++) {
    await tester.pump(_ms(16));
    look();
  }
  return least;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('일기·전체 바꾸기', () {
    testWidgets('일기 → 전체: 앞 절반은 일기가 오른쪽 끝으로 접히고, 가운데에서 격자로 바뀌어 펴진다 (0.35초)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _seedFew(e));
      await _openAlbum(tester, e);
      expect(_flip(tester).scaleX, 1);

      await tester.tap(_key('view-all'));
      await tester.pump();
      expect(find.byType(DiaryItem), findsWidgets);
      expect(_cellIds(tester), isEmpty);
      await tester.pump(_ms(88));
      final s = _flip(tester).scaleX;
      expect(s, closeTo(math.cos(math.pi / 4), 0.02));
      expect(_flip(tester).shadow, 0);
      // 오른쪽 끝(화면 오른쪽)이 축: 항목 오른쪽은 거의 그대로, 폭은 s배
      final r = tester.getRect(find.byType(DiaryItem).first);
      expect(r.right, closeTo(390 - 16 * s, 0.5));
      expect(r.width, closeTo(358 * s, 0.5));
      expect(_cellIds(tester), isEmpty);

      // 가운데: 가로 0, 잉크 그림자 18%, 이제 격자
      await tester.pump(_ms(87));
      expect(_flip(tester).scaleX, closeTo(0, 0.02));
      expect(_flip(tester).shadow, closeTo(_f.shadowInk, 0.01));
      await tester.pump();
      expect(find.byType(DiaryItem), findsNothing);
      expect(_cellIds(tester), containsAll(['kr001', 'kr002', 'kr022']));
      await tester.pump(_ms(88));
      expect(_flip(tester).scaleX, closeTo(math.cos(math.pi / 4), 0.02));
      await tester.pump(_ms(100));
      expect(_flip(tester).scaleX, 1);
      expect(_flip(tester).shadow, 0);
      await end(tester, e);
    });

    testWidgets('넘기는 중에는 접히는 항목을 눌러도 그림이 안 열린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _seedFew(e));
      await _openAlbum(tester, e);
      await tester.tap(_key('view-all'));
      await tester.pump();
      await tester.pump(_ms(80));
      // 접히는 일기 항목을 눌러도 크게 보기는 없다
      await tester.tap(find.byType(DiaryItem).first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(_ms(400));
      expect(find.byType(PaintingViewer), findsNothing);
      // 지금은 격자 (넘김이 끝남)
      expect(_cellIds(tester), isNotEmpty);
      await end(tester, e);
    });

    testWidgets('앞 절반에 다시 바꾸면 하던 넘김의 끝(격자)으로 건너뛰고 격자에서 일기로 다시 넘긴다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _seedFew(e));
      await _openAlbum(tester, e);
      await tester.tap(_key('view-all'));
      await tester.pump();
      await tester.pump(_ms(80));
      expect(find.byType(DiaryItem), findsWidgets);
      await tester.tap(_key('view-diary'));
      await tester.pump();
      expect(_cellIds(tester), isNotEmpty);
      expect(find.byType(DiaryItem), findsNothing);
      expect(_flip(tester).scaleX, 1);
      await tester.pump(_ms(200));
      expect(find.byType(DiaryItem), findsWidgets);
      expect(_cellIds(tester), isEmpty);
      await tester.pump(_ms(200));
      expect(_flip(tester).scaleX, 1);
      await end(tester, e);
    });

    testWidgets('움직임 줄이기면 넘기지 않고 바로 바뀐다', (tester) async {
      _reduceMotion(tester);
      final e = UiEnv();
      await e.seed(tester, () => _seedFew(e));
      await _openAlbum(tester, e);
      await tester.tap(_key('view-all'));
      await tester.pump();
      expect(_cellIds(tester), isNotEmpty);
      expect(find.byType(DiaryItem), findsNothing);
      expect(_flip(tester).scaleX, 1);
      await tester.pump(_ms(100));
      expect(_flip(tester).scaleX, 1);
      expect(_flip(tester).shadow, 0);
      await end(tester, e);
    });
  });

  group('달 머리줄', () {
    testWidgets('열 때 보이는 머리줄은 그대로, 스크롤로 화면에 들어오는 머리줄은 넘어간다 (위로 돌아와도)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _seedMonths(e));
      await _openAlbum(tester, e);
      final oct = diaryMonthLabel(DateTime.utc(2026, 10, 10));
      final sep = diaryMonthLabel(DateTime.utc(2026, 9, 10));
      expect(_monthScale(tester, oct), 1);
      // 열고 나서 0.4초 동안 맨 위 머리줄은 그대로
      for (var i = 0; i < 25; i++) {
        await tester.pump(_ms(16));
        expect(_monthScale(tester, oct), 1);
      }
      // 아래로 내려 9월 머리줄이 들어오면 넘어간다
      expect(find.text(sep).evaluate().isEmpty || tester.getTopLeft(find.text(sep)).dy > 844, isTrue);
      final least = await _scroll(tester, -900, sep);
      expect(least, lessThan(0.3));
      expect(_monthScale(tester, sep), 1);
      // 다시 위로: 10월 머리줄이 다시 들어오며 넘어간다
      final back = await _scroll(tester, 1200, oct);
      expect(back, lessThan(0.3));
      expect(_monthScale(tester, oct), 1);
      await end(tester, e);
    });

    testWidgets('움직임 줄이기면 스크롤해도 머리줄은 넘어가지 않는다', (tester) async {
      _reduceMotion(tester);
      final e = UiEnv();
      await e.seed(tester, () => _seedMonths(e));
      await _openAlbum(tester, e);
      final sep = diaryMonthLabel(DateTime.utc(2026, 9, 10));
      final least = await _scroll(tester, -900, sep);
      expect(least, 1);
      expect(_monthScale(tester, sep), 1);
      await end(tester, e);
    });
  });
}
