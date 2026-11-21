import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/domain/unified_wardrobe.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

import 'spirit_capture.dart';

/// T17a: 정령 옷 최종 v11(워터마크 판, 16장 11/20·정령 계약 v0.11)을 rive 0.15.0-dev.4로 아트보드 그대로
/// (502×600, 1px = 1px) 그려 폰에서 볼 것(옷 5벌 × 7자세, 친구 8·물빛 구슬, 갈매기 + 연잎, 친구 누름)을
/// 맥에서 그림 차이로 먼저 본다. 좌표는 v11 inputs.md(Spirit 아트보드 좌표). 그림을 뜨기 전 실시간 틈을 준다
/// (spirit_capture.dart: v11은 0.15가 지연 그리기로 그린다)

const _w = 502, _h = 600;

/// 불투명(알파 20 이상) 테두리 (왼, 위, 오른, 아래)
typedef _Box = (int, int, int, int);

final _riveConfig = (() {
  final config = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  return (config['character'] as Map<String, dynamic>)['rive'] as Map<String, dynamic>;
})();

void main() {
  late rive.File file;
  final cs = <SpiritController>[];
  final keys = <GlobalKey>[];

  /// 정령 [n]개를 가로로 놓는다 (각 502×600)
  Future<void> show(WidgetTester tester, {int n = 1}) async {
    tester.view.physicalSize = Size(_w * n.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    file = (await tester.runAsync<rive.File?>(
      () => rive.File.asset(SpiritCharacter.asset, riveFactory: rive.Factory.flutter),
    ))!;
    cs
      ..clear()
      ..addAll([for (var i = 0; i < n; i++) SpiritController(file)]);
    keys
      ..clear()
      ..addAll([for (var i = 0; i < n; i++) GlobalKey()]);
    addTearDown(() {
      for (final c in cs) {
        c.dispose();
      }
      file.dispose();
    });
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < n; i++)
            RepaintBoundary(
              key: keys[i],
              child: SizedBox(
                width: _w.toDouble(),
                height: _h.toDouble(),
                child: rive.RiveWidget(controller: cs[i], fit: rive.Fit.contain),
              ),
            ),
        ]),
      ),
    ));
  }

  /// 모든 정령을 [frames]만큼(1/60초씩) 같이 돌린다
  void run(int frames) {
    for (var i = 0; i < frames; i++) {
      for (final c in cs) {
        c.advance(1 / 60);
      }
    }
  }

  /// [i]번 정령을 그린 RGBA
  Future<Uint8List> capture(WidgetTester tester, [int i = 0]) async {
    await settleSpirit(tester, cs);
    return (await tester.runAsync(() async {
      final boundary = keys[i].currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }))!;
  }

  /// 정령마다 [looks]를 입히고 같은 자세로 1초 같이 돌려(떠 있기 위상이 같게) 모두 그린다
  Future<List<Uint8List>> side(WidgetTester tester, List<Map<String, int>> looks, {int pose = 0}) async {
    expect(looks, hasLength(cs.length));
    for (var i = 0; i < cs.length; i++) {
      cs[i]
        ..wear(SpiritLook(choices: looks[i]))
        ..setPose(pose);
    }
    run(60);
    return [for (var i = 0; i < cs.length; i++) await capture(tester, i)];
  }

  _Box box(Uint8List raw, {bool Function(int i)? where}) {
    var (l, t, r, b) = (_w, _h, -1, -1);
    for (var p = 0; p < _w * _h; p++) {
      if (where == null ? raw[p * 4 + 3] < 20 : !where(p)) continue;
      final x = p % _w, y = p ~/ _w;
      if (x < l) l = x;
      if (x > r) r = x;
      if (y < t) t = y;
      if (y > b) b = y;
    }
    return (l, t, r, b);
  }

  /// 두 그림에서 색이나 알파 중 하나라도 [over]보다 많이 다른 점인지
  bool Function(int) differs(Uint8List a, Uint8List b, {int over = 40}) => (p) {
        final i = p * 4;
        return (a[i] - b[i]).abs() > over ||
            (a[i + 1] - b[i + 1]).abs() > over ||
            (a[i + 2] - b[i + 2]).abs() > over ||
            (a[i + 3] - b[i + 3]).abs() > over;
      };

  /// [f]가 참인 점의 수 (가로·세로 2px마다 하나씩 보고 4를 곱한 어림값, 시험 시간을 줄이려고)
  int count(bool Function(int) f) {
    var n = 0;
    for (var y = 0; y < _h; y += 2) {
      for (var x = 0; x < _w; x += 2) {
        if (f(y * _w + x)) n += 4;
      }
    }
    return n;
  }

  /// 정령 [n]개를 놓고 그림이 상태를 따라올 때까지 기다린 뒤 정면(자세 0)으로
  Future<void> ready(WidgetTester tester, {int n = 1}) async {
    await show(tester, n: n);
    await warmUpSpirit(tester, cs, (i) async => box(await capture(tester, i)).$2 > 130);
    for (final c in cs) {
      c.setPose(0);
    }
  }

  void transparentCorners(Uint8List raw, String reason) {
    for (final p in [0, _w - 1, (_h - 1) * _w, _h * _w - 1]) {
      expect(raw[p * 4 + 3], 0, reason: reason);
    }
  }

  test('앱이 읽는 파일은 config character.rive.next.file (3월 초 정식 내보내기 전까지 워터마크 판)', () {
    final next = _riveConfig['next'] as Map<String, dynamic>;
    expect(next['pending'], isTrue, reason: '정식 판이 오면 file 키로 옮기고 이 시험을 고친다 (개발인계 3월 초 할 일)');
    expect(next['devUse'], 'fileIdWatermarked');
    expect(SpiritCharacter.asset, 'assets/rive/${next['file']}');
    expect(File(SpiritCharacter.asset).existsSync(), isTrue);
    expect(File('assets/rive/${_riveConfig['file']}').existsSync(), isFalse, reason: 'v36은 앱에서 뺐다 (11/21 Annie)');
  });

  testWidgets('정령은 매 프레임 그린다 (alwaysDraw, v11 스크립트 그림)', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 300, height: 300, child: SpiritCharacter()),
    ));
    for (var i = 0; i < 20 && find.byType(rive.RiveWidget).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    final w = tester.widget<rive.RiveWidget>(find.byType(rive.RiveWidget));
    expect(w.drawOptimization, rive.DrawOptimization.alwaysDraw);
  });

  testWidgets('입력·클립: 색 입력 45 + 몸 색, 컨트롤러가 얹는 클립이 모두 있고, 부분색은 앱이 넣지 않는다', (tester) async {
    await ready(tester);
    final c = cs.first;
    expect(c.instance.color('bodyColor'), isNotNull);
    for (final p in unifiedProps) {
      if (p.colorField case final f?) {
        expect(c.instance.color(f), isNotNull, reason: f);
      }
      expect(c.instance.number('${p.slot}Choice'), isNotNull, reason: p.slot);
    }
    for (final name in [
      for (var n = 0; n <= 6; n++) 'Pose_${n}_stable',
      'GreetOneShot', 'JoyOneShot', 'ImportedHeadPress', 'ImportedBellyPress', 'ImportedAngryOneShot', 'MotionIdle',
    ]) {
      final a = c.artboard.animationNamed(name);
      expect(a, isNotNull, reason: name);
      a!.dispose();
    }
    // 부분색 23개(…Inner·Lining·Trim·Detail·PantsColor)는 riv 기본값 그대로 (config next.note)
    const parts = ['travelCapeInnerColor', 'travelCapeLiningColor', 'travelVestPantsColor', 'goldArtistCoatDetailColor'];
    final before = {for (final f in parts) f: c.instance.color(f)!.value};
    c.wear(SpiritLook(choices: const {'cloth': 1}, colors: {
      for (final p in unifiedProps) ?p.colorField: 0xFF102030,
    }, bodyArgb: 0xFF7F8DB3));
    expect(c.instance.color('travelCapeColor')!.value.toARGB32(), 0xFF102030);
    for (final f in parts) {
      expect(c.instance.color(f)!.value, before[f], reason: f);
    }
  });

  // 옷 5벌 × 자세 7: 시험 하나가 2분을 넘지 않게 자세를 세 묶음으로 나눈다
  for (final poses in [
    [0, 1, 2],
    [3, 4],
    [5, 6],
  ]) {
    testWidgets('옷 5벌 × 자세 ${poses.join('·')}: 모두 그려지고 바탕은 투명, 옷마다 그림이 다르다', (tester) async {
      await ready(tester, n: 5);
      for (final pose in poses) {
        final shots = await side(tester, [for (var cloth = 1; cloth <= 5; cloth++) {'cloth': cloth}], pose: pose);
        for (var i = 0; i < 5; i++) {
          transparentCorners(shots[i], '옷 ${i + 1} 자세 $pose');
          final b = box(shots[i]);
          expect(b.$4 - b.$2, greaterThan(150), reason: '옷 ${i + 1} 자세 $pose: 정령이 그려지지 않았다 $b');
        }
        for (var a = 0; a < 5; a++) {
          for (var b = a + 1; b < 5; b++) {
            expect(count(differs(shots[a], shots[b])), greaterThan(150), reason: '자세 $pose 옷 ${a + 1}·${b + 1}이 같다');
          }
        }
      }
    });
  }

  testWidgets('친구 8(pet 6~13)과 물빛 구슬(둥실 6)이 그려진다: 없을 때와 그림이 다르고 몸은 그대로', (tester) async {
    await ready(tester, n: 2);
    for (final (what, look) in [
      for (var n = 6; n <= 13; n++) ('친구 $n', {'cloth': 4, 'pet': n}),
      ('물빛 구슬', {'cloth': 4, 'float': 6}),
      // 상점 친구와 구슬을 같이 껴도 둘 다 보인다
      ('구슬 위 친구 9', {'cloth': 4, 'pet': 9, 'float': 6}),
    ]) {
      final reference = what == '구슬 위 친구 9' ? {'cloth': 4, 'float': 6} : {'cloth': 4};
      final [plain, worn] = await side(tester, [reference, look]);
      final added = count(differs(worn, plain));
      final where = box(worn, where: differs(worn, plain));
      // ignore: avoid_print
      print('$what: 다른 점 $added, 자리 $where');
      expect(added, greaterThan(300), reason: what);
      // 바뀐 곳은 몸 밖(친구는 머리 옆 위·발 옆, 구슬은 머리 위): 몸 가운데(244, 330)를 덮지 않는다
      final coversBody = where.$1 <= 244 && 244 <= where.$3 && where.$2 <= 330 && 330 <= where.$4;
      expect(coversBody, isFalse, reason: '$what 자리 $where');
    }
  });

  testWidgets('갈매기 + 연잎: 갈매기가 종이새 자리(가운데 x 58·바닥 y 439)로 옮겨 연잎과 겹치지 않는다', (tester) async {
    await ready(tester, n: 4);
    final [plain, gull, lotus, both] = await side(tester, [
      {'cloth': 4},
      {'cloth': 4, 'pet': 5},
      {'cloth': 4, 'float': 2},
      {'cloth': 4, 'pet': 5, 'float': 2},
    ]);
    final alone = box(gull, where: differs(gull, plain));
    final moved = box(both, where: differs(both, lotus));
    final lotusBox = box(lotus, where: differs(lotus, plain));
    // ignore: avoid_print
    print('갈매기 혼자 $alone · 연잎과 $moved · 연잎 $lotusBox');
    expect((moved.$1 + moved.$3) / 2, closeTo(58, 30), reason: '연잎과 낀 갈매기 가운데 x');
    expect(moved.$4, closeTo(439, 20), reason: '연잎과 낀 갈매기 바닥 y');
    // 혼자일 때(다른 둥실·둥실 없음)는 기존 머리 위 자리: 연잎과 낄 때보다 한참 위
    expect(alone.$4, lessThan(moved.$2), reason: '혼자일 때는 머리 위 자리');
    final overlap =
        moved.$1 <= lotusBox.$3 && lotusBox.$1 <= moved.$3 && moved.$2 <= lotusBox.$4 && lotusBox.$2 <= moved.$4;
    expect(overlap, isFalse, reason: '갈매기 $moved · 연잎 $lotusBox');
  });

  // 친구 고유 반응은 riv 안 스크립트가 pointerDown을 받아 1.5초 (v11 inputs.md, 새 tapPet 입력 없음).
  // 날개 친구(6~9, 머리 옆 위)와 땅 친구(10~13, 발 옆)로 나눈다
  for (final (group, ids) in [('날개 친구', [6, 7, 8, 9]), ('땅 친구', [10, 11, 12, 13])]) {
    testWidgets('$group ${ids.first}~${ids.last} 고유 반응: 친구를 누르면(pointerDown) 누르지 않은 쪽과 그림이 달라진다', (tester) async {
      await ready(tester, n: 3);
      for (final n in ids) {
        final look = {'cloth': 4, 'pet': n};
        final [bare, still, _] = await side(tester, [{'cloth': 4}, look, look]);
        final friend = box(still, where: differs(still, bare));
        final at = rive.Vec2D.fromValues((friend.$1 + friend.$3) / 2, (friend.$2 + friend.$4) / 2);
        cs[2].stateMachine.pointerDown(at);
        cs[2].stateMachine.pointerUp(at);
        run(18);
        final a = await capture(tester, 2), b = await capture(tester, 1);
        final changed = count(differs(a, b));
        // ignore: avoid_print
        print('친구 $n 자리 $friend 누름 뒤 0.3초 다른 점 $changed');
        expect(changed, greaterThan(40), reason: '친구 $n 누름 반응이 그림에 없다 (자리 $friend)');
        run(90);
      }
    });
  }
}
