import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/domain/sky.dart';
import 'package:doobal/domain/time_tint.dart';
import 'package:doobal/ui/scene/scene_painter.dart';
import 'package:doobal/ui/scene/scene_palette.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

const _seoul = LatLng(37.5776, 126.9769);

// 한국 시각 → UTC
DateTime _kst(int y, int mo, int d, int h) => DateTime.utc(y, mo, d, h - 9);

Widget _scene({
  required SceneMode mode,
  double distanceM = 0,
  DateTime? now,
  LatLng position = _seoul,
  bool onSea = false,
  bool running = false,
  bool withCamp = false,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SceneView(
      mode: mode,
      distanceM: distanceM,
      nowUtc: now ?? _kst(2026, 11, 18, 12),
      position: position,
      onSea: onSea,
      rules: rules,
      landmarks: landmarks,
      camp: withCamp ? campTheme : null,
      running: running,
    ),
  );
}

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('쉼터: 낮·밤·테마 없음 모두 그려진다', (tester) async {
    phone(tester);
    for (final h in [3, 6, 12, 18, 23]) {
      await tester.pumpWidget(_scene(mode: SceneMode.rest, now: _kst(2026, 11, 18, h), withCamp: true));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(_scene(mode: SceneMode.rest));
    expect(tester.takeException(), isNull);
  });

  testWidgets('걷는 중: 계절·걷기·달리기·배 위·여러 거리에서 그려진다', (tester) async {
    phone(tester);
    for (final month in [1, 4, 7, 10]) {
      for (final running in [false, true]) {
        await tester.pumpWidget(_scene(
          mode: SceneMode.walking,
          distanceM: 123.4 + month,
          now: _kst(2026, month, 15, 10),
          running: running,
        ));
        expect(tester.takeException(), isNull);
      }
    }
    for (final distance in [0.0, 1e-9, 99.99, 200.0, 12345.678]) {
      await tester.pumpWidget(_scene(mode: SceneMode.walking, distanceM: distance, onSea: true));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('화면 크기가 달라도 그려진다 (작은 폰·태블릿)', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    for (final size in const [Size(320, 568), Size(768, 1024)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_scene(mode: SceneMode.walking, distanceM: 50));
      await tester.pumpWidget(_scene(mode: SceneMode.rest, withCamp: true));
      expect(tester.takeException(), isNull);
    }
  });

  test('후경 지역(landmarks.json의 backdrop 전부)과 sea에 색이 있다', () {
    final backdrops = {for (final l in landmarks) l.backdrop};
    for (final b in backdrops) {
      expect(backdropTints.containsKey(b), isTrue, reason: b);
    }
    expect(backdropTints.containsKey('sea'), isTrue);
  });

  test('하늘 5단계 모두 하늘색이 있다', () {
    for (final p in SkyPhase.values) {
      expect(skyColors.containsKey(p), isTrue);
    }
  });

  group('시간대 색: 하늘은 그대로, 그 아래는 곱해진다', () {
    // 겨울 쉼터를 그려 픽셀을 읽는다. 땅 맨 위줄 바로 아래(x=20)는 땅 바탕색만 있다
    Future<ui.Image> render(SkyPhase phase) async {
      final recorder = ui.PictureRecorder();
      const size = Size(390, 844);
      ScenePainter(
        look: SceneLook(phase, 'capital', Season.winter),
        mode: SceneMode.rest,
        distanceM: 0,
        rules: rules,
        onSea: false,
        running: false,
      ).paint(Canvas(recorder), size);
      return recorder.endRecording().toImage(390, 844);
    }

    Future<Color> pixel(ui.Image image, int x, int y) async {
      final data = (await image.toByteData())!;
      final i = (y * image.width + x) * 4;
      return Color.fromARGB(
          data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
    }

    void expectNear(Color actual, Color expected) {
      expect((actual.r * 255 - expected.r * 255).abs(), lessThanOrEqualTo(2));
      expect((actual.g * 255 - expected.g * 255).abs(), lessThanOrEqualTo(2));
      expect((actual.b * 255 - expected.b * 255).abs(), lessThanOrEqualTo(2));
    }

    Color multiplied(Color base, int factor) => Color.fromARGB(
        255,
        (base.r * 255 * ((factor >> 16) & 0xFF) / 255).round(),
        (base.g * 255 * ((factor >> 8) & 0xFF) / 255).round(),
        (base.b * 255 * (factor & 0xFF) / 255).round());

    testWidgets('낮: 땅은 바탕색 그대로', (tester) async {
      final image = (await tester.runAsync(() => render(SkyPhase.day)))!;
      final ground = (await tester.runAsync(() => pixel(image, 20, 700)))!;
      expectNear(ground, groundColors[Season.winter]!);
    });

    testWidgets('밤: 하늘 맨 위는 하늘색 그대로, 땅은 밤 배경 세기로 곱해진다', (tester) async {
      final image = (await tester.runAsync(() => render(SkyPhase.night)))!;
      final sky = (await tester.runAsync(() => pixel(image, 20, 0)))!;
      final ground = (await tester.runAsync(() => pixel(image, 20, 700)))!;
      expectNear(sky, skyColors[SkyPhase.night]!.top);
      final t = timeTintOf(SkyPhase.night, rules)!;
      expectNear(
          ground, multiplied(groundColors[Season.winter]!, multiplyFactor(t.color, t.background)));
    });

    testWidgets('밤: 하늘이 비치는 투명한 곳(후경 위쪽)이 곱해져 칠해지지 않는다', (tester) async {
      final image = (await tester.runAsync(() => render(SkyPhase.night)))!;
      // 화면 한가운데 위쪽 (y=200)은 하늘뿐이다
      final sky = (await tester.runAsync(() => pixel(image, 195, 200)))!;
      final c = skyColors[SkyPhase.night]!;
      // 하늘 그라디언트 위 25% 지점: 위·아래 색 사이
      expect(sky.b * 255, inInclusiveRange(c.top.b * 255 - 2, c.bottom.b * 255 + 2));
      expect(sky.r * 255, greaterThanOrEqualTo(c.top.r * 255 - 2));
    });
  });
}
