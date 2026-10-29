import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/sky.dart';
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

  test('하늘 5단계 모두 하늘색·어두운 정도가 있다', () {
    for (final p in SkyPhase.values) {
      expect(skyColors.containsKey(p), isTrue);
      expect(phaseShade.containsKey(p), isTrue);
    }
  });
}
