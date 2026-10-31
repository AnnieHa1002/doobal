import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/album/album_widgets.dart';
import 'package:doobal/ui/album/painting_detail_screen.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/common/frame_style.dart';
import 'package:doobal/ui/common/framed_painting.dart';
import 'package:doobal/ui/common/notice_dot.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/map/landmark_card.dart';
import 'package:doobal/ui/map/map_painter.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

final _bubble = find.byKey(const ValueKey('first-sketch-bubble'));
final _dot = find.byKey(const ValueKey('depart-dot'));
final _card = find.byKey(const ValueKey('arrival-card'));
Finder _cell(String id) => find.byKey(ValueKey('cell-$id'));
Finder _wall(int i) => find.byKey(ValueKey('wall-$i'));
Finder _packIn(Finder owner) => find.descendant(of: owner, matching: find.byType(FirstPackFace));

/// [owner] 안의 첫 그림 액자 (FramedPainting.firstPack)
Finder _packFrameIn(Finder owner) => find.descendant(
    of: owner,
    matching: find.byWidgetPredicate((w) => w is FramedPainting && w.firstPack));

// 설치 직후 도착까지 걸은 스케치의 도착 시각: t1 + 2시간 = 한국 11월 18일 12시
final _arrivedAt = t1.add(const Duration(hours: 2));
final _journeyId = 'j${t1.millisecondsSinceEpoch}';

/// 앱(DoobalApp = 관문 → 쉼터)을 띄우고 쉼터 글자가 뜰 때까지
Future<void> _pumpRest(WidgetTester tester, UiEnv e) async {
  await pumpDoobal(tester, e, const DoobalApp());
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
}

Future<void> _openAlbum(WidgetTester tester, UiEnv e, {double height = 844}) async {
  await openOnTop(tester, e, const AlbumScreen(),
      height: height, ready: () => _wall(0).evaluate().isNotEmpty);
  // 그림·벽 값까지 한 박자 더
  await settle(tester, () => false, tries: 6);
}

