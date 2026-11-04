import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 몸 색 곱하기 필터(ColorFiltered)가 Rive 정령 위에서 실제로 색을 바꾸는지 렌더해서 본다.
/// 600×600 캔버스(정령 캔버스와 같은 크기)에 정령을 그리고, 배(y365)의 한 점 색을 읽는다

/// 배 한가운데 (정령 캔버스 기준). 몸통이라 소품·얼굴이 없는 자리
const _belly = Offset(300, 380);

/// 정령을 [look]으로 그려 [points]의 불투명 색(0xRRGGBB)을 읽는다
Future<List<int>> _paint(WidgetTester tester, SpiritLook look, List<Offset> points) async {
  tester.view.physicalSize = const Size(600, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SpiritController? controller;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Colors.white,
          child: SpiritCharacter(look: look, onReady: (c) => controller = c),
        ),
      ),
    ),
  );
  for (var i = 0; i < 120 && controller == null; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(controller, isNotNull, reason: '정령 Rive 파일을 읽지 못했다');
  for (var f = 0; f < 20; f++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final colors = await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List();
    image.dispose();
    return [for (final p in points) _rgb(bytes, image.width, p)];
  });
  await tester.pumpWidget(const SizedBox());
  return colors!;
}

int _rgb(Uint8List bytes, int width, Offset p) {
  final i = (p.dy.round() * width + p.dx.round()) * 4;
  return bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
}

int _r(int c) => (c >> 16) & 0xFF;
int _g(int c) => (c >> 8) & 0xFF;
int _b(int c) => c & 0xFF;

/// 두 색의 채널별 최대 차이
int _diff(int a, int b) => [(_r(a) - _r(b)).abs(), (_g(a) - _g(b)).abs(), (_b(a) - _b(b)).abs()]
    .reduce((x, y) => x > y ? x : y);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 몸통 위를 훑는 점들 (머리·배 영역: 얼굴 선과 소품 자리도 섞여 있다)
  final grid = [
    for (var y = 160; y <= 440; y += 20)
      for (var x = 220; x <= 380; x += 20) Offset(x.toDouble(), y.toDouble()),
  ];

  /// 필터 없는 그림에서 몸통 평면색(#FFF5E2)인 점의 수: 같은 점들이 견본색이 되어야 한다
  const bodyFlat = 0xFFF5E2;

  testWidgets('몸 색을 주면 몸통 픽셀이 견본색이 된다 (필터 없는 그림은 평면색 #FFF5E2)', (tester) async {
    final plain = await _paint(tester, SpiritLook.base, grid);
    final flatAt = [for (var i = 0; i < grid.length; i++) if (plain[i] == bodyFlat) i];
    // 훑는 점의 상당수가 몸통이다 (그림이 바뀌어 이 가정이 깨지면 먼저 알린다)
    expect(flatAt.length, greaterThan(40), reason: '몸통 평면색 점 ${flatAt.length}개');
    expect(_diff((await _paint(tester, SpiritLook.base, [_belly])).single, bodyFlat), 0);

    for (final swatch in [0xFFC9775A, 0xFF7F8DB3, 0xFFCDE0AC, 0xFFF3E4C4, 0xFF9FAE7E]) {
      final tinted = await _paint(tester, SpiritLook.base.copyWith(bodyArgb: swatch), grid);
      for (final i in flatAt) {
        expect(_diff(tinted[i], swatch & 0xFFFFFF), lessThanOrEqualTo(2),
            reason: '견본 ${swatch.toRadixString(16)}, 점 ${grid[i]}: ${tinted[i].toRadixString(16)}');
      }
      // 몸통이 아닌 점(바탕 흰색)은 그대로다: 필터가 알파·배경을 건드리지 않는다
      for (var i = 0; i < grid.length; i++) {
        if (plain[i] == 0xFFFFFF) expect(tinted[i], 0xFFFFFF, reason: '바탕 ${grid[i]}');
      }
    }
  });

  testWidgets('색을 바꾸면 그림도 바뀐다 (테라코타와 남청은 서로 다른 색)', (tester) async {
    final a = (await _paint(tester, SpiritLook.base.copyWith(bodyArgb: 0xFFC9775A), [_belly])).single;
    final b = (await _paint(tester, SpiritLook.base.copyWith(bodyArgb: 0xFF7F8DB3), [_belly])).single;
    expect(_diff(a, b), greaterThan(30), reason: '${a.toRadixString(16)} vs ${b.toRadixString(16)}');
    // 테라코타는 빨강이 파랑보다 크고, 남청은 반대다
    expect(_r(a), greaterThan(_b(a)));
    expect(_b(b), greaterThan(_r(b)));
  });

  testWidgets('몸 색이 null이면 필터 없이 Rive 그림 그대로다', (tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: SpiritCharacter()),
    );
    expect(find.byType(ColorFiltered), findsNothing);
    await tester.pumpWidget(
      MaterialApp(home: SpiritCharacter(look: SpiritLook.base.copyWith(bodyArgb: 0xFFC9775A))),
    );
    for (var i = 0; i < 100 && find.byType(ColorFiltered).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.byType(ColorFiltered), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
