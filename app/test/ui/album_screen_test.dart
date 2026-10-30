import 'package:doobal/app/providers.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/album/album_widgets.dart';
import 'package:doobal/ui/album/painting_detail_screen.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/common/frame_style.dart';
import 'package:doobal/ui/common/framed_painting.dart';
import 'package:doobal/ui/common/notice_dot.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 101곳이 모두 그려지도록 세로를 길게 잡은 화면 높이
const _tall = 6000.0;

Finder _wall(int i) => find.byKey(ValueKey('wall-$i'));
Finder _cell(String id) => find.byKey(ValueKey('cell-$id'));
Finder _prop(String id) => find.byKey(ValueKey('prop-$id'));

FramedPainting _framed(WidgetTester tester, Finder owner) => tester
    .widget<FramedPainting>(find.descendant(of: owner, matching: find.byType(FramedPainting)));

/// 소품 줄 안의 Opacity (잠긴 소품만 흐리게 하려고 감싼다)
Finder _fade(String propId) =>
    find.descendant(of: _prop(propId), matching: find.byType(Opacity));

Future<void> _openAlbum(WidgetTester tester, UiEnv e,
    {Widget screen = const AlbumScreen(), double height = 844}) async {
  await openOnTop(tester, e, screen,
      height: height, ready: () => _wall(0).evaluate().isNotEmpty);
  // 그림·벽 값까지 한 박자 더
  await settle(tester, () => false, tries: 6);
}

Future<List<String?>> _dbWall(WidgetTester tester, UiEnv e) async =>
    (await tester.runAsync(e.svc.wall))!;

