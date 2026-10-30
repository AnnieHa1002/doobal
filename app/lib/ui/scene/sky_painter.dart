import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/rules.dart';
import '../../domain/sky.dart';
import 'scene_palette.dart';

/// 별 개수
const _starCount = 40;

/// 하늘 한 장: 지평선까지 세로 그라디언트(위·가운데·지평선), 그 아래는 지평선 색.
/// 별 → 빛무리 → 해·달 순. 시간대 색은 입히지 않는다.
/// 크기는 모두 config의 기준 화면(screenHeightPx) px × [k] (k = 화면 높이 / 기준 높이).
/// 장면(ScenePainter)과 시작 화면의 밤하늘이 함께 쓴다
void paintSky(
  Canvas canvas,
  Size size,
  double k, {
  required SkyLook sky,
  required Celestial celestial,
  required Rules rules,
}) {
  final horizon = rules.horizonY * k;
  final skyRect = Rect.fromLTRB(0, 0, size.width, horizon);
  canvas.drawRect(
    skyRect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(sky.top), Color(sky.mid), Color(sky.horizon)],
        stops: [0, rules.skyMidStop, 1],
      ).createShader(skyRect),
  );
  canvas.drawRect(Rect.fromLTRB(0, horizon, size.width, size.height),
      Paint()..color = Color(sky.horizon));

  canvas.save();
  canvas.clipRect(skyRect);
  _stars(canvas, size, horizon, k, sky.stars);
  _celestial(canvas, size, k, sky, celestial, rules);
  canvas.restore();
}

/// 별: 번호로만 정해지는 고정 위치(번호를 섞은 값이라 줄지어 서지 않는다). 하늘 위쪽 절반에 불투명도 sky.stars로
void _stars(Canvas canvas, Size size, double horizon, double k, double alpha) {
  if (alpha <= 0) return;
  final paint = Paint()..color = starColor.withValues(alpha: alpha);
  for (var i = 0; i < _starCount; i++) {
    final fx = _scatter(i, 1);
    final fy = _scatter(i, 2);
    final r = (1 + i * 7 % 3) * 2.5 * k;
    canvas.drawCircle(Offset(fx * size.width, horizon * (0.03 + 0.5 * fy)), r, paint);
  }
}

/// 번호 [i]를 섞어 [0, 1)로. 같은 번호·[salt]면 늘 같은 값
double _scatter(int i, int salt) {
  var x = (i * 374761393 + salt * 668265263) & 0x7FFFFFFF;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7FFFFFFF;
  return (x ^ (x >> 16)) / 0x80000000;
}

/// 빛무리와 해·달. 호: x는 leftX → rightX, y는 지평선에서 peakY까지 올랐다 내려온다.
/// 해도 달도 없을 때(none)도 빛무리는 호의 그 자리(진 자리·뜰 자리 = 지평선)에 남는다
void _celestial(
  Canvas canvas,
  Size size,
  double k,
  SkyLook sky,
  Celestial c,
  Rules rules,
) {
  final arc = rules.skyArc;
  final center = Offset(
    (arc.leftX + (arc.rightX - arc.leftX) * c.progress) * size.width,
    (rules.horizonY - (rules.horizonY - arc.peakY) * math.sin(math.pi * c.progress)) * k,
  );
  final radius = arc.glowRadiusPx * k;
  final glow = Color(sky.glow);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(colors: [
        glow.withValues(alpha: sky.glowStrength),
        glow.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
  switch (c.body) {
    case SkyBody.sun:
      canvas.drawCircle(center, 70 * k, Paint()..color = sunDisc);
    case SkyBody.moon:
      canvas.drawCircle(center, 55 * k, Paint()..color = moonDisc);
    case SkyBody.none:
      break;
  }
}

/// 하늘만 화면 가득 칠한다 (장면 없이). 시작 화면의 고정 밤하늘
class SkyPainter extends CustomPainter {
  const SkyPainter({required this.sky, required this.celestial, required this.rules});

  final SkyLook sky;
  final Celestial celestial;
  final Rules rules;

  @override
  void paint(Canvas canvas, Size size) => paintSky(
        canvas,
        size,
        size.height / rules.screenHeightPx,
        sky: sky,
        celestial: celestial,
        rules: rules,
      );

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.sky != sky || old.celestial != celestial || old.rules != rules;
}
