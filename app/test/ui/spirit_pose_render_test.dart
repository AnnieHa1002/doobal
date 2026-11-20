import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/debug/spirit_preview_screen.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import 'spirit_capture.dart';

/// 앱 정령 riv를 아트보드 그대로(502×600, 1px = 1px) 그려 자세·누르기가 실제 그림을 바꾸는지 본다.
/// 11/16 T5 정리: 옛 사람형 파일(doobal_custom.riv)로 보던 자세·투명 바탕·누르기 시험을 v36으로 옮김.
/// 11/21 T17a: 옷 최종 v11(rive 0.15)로. 그림을 뜨기 전 실시간 틈을 준다(spirit_capture.dart, 지연 그리기).
/// 숫자는 이 방법으로 잰 값(자세 0·여행복·소품 없음). 정면 x 105~384·y 86~559(둥둥 ±6px)는 v36과 같다.
/// v11에서 바뀐 것: 앉기 정면 발 줄 y 547 → 538~540(앉아서도 2px쯤 움직임), 앉기 옆 536 → 517,
/// 잠들기 y 247~460 → 165~468(머리가 더 위, Codex 납품 qa/clothes_5x7과 같은 모양)

const _w = 502, _h = 600;

/// 불투명(알파 20 이상) 테두리 (왼, 위, 오른, 아래)
typedef _Box = (int, int, int, int);

final _bodyBox = (() {
  final config = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  final rive = (config['character'] as Map<String, dynamic>)['rive'] as Map<String, dynamic>;
  return ((rive['bodyBox'] as Map<String, dynamic>)['bbox'] as List).cast<num>();
})();

