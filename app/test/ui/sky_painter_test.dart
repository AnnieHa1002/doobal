import 'dart:ui' as ui;

import 'package:doobal/domain/sky.dart';
import 'package:doobal/ui/scene/sky_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

SkyLook get _night => skyLookOf(const SkyMix(SkyPhase.night, SkyPhase.night, 0), rules);
const _moon = Celestial(SkyBody.moon, 0.7);

void main() {
  SkyPainter painter({SkyLook? sky, Celestial celestial = _moon}) =>
      SkyPainter(sky: sky ?? _night, celestial: celestial, rules: rules);

  test('같은 하늘이면 다시 그리지 않고, 하늘이나 해·달이 바뀌면 다시 그린다', () {
    expect(painter().shouldRepaint(painter()), isFalse);
    expect(painter().shouldRepaint(painter(celestial: const Celestial(SkyBody.moon, 0.5))), isTrue);
    final day = skyLookOf(const SkyMix(SkyPhase.day, SkyPhase.day, 0), rules);
    expect(painter().shouldRepaint(painter(sky: day)), isTrue);
  });

  test('밤하늘·낮하늘 모두 그려진다 (별·빛무리·달·해 포함, 예외 없이)', () {
    for (final (sky, body) in [
      (_night, SkyBody.moon),
      (skyLookOf(const SkyMix(SkyPhase.day, SkyPhase.day, 0), rules), SkyBody.sun),
      (_night, SkyBody.none),
    ]) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      painter(sky: sky, celestial: Celestial(body, 0.4)).paint(canvas, const ui.Size(390, 844));
      recorder.endRecording().dispose();
    }
  });
}
