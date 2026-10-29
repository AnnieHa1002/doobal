import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/domain/sky.dart';
import 'package:doobal/domain/sun.dart';
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

  test('계절마다 숲·풀밭·땅 색이 있다', () {
    for (final season in Season.values) {
      expect(groveColors.containsKey(season), isTrue, reason: season.name);
      expect(meadowColors.containsKey(season), isTrue, reason: season.name);
      expect(groundColors.containsKey(season), isTrue, reason: season.name);
      expect(tuftColors.containsKey(season), isTrue, reason: season.name);
    }
  });

  test('다시 그릴지: 장면 값이 같으면 안 그리고, 하늘이나 거리가 바뀌면 그린다', () {
    ScenePainter painter(SceneLook look, {double distanceM = 0}) => ScenePainter(
          look: look,
          mode: SceneMode.walking,
          distanceM: distanceM,
          rules: rules,
          onSea: false,
          running: false,
        );
    final noon = sceneLook(_kst(2026, 11, 18, 12), _seoul, false, landmarks, rules);
    final same = sceneLook(_kst(2026, 11, 18, 12), _seoul, false, landmarks, rules);
    final later = sceneLook(_kst(2026, 11, 18, 13), _seoul, false, landmarks, rules);
    expect(painter(noon).shouldRepaint(painter(same)), isFalse);
    expect(painter(noon).shouldRepaint(painter(later)), isTrue);
    expect(painter(noon).shouldRepaint(painter(noon, distanceM: 1)), isTrue);
  });

  group('그린 픽셀: 하늘은 그대로, 그 아래는 시간대 색이 곱해진다', () {
    // 390×844 화면 (k = 844 / 2532 = 1/3). 쉼터(테마 없음)를 그려 픽셀을 읽는다.
    // x=20은 땅 줄무늬 0번 칸(밝은 칸)이고 캐릭터·전경 풀과 떨어져 있어 한 가지 색만 있다
    const w = 390, h = 844;
    int py(double refY) => (refY * h / rules.screenHeightPx).round();

    Future<ui.Image> render(SceneLook look,
        {SceneMode mode = SceneMode.rest, bool onSea = false}) async {
      final recorder = ui.PictureRecorder();
      ScenePainter(
        look: look,
        mode: mode,
        distanceM: 0,
        rules: rules,
        onSea: onSea,
        running: false,
      ).paint(Canvas(recorder), Size(w.toDouble(), h.toDouble()));
      return recorder.endRecording().toImage(w, h);
    }

    Future<Color> pixel(ui.Image image, int x, int y) async {
      final data = (await image.toByteData())!;
      final i = (y * image.width + x) * 4;
      return Color.fromARGB(
          data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
    }

    void expectNear(Color actual, Color expected, {int tolerance = 2}) {
      expect((actual.r * 255 - expected.r * 255).abs(), lessThanOrEqualTo(tolerance));
      expect((actual.g * 255 - expected.g * 255).abs(), lessThanOrEqualTo(tolerance));
      expect((actual.b * 255 - expected.b * 255).abs(), lessThanOrEqualTo(tolerance));
    }

    Color multiplied(Color base, int factor) => Color.fromARGB(
        255,
        (base.r * 255 * ((factor >> 16) & 0xFF) / 255).round(),
        (base.g * 255 * ((factor >> 8) & 0xFF) / 255).round(),
        (base.b * 255 * (factor & 0xFF) / 255).round());

    Color topKey(String phase) => Color(rules.skyKeys[phase]!.top);

    // 직접 만든 장면: 단계에 머무는 하늘, 해달 없음(빛무리는 왼쪽 지평선), 별은 [stars]
    SceneLook held(SkyPhase phase, {double? stars}) {
      final mix = SkyMix(phase, phase, 0);
      final sky = skyLookOf(mix, rules);
      return SceneLook(
        mix,
        SkyLook(
          top: sky.top,
          mid: sky.mid,
          horizon: sky.horizon,
          glow: sky.glow,
          glowStrength: sky.glowStrength,
          stars: stars ?? sky.stars,
        ),
        const Celestial(SkyBody.none, 0),
        'capital',
        Season.winter,
      );
    }

    SceneLook real(DateTime nowUtc) => sceneLook(nowUtc, _seoul, false, landmarks, rules);

    testWidgets('낮 12:00: 땅(풀 언덕)은 바탕색 그대로', (tester) async {
      final look = real(_kst(2026, 11, 18, 12));
      final image = (await tester.runAsync(() => render(look)))!;
      final ground = (await tester.runAsync(() => pixel(image, 20, py(2400))))!;
      expectNear(ground, groundColors[look.season]!);
    });

    testWidgets('밤 02:00: 하늘 맨 위는 밤 키 색 그대로, 땅은 밤 배경 세기로 곱해진다', (tester) async {
      final look = real(_kst(2026, 11, 18, 2));
      expect(look.phase, SkyPhase.night);
      final image = (await tester.runAsync(() => render(look)))!;
      final sky = (await tester.runAsync(() => pixel(image, 20, 0)))!;
      final ground = (await tester.runAsync(() => pixel(image, 20, py(2400))))!;
      expectNear(sky, topKey('night'));
      final factor = multiplyFactor(0xFF1F2A3C, 0.52);
      expect(tintFactorAt(look.mix, rules, character: false), factor);
      expectNear(ground, multiplied(groundColors[look.season]!, factor));
    });

    testWidgets('하늘이 섞이는 중에도 땅은 그 시각의 곱하기 색 (일출 45분 전 · 일몰 1시간 전 · 일몰 30분 뒤)',
        (tester) async {
      final sun = sunTimes(_seoul, '2026-11-18', rules.sunZenithDeg);
      for (final now in [
        sun.sunrise.subtract(const Duration(minutes: 45)),
        sun.sunset.subtract(const Duration(minutes: 60)),
        sun.sunset.add(const Duration(minutes: 30)),
      ]) {
        final look = real(now);
        expect(look.mix.t, greaterThan(0), reason: '$now');
        final image = (await tester.runAsync(() => render(look)))!;
        final ground = (await tester.runAsync(() => pixel(image, 20, py(2400))))!;
        final factor = tintFactorAt(look.mix, rules, character: false);
        expect(factor, isNot(0xFFFFFFFF), reason: '$now');
        expectNear(ground, multiplied(groundColors[look.season]!, factor));
      }
    });

    testWidgets('밤: 하늘이 비치는 곳(후경 위쪽)은 곱해지지 않고 하늘 그라디언트 그대로', (tester) async {
      // 별 없음·해달 없음이라 하늘 색만 있다. y=100은 위(0)~가운데(60%) 구간의 31.8% 지점
      final look = held(SkyPhase.night, stars: 0);
      final image = (await tester.runAsync(() => render(look)))!;
      final sky = (await tester.runAsync(() => pixel(image, 20, 100)))!;
      final horizon = rules.horizonY * h / rules.screenHeightPx;
      final t = 100.5 / (horizon * rules.skyMidStop);
      final key = rules.skyKeys['night']!;
      expectNear(sky, Color.lerp(Color(key.top), Color(key.mid), t)!);
      // 곱해졌다면 이렇게 어두워진다
      final dimmed = multiplied(Color(key.top), multiplyFactor(0xFF1F2A3C, 0.52));
      expect((sky.b - dimmed.b).abs() * 255, greaterThan(20));
    });

    testWidgets('낮: 풀밭 → 길 띠 → 풀 언덕이 위에서 아래로 한 가지 색씩', (tester) async {
      final look = held(SkyPhase.day);
      final image = (await tester.runAsync(() => render(look)))!;
      // 풀밭 띠 아래(2050)와 길 띠 위(2131) 사이, 길 가운데(2171), 길 아래 풀 언덕(2400)
      expectNear((await tester.runAsync(() => pixel(image, 20, py(2090))))!,
          meadowColors[Season.winter]!);
      expectNear((await tester.runAsync(() => pixel(image, 20, py(rules.pathY))))!, pathColor);
      expectNear((await tester.runAsync(() => pixel(image, 20, py(2400))))!,
          groundColors[Season.winter]!);
    });

    testWidgets('배 구간: 능선·숲·풀밭이 숨겨져 지평선 아래는 바다색', (tester) async {
      final look = held(SkyPhase.day);
      final image =
          (await tester.runAsync(() => render(look, mode: SceneMode.walking, onSea: true)))!;
      // 지평선(1580) 아래 1700: 능선·숲이 있었다면 그 색이다
      expectNear((await tester.runAsync(() => pixel(image, 20, py(1700))))!, seaColor);
      // 육지에서는 같은 자리에 숲이 있다
      final land =
          (await tester.runAsync(() => render(look, mode: SceneMode.walking)))!;
      expectNear((await tester.runAsync(() => pixel(land, 20, py(1900))))!,
          groveColors[Season.winter]!);
    });
  });
}
