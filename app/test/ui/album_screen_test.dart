import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_diary.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/album/album_widgets.dart';
import 'package:doobal/ui/album/painting_detail_screen.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/common/framed_painting.dart';
import 'package:doobal/ui/common/notice_dot.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

const _firstOnlyHint = '걸어서 명소에 닿으면 여기에 걸려요';
const _noPropsLine = '아직 모은 소품이 없어요';

Finder _cell(String id) => find.byKey(ValueKey('cell-$id'));
Finder _prop(String id) => find.byKey(ValueKey('prop-$id'));
Finder _chip(String region) => find.byKey(ValueKey('album-chip-$region'));
Finder _hint() => find.byKey(const ValueKey('album-first-only-hint'));

FramedPainting _framed(WidgetTester tester, Finder owner) => tester
    .widget<FramedPainting>(find.descendant(of: owner, matching: find.byType(FramedPainting)));

/// 키가 `<prefix><이름>`인 위젯의 이름을 화면 순서대로
List<String> _keyNames(WidgetTester tester, String prefix) => [
      for (final w in tester.widgetList(find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith(prefix);
      })))
        (w.key! as ValueKey<String>).value.substring(prefix.length),
    ];

/// 그림 격자의 칸 id (첫 그림은 sketch)
List<String> _cellIds(WidgetTester tester) => _keyNames(tester, 'cell-');

/// 화면에 있는 권역 칩 (`전체`는 all)
List<String> _chipKeys(WidgetTester tester) => _keyNames(tester, 'album-chip-');

/// 화집을 연다. 그림 탭의 기본 보기는 일기라서, 격자를 보는 테스트는 [all]로 `전체`를 눌러 둔다
Future<void> _openAlbum(WidgetTester tester, UiEnv e,
    {Widget screen = const AlbumScreen(), double height = 844, bool all = true}) async {
  await openOnTop(tester, e, screen,
      height: height, ready: () => find.byKey(const ValueKey('view-all')).evaluate().isNotEmpty);
  // 그림 값까지 한 박자 더
  await settle(tester, () => false, tries: 6);
  if (all) {
    await tester.tap(find.byKey(const ValueKey('view-all')));
    await settle(tester, () => false, tries: 3);
  }
}