Text _name(WidgetTester tester, Finder owner, String name) =>
    tester.widget<Text>(find.descendant(of: owner, matching: find.text(name)));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('쉼터: 첫날 (아직 안 걸음)', () {
    testWidgets('상태 알약, 출발하기의 알림 점, 말풍선 "첫 그림을 그리러 가요"', (tester) async {
      final e = UiEnv();
      // 환산 2.5km인 목적지로 정해 두면 글을 그대로 비교할 수 있다 (2.5km ÷ 0.7m = 3,571보 → 3,600보)
      await e.seed(tester, () => e.insertSketchJourney(2.5));
      await _pumpRest(tester, e);

      expect(find.text('쉬는 중 · 내 동네 스케치까지 2.5 km'), findsOneWidget);
      expect(_dot, findsOneWidget);
      expect(
          find.descendant(
              of: _bubble, matching: find.text('첫 그림을 그리러 가요. 중구에서 2.5 km · 약 3,600보')),
          findsOneWidget);
      // 점은 출발하기 버튼 위에 걸친다
      final button = tester.getRect(find.byTooltip('출발하기'));
      final dot = tester.getRect(_dot);
      expect(button.contains(dot.center), isTrue);
      // 말풍선은 출발하기 바로 위
      expect(tester.getRect(_bubble).bottom, lessThanOrEqualTo(button.top));
      expect(tester.getRect(_bubble).bottom, greaterThan(button.top - 24));
      await end(tester, e);
    });

    testWidgets('config 범위 안의 짧은 여정(0.6km)은 `0.6 km · 약 900보`로 나온다', (tester) async {
      final e = UiEnv();
      // 0.6km ÷ 0.7m = 857보 → 900보
      await e.seed(tester, () => e.insertSketchJourney(0.6));
      await _pumpRest(tester, e);

      expect(find.text('쉬는 중 · 내 동네 스케치까지 0.6 km'), findsOneWidget);
      expect(
          find.descendant(
              of: _bubble, matching: find.text('첫 그림을 그리러 가요. 중구에서 0.6 km · 약 900보')),
          findsOneWidget);
      await end(tester, e);
    });

    testWidgets('말풍선은 카드색에 잉크 2px 테두리', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertSketchJourney(2.5));
      await _pumpRest(tester, e);

      final box = tester
          .widgetList<Container>(find.descendant(of: _bubble, matching: find.byType(Container)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect(box.color, Palette.card);
      expect((box.border! as Border).top.color, Palette.ink);
      expect((box.border! as Border).top.width, 2);
      await end(tester, e);
    });

    testWidgets('실제로 정해진 목적지: 거리와 걸음이 알약·말풍선에 같은 값으로 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await _pumpRest(tester, e);

      final snap = (await tester.runAsync(() => e.svc.snapshot(e.now)))!;
      final km = snap.journey!.progress.remainingKm;
      expect(km, inInclusiveRange(rules.firstSketchMinKm - 1e-6, rules.firstSketchMaxKm + 1e-6));
      // 0.5~0.8km라 `0.6 km`처럼 소수 한 자리로 나온다
      expect(formatKm(km), matches(RegExp(r'^0\.[5-8] km$')));
      expect(find.text('쉬는 중 · 내 동네 스케치까지 ${formatKm(km)}'), findsOneWidget);
      expect(find.text('첫 그림을 그리러 가요. 중구에서 ${formatKm(km)} · '
          '약 ${formatInt(sketchSteps(km, rules))}보'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('걷기 시작해서 진행이 생기면 말풍선과 알림 점이 함께 사라진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      // 앱을 켜면 동기화하니 그 전에 걸은 기록을 넣어 둔다 (3분 × 100보 = 0.21km, 첫 여정의 최소 거리보다 짧다)
      e.source.records.add(walkRecord(t1.add(const Duration(minutes: 1)), 3, 100));
      e.now = t1.add(const Duration(minutes: 40));
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(
          tester,
          () =>
              find.textContaining('쉬는 중 · 내 동네 스케치까지').evaluate().isNotEmpty &&
              _bubble.evaluate().isEmpty);

      final snap = (await tester.runAsync(() => e.svc.snapshot(e.now)))!;
      expect(snap.journey!.progress.progressKm, greaterThan(0));
      expect(_bubble, findsNothing);
      expect(_dot, findsNothing);
      // 알약은 줄어든 남은 거리로, 출발하기는 그대로
      expect(find.text('쉬는 중 · 내 동네 스케치까지 ${formatKm(snap.journey!.progress.remainingKm)}'),
          findsOneWidget);
      expect(find.byTooltip('출발하기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('다른 목적지(명소)로 가는 중이거나 여정이 없으면 말풍선·점·스케치 알약이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney('kr001', t1, useFund: false);
      });
      await _pumpRest(tester, e);
      expect(_bubble, findsNothing);
      expect(_dot, findsNothing);
      expect(find.textContaining('내 동네 스케치'), findsNothing);
      expect(find.textContaining('쉬는 중 · 목적지까지'), findsOneWidget);
      await end(tester, e);

      final none = UiEnv();
      await none.seed(tester);
      await _pumpRest(tester, none);
      expect(_bubble, findsNothing);
      expect(_dot, findsNothing);
      expect(find.text('쉬는 중 · 목적지를 골라 보세요'), findsOneWidget);
      await end(tester, none);
    });

    testWidgets('출발하기를 누르면 걷는 중으로 간다 (여정이 있다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await _pumpRest(tester, e);
      await tester.tap(find.byTooltip('출발하기'));
      await transition(tester);
      expect(find.text('걷는 중'), findsOneWidget);
      expect(find.textContaining('내 동네 스케치까지'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('FirstPackFace · FramedPainting.firstPack', () {
    Future<void> pump(WidgetTester tester, Widget child, {double w = 200, double h = 150}) =>
        tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: w, height: h, child: child)),
        ));

    testWidgets('에셋 이름은 painting_first_pack_v01 (그림이 나오면 Image.asset으로 바꾼다)', (tester) async {
      expect(firstPackAsset, 'painting_first_pack_v01');
    });

    testWidgets('종이색 바탕에 짐 꾸러미 아이콘, 부모 상자를 꽉 채운다', (tester) async {
      for (final (w, h) in [(200.0, 150.0), (78.0, 100.0), (30.0, 30.0)]) {
        await pump(tester, const FirstPackFace(), w: w, h: h);
        expect(tester.takeException(), isNull, reason: '$w×$h');
        expect(tester.getSize(find.byType(FirstPackFace)), Size(w, h));
        expect(find.byIcon(Icons.backpack_outlined), findsOneWidget);
        expect(tester.widget<ColoredBox>(find.byType(ColoredBox)).color, Palette.paper);
      }
    });

    testWidgets('나무 액자에 끼운다: 액자 띠는 나무색이고 그림은 짐 꾸러미 자리표시', (tester) async {
      await pump(tester, const FramedPainting.firstPack());
      expect(tester.takeException(), isNull);
      final framed = tester.widget<FramedPainting>(find.byType(FramedPainting));
      expect((framed.firstPack, framed.frame, framed.landmark), (true, Frame.wood, null));
      expect(find.byType(FirstPackFace), findsOneWidget);
      final border = tester.widget<FrameBorder>(find.byType(FrameBorder));
      expect((border.color, border.lineColor), (frameColors[Frame.wood], Palette.ink));
      // 명소 그림(PaintingFace)이 아니다
      expect(find.byType(PaintingFace), findsNothing);
    });

    testWidgets('빈 액자(FramedPainting.empty)는 첫 그림이 아니다', (tester) async {
      await pump(tester, const FramedPainting.empty());
      expect(find.byType(FirstPackFace), findsNothing);
      expect(tester.widget<FramedPainting>(find.byType(FramedPainting)).firstPack, isFalse);
    });
  });

  group('도착', () {
    Future<void> openArrival(WidgetTester tester, UiEnv e) => openOnTop(
        tester, e, ArrivalScreen(journeyId: _journeyId),
        ready: () => _card.evaluate().isNotEmpty);

    testWidgets('카드 제목은 "첫 그림", 이름 줄은 첫 여행 짐 꾸러미, 거리·날짜·그날 걸음은 그대로', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await openArrival(tester, e);
      await tester.pump(const Duration(seconds: 2));

      final row = (await tester.runAsync(() => e.db.select(e.db.journeys).getSingle()))!;
      final day = (await tester.runAsync(() => e.db.select(e.db.daySummaries).getSingle()))!;
      Finder inCard(String text) => find.descendant(of: _card, matching: find.text(text));
      expect(inCard('첫 그림'), findsOneWidget);
      expect(inCard('첫 여행 짐 꾸러미'), findsOneWidget);
      expect(inCard('이번 여정 ${formatKm(row.totalEffectiveKm)}'), findsOneWidget);
      expect(inCard('11월 18일'), findsOneWidget);
      expect(inCard('그날 걸음 ${formatInt(day.steps)}보'), findsOneWidget);
      // 여정 이름은 카드에 나오지 않는다
      expect(find.text('내 동네 스케치'), findsNothing);
      // 제목이 이름보다 위
      expect(tester.getTopLeft(inCard('첫 그림')).dy,
          lessThan(tester.getTopLeft(inCard('첫 여행 짐 꾸러미')).dy));
      await end(tester, e);
    });

    testWidgets('등급 라벨·n번째 방문·재방문·권역 소품은 없고, 액자 단계도 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await openArrival(tester, e);

      // 번지기 시작할 때부터 나무 액자가 있다 (나중에 붙는 액자 단계가 없다)
      expect(find.byKey(const ValueKey('arrival-first-pack-frame')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      for (final f in Frame.values) {
        expect(find.text(frameLabel(f)), findsNothing);
      }
      expect(find.textContaining('번째 방문'), findsNothing);
      expect(find.textContaining('액자는'), findsNothing);
      expect(find.byKey(const ValueKey('arrival-frame')), findsNothing);
      expect(find.byKey(const ValueKey('arrival-frame-label')), findsNothing);
      expect(find.byKey(const ValueKey('arrival-revisit')), findsNothing);
      expect(find.byKey(const ValueKey('arrival-prop')), findsNothing);
      expect(find.textContaining('완성'), findsNothing);

      // 그림 자리에는 짐 꾸러미 자리표시, 액자는 나무색, 버튼은 명소 도착과 같다
      expect(find.byType(FirstPackFace), findsOneWidget);
      expect(find.byType(PaintingFace), findsNothing);
      expect(find.byKey(const ValueKey('arrival-painting')), findsOneWidget);
      final frame = tester.widget<FrameBorder>(find.byType(FrameBorder));
      expect(frame.color, frameColors[Frame.wood]);
      expect(find.text('화집에 걸기'), findsOneWidget);
      expect(find.text('다음 목적지'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('그림은 번지며 나타난다 (처음에는 투명)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await openArrival(tester, e);
      double opacity() =>
          tester.widget<Opacity>(find.byKey(const ValueKey('arrival-painting'))).opacity;
      expect(opacity(), lessThan(0.5));
      expect(find.descendant(of: find.byKey(const ValueKey('arrival-painting')),
          matching: find.byType(ImageFiltered)), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(opacity(), 1);
      await end(tester, e);
    });

    testWidgets('앱을 열면 쉼터 위에 도착 화면이 한 번 뜨고, 닫으면 본 것으로 적힌다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => _card.evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(find.byType(FirstPackFace), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await settle(tester, () => false, tries: 4);
      expect(find.byType(ArrivalScreen), findsNothing);
      final row = (await tester.runAsync(() => e.db.select(e.db.journeys).getSingle()))!;
      expect(row.arrivalShown, isTrue);
      await end(tester, e);
    });

    testWidgets('화집에 걸기: 첫 그림이 벽 첫 칸에 걸린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await openArrival(tester, e);
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('화집에 걸기'));
      await transition(tester);
      await settle(tester, () => _wall(0).evaluate().isNotEmpty);
      await settle(tester, () => _packIn(_wall(0)).evaluate().isNotEmpty);

      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(_packIn(_wall(0)), findsOneWidget);
      expect((await tester.runAsync(e.svc.wall))!, [sketchId, null, null, null]);
      await end(tester, e);
    });
  });

  group('화집', () {
    testWidgets('그림 탭 맨 앞에 첫 그림 칸 (1 + 101칸), 못 얻었으면 빈 액자와 흐린 "첫 그림"', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e, height: 6000);

      expect(find.byType(PaintingCell), findsNWidgets(101));
      expect(find.byType(FirstPackCell), findsOneWidget);
      // 첫 그림 칸이 격자의 맨 앞 (첫 명소 칸의 앞)
      final pack = tester.getTopLeft(_cell(sketchId));
      final first = tester.getTopLeft(_cell('kr001'));
      expect(pack.dy, first.dy);
      expect(pack.dx, lessThan(first.dx));

      final framed = find.descendant(of: _cell(sketchId), matching: find.byType(FramedPainting));
      expect(framed, findsOneWidget);
      expect(tester.widget<FramedPainting>(framed).frame, isNull);
      expect(tester.widget<FramedPainting>(framed).firstPack, isFalse);
      expect(_packIn(_cell(sketchId)), findsNothing);
      expect(_name(tester, _cell(sketchId), '첫 그림').style?.color, Palette.subInk);
      expect(find.byKey(const ValueKey('new-painting-sketch')), findsNothing);

      // 못 얻은 칸은 눌러도 아무 일도 없다
      await tester.tap(_cell(sketchId));
      await transition(tester);
      expect(find.byType(PaintingDetailScreen), findsNothing);
      await end(tester, e);
    });

    testWidgets('권역 칩을 고르면 첫 그림 칸이 사라지고, 전체를 누르면 돌아온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e, height: 6000);

      await tester.tap(find.byKey(const ValueKey('album-chip-capital')));
      await tester.pump();
      expect(_cell(sketchId), findsNothing);
      expect(find.byType(FirstPackCell), findsNothing);
      final capital = landmarks.where((l) => l.region == 'capital').length;
      expect(find.byType(PaintingCell), findsNWidgets(capital));

      await tester.tap(find.byKey(const ValueKey('album-chip-all')));
      await tester.pump();
      expect(_cell(sketchId), findsOneWidget);
      expect(find.byType(PaintingCell), findsNWidgets(101));
      await end(tester, e);
    });

    testWidgets('얻으면 짐 꾸러미가 나무 액자에 끼고, 새 그림 점이 붙고, 이름은 잉크색', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await _openAlbum(tester, e, height: 6000);
      await settle(tester, () => _packIn(_cell(sketchId)).evaluate().isNotEmpty);

      expect(_packIn(_cell(sketchId)), findsOneWidget);
      final framed = tester.widget<FramedPainting>(_packFrameIn(_cell(sketchId)));
      expect((framed.frame, framed.landmark), (Frame.wood, null));
      expect(_name(tester, _cell(sketchId), '첫 그림').style?.color, Palette.ink);
      expect(find.byKey(const ValueKey('new-painting-sketch')), findsOneWidget);
      expect(find.byType(NoticeDot), findsOneWidget);

      // 도착한 시각(한국 11월 18일 12시)만 남은 그림이다
      final owned = (await tester.runAsync(e.svc.paintings))!.single;
      expect((owned.isFirstPack, owned.visits, owned.firstArrivedAt), (true, 1, _arrivedAt));
      // 열었으니 새 그림 표시는 지워졌다
      final snap = (await tester.runAsync(() => e.svc.snapshot(e.now)))!;
      expect(snap.unseenPaintings, 0);
      expect(snap.paintingsCount, 1);
      await end(tester, e);
    });

    testWidgets('다시 열면 새 그림 점이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.arriveAtSketch();
        await e.svc.markPaintingsSeen();
      });
      await _openAlbum(tester, e, height: 6000);
      await settle(tester, () => _packIn(_cell(sketchId)).evaluate().isNotEmpty);
      expect(_packIn(_cell(sketchId)), findsOneWidget);
      expect(find.byKey(const ValueKey('new-painting-sketch')), findsNothing);
      await end(tester, e);
    });

    testWidgets('눌러서 상세: 큰 그림, "첫 그림 · 첫 여행 짐 꾸러미", 받은 날짜만', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await _openAlbum(tester, e);
      await settle(tester, () => _packIn(_cell(sketchId)).evaluate().isNotEmpty);

      await tester.tap(_cell(sketchId));
      await transition(tester);
      await settle(
          tester, () => find.byKey(const ValueKey('detail-first-pack')).evaluate().isNotEmpty);

      expect(find.byType(PaintingDetailScreen), findsOneWidget);
      final detail = find.byKey(const ValueKey('detail-first-pack'));
      expect(detail, findsOneWidget);
      expect(_packIn(detail), findsOneWidget);
      final framed = tester.widget<FramedPainting>(detail);
      expect((framed.firstPack, framed.frame, framed.thickness), (true, Frame.wood, 12));
      expect(find.text('첫 그림 · 첫 여행 짐 꾸러미'), findsOneWidget);
      expect(find.text('11월 18일'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-painting')), findsNothing);
      for (final f in Frame.values) {
        expect(find.text(frameLabel(f)), findsNothing);
      }
      expect(find.textContaining('번째 방문'), findsNothing);
      expect(find.textContaining('km'), findsNothing);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(PaintingDetailScreen), findsNothing);
      await end(tester, e);
    });

    testWidgets('벽 칸을 길게 눌러 시트에서 첫 그림을 고르면 그 칸에 걸린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await _openAlbum(tester, e);
      await settle(tester, () => _packIn(_cell(sketchId)).evaluate().isNotEmpty);

      await tester.longPress(_wall(2));
      await transition(tester);
      final pick = find.byKey(const ValueKey('pick-sketch'));
      expect(pick, findsOneWidget);
      expect(_packIn(pick), findsOneWidget);
      expect(find.descendant(of: pick, matching: find.text('첫 그림')), findsOneWidget);

      await tester.tap(pick);
      await transition(tester);
      await settle(tester, () => _packIn(_wall(2)).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('pick-sketch')), findsNothing);
      expect(_packIn(_wall(2)), findsOneWidget);
      // 벽에서도 나무 액자
      expect(tester.widget<FramedPainting>(_packFrameIn(_wall(2))).frame, Frame.wood);
      expect((await tester.runAsync(e.svc.wall))!, [null, null, sketchId, null]);
      // 다른 칸은 그대로 빈 액자
      expect(_packIn(_wall(0)), findsNothing);
      await end(tester, e);
    });

    testWidgets('소품 탭의 권역 진행에는 첫 그림이 세지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.arriveAtSketch();
        await e.svc.markPaintingsSeen();
      });
      await _openAlbum(tester, e, height: 3000);
      await tester.tap(find.byKey(const ValueKey('tab-props')));
      await tester.pump();
      await settle(tester, () => find.byKey(const ValueKey('prop-hat_01')).evaluate().isNotEmpty);
      // 수도권 소품(해치)은 잠긴 채, 얻는 방법의 진행 숫자는 0곳 (첫 그림은 서울이어도 세지 않는다)
      final capital = landmarks.where((l) => l.region == 'capital').length;
      expect(find.text('수도권 0/$capital'), findsOneWidget);
      expect(find.textContaining('수도권 1/'), findsNothing);
      await end(tester, e);
    });
  });

  group('지도', () {
    Future<void> openMap(WidgetTester tester, UiEnv e) => openOnTop(tester, e, const MapScreen(),
        ready: () => find.byType(InteractiveViewer).evaluate().isNotEmpty);

    MapPainter painter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<MapPainter>()
        .single;

    testWidgets('스케치 여정 중: 목적지는 가상 좌표로 그리고, 카드는 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.startSketch);
      await openMap(tester, e);
      await settle(tester, () => false, tries: 6);

      final data = painter(tester).data;
      final row = (await tester.runAsync(() => e.db.select(e.db.journeys).getSingle()))!;
      expect(data.destId, sketchId);
      expect(data.destPoint, LatLng(row.destLat!, row.destLng!));
      expect(data.visited, isEmpty);
      expect(find.byType(LandmarkCard), findsNothing);
      await end(tester, e);
    });

    testWidgets('도착한 뒤: 방문한 명소 표시와 권역 칩 숫자에 스케치가 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await openMap(tester, e);
      await settle(tester, () => false, tries: 6);

      final data = painter(tester).data;
      expect(data.destId, isNull);
      expect(data.destPoint, isNull);
      expect(data.visited, isEmpty);
      expect(find.text('수도권 0/${landmarks.where((l) => l.region == 'capital').length}'),
          findsOneWidget);
      // 지나온 길은 하나
      expect(data.paths, hasLength(1));
      await end(tester, e);
    });
  });
}