void main() {
  late rive.File file;
  late SpiritController c;
  final key = GlobalKey();

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(502, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    file = (await tester.runAsync<rive.File?>(
      () => rive.File.asset(SpiritCharacter.asset, riveFactory: rive.Factory.flutter),
    ))!;
    c = SpiritController(file);
    addTearDown(() {
      c.dispose();
      file.dispose();
    });
    // 몸 키를 잰 모습: 여행복만 (config bodyBox)
    c.wear(const SpiritLook(choices: {'cloth': 4}));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 502,
            height: 600,
            child: rive.RiveWidget(controller: c, fit: rive.Fit.contain),
          ),
        ),
      ),
    ));
  }

  /// [frames]만큼(1/60초씩) 돌리고 그린 RGBA
  Future<List<int>> capture(WidgetTester tester, [int frames = 1]) async {
    for (var i = 0; i < frames; i++) {
      c.advance(1 / 60);
    }
    await settleSpirit(tester, [c]);
    return (await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List().toList();
      } finally {
        image.dispose();
      }
    }))!;
  }

  _Box box(List<int> raw) {
    var (l, t, r, b) = (_w, _h, -1, -1);
    for (var i = 3; i < raw.length; i += 4) {
      if (raw[i] < 20) continue;
      final x = (i ~/ 4) % _w, y = (i ~/ 4) ~/ _w;
      if (x < l) l = x;
      if (x > r) r = x;
      if (y < t) t = y;
      if (y > b) b = y;
    }
    expect(b, greaterThan(t), reason: '정령이 그려지지 않았다');
    return (l, t, r, b);
  }

  /// 배경 위에 얹으니 네 모서리는 늘 투명해야 한다
  void transparentCorners(List<int> raw, String reason) {
    for (final p in [0, _w - 1, (_h - 1) * _w, _h * _w - 1]) {
      expect(raw[p * 4 + 3], 0, reason: reason);
    }
  }

  /// 정면 둥둥(자세 0)의 테두리가 config bodyBox(11/15 실측)와 같다. 둥둥 오르내림 ±6px에 여유 2px
  void frontFloat(_Box b, String reason) {
    expect(b.$1, closeTo(_bodyBox[0], 2), reason: '$reason 왼쪽');
    expect(b.$3, closeTo(_bodyBox[2], 2), reason: '$reason 오른쪽');
    expect(b.$2, closeTo(_bodyBox[1], 8), reason: '$reason 머리 위');
    expect(b.$4, closeTo(_bodyBox[3], 8), reason: '$reason 발');
    expect(b.$4 - b.$2, closeTo(_bodyBox[3] - _bodyBox[1], 2), reason: '$reason 몸 키');
  }

  testWidgets('자세 7개를 실제로 그린다: 바탕은 투명, 앉기는 발이 땅에 붙고 잠들기는 눕는다, 정면으로 돌아오면 처음 자리',
      (tester) async {
    await show(tester);
    await warmUpSpirit(tester, [c], (_) async => box(await capture(tester)).$2 > 130);
    c.setPose(0);
    final front = box(await capture(tester, 60));
    frontFloat(front, '정면');

    final seen = <int, List<_Box>>{};
    for (final pose in [2, 3, 4, 5, 6, 1]) {
      c.setPose(pose);
      expect(c.poseChoice, pose);
      // 전환이 끝나도록 1초 뒤부터 0.5초마다 세 번
      await capture(tester, 60);
      for (var i = 0; i < 3; i++) {
        final raw = await capture(tester, 30);
        transparentCorners(raw, '자세 $pose');
        (seen[pose] ??= []).add(box(raw));
      }
    }

    // 앉기(정면·옆)는 둥둥 오르내림이 없어 발 줄이 거의 그대로이고(v11은 2px 안), 정면 둥둥의 발보다 위다
    for (final pose in [2, 3]) {
      final bottoms = [for (final b in seen[pose]!) b.$4]..sort();
      expect(bottoms.last - bottoms.first, lessThanOrEqualTo(3), reason: '앉기 $pose 발 줄이 움직였다: $bottoms');
      for (final y in bottoms) {
        expect(y, inInclusiveRange(510, 552), reason: '앉기 $pose 발 줄');
      }
    }
    // 앉기 정면은 다리·팔이 옆으로 나와 정면 둥둥보다 넓다
    expect(seen[2]!.first.$3 - seen[2]!.first.$1, greaterThan(front.$3 - front.$1 + 40));
    // 잠들기는 누워서 몸 위 끝이 150 아래로 내려가고(서 있으면 86) 아래 끝은 480 위다
    for (final b in seen[4]!) {
      expect(b.$2, greaterThan(150), reason: '잠들기 머리 위');
      expect(b.$4, lessThan(480), reason: '잠들기 아래');
    }
    // 옆 이동은 몸이 오른쪽으로 쏠린다 (옆모습은 왼쪽을 본다)
    for (final b in seen[6]!) {
      expect(b.$1, greaterThan(front.$1 + 10), reason: '옆 이동 왼쪽');
      expect(b.$3, greaterThan(front.$3 + 10), reason: '옆 이동 오른쪽');
    }

    c.setPose(0);
    await capture(tester, 60);
    for (var i = 0; i < 3; i++) {
      final raw = await capture(tester, 30);
      transparentCorners(raw, '정면 복귀');
      frontFloat(box(raw), '정면 복귀');
    }

    // 걷기·뛰기 장면은 옆 이동 그림으로 (화면 호출 그대로)
    c.setPose(null);
    c.setScene(speed: 1, sitting: false);
    expect(c.poseChoice, 6);
    final walking = box(await capture(tester, 60));
    expect(walking.$1, greaterThan(front.$1 + 10));
    c.setScene(speed: 0, sitting: false);
    expect(c.poseChoice, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('머리를 누르면 머리가 눌리고 배를 누르면 배가 옆으로 퍼진다, 반응이 끝나면 정면 둥둥 그대로', (tester) async {
    await show(tester);
    await warmUpSpirit(tester, [c], (_) async => box(await capture(tester)).$2 > 130);
    c.setPose(0);
    await capture(tester, 120);

    // 머리: 0.1초 안에 위 끝이 30px 넘게 내려가고 발은 그대로
    final before = box(await capture(tester));
    c.press(SpiritPress.head);
    expect(c.headPressed, isTrue);
    final head = box(await capture(tester, 6));
    expect(head.$2, greaterThan(before.$2 + 30), reason: '머리가 눌려야 한다');
    expect(head.$4, closeTo(before.$4, 2), reason: '머리를 눌러도 발은 그대로');
    await capture(tester, 72); // 반응 1.2초
    expect(c.headPressed, isFalse);
    await capture(tester, 30);
    frontFloat(box(await capture(tester)), '머리 반응 뒤');

    // 배: 0.4초 안에 폭이 20px 넘게 넓어지고 머리 위는 거의 그대로
    final calm = box(await capture(tester));
    c.press(SpiritPress.belly);
    expect(c.bellyPressed, isTrue);
    var widest = 0;
    var highest = _h;
    for (var i = 0; i < 4; i++) {
      final b = box(await capture(tester, 6));
      if (b.$3 - b.$1 > widest) widest = b.$3 - b.$1;
      if (b.$2 < highest) highest = b.$2;
    }
    expect(widest, greaterThan(calm.$3 - calm.$1 + 20), reason: '배가 퍼져야 한다');
    expect(highest, closeTo(calm.$2, 8), reason: '배를 눌러도 머리 위는 그대로');
    await capture(tester, 72);
    expect(c.bellyPressed, isFalse);
    await capture(tester, 30);
    frontFloat(box(await capture(tester)), '배 반응 뒤');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('개발 화면 ‘정령 움직임’: 자세 7·표정 6·소품·뒤집기를 고르면 앱 정령에 그대로 넘긴다', (tester) async {
    tester.view.physicalSize = const Size(420, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SpiritPreviewScreen()));
    SpiritCharacter spirit() => tester.widget<SpiritCharacter>(find.byType(SpiritCharacter));
    final react = find.widgetWithText(OutlinedButton, '기쁨');
    for (var i = 0; i < 150 && tester.widget<OutlinedButton>(react).onPressed == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(tester.widget<OutlinedButton>(react).onPressed, isNotNull, reason: '정령을 읽으면 반응 단추가 켜진다');
    // 소품 줄은 v36 때 6 + v11 옷·친구 8·구슬 미리보기 11 (T17a, Codex 앱 패치)
    expect(find.byType(ChoiceChip), findsNWidgets(7 + 6 + 17));
    expect((spirit().pose, spirit().expression, spirit().mirrored), (0, 0, false));

    await tester.tap(find.text('4 잠들기'));
    await tester.tap(find.text('4 졸림'));
    await tester.tap(find.text('봇짐 지팡이'));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect((spirit().pose, spirit().expression, spirit().mirrored), (4, 4, true));
    expect(spirit().look.choices, {'cloth': 4, 'bag': 5});

    for (final label in ['인사', '기쁨', '화남', '머리 눌림', '배 눌림']) {
      await tester.tap(find.widgetWithText(OutlinedButton, label));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 반응이 끝나도 고른 자세 그대로
    await tester.pump(const Duration(seconds: 3));
    expect(spirit().pose, 4);
    await tester.pumpWidget(const SizedBox());
  });
}