/// 걸음 기록을 넣고 동기화해서 누적 11.2km·16,000보를 쌓는다 (hand_02 지팡이를 얻는다).
/// 거리 소품은 앱 걷기 창 안에서 걸은 이동 거리로 세서, 걷는 중 화면을 연 것처럼 창을 열고 닫는다
/// (11.2km × 1.3 = 14.56km)
Future<void> _walk11km(UiEnv e) async {
  final id = await e.svc.startAppWalk(t1);
  e.source.records.add(walkRecord(t1, 160, 100));
  e.now = t1.add(const Duration(hours: 5));
  await e.svc.sync(e.now);
  await e.svc.finishAppWalk(id, t1.add(const Duration(minutes: 160)));
  // 이 걷기로 도장도 받지만 소품 점만 보는 시험이라 도장은 본 것으로 둔다
  await e.svc.markBadgesSeen();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('뒤로와 제목 `화집`, 위 배경·벽 액자는 없다 (11/4)', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _openAlbum(tester, e);
    expect(find.text('화집'), findsOneWidget);
    expect(find.byTooltip('뒤로'), findsOneWidget);
    expect(find.byKey(const ValueKey('wall-0')), findsNothing);
    await end(tester, e);
  });

  group('그림 탭 일기 (UI 명세 10장, 16장 11/2)', () {
    // 11월 18일 첫 그림, 21일 kr001, 24일 kr002, 27일 kr002 재방문(나무 → 은), 12월 8일 kr022
    final day0 = t1;
    Future<void> seedDiary(UiEnv e) async {
      await e.insertArrival('j-sketch', sketchId, day0, km: 0.6);
      await e.insertArrival('j-a', 'kr001', day0.add(const Duration(days: 3)), km: 12.4);
      await e.insertArrival('j-b', 'kr002', day0.add(const Duration(days: 6)), km: 5);
      await e.insertArrival('j-c', 'kr002', day0.add(const Duration(days: 9)),
          visitNo: 2, prevFrame: Frame.wood, frame: Frame.silver, km: 32.7);
      await e.insertArrival('j-d', 'kr022', day0.add(const Duration(days: 20)), km: 8.1);
    }

    Finder entry(String id) => find.byKey(ValueKey('diary-$id'));
    List<String> entryOrder(WidgetTester tester) => [
          for (final w in tester.widgetList<DiaryItem>(find.byType(DiaryItem)))
            w.entry.journeyId,
        ];

    testWidgets('기본 보기는 일기: 도착마다 한 항목, 최근이 위, 첫 그림이 맨 아래, 달이 바뀌면 머리줄',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => seedDiary(e));
      await _openAlbum(tester, e, height: 3000, all: false);

      expect(find.byKey(const ValueKey('view-diary')), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(_cellIds(tester), isEmpty);
      // 재방문(j-c)도 새 항목이다
      expect(entryOrder(tester), ['j-d', 'j-c', 'j-b', 'j-a', 'j-sketch']);
      final dec = tester.getTopLeft(find.text('2026년 12월')).dy;
      final nov = tester.getTopLeft(find.text('2026년 11월')).dy;
      expect(dec, lessThan(tester.getTopLeft(entry('j-d')).dy));
      expect(nov, greaterThan(tester.getTopLeft(entry('j-d')).dy));
      expect(nov, lessThan(tester.getTopLeft(entry('j-c')).dy));
      await end(tester, e);
    });

    testWidgets('메모: 날짜(요일)·이름·n번째 방문·이번 여정 km · 그날 걸음·액자(올랐으면 나무 → 은)',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => seedDiary(e));
      await _openAlbum(tester, e, height: 3000, all: false);

      String memo(String id) => [
            for (final t in tester.widgetList<Text>(
                find.descendant(of: entry(id), matching: find.byType(Text))))
              t.data ?? '',
          ].join(' / ');
      expect(memo('j-c'), '11월 27일 (금) / 인천 차이나타운·월미도 / 2번째 방문 / 이번 여정 32.7km · 그날 0보 / 나무 → 은');
      expect(memo('j-a'), contains('11월 21일 (토) / 경복궁 / 1번째 방문 / 이번 여정 12.4km'));
      expect(memo('j-a'), endsWith('나무 액자'));
      // 첫 그림: 제목과 받기까지 한 줄 (걸음 분이 없으면 걸음은 뺀다)
      expect(memo('j-sketch'),
          '첫 그림 · 첫 여행 짐 꾸러미 / 11월 18일 · $testHomeName에서 0.6km · 1분 걸려 받았어요');
      // 사진 테두리는 받은 액자 색 (첫 그림은 나무 액자 그림)
      final framed = tester.widget<FramedPainting>(
          find.descendant(of: entry('j-c'), matching: find.byType(FramedPainting)));
      expect((framed.frame, framed.landmark?.id), (Frame.silver, 'kr002'));
      expect(
          tester
              .widget<FramedPainting>(
                  find.descendant(of: entry('j-sketch'), matching: find.byType(FramedPainting)))
              .firstPack,
          isTrue);
      await end(tester, e);
    });

    testWidgets('사진과 메모는 항목마다 좌우를 번갈아 둔다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => seedDiary(e));
      await _openAlbum(tester, e, height: 3000, all: false);

      bool photoLeft(String id) {
        final photo = tester.getCenter(
            find.descendant(of: entry(id), matching: find.byType(FramedPainting)));
        final memo = tester.getCenter(find.descendant(
            of: entry(id), matching: find.textContaining('번째 방문')).first);
        return photo.dx < memo.dx;
      }

      expect([for (final id in ['j-d', 'j-c', 'j-b', 'j-a']) photoLeft(id)],
          [true, false, true, false]);
      await end(tester, e);
    });

    testWidgets('항목을 누르면 그 명소의 그림 상세', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => seedDiary(e));
      await _openAlbum(tester, e, height: 3000, all: false);

      await tester.tap(entry('j-c'));
      await transition(tester);
      await settle(tester, () => find.byType(PaintingDetailScreen).evaluate().isNotEmpty);
      expect(tester.widget<PaintingDetailScreen>(find.byType(PaintingDetailScreen)).landmarkId,
          'kr002');
      await end(tester, e);
    });

    testWidgets('`전체`를 누르면 격자, `일기`를 누르면 다시 일기', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => seedDiary(e));
      await _openAlbum(tester, e, height: 3000, all: false);

      await tester.tap(find.byKey(const ValueKey('view-all')));
      await settle(tester, () => false, tries: 3);
      expect(find.byType(DiaryItem), findsNothing);
      expect(_cellIds(tester), [sketchId, 'kr001', 'kr002', 'kr022']);
      expect(_chipKeys(tester), contains('all'));

      await tester.tap(find.byKey(const ValueKey('view-diary')));
      await settle(tester, () => false, tries: 3);
      expect(find.byType(DiaryItem), findsNWidgets(5));
      expect(_cellIds(tester), isEmpty);
      await end(tester, e);
    });

    testWidgets('아직 받은 그림이 없으면 일기에 한 줄 안내', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e, all: false);
      expect(find.text(diaryEmptyLine), findsOneWidget);
      expect(find.byType(DiaryItem), findsNothing);
      await end(tester, e);
    });
  });

  group('그림 탭', () {
    testWidgets('아무것도 못 얻었으면 칸이 없고 `걸어서 명소에 닿으면 여기에 걸려요`만 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e);

      expect(_cellIds(tester), isEmpty);
      expect(find.byType(PaintingCell), findsNothing);
      expect(find.byType(FirstPackCell), findsNothing);
      // 격자 안에는 빈 액자도 없다 (벽의 점선 칸만 있다)
      expect(find.descendant(of: find.byType(SliverGrid), matching: find.byType(FramedPainting)),
          findsNothing);
      expect(find.text(_firstOnlyHint), findsOneWidget);
      expect(_chipKeys(tester), ['all']);
      await end(tester, e);
    });

    testWidgets('첫 그림뿐이면 첫 그림 한 칸과 그 아래에 한 줄 안내', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({sketchId: Frame.wood}));
      await _openAlbum(tester, e);
      await settle(tester, () => _cell(sketchId).evaluate().isNotEmpty);

      expect(_cellIds(tester), [sketchId]);
      expect(find.byType(FirstPackCell), findsOneWidget);
      expect(find.byType(PaintingCell), findsNothing);
      expect(find.text(_firstOnlyHint), findsOneWidget);
      // 안내는 격자(첫 그림 칸) 아래에 있다
      expect(tester.getTopLeft(_hint()).dy, greaterThan(tester.getBottomLeft(_cell(sketchId)).dy));
      expect(_chipKeys(tester), ['all']);
      await end(tester, e);
    });

    testWidgets('얻은 그림만 나온다: 첫 그림이 맨 앞, 명소는 landmarks.json 순서, 못 얻은 칸은 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 얻은 순서는 kr003, sketch, kr001이지만 화면은 첫 그림 → 명소 순서
        await e.ownPaintings({'kr003': Frame.silver, sketchId: Frame.wood, 'kr001': Frame.gold});
      });
      await _openAlbum(tester, e);
      await settle(tester, () => _cell('kr001').evaluate().isNotEmpty);

      expect(_cellIds(tester), [sketchId, 'kr001', 'kr003']);
      expect(find.byType(FirstPackCell), findsOneWidget);
      expect(find.byType(PaintingCell), findsNWidgets(2));
      expect(_cell('kr002'), findsNothing);
      expect(_framed(tester, _cell('kr001')).frame, Frame.gold);
      expect(_framed(tester, _cell('kr003')).frame, Frame.silver);
      expect(_framed(tester, _cell(sketchId)).firstPack, isTrue);
      // 격자 안은 모두 얻은 그림이라 빈 액자가 없다
      final frames = tester.widgetList<FramedPainting>(
          find.descendant(of: find.byType(SliverGrid), matching: find.byType(FramedPainting)));
      expect(frames, hasLength(3));
      expect(frames.every((f) => f.frame != null), isTrue);
      // 첫 그림 말고 얻은 명소 그림이 있으면 안내는 없다
      expect(find.text(_firstOnlyHint), findsNothing);
      expect(_hint(), findsNothing);

      Color? nameColor(String id, String name) => tester
          .widget<Text>(find.descendant(of: _cell(id), matching: find.text(name)))
          .style
          ?.color;
      expect(nameColor('kr001', '경복궁'), Palette.ink);
      expect(nameColor(sketchId, '첫 그림'), Palette.ink);
      await end(tester, e);
    });

    testWidgets('명소 이름은 한 줄 말줄임: 긴 이름은 …로 줄고 이름 줄은 한 줄 높이', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.wood, 'kr002': Frame.wood}));
      await _openAlbum(tester, e);
      await settle(tester, () => _cell('kr002').evaluate().isNotEmpty);

      for (final (id, name) in [('kr001', '경복궁'), ('kr002', '인천 차이나타운·월미도')]) {
        final label = find.descendant(of: _cell(id), matching: find.text(name));
        final text = tester.widget<Text>(label);
        expect((text.maxLines, text.overflow), (1, TextOverflow.ellipsis), reason: name);
        // 이름 줄은 한 줄 높이: 12pt · 줄 높이 1.25 = 15pt + 2pt (두 줄이면 32pt)
        expect(tester.getSize(label).height, closeTo(17, 0.01), reason: name);
      }
      // 칸 너비(약 114pt)에 안 들어가는 이름은 말줄임표로 잘린다
      final long = find.descendant(of: _cell('kr002'), matching: find.text('인천 차이나타운·월미도'));
      expect(tester.renderObject<RenderParagraph>(long).didExceedMaxLines, isTrue);
      await end(tester, e);
    });

    testWidgets('칩은 `전체` + 얻은 그림이 있는 권역만, 칩을 누르면 그 권역 그림만 (첫 그림은 전체에서만)',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({
          sketchId: Frame.wood,
          'kr001': Frame.gold, // 수도권
          'kr022': Frame.wood, // 강원
          'kr089': Frame.wood, // 울릉
        });
      });
      await _openAlbum(tester, e);
      await settle(tester, () => _cell('kr089').evaluate().isNotEmpty);

      // 얻은 권역만, 권역 순서(수도권 → 강원 → 울릉)로
      expect(_chipKeys(tester), ['all', 'capital', 'gangwon', 'ulleung']);
      expect(find.text('수도권'), findsOneWidget);
      expect(find.text('강원'), findsOneWidget);
      expect(find.text('울릉'), findsOneWidget);
      for (final r in ['chungcheong', 'jeolla', 'gyeongsang', 'jeju']) {
        expect(_chip(r), findsNothing, reason: r);
        expect(find.text(regionLabels[r]!), findsNothing, reason: r);
      }
      expect(_cellIds(tester), [sketchId, 'kr001', 'kr022', 'kr089']);

      await tester.tap(_chip('gangwon'));
      await tester.pump();
      expect(_cellIds(tester), ['kr022']);
      expect(find.byType(FirstPackCell), findsNothing);
      expect(_hint(), findsNothing);

      await tester.tap(_chip('capital'));
      await tester.pump();
      expect(_cellIds(tester), ['kr001']);

      await tester.tap(_chip('all'));
      await tester.pump();
      expect(_cellIds(tester), [sketchId, 'kr001', 'kr022', 'kr089']);
      await end(tester, e);
    });

    testWidgets('얻은 그림을 누르면 그림 상세: 이름, 시도 시군구 · 지형, 액자, 방문 기록', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // UTC 11-17 16:00 = 한국 11-18 01:00
        await e.insertArrival('j1', 'kr001', DateTime.utc(2026, 11, 17, 16), km: 12.34);
        await e.insertArrival('j2', 'kr001', DateTime.utc(2026, 11, 25, 3),
            visitNo: 2, prevFrame: Frame.wood, frame: Frame.gold, km: 61.5);
        await e.insertArrival('j3', 'kr002', DateTime.utc(2026, 11, 26, 3), km: 3);
      });
      await _openAlbum(tester, e);
      await settle(tester, () => _cell('kr001').evaluate().isNotEmpty);

      await tester.tap(_cell('kr001'));
      await transition(tester);
      await settle(tester, () => find.text('1번째 방문 · 12.3 km · 11월 18일').evaluate().isNotEmpty);

      expect(find.byType(PaintingDetailScreen), findsOneWidget);
      expect(find.text('경복궁'), findsOneWidget);
      expect(find.text('서울특별시 종로구 · 도시'), findsOneWidget);
      expect(find.text('금 액자'), findsOneWidget);
      expect(find.text('1번째 방문 · 12.3 km · 11월 18일'), findsOneWidget);
      expect(find.text('2번째 방문 · 61.5 km · 11월 25일'), findsOneWidget);
      // 다른 명소의 방문은 섞이지 않는다
      expect(find.textContaining('3.0 km'), findsNothing);
      final big = tester.widget<FramedPainting>(find.byKey(const ValueKey('detail-painting')));
      expect((big.landmark!.id, big.frame, big.thickness), ('kr001', Frame.gold, 12));

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.byType(PaintingDetailScreen), findsNothing);
      expect(find.byType(AlbumScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('그림이 많아도 얻은 것만 3열로 나온다 (101곳 모두 얻으면 첫 그림 + 101칸)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({sketchId: Frame.wood, for (final l in landmarks) l.id: Frame.wood});
      });
      await _openAlbum(tester, e, height: 6000);
      await settle(tester, () => _cell('kr101').evaluate().isNotEmpty);

      expect(_cellIds(tester), [sketchId, for (final l in landmarks) l.id]);
      expect(_chipKeys(tester), ['all', ...regionLabels.keys]);
      // 3열: 첫 줄에 첫 그림과 명소 둘
      final y = tester.getTopLeft(_cell(sketchId)).dy;
      expect(tester.getTopLeft(_cell('kr001')).dy, y);
      expect(tester.getTopLeft(_cell('kr002')).dy, y);
      expect(tester.getTopLeft(_cell('kr003')).dy, greaterThan(y));
      expect(find.text(_firstOnlyHint), findsNothing);
      await end(tester, e);
    });
  });

  group('소품 탭', () {
    /// 소품 탭을 열고 [ready]가 보일 때까지 기다린다 (기본: 기본 소품 모자)
    Future<void> openProps(WidgetTester tester, UiEnv e, {Finder? ready}) async {
      await _openAlbum(tester, e, height: 3000);
      await tester.tap(find.byKey(const ValueKey('tab-props')));
      await tester.pump();
      final f = ready ?? _prop('hat_01');
      await settle(tester, () => f.evaluate().isNotEmpty);
    }

    /// 지금 화면의 소품 줄 id (위에서 아래로)
    List<String> shownProps(WidgetTester tester) =>
        [for (final r in tester.widgetList<PropRow>(find.byType(PropRow))) r.prop.id];

    /// 소품 칸 순서(모자·옷·손·가방·신발·어깨 친구)와 props.json 순서로, [have]인 소품만
    List<String> expected(bool Function(Prop p) have) => [
          for (final slot in propSlotLabels.keys)
            for (final p in props)
              if (p.slot == slot && have(p)) p.id,
        ];

    bool isDefault(Prop p) => p.kind == PropUnlockKind.initial;

    testWidgets('얻은 소품만 칸별로: 기본 소품뿐이면 잠긴 소품·얻는 방법이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openProps(tester, e);

      final ids = shownProps(tester);
      expect(ids, expected(isDefault));
      expect(ids.length, lessThan(props.length));
      // 잠긴 소품은 줄이 없고, 얻는 방법·잠금 표시도 없다
      for (final id in ['hat_02', 'hand_03', 'pet_02', 'cloth_04', 'hat_10']) {
        expect(_prop(id), findsNothing, reason: id);
      }
      expect(find.textContaining('누적'), findsNothing);
      expect(find.textContaining('동행 이야기'), findsNothing);
      expect(find.text('수도권 0/12'), findsNothing);
      expect(find.descendant(of: find.byType(PropRow), matching: find.byType(Opacity)),
          findsNothing);
      expect(find.byKey(const ValueKey('album-no-props')), findsNothing);

      // 얻은 소품이 있는 칸의 이름이 위에서 아래로 (칸마다 기본 소품이 하나씩 있다)
      final labels = [
        for (final slot in propSlotLabels.entries)
          if (props.any((p) => p.slot == slot.key && isDefault(p))) slot.value,
      ];
      expect(labels, propSlotLabels.values.toList());
      final ys = [for (final label in labels) tester.getTopLeft(find.text(label)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(ys.toSet(), hasLength(labels.length));
      await end(tester, e);
    });

    testWidgets('걸어서 얻은 소품은 그 칸에 props.json 순서로 붙는다 (11km → 지팡이)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walk11km(e));
      await openProps(tester, e, ready: _prop('hand_02'));

      expect(shownProps(tester), expected((p) => isDefault(p) || p.id == 'hand_02'));
      expect(find.descendant(of: _prop('hand_02'), matching: find.text('지팡이')), findsOneWidget);
      expect(find.descendant(of: _prop('hat_01'), matching: find.text('베레모')), findsOneWidget);
      // 25km에 얻는 모자는 아직 없다
      expect(_prop('hat_02'), findsNothing);
      await end(tester, e);
    });

    testWidgets('권역을 채운 소품도 얻으면 나온다 (울릉 그림이 있으면 괭이갈매기)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({'kr089': Frame.wood});
        await e.svc.sync(e.now.add(const Duration(minutes: 1)));
      });
      await openProps(tester, e, ready: _prop('pet_05'));
      expect(_prop('pet_05'), findsOneWidget);
      expect(find.text(props.firstWhere((p) => p.id == 'pet_05').name), findsOneWidget);
      expect(find.text('울릉 0/1'), findsNothing);
      // 다른 어깨 친구는 잠긴 채라 없다
      expect(_prop('pet_02'), findsNothing);
      await end(tester, e);
    });

    testWidgets('얻은 소품이 없는 칸은 감춘다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 모자와 어깨 친구 하나씩만 얻은 상태로 둔다
        await e.db.delete(e.db.propsOwned).go();
        await e.db.batch((b) => b.insertAll(e.db.propsOwned, [
              PropsOwnedCompanion.insert(
                  propId: 'hat_01', unlockedUtc: 1, seen: const Value(true)),
              PropsOwnedCompanion.insert(
                  propId: 'pet_01', unlockedUtc: 1, seen: const Value(true)),
            ]));
      });
      await openProps(tester, e);

      expect(shownProps(tester), ['hat_01', 'pet_01']);
      expect(find.text('모자'), findsOneWidget);
      expect(find.text('어깨 친구'), findsOneWidget);
      for (final label in ['옷', '손', '가방', '신발']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.byKey(const ValueKey('album-no-props')), findsNothing);
      await end(tester, e);
    });

    testWidgets('얻은 소품이 하나도 없으면 `아직 모은 소품이 없어요` 한 줄뿐', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.db.delete(e.db.propsOwned).go());
      await openProps(tester, e, ready: find.byKey(const ValueKey('album-no-props')));

      expect(find.text(_noPropsLine), findsOneWidget);
      expect(find.byType(PropRow), findsNothing);
      for (final label in propSlotLabels.values) {
        expect(find.text(label), findsNothing, reason: label);
      }
      await end(tester, e);
    });

    testWidgets('소품 탭을 열면 새 소품 표시가 지워지고, 그림 탭으로 돌아올 수 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walk11km(e));
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.unseenProps, 1);
      await _openAlbum(tester, e);
      // 열기만 해서는 그대로
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.unseenProps, 1);

      await tester.tap(find.byKey(const ValueKey('tab-props')));
      await tester.pump();
      await settle(tester, () => false, tries: 4);
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.unseenProps, 0);
      expect(find.text('모자'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-paintings')));
      await tester.pump();
      // 그림 탭으로 돌아오면 보던 보기(전체)와 칩이 그대로다
      expect(find.byKey(const ValueKey('album-chip-all')), findsOneWidget);
      expect(find.text('모자'), findsNothing);
      await end(tester, e);
    });
  });

  group('화집의 알림 점', () {
    Finder newDot(String id) => find.byKey(ValueKey('new-painting-$id'));
    Finder tabDot() => find.byKey(const ValueKey('props-tab-dot'));

    Future<int> unseenPaintings(WidgetTester tester, UiEnv e) async =>
        (await tester.runAsync(() => e.svc.snapshot(e.now)))!.unseenPaintings;

    testWidgets('열면 새 그림 칸에만 점이 붙고 배낭의 새 그림 표시는 바로 꺼진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({'kr001': Frame.gold});
        await e.ownPaintings({'kr002': Frame.wood}, seen: false);
      });
      expect(await unseenPaintings(tester, e), 1);
      await _openAlbum(tester, e);
      await settle(tester, () => newDot('kr002').evaluate().isNotEmpty);

      expect(newDot('kr002'), findsOneWidget);
      expect(newDot('kr001'), findsNothing);
      expect(newDot('kr003'), findsNothing);
      // 칸의 오른쪽 위 모서리에 걸친 10pt 점
      expect(tester.getSize(newDot('kr002')), const Size(10, 10));
      final corner = tester.getTopRight(_cell('kr002'));
      expect((tester.getCenter(newDot('kr002')) - corner).distance, lessThan(8));
      // 열자마자 읽어 둔 값이라, 표시가 꺼진 뒤에도 이번 방문 동안은 남는다
      expect(await unseenPaintings(tester, e), 0);
      expect(await tester.runAsync(e.svc.unseenPaintingIds), isEmpty);
      await settle(tester, () => false, tries: 6);
      expect(newDot('kr002'), findsOneWidget);

      // 나갔다 다시 열면 이미 본 그림이라 점이 없다
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await tester.tap(find.text('열기'));
      await transition(tester);
      // 새로 연 화집은 일기부터라 `전체`로 바꾼다
      await settle(tester, () => find.byKey(const ValueKey('view-all')).evaluate().isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('view-all')));
      await settle(tester, () => _cell('kr002').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
      expect(_cell('kr002'), findsOneWidget);
      expect(newDot('kr002'), findsNothing);
      await end(tester, e);
    });

    testWidgets('새 그림이 없으면 점이 없고, 아무것도 바꾸지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.gold}));
      await _openAlbum(tester, e);
      await settle(tester, () => false, tries: 6);

      expect(find.byType(NoticeDot), findsNothing);
      expect(await unseenPaintings(tester, e), 0);
      await end(tester, e);
    });

    testWidgets('안 본 소품이 있으면 `소품` 탭 라벨 오른쪽 위에 점이 붙고, 탭을 열면 사라진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walk11km(e));
      await _openAlbum(tester, e);
      await settle(tester, () => tabDot().evaluate().isNotEmpty);

      expect(tabDot(), findsOneWidget);
      expect(tester.getSize(tabDot()), const Size(10, 10));
      // 라벨 글자의 오른쪽 위에 걸쳐 있다 (글자 위치는 그대로)
      final label = find.descendant(
          of: find.byKey(const ValueKey('tab-props')), matching: find.text('소품'));
      final corner = tester.getTopRight(label);
      final center = tester.getCenter(tabDot());
      expect(center.dx, greaterThan(corner.dx));
      expect(center.dy, lessThan(tester.getCenter(label).dy));
      expect((center - corner).distance, lessThan(10));
      // 새 그림은 없어서 그림 칸 점은 없고 탭 점뿐이다
      expect(find.byType(NoticeDot), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-props')));
      await tester.pump();
      await settle(tester, () => tabDot().evaluate().isEmpty);
      expect(tabDot(), findsNothing);
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.unseenProps, 0);
      await end(tester, e);
    });

    testWidgets('새 소품이 없으면 `소품` 탭에 점이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e);
      await settle(tester, () => false, tries: 6);

      expect(find.byKey(const ValueKey('tab-props')), findsOneWidget);
      expect(tabDot(), findsNothing);
      await end(tester, e);
    });
  });

  group('쉼터 배낭의 알림 점', () {
    Finder dot() => find.byKey(const ValueKey('backpack-dot'));

    testWidgets('새 소품이 없으면 점이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(find.text('배낭'), findsOneWidget);
      expect(dot(), findsNothing);
      await end(tester, e);
    });

    testWidgets('새 그림만 있어도 점이 붙고, 화집을 열었다 돌아오면 사라진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.wood}, seen: false));
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.unseenProps, 0);
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => dot().evaluate().isNotEmpty);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(dot(), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('camp-object-backpack')));
      await transition(tester);
      await settle(
          tester, () => find.byKey(const ValueKey('new-painting-kr001')).evaluate().isNotEmpty);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await settle(tester, () => dot().evaluate().isEmpty);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(dot(), findsNothing);
      await end(tester, e);
    });

    testWidgets('본 그림과 본 소품뿐이면 점이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.wood}));
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
      expect(dot(), findsNothing);
      await end(tester, e);
    });

    testWidgets('안 본 소품이 있으면 배낭에 점(10pt 테라코타, 잉크 1.5 테두리)이 붙고, 소품 탭을 보면 사라진다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walk11km(e));
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => dot().evaluate().isNotEmpty);

      expect(dot(), findsOneWidget);
      final box = tester.widget<Container>(
          find.descendant(of: dot(), matching: find.byType(Container)));
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, Palette.terracotta);
      expect(deco.shape, BoxShape.circle);
      expect((deco.border! as Border).top.width, 1.5);
      expect(tester.getSize(dot()), const Size(10, 10));
      // 배낭 물건의 오른쪽 위 모서리에 걸쳐 있다
      final bag = find.byKey(const ValueKey('camp-object-backpack'));
      final corner = tester.getTopRight(bag);
      expect((tester.getCenter(dot()) - corner).distance, lessThan(8));

      await tester.tap(find.byKey(const ValueKey('camp-object-backpack')));
      await transition(tester);
      await settle(tester, () => find.byKey(const ValueKey('tab-props')).evaluate().isNotEmpty);
      expect(find.byType(AlbumScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-props')));
      await tester.pump();
      await settle(tester, () => false, tries: 6);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await settle(tester, () => dot().evaluate().isEmpty);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(dot(), findsNothing);
      await end(tester, e);
    });
  });
}
