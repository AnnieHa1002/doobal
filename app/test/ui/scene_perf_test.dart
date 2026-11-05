import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/rest_camera.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/scene/scene_art.dart';
import 'package:doobal/ui/scene/scene_art_painter.dart';
import 'package:doobal/ui/scene/scene_painter.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 어떤 그리기 호출이 몇 번 불렸는지 세는 캔버스
class _Count implements Canvas {
  final counts = <String, int>{};
  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString().replaceAll('Symbol("', '').replaceAll('")', '');
    counts[n] = (counts[n] ?? 0) + 1;
    return null;
  }
}

const _seoul = LatLng(37.5776, 126.9769);
const _restPasses = [
  ScenePass.restSky,
  ScenePass.restClouds,
  ScenePass.restFar,
  ScenePass.restBack,
  ScenePass.restFront,
  ScenePass.restFire,
];
const _walkPasses = [ScenePass.background, ScenePass.foreground];

/// DOOBAL_PERF_OUT이 있으면 잰 값을 그 파일에 쓴다 (전후 비교용)
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final day = DateTime.utc(2026, 4, 15, 3);
  final night = DateTime.utc(2026, 4, 15, 15);
  SceneLook lookAt(DateTime t, bool sea) => sceneLook(t, _seoul, sea, landmarks, rules);

  SceneArtPainter painter(SceneArt art, SceneLook look, ScenePass pass, bool rest, bool sea, double i) =>
      SceneArtPainter(
        art: art,
        look: look,
        mode: rest ? SceneMode.rest : SceneMode.walking,
        distanceM: 1234 + i,
        rules: rules,
        onSea: sea,
        pass: pass,
        elapsed: 4 + i * .1,
        camp: rest ? campTheme : null,
        seed: 'kr001',
        layoutSize: rest ? const Size(390, 844) : null,
      );

  testWidgets('해독 크기와 프레임마다 그리는 양', (tester) async {
    final report = <String, dynamic>{};
    final decoded = <String, double>{};
    for (final (name, w, dpr) in [('flip6_411@2.625', 411.0, 2.625), ('phone_390@3', 390.0, 3.0)]) {
      for (final (mode, rest, sea) in [('rest', true, false), ('walk', false, false), ('sea', false, true)]) {
        final look = lookAt(day, sea);
        final stage = RestGeometry(campTheme, rules.rest, w, w * 844 / 390);
        final art = (await tester.runAsync(() => SceneArt.load(
              rootBundle,
              look,
              rest,
              w / 1170,
              dpr,
              onSea: sea,
              restFarWidthPx: rest ? stage.farWidth / (w / 1170) : null,
              camp: rest ? campTheme : null,
            )))!;
        final bytes = art.images.values.fold<int>(0, (n, i) => n + i.width * i.height * 4);
        decoded['$name $mode'] = bytes / 1048576;
        report['decode $name $mode'] = {'images': art.images.length, 'MB': (bytes / 1048576).toStringAsFixed(1)};
        if (w == 390) {
          final passes = rest ? _restPasses : _walkPasses;
          for (final (tname, t) in [('day', day), ('night', night)]) {
            final l = lookAt(t, sea);
            var saveLayers = 0, images = 0;
            for (final pass in passes) {
              final c = _Count();
              await tester.runAsync(() async => painter(art, l, pass, rest, sea, 0).paint(c, const Size(585, 844)));
              saveLayers += c.counts['saveLayer'] ?? 0;
              images += (c.counts['drawImageRect'] ?? 0) + (c.counts['drawImage'] ?? 0);
            }
            report['ops $mode $tname'] = {'saveLayer': saveLayers, 'images': images};
            expect(saveLayers, 0, reason: '$mode $tname: 매 프레임 saveLayer');
            final sw = Stopwatch()..start();
            const runs = 5;
            await tester.runAsync(() async {
              for (var i = 0; i < runs; i++) {
                final rec = ui.PictureRecorder();
                final canvas = Canvas(rec)..scale(3);
                for (final pass in passes) {
                  painter(art, l, pass, rest, sea, i.toDouble()).paint(canvas, const Size(390, 844));
                }
                final pic = rec.endRecording();
                final img = await pic.toImage(1170, 2532);
                img.dispose();
                pic.dispose();
              }
            });
            report['frameMs $mode $tname'] = (sw.elapsedMilliseconds / runs).toStringAsFixed(1);
          }
        }
        await tester.runAsync(() async => art.dispose());
      }
    }
    // 예전(effa8fd)의 절반쯤을 넘지 않게 묶어 둔다. 그림이 늘면 값을 고친다
    expect(decoded['flip6_411@2.625 rest']!, lessThan(35));
    expect(decoded['flip6_411@2.625 walk']!, lessThan(110));
    final out = Platform.environment['DOOBAL_PERF_OUT'];
    if (out != null) {
      await tester.runAsync(() => File(out).writeAsString(const JsonEncoder.withIndent(' ').convert(report)));
    }
  });

  testWidgets('쉼터 후경은 보이는 조각만 읽는다', (tester) async {
    final stage = RestGeometry(campTheme, rules.rest, 390, 844);
    final art = (await tester.runAsync(() => SceneArt.load(
          rootBundle,
          lookAt(day, false),
          true,
          1 / 3,
          3,
          restFarWidthPx: stage.farWidth * 3,
          camp: campTheme,
        )))!;
    expect(art.images.containsKey('bg_far_capital_wide_part1_v10_clean.png'), isTrue);
    expect(art.images.containsKey('bg_far_capital_wide_part2_v10_clean.png'), isFalse);
    // 쓰지 않는 하늘 조각은 읽지 않는다
    expect(art.images.keys.where((k) => k.startsWith('sky_star_spark')), isEmpty);
    await tester.runAsync(() async => art.dispose());
  });

  testWidgets('시간이 흐르거나 장면을 밀어도 캠프 판은 다시 만들지 않고, 불꽃은 프레임이 바뀔 때만 그린다', (tester) async {
    phone(tester);
    final e = UiEnv();
    await e.seed(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [...e.overrides, restWiggleProvider.overrideWithValue(const WiggleSpec.off())],
      child: const MaterialApp(home: RestScreen()),
    ));
    SceneArtPainter? find_(ScenePass pass) {
      for (final element in find.byType(CustomPaint).evaluate()) {
        final p = (element.widget as CustomPaint).painter;
        if (p is SceneArtPainter && p.pass == pass) return p;
      }
      return null;
    }

    for (var i = 0; i < 200 && find_(ScenePass.restBack) == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    final back = find_(ScenePass.restBack)!;
    final sky = find_(ScenePass.restSky)!;
    final far = find_(ScenePass.restFar)!;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 350)));
    await tester.pump();
    expect(identical(find_(ScenePass.restBack), back), isTrue);
    expect(identical(find_(ScenePass.restSky), sky), isTrue);
    expect(identical(find_(ScenePass.restFar), far), isTrue);

    await tester.dragFrom(const Offset(300, 300), const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(identical(find_(ScenePass.restBack), back), isTrue);
    expect(identical(find_(ScenePass.restFar), far), isTrue);

    // 판은 시간이 달라도 다시 그릴 필요가 없다. 불꽃은 프레임이 바뀔 때만
    SceneArtPainter at(ScenePass pass, double elapsed) => SceneArtPainter(
          art: back.art,
          look: back.look,
          mode: SceneMode.rest,
          distanceM: 0,
          rules: back.rules,
          onSea: false,
          pass: pass,
          elapsed: elapsed,
          camp: back.camp,
          seed: back.seed,
          layoutSize: back.layoutSize,
        );
    expect(at(ScenePass.restBack, 9).shouldRepaint(at(ScenePass.restBack, 1)), isFalse);
    expect(at(ScenePass.restFire, 0.1).shouldRepaint(at(ScenePass.restFire, 0)), isFalse);
    expect(at(ScenePass.restFire, 0.25).shouldRepaint(at(ScenePass.restFire, 0)), isTrue);
    await end(tester, e);
  });
}