/// 걸음 기록을 넣고 동기화해서 누적 11.2km·16,000보를 쌓는다 (hand_02 지팡이를 얻는다)
Future<void> _walk11km(UiEnv e) async {
  e.source.records.add(walkRecord(t1, 160, 100));
  e.now = t1.add(const Duration(hours: 5));
  await e.svc.sync(e.now);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('화면 틀·벽', () {
    testWidgets('뒤로와 제목 `화집`, 빈 벽 4칸, 탭 둘, 권역 칩 8개', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e);

      expect(find.text('화집'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(find.byType(FramedPainting), findsAtLeast(4));
      for (var i = 0; i < 4; i++) {
        expect(_framed(tester, _wall(i)).landmark, isNull, reason: 'wall-$i');
      }
      expect(_wall(4), findsNothing);
      expect(find.text('그림'), findsOneWidget);
      expect(find.text('소품'), findsOneWidget);
      expect(find.text('전체'), findsOneWidget);
      for (final label in regionLabels.values) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // 바꾸기 모드가 아니라 안내가 없다
      expect(find.text('바꿀 액자를 누르세요'), findsNothing);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('열기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('벽에 건 그림은 그 액자 색으로 보이고, 눌러도 아무 일도 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({'kr001': Frame.gold, 'kr002': Frame.wood});
        await e.svc.setWall(0, 'kr002');
        await e.svc.setWall(2, 'kr001');
      });
      await _openAlbum(tester, e);
      await settle(tester, () => _framed(tester, _wall(0)).landmark != null);

      expect(_framed(tester, _wall(0)).landmark!.id, 'kr002');
      expect(_framed(tester, _wall(0)).frame, Frame.wood);
      expect(_framed(tester, _wall(1)).landmark, isNull);
      expect(_framed(tester, _wall(2)).landmark!.id, 'kr001');
      expect(_framed(tester, _wall(2)).frame, Frame.gold);
      expect(frameColors[Frame.gold], isNot(frameColors[Frame.wood]));

      await tester.tap(_wall(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(await _dbWall(tester, e), ['kr002', null, 'kr001', null]);
      expect(find.byType(PaintingDetailScreen), findsNothing);
      await end(tester, e);
    });

    testWidgets('칸을 길게 누르면 얻은 그림만 시트에 나오고, 고르면 그 칸에 건다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.gold, 'kr002': Frame.wood}));
      await _openAlbum(tester, e);

      await tester.longPress(_wall(1));
      await transition(tester);
      expect(find.byKey(const ValueKey('pick-kr001')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-kr002')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-kr003')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pick-kr002')));
      await transition(tester);
      await settle(tester, () => _framed(tester, _wall(1)).landmark != null);
      expect(find.byKey(const ValueKey('pick-kr002')), findsNothing);
      expect(await _dbWall(tester, e), [null, 'kr002', null, null]);
      expect(_framed(tester, _wall(1)).landmark!.id, 'kr002');

      // 같은 그림을 다른 칸에 걸면 옮겨진다
      await tester.longPress(_wall(3));
      await transition(tester);
      await tester.tap(find.byKey(const ValueKey('pick-kr002')));
      await transition(tester);
      await settle(tester, () => _framed(tester, _wall(1)).landmark == null);
      expect(await _dbWall(tester, e), [null, null, null, 'kr002']);
      expect(_framed(tester, _wall(3)).landmark!.id, 'kr002');
      await end(tester, e);
    });

    testWidgets('시트 밖을 눌러 닫으면 그대로, 얻은 그림이 없으면 시트가 열리지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e);
      await tester.longPress(_wall(0));
      await transition(tester);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.runAsync(() => e.ownPaintings({'kr001': Frame.wood}));
      e.now = e.now.add(const Duration(minutes: 1));
      ProviderScope.containerOf(tester.element(find.byType(AlbumScreen)))
          .invalidate(snapshotProvider);
      await settle(tester, () => false, tries: 8);
      await tester.longPress(_wall(0));
      await transition(tester);
      expect(find.byKey(const ValueKey('pick-kr001')), findsOneWidget);
      await tester.tapAt(const Offset(195, 40));
      await transition(tester);
      expect(find.byKey(const ValueKey('pick-kr001')), findsNothing);
      expect(await _dbWall(tester, e), [null, null, null, null]);
      await end(tester, e);
    });

    testWidgets('바꾸기 모드(직접 열기): 안내가 있고, 칸을 누르면 그 자리에 걸고 안내가 사라진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({
          'kr001': Frame.gold,
          'kr002': Frame.wood,
          'kr003': Frame.wood,
          'kr004': Frame.wood,
          'kr005': Frame.wood,
        });
        for (final (i, id) in ['kr002', 'kr003', 'kr004', 'kr005'].indexed) {
          await e.svc.setWall(i, id);
        }
      });
      await _openAlbum(tester, e, screen: const AlbumScreen(hangLandmarkId: 'kr001'));

      expect(find.text('바꿀 액자를 누르세요'), findsOneWidget);
      await tester.tap(_wall(0));
      await settle(tester, () => find.text('바꿀 액자를 누르세요').evaluate().isEmpty);
      expect(find.text('바꿀 액자를 누르세요'), findsNothing);
      expect(await _dbWall(tester, e), ['kr001', 'kr003', 'kr004', 'kr005']);
      await settle(tester, () => _framed(tester, _wall(0)).landmark?.id == 'kr001');
      expect(_framed(tester, _wall(0)).frame, Frame.gold);
      await end(tester, e);
    });
  });

  group('그림 탭', () {
    testWidgets('명소 101곳이 landmarks.json 순서로 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e, height: _tall);

      final shown = tester.widgetList<PaintingCell>(find.byType(PaintingCell)).toList();
      expect(shown, hasLength(101));
      expect([for (final c in shown) c.landmark.id], [for (final l in landmarks) l.id]);
      await end(tester, e);
    });

    testWidgets('얻은 그림은 액자 색과 잉크색 이름, 못 얻은 그림은 빈 밝은 액자와 흐린 이름', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.gold, 'kr003': Frame.silver}));
      await _openAlbum(tester, e);
      await settle(tester, () => _framed(tester, _cell('kr001')).landmark != null);

      expect(_framed(tester, _cell('kr001')).frame, Frame.gold);
      expect(_framed(tester, _cell('kr003')).frame, Frame.silver);
      expect(_framed(tester, _cell('kr002')).frame, isNull);
      expect(_framed(tester, _cell('kr002')).landmark, isNull);

      Color? nameColor(String id, String name) => tester
          .widget<Text>(find.descendant(of: _cell(id), matching: find.text(name)))
          .style
          ?.color;
      expect(nameColor('kr001', '경복궁'), Palette.ink);
      expect(nameColor('kr002', '인천 차이나타운·월미도'), Palette.subInk);
      await end(tester, e);
    });

    testWidgets('권역 칩을 누르면 그 권역 명소만, 전체를 누르면 모두', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openAlbum(tester, e, height: _tall);

      Future<List<String>> shownRegions() async => [
            for (final c in tester.widgetList<PaintingCell>(find.byType(PaintingCell)))
              c.landmark.region,
          ];

      for (final r in ['gyeongsang', 'jeolla', 'jeju', 'ulleung']) {
        // 칩 줄은 옆으로 밀리는 줄이라 뒤쪽 칩은 먼저 보이게 한다
        await tester.ensureVisible(find.byKey(ValueKey('album-chip-$r')));
        await tester.tap(find.byKey(ValueKey('album-chip-$r')));
        await tester.pump();
        final regions = await shownRegions();
        expect(regions, isNotEmpty, reason: r);
        expect(regions.toSet(), {r});
        expect(regions.length, landmarks.where((l) => l.region == r).length, reason: r);
      }
      expect(await shownRegions(), hasLength(1));

      await tester.ensureVisible(find.byKey(const ValueKey('album-chip-all')));
      await tester.tap(find.byKey(const ValueKey('album-chip-all')));
      await tester.pump();
      expect(await shownRegions(), hasLength(101));
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
      await settle(tester, () => _framed(tester, _cell('kr001')).landmark != null);

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

    testWidgets('못 얻은 그림을 눌러도 아무 일도 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.wood}));
      await _openAlbum(tester, e);
      await tester.tap(_cell('kr002'));
      await transition(tester);
      expect(find.byType(PaintingDetailScreen), findsNothing);
      expect(find.byType(AlbumScreen), findsOneWidget);
      await end(tester, e);
    });
  });

  group('소품 탭', () {
    Future<void> openProps(WidgetTester tester, UiEnv e) async {
      await _openAlbum(tester, e, height: 3000);
      await tester.tap(find.byKey(const ValueKey('tab-props')));
      await tester.pump();
      await settle(tester, () => _prop('hat_01').evaluate().isNotEmpty);
      // 얻은 소품 목록이 와서 기본 소품이 얻은 모습이 될 때까지
      await settle(tester, () => _fade('hat_01').evaluate().isEmpty);
    }

    testWidgets('27개를 칸별로: 모자·옷·손·가방·신발·어깨 친구 순서', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openProps(tester, e);

      expect(find.byType(PropRow), findsNWidgets(27));
      final ys = [
        for (final label in ['모자', '옷', '손', '가방', '신발', '어깨 친구'])
          tester.getTopLeft(find.text(label)).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(ys.toSet(), hasLength(6));

      // 칸 안에서는 props.json 순서, 칸 사이도 위에서 아래로
      final order = [
        for (final p in tester.widgetList<PropRow>(find.byType(PropRow))) p.prop.slot,
      ];
      expect(order, [
        ...List.filled(7, 'hat'),
        ...List.filled(4, 'cloth'),
        ...List.filled(6, 'hand'),
        ...List.filled(3, 'bag'),
        ...List.filled(2, 'shoe'),
        ...List.filled(5, 'pet'),
      ]);
      await end(tester, e);
    });

    testWidgets('얻은 소품은 이름만, 잠긴 소품은 흐리게 얻는 방법을 붙인다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _walk11km(e);
        // 전라 21곳 중 2곳
        final jeolla = [for (final l in landmarks) if (l.region == 'jeolla') l.id];
        await e.ownPaintings({for (final id in jeolla.take(2)) id: Frame.wood});
      });
      await openProps(tester, e);
      await settle(tester, () => find.text('전라 2/21').evaluate().isNotEmpty);

      bool faded(String id) => _fade(id).evaluate().isNotEmpty;
      bool has(String id, String text) =>
          find.descendant(of: _prop(id), matching: find.text(text)).evaluate().isNotEmpty;

      // 기본 소품과 11km로 얻은 지팡이(10km)는 얻은 모습
      const owned = ['hat_01', 'hand_01', 'hand_02', 'pet_01', 'bag_01', 'shoe_01', 'cloth_01'];
      for (final id in owned) {
        expect(faded(id), isFalse, reason: id);
        expect(find.descendant(of: _prop(id), matching: find.textContaining('누적')), findsNothing);
      }
      expect(has('hand_02', '지팡이'), isTrue);
      expect(has('hat_01', '베레모'), isTrue);

      // 잠긴 소품: 거리·걸음·권역·동료
      expect(faded('hat_02'), isTrue);
      expect(has('hat_02', '깃털 꽂은 여행 모자'), isTrue);
      expect(has('hat_02', '누적 25km · 지금 11km'), isTrue);
      expect(has('hand_03', '누적 150km · 지금 11km'), isTrue);
      expect(has('hat_03', '누적 1,000km · 지금 11km'), isTrue);
      expect(has('cloth_04', '누적 1,000,000보 · 지금 16,000보'), isTrue);
      expect(has('hat_04', '전라 2/21'), isTrue);
      expect(has('pet_02', '수도권 0/12'), isTrue);
      expect(has('pet_05', '울릉 0/1'), isTrue);
      for (final id in ['hat_10', 'hat_11', 'hand_09']) {
        expect(faded(id), isTrue, reason: id);
        expect(has(id, '동행 이야기 완결'), isTrue, reason: id);
      }
      await end(tester, e);
    });

    testWidgets('권역을 채운 소품은 얻은 모습 (울릉 그림이 있으면 괭이갈매기)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({'kr089': Frame.wood});
        await e.svc.sync(e.now.add(const Duration(minutes: 1)));
      });
      await openProps(tester, e);
      await settle(tester, () => _fade('pet_05').evaluate().isEmpty);
      expect(_fade('pet_05'), findsNothing);
      expect(find.text('울릉 0/1'), findsNothing);
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
      expect(find.text('전체'), findsOneWidget);
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

    testWidgets('도착해서 연 화집(거는 모드)에서도 방금 얻은 그림 칸에 점이 붙는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({'kr001': Frame.gold, 'kr002': Frame.wood}, seen: false);
        await e.svc.setWall(0, 'kr001');
        await e.svc.setWall(1, 'kr002');
      });
      await _openAlbum(tester, e, screen: const AlbumScreen(hangLandmarkId: 'kr002'));
      await settle(tester, () => newDot('kr002').evaluate().isNotEmpty);

      expect(find.text('바꿀 액자를 누르세요'), findsOneWidget);
      expect(newDot('kr001'), findsOneWidget);
      expect(newDot('kr002'), findsOneWidget);
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

      await tester.tap(find.byIcon(Icons.backpack_outlined));
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
      final bag = find
          .ancestor(of: find.byIcon(Icons.backpack_outlined), matching: find.byType(Container))
          .first;
      final corner = tester.getTopRight(bag);
      expect((tester.getCenter(dot()) - corner).distance, lessThan(8));

      await tester.tap(find.byIcon(Icons.backpack_outlined));
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
