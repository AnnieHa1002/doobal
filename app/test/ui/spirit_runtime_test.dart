import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

Future<(rive.File, SpiritController)> load() async {
  await rive.RiveNative.init();
  final file = (await rive.File.asset(
    SpiritCharacter.asset,
    riveFactory: rive.Factory.flutter,
  ))!;
  final controller = SpiritController(file);
  return (file, controller);
}

void tick(SpiritController c, int frames) {
  for (var i = 0; i < frames; i++) {
    c.advance(1 / 60);
  }
}

double vm(SpiritController c, String name) => c.instance.number(name)!.value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('v25 파일의 기본값은 SpiritLook.base와 같고, wear가 얼굴·소품 입력을 모두 바꾼다', () async {
    final (file, c) = await load();
    addTearDown(file.dispose);
    addTearDown(c.dispose);
    const base = SpiritLook.base;
    expect(
      [vm(c, 'eyeStyle'), vm(c, 'browStyle'), vm(c, 'noseStyle'), vm(c, 'mouthStyle')],
      [base.eye, base.brow, base.nose, base.mouth],
    );
    expect([vm(c, 'bagStyle'), vm(c, 'outfitStyle'), vm(c, 'companionStyle')], [0, 0, 0]);

    c.wear(const SpiritLook(eye: 4, brow: 0, nose: 3, mouth: 5, bag: 2, outfit: 1, companion: 1));
    tick(c, 3);
    expect(
      [vm(c, 'eyeStyle'), vm(c, 'browStyle'), vm(c, 'noseStyle'), vm(c, 'mouthStyle')],
      [4, 0, 3, 5],
    );
    expect([vm(c, 'bagStyle'), vm(c, 'outfitStyle'), vm(c, 'companionStyle')], [2, 1, 1]);
  });

  test('새 정령 파일과 10개 동작 및 독립 머리·배 제어를 읽는다', () async {
    final (file, c) = await load();
    addTearDown(() {
      c.dispose();
      file.dispose();
    });
    expect(c.artboard.width, 600);
    expect(c.artboard.height, 600);
    for (final motion in SpiritMotion.values) {
      final animation = c.artboard.animationNamed(
        motion.name[0].toUpperCase() + motion.name.substring(1),
      );
      expect(animation, isNotNull, reason: motion.name);
      animation?.dispose();
    }
    expect(c.instance.boolean('headPressed'), isNotNull);
    expect(c.instance.boolean('bellyPressed'), isNotNull);
  });
  test('이동·앉기·배 매핑, 눌림 해제 후 최신 장면 복귀', () async {
    final (file, c) = await load();
    addTearDown(() {
      c.dispose();
      file.dispose();
    });
    c.setScene(speed: 1, sitting: false);
    tick(c, 20);
    expect(c.motion, SpiritMotion.walk);
    expect(c.direction, 1);
    c.press(SpiritPress.head);
    tick(c, 15);
    expect(c.motion, SpiritMotion.idle);
    expect(c.headPressed, true);
    expect(c.bellyPressed, false);
    expect(c.direction, 0);
    c.setScene(speed: 2, sitting: false);
    c.release();
    tick(c, 50);
    expect(c.motion, SpiritMotion.run);
    expect(c.direction, 1);
    c.setScene(speed: 0, sitting: true);
    tick(c, 20);
    expect(c.motion, SpiritMotion.sit);
    c.press(SpiritPress.belly);
    tick(c, 15);
    expect(c.motion, SpiritMotion.sit);
    expect(c.bellyPressed, true);
    expect(c.headPressed, false);
    c.release();
    tick(c, 50);
    expect(c.motion, SpiritMotion.sit);
    c.setScene(speed: 2, sitting: false, boat: true);
    tick(c, 20);
    expect(c.motion, SpiritMotion.idle);
  });
  test('흔들기·넘어지기·웃기가 끝나면 직전 걷기로 복귀한다', () async {
    final (file, c) = await load();
    addTearDown(() {
      c.dispose();
      file.dispose();
    });
    c.setScene(speed: 1, sitting: false);
    for (final m in [
      SpiritMotion.wave,
      SpiritMotion.fall,
      SpiritMotion.laugh,
    ]) {
      c.play(m);
      tick(c, 25);
      expect(c.motion, m);
      tick(c, 160);
      expect(c.motion, SpiritMotion.walk, reason: m.name);
    }
  });
  test('잠자기 중에도 머리·배 중 하나만 눌리고 시선은 범위 안에 머문다', () async {
    final (file, c) = await load();
    addTearDown(() {
      c.dispose();
      file.dispose();
    });
    c.play(SpiritMotion.sleep);
    tick(c, 30);
    expect(c.motion, SpiritMotion.sleep);
    expect(c.direction, 0);
    final sleepingFace = c.artboard.component('front_face_pose')!;
    expect(sleepingFace.rotation, closeTo(-1.0471975512, .001));
    sleepingFace.dispose();
    c.press(SpiritPress.head);
    tick(c, 15);
    c.press(SpiritPress.belly);
    tick(c, 15);
    expect(c.headPressed, false);
    expect(c.bellyPressed, true);
    c.release();
    tick(c, 50);
    expect(c.motion, SpiritMotion.sleep);
    expect(c.direction, 0);
    c.setLook(double.infinity, 20);
    expect(c.instance.number('lookX')!.value, 0);
    expect(c.instance.number('lookY')!.value, 1);
  });
  testWidgets('실제 Flutter 터치로 머리·배를 구분하고 취소 후 복원한다', (tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SpiritController? controller;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: SpiritCharacter(
            capeEnabled: true,
            onReady: (c) => controller = c,
          ),
        ),
      ),
    );
    for (var i = 0; i < 120 && controller == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(controller, isNotNull);
    await tester.pump(const Duration(milliseconds: 100));
    Future<void> capture(String name) async {
      final directory = Platform.environment['DOOBAL_SPIRIT_CAPTURE_DIR'];
      if (directory == null) return;
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await b.toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        await File('$directory/$name.png').writeAsBytes(bytes);
        image.dispose();
      });
    }

    await capture('flutter_idle');
    expect(controller!.capeEnabled, isTrue);
    controller!.setCape(false);
    for (var f = 0; f < 20; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller!.capeEnabled, isFalse);
    await capture('flutter_cape_off');
    controller!.setCape(true);
    for (var f = 0; f < 20; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller!.capeEnabled, isTrue);
    var gesture = await tester.startGesture(const Offset(300, 220));
    for (var f = 0; f < 16; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller!.headPressed, true);
    expect(controller!.bellyPressed, false);
    await capture('flutter_head_hold');
    await gesture.cancel();
    for (var f = 0; f < 55; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller!.headPressed, false);
    gesture = await tester.startGesture(const Offset(300, 365));
    for (var f = 0; f < 16; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller!.bellyPressed, true);
    expect(controller!.headPressed, false);
    await capture('flutter_belly_hold');
    await gesture.up();
    for (var f = 0; f < 55; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller!.bellyPressed, false);
    for (final motion in [
      SpiritMotion.wave,
      SpiritMotion.walk,
      SpiritMotion.sit,
      SpiritMotion.fall,
      SpiritMotion.run,
      SpiritMotion.laugh,
      SpiritMotion.sleep,
    ]) {
      controller!.play(motion);
      for (var f = 0; f < 40; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await capture('flutter_${motion.name}');
    }
    if (Platform.environment['DOOBAL_SPIRIT_DEMO'] == '1') {
      final folder = Platform.environment['DOOBAL_SPIRIT_CAPTURE_DIR']!;
      await tester.runAsync(
        () => Directory('$folder/demo_frames').create(recursive: true),
      );
      var frame = 0;
      Future<void> demoFrame() async =>
          capture('demo_frames/${(frame++).toString().padLeft(3, '0')}');
      controller!.play(SpiritMotion.idle);
      for (var f = 0; f < 40; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (final motion in [
        SpiritMotion.wave,
        SpiritMotion.walk,
        SpiritMotion.sit,
        SpiritMotion.fall,
        SpiritMotion.run,
        SpiritMotion.laugh,
        SpiritMotion.sleep,
      ]) {
        controller!.play(motion);
        final step = {
          SpiritMotion.wave: 12,
          SpiritMotion.walk: 8,
          SpiritMotion.sit: 11,
          SpiritMotion.fall: 15,
          SpiritMotion.run: 5,
          SpiritMotion.laugh: 13,
          SpiritMotion.sleep: 22,
        }[motion]!;
        for (var shot = 0; shot < 8; shot++) {
          for (var f = 0; f < step; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await demoFrame();
        }
      }
      for (final region in SpiritPress.values) {
        controller!.play(SpiritMotion.idle);
        for (var f = 0; f < 40; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        controller!.press(region);
        for (var shot = 0; shot < 6; shot++) {
          for (var f = 0; f < 4; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await demoFrame();
        }
        controller!.release();
        for (var shot = 0; shot < 6; shot++) {
          for (var f = 0; f < 6; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await demoFrame();
        }
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
