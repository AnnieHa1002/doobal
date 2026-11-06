import 'dart:async';

import 'package:doobal/app/providers.dart';
import 'package:doobal/domain/asset_index.dart';
import 'package:doobal/ui/common/item_cell.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 상점·꾸미기·화집이 같이 쓰는 칸

const _icon = 'assets/items/basic_v02/item_hat_01_icon_v02.png';

Future<void> _pump(WidgetTester tester, Widget child, {List<String> files = const []}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [assetIndexProvider.overrideWith((ref) => AssetIndex(files))],
    child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 118, child: Center(child: child))))),
  ));
  // 파일 목록(FutureProvider)을 읽을 때까지
  await tester.pump();
  await tester.pump();
}

Image _image(WidgetTester tester) => tester.widget<Image>(find.byType(Image));

void main() {
  group('칸 그림', () {
    testWidgets('파일이 있으면 그 그림: 64×64, 192px로 읽는다', (tester) async {
      await _pump(tester, const ItemArt(id: 'hat_01', name: '베레모'), files: [_icon]);
      final image = _image(tester);
      expect((image.image as ResizeImage).width, 192);
      expect(((image.image as ResizeImage).imageProvider as AssetImage).assetName, _icon);
      expect(tester.getSize(find.byType(ItemArt)), const Size(64, 64));
      expect(find.byType(ItemPlaceholder), findsNothing);
      expect(find.text('베레모'), findsNothing);
    });

    testWidgets('파일이 없으면 점선 칸 + 이름', (tester) async {
      await _pump(tester, const ItemArt(id: 'hat_02', name: '여행 모자'));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ItemPlaceholder), findsOneWidget);
      expect(tester.getSize(find.byType(ItemPlaceholder)), const Size(60, 56));
      expect(find.text('여행 모자'), findsOneWidget);
    });

    testWidgets('새 파일을 넣기만 하면 코드 없이 그 그림을 쓴다', (tester) async {
      const file = 'assets/items/icons/item_face_01_icon_v01_clean.webp';
      await _pump(tester, const ItemArt(id: 'face_01', name: '헤드폰'), files: [file]);
      final image = _image(tester).image as ResizeImage;
      expect((image.imageProvider as AssetImage).assetName, file);
    });

    testWidgets('파일을 못 읽으면 점선 칸으로 돌아간다', (tester) async {
      await _pump(
        tester,
        const ItemImage('assets/items/icons/없는_그림.png', size: itemArtSize, fallback: ItemPlaceholder(name: '장화')),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.text('장화'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('파일 목록을 읽기 전에도 점선 칸으로 그린다', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          assetIndexProvider.overrideWith((ref) => Completer<AssetIndex>().future),
        ],
        child: const MaterialApp(home: Scaffold(body: ItemArt(id: 'hat_01', name: '베레모'))),
      ));
      await tester.pump();
      expect(find.byType(ItemPlaceholder), findsOneWidget);
    });

    testWidgets('글자를 키워도 점선 칸이 넘치지 않는다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, const ItemArt(id: 'x', name: '고양이 슬리퍼'));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ItemPlaceholder)), const Size(60, 56));
    });
  });

  group('칸', () {
    testWidgets('이름과 상태를 꼬리표에 쓰고, 상태 색은 받은 대로', (tester) async {
      await _pump(
        tester,
        ItemCell(
          name: '지름길',
          art: const ItemPlaceholder(),
          tilt: 0,
          state: '50 럭',
          stateColor: Palette.terracottaDeep,
          onTap: () {},
        ),
      );
      expect(find.text('지름길'), findsOneWidget);
      expect(tester.widget<Text>(find.text('50 럭')).style!.color, Palette.terracottaDeep);
      final semantics = tester.getSemantics(find.byType(ItemCell));
      expect(semantics.label, '지름길, 50 럭');
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('상태가 없으면 한 줄, 빈 칸은 글자 없는 점선', (tester) async {
      await _pump(tester, const ItemCell(name: '없음', art: ItemPlaceholder(), tilt: 0));
      expect(find.text('없음'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('누르면 onTap, 없으면 눌리지 않는다', (tester) async {
      var taps = 0;
      await _pump(tester, ItemCell(name: '장화', art: const ItemPlaceholder(), tilt: 0, onTap: () => taps++));
      await tester.tap(find.byType(ItemCell));
      expect(taps, 1);

      await _pump(tester, const ItemCell(name: '장화', art: ItemPlaceholder(), tilt: 0));
      await tester.tap(find.byType(ItemCell), warnIfMissed: false);
      expect(taps, 1);
      expect(tester.getSemantics(find.byType(ItemCell)).flagsCollection.isButton, isFalse);
    });

    testWidgets('고른 칸만 점선 고리', (tester) async {
      Finder ring() => find.descendant(
            of: find.byType(ItemCell),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter != null && w.painter is! DashedBoxPainter,
            ),
          );
      await _pump(tester, const ItemCell(name: '베레모', art: ItemPlaceholder(), tilt: 0));
      expect(ring(), findsNothing);
      await _pump(tester, const ItemCell(name: '베레모', art: ItemPlaceholder(), tilt: 0, selected: true));
      expect(ring(), findsOneWidget);
    });

    testWidgets('꼬리표는 짝수 칸 -2도, 홀수 칸 +2도', (tester) async {
      double angle() {
        final t = tester.widget<Transform>(
          find.descendant(of: find.byType(ItemCell), matching: find.byType(Transform)).first,
        );
        return t.transform.getRotation().entry(1, 0);
      }

      await _pump(tester, const ItemCell(name: '가', art: ItemPlaceholder(), tilt: 0));
      expect(angle(), lessThan(0));
      await _pump(tester, const ItemCell(name: '가', art: ItemPlaceholder(), tilt: 1));
      expect(angle(), greaterThan(0));
    });
  });

  testWidgets('선반은 3열로 놓고 남는 자리는 비운다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [assetIndexProvider.overrideWith((ref) => AssetIndex(const []))],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ItemShelf(cells: [
              for (var i = 0; i < 4; i++)
                ItemCell(key: ValueKey('c$i'), name: '$i', art: const ItemPlaceholder(), tilt: i),
            ]),
          ),
        ),
      ),
    ));
    Offset at(int i) => tester.getTopLeft(find.byKey(ValueKey('c$i')));
    expect(at(0).dy, at(2).dy);
    expect(at(0).dx, lessThan(at(1).dx));
    expect(at(1).dx, lessThan(at(2).dx));
    expect(at(3).dx, at(0).dx);
    expect(at(3).dy, greaterThan(at(0).dy));
    expect(tester.getSize(find.byKey(const ValueKey('c0'))).width, 130);
  });
}
