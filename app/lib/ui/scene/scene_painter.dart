import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/camp_theme.dart';
import '../../domain/parallax.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
import '../../domain/sky.dart';
import '../../domain/time_tint.dart';
import '../common/palette.dart';
import 'scene_palette.dart';

enum SceneMode { rest, walking }

// 설계 기준 화면(390×844)에서의 위치. 크기는 화면 높이 / 844 로 줄이거나 늘린다
const _designH = 844.0;

/// 땅이 시작하는 높이 (화면 높이 비율)
const _groundTop = 0.80;

/// 걷는 중 캐릭터의 발 높이 (UI 명세: y≈713pt)
const _walkFootY = 713 / 844;

/// 땅 한 장을 줄무늬 몇 칸으로 나눌지(짝수여야 한 바퀴 돌아도 무늬가 이어진다)와 전경 풀 개수
const _groundStripes = 32;
const _tuftCount = 64;

/// 쉼터 텐트 자리 (그림이 나오기 전 임시 위치)
const _tentSpot = FootSpot(0.52, 0.74);

/// 쉼터·걷는 중 공용 장면을 칠한다. 그림 파일이 생기기 전의 임시 그림이다.
/// 걷는 중: 하늘 → 후경 → 땅(배 구간은 물결 + 고정된 배) → 캐릭터 → 전경.
/// 쉼터: 하늘 → 후경 → 땅(안 움직임) → 캠프 뒤(텐트·이정표) → 캐릭터 → 캠프 앞(모닥불).
/// 시간대 색(config scene.timeTint)은 하늘만 빼고 곱해 입힌다. 캐릭터는 따로 약하게
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.look,
    required this.mode,
    required this.distanceM,
    required this.rules,
    required this.onSea,
    required this.running,
    this.camp,
  });

  final SceneLook look;
  final SceneMode mode;

  /// 땅이 스크롤되는 거리(m). 쉼터에서는 쓰지 않는다
  final double distanceM;
  final Rules rules;
  final bool onSea;
  final bool running;

  /// 쉼터 테마. 없으면 캠프 물건 없이 캐릭터만 가운데에 그린다
  final CampTheme? camp;

  bool get _rest => mode == SceneMode.rest;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / _designH;
    _sky(canvas, size);
    if (_rest) {
      _tinted(canvas, size, () {
        _backdrop(canvas, size, k);
        _land(canvas, size, scrolling: false);
        if (camp != null) {
          _tent(canvas, size, k, _tentSpot);
          _signpost(canvas, size, k, camp!.signpost);
        }
      });
      final spot = camp?.character ?? const FootSpot(0.5, _walkFootY);
      _character(canvas, k, spot.x * size.width, spot.footY * size.height, standing: true);
      if (camp != null) _tinted(canvas, size, () => _fire(canvas, size, k, camp!));
      return;
    }
    _tinted(canvas, size, () {
      _backdrop(canvas, size, k);
      if (onSea) {
        _sea(canvas, size, k);
      } else {
        _land(canvas, size, scrolling: true);
      }
    });
    _character(canvas, k, size.width / 2, size.height * _walkFootY, standing: onSea);
    // 물 위에는 풀이 없다
    if (!onSea) _tinted(canvas, size, () => _foreground(canvas, size, k));
  }

  /// [draw]가 그린 것에 시간대 색(배경 세기)을 곱한다. 낮은 그대로 그린다.
  /// 투명한 곳(하늘이 비치는 곳)은 그대로 두려고 곱하기 중 알파도 곱하는 modulate를 쓴다.
  /// 불투명한 그림 위에서는 multiply와 같다
  void _tinted(Canvas canvas, Size size, VoidCallback draw) {
    final tint = timeTintOf(look.phase, rules);
    if (tint == null) return draw();
    canvas.saveLayer(Offset.zero & size, _tintPaint(tint.color, tint.background));
    draw();
    canvas.restore();
  }

  Paint _tintPaint(int color, double strength) => Paint()
    ..colorFilter =
        ColorFilter.mode(Color(multiplyFactor(color, strength)), BlendMode.modulate);

  void _sky(Canvas canvas, Size size) {
    final c = skyColors[look.phase]!;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c.top, c.bottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _backdrop(Canvas canvas, Size size, double k) {
    final offset = _rest
        ? 0.0
        : layerOffsetPx(distanceM, rules.parallaxBackdrop, rules.groundPxPerM,
            rules.groundTileWidthPx);
    final tint = backdropTints[look.backdrop] ?? fallbackBackdropTint;
    final sea = look.backdrop == seaBackdrop;
    final base = size.height * _groundTop;
    final skyBottom = skyColors[look.phase]!.bottom;
    // 먼 언덕은 하늘 쪽으로 흐리게
    _hills(canvas, size, offset, base - 16 * k, (sea ? 50 : 150) * k, 1.3,
        Color.lerp(tint, skyBottom, 0.45)!);
    _hills(canvas, size, offset, base + 4 * k, (sea ? 24 : 90) * k, 0.0, tint);
  }

  /// 가로 한 바퀴(groundTileWidthPx)에서 끊김 없이 이어지는 언덕 실루엣
  void _hills(Canvas canvas, Size size, double offset, double baseY, double amp, double phase,
      Color color) {
    const step = 12.0;
    final period = rules.groundTileWidthPx;
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + step; x += step) {
      final t = 2 * math.pi * (x + offset) / period;
      final h = 0.5 * math.sin(3 * t + phase) +
          0.35 * math.sin(7 * t + 2 * phase) +
          0.15 * math.sin(13 * t);
      path.lineTo(x, baseY - amp * (0.55 + 0.45 * h));
    }
    path
      ..lineTo(size.width + step, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _land(Canvas canvas, Size size, {required bool scrolling}) {
    final top = size.height * _groundTop;
    final base = groundColors[look.season]!;
    canvas.drawRect(Rect.fromLTRB(0, top, size.width, size.height), Paint()..color = base);

    final period = rules.groundWidthPx;
    final stripeW = period / _groundStripes;
    final offset = scrolling
        ? layerOffsetPx(distanceM, rules.parallaxGround, rules.groundPxPerM, period)
        : 0.0;
    final dark = Paint()..color = Color.lerp(base, Palette.ink, 0.10)!;
    for (var i = (offset / stripeW).floor(); i * stripeW < offset + size.width; i++) {
      if (i.isEven) continue;
      final x = i * stripeW - offset;
      canvas.drawRect(Rect.fromLTRB(x, top, x + stripeW, size.height), dark);
    }
    canvas.drawLine(
      Offset(0, top),
      Offset(size.width, top),
      Paint()
        ..color = Palette.ink
        ..strokeWidth = 2,
    );
  }

  void _sea(Canvas canvas, Size size, double k) {
    final top = size.height * _groundTop;
    canvas.drawRect(Rect.fromLTRB(0, top, size.width, size.height),
        Paint()..color = seaColor);

    // 물결은 땅과 같은 속도로 스크롤. 파장이 한 바퀴를 나눠 떨어져야 이어진다
    final period = rules.groundWidthPx;
    final waveLen = period / 16;
    final offset = layerOffsetPx(distanceM, rules.parallaxGround, rules.groundPxPerM, period);
    final wave = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round;
    const rows = 6;
    final rowH = (size.height - top) / rows;
    for (var r = 0; r < rows; r++) {
      final y = top + (r + 0.5) * rowH;
      final path = Path();
      for (var x = 0.0; x <= size.width + 8; x += 8) {
        final yy = y + 4 * k * math.sin(2 * math.pi * (x + offset) / waveLen + r * 1.7);
        x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
      }
      canvas.drawPath(path, wave);
    }
    _boat(canvas, size, k);
  }

  /// 화면 가운데에 고정된 배. 캐릭터가 갑판 위에 선다
  void _boat(Canvas canvas, Size size, double k) {
    final cx = size.width / 2;
    final deckY = size.height * _walkFootY;
    final halfDeck = size.width * 0.30;
    final halfKeel = size.width * 0.22;
    final depth = size.height * 0.045;
    final stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * k
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 돛대와 깃발 (뒤쪽)
    final mastX = cx - halfDeck * 0.8;
    canvas.drawLine(Offset(mastX, deckY), Offset(mastX, deckY - 120 * k), stroke);
    final flag = Path()
      ..moveTo(mastX, deckY - 120 * k)
      ..lineTo(mastX + 34 * k, deckY - 108 * k)
      ..lineTo(mastX, deckY - 96 * k)
      ..close();
    canvas.drawPath(flag, Paint()..color = Palette.terracotta);
    canvas.drawPath(flag, stroke);

    final hull = Path()
      ..moveTo(cx - halfDeck, deckY)
      ..lineTo(cx + halfDeck, deckY)
      ..lineTo(cx + halfKeel, deckY + depth)
      ..lineTo(cx - halfKeel, deckY + depth)
      ..close();
    canvas.drawPath(hull, Paint()..color = boatHull);
    canvas.drawPath(hull, stroke);
    canvas.drawLine(Offset(cx - halfDeck, deckY), Offset(cx + halfDeck, deckY),
        Paint()
          ..color = boatDeck
          ..strokeWidth = 6 * k);
  }

  /// 전경 풀: 아래 15%에 계절별 색으로. 땅보다 빠르게(parallaxForeground) 지나간다
  void _foreground(Canvas canvas, Size size, double k) {
    final period = rules.groundWidthPx;
    final offset =
        layerOffsetPx(distanceM, rules.parallaxForeground, rules.groundPxPerM, period);
    final blade = Paint()
      ..color = tuftColors[look.season]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * k
      ..strokeCap = StrokeCap.round;
    final speck = Paint()..color = tuftSpecks[look.season]!;
    final spacing = period / _tuftCount;
    for (var i = 0; i < _tuftCount; i++) {
      // 풀마다 높이·간격을 다르게 하는 고정된 값 (i로만 정해 항상 같다)
      final jitter = (i * 37 % 11) / 11;
      final worldX = i * spacing + jitter * spacing * 0.6;
      var x = (worldX - offset) % period;
      if (x > size.width + 24 * k) x -= period;
      if (x < -24 * k) continue;
      final y = size.height * (0.87 + 0.12 * ((i * 53 % 7) / 7));
      final h = (14 + 16 * jitter) * k;
      for (final dx in const [-6.0, 0.0, 6.0]) {
        canvas.drawLine(Offset(x + dx * k, y), Offset(x + dx * 1.8 * k, y - h), blade);
      }
      if (look.season != Season.summer) {
        canvas.drawCircle(Offset(x + 10 * k, y - h * 0.7), 2.5 * k, speck);
      }
    }
  }

  void _tent(Canvas canvas, Size size, double k, FootSpot spot) {
    final cx = spot.x * size.width;
    final fy = spot.footY * size.height;
    final w = size.width * 0.30;
    final h = size.height * 0.12;
    final stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * k
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(cx - w / 2, fy)
      ..lineTo(cx, fy - h)
      ..lineTo(cx + w / 2, fy)
      ..close();
    canvas.drawPath(body, Paint()..color = tentColor);
    canvas.drawPath(body, stroke);
    final door = Path()
      ..moveTo(cx - w * 0.12, fy)
      ..lineTo(cx, fy - h * 0.55)
      ..lineTo(cx + w * 0.12, fy)
      ..close();
    canvas.drawPath(door, Paint()..color = tentDoor);
    canvas.drawPath(door, stroke);
  }

  void _signpost(Canvas canvas, Size size, double k, FootSpot spot) {
    final x = spot.x * size.width;
    final fy = spot.footY * size.height;
    final wood = Paint()..color = woodColor;
    final stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k;
    final pole = Rect.fromLTWH(x - 3 * k, fy - 80 * k, 6 * k, 80 * k);
    canvas.drawRect(pole, wood);
    canvas.drawRect(pole, stroke);
    for (final (i, dir) in [(0, 1.0), (1, -1.0)]) {
      final y = fy - (76 - i * 22) * k;
      final plank = Rect.fromLTWH(dir > 0 ? x : x - 44 * k, y, 44 * k, 16 * k);
      canvas.drawRect(plank, wood);
      canvas.drawRect(plank, stroke);
    }
  }

  /// 모닥불: 캐릭터와 동료 자리 사이, 캐릭터 앞쪽. 밤일수록 불빛이 번진다
  void _fire(Canvas canvas, Size size, double k, CampTheme camp) {
    final x = (camp.character.x + camp.companion.x) / 2 * size.width;
    final fy = (camp.character.footY + 0.02) * size.height;
    final glow = switch (look.phase) {
      SkyPhase.night => 0.40,
      SkyPhase.sunset || SkyPhase.dawn => 0.25,
      _ => 0.10,
    };
    canvas.drawCircle(
      Offset(x, fy - 18 * k),
      70 * k,
      Paint()
        ..shader = RadialGradient(colors: [
          flameOuter.withValues(alpha: glow),
          flameOuter.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: Offset(x, fy - 18 * k), radius: 70 * k)),
    );
    final log = Paint()
      ..color = woodColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - 22 * k, fy), Offset(x + 18 * k, fy - 8 * k), log);
    canvas.drawLine(Offset(x + 22 * k, fy), Offset(x - 18 * k, fy - 8 * k), log);
    Path flame(double s) => Path()
      ..moveTo(x - 14 * s * k, fy - 8 * k)
      ..quadraticBezierTo(x - 16 * s * k, fy - 30 * s * k, x, fy - 52 * s * k)
      ..quadraticBezierTo(x + 16 * s * k, fy - 30 * s * k, x + 14 * s * k, fy - 8 * k)
      ..close();
    canvas.drawPath(flame(1), Paint()..color = flameOuter);
    canvas.drawPath(flame(0.55), Paint()..color = flameInner);
  }

  /// 캐릭터 자리표시자: 잉크 선의 작은 화가. 오른쪽을 보고 선다.
  /// 걷기는 다리를 걸음 보폭에 맞춰 흔들고, 달리기는 앞으로 기울고 속도 선이 붙는다.
  /// 서 있을 때(쉼터·배 위)는 다리를 흔들지 않는다
  void _character(Canvas canvas, double k, double cx, double footY, {required bool standing}) {
    canvas.save();
    canvas.translate(cx, footY);
    canvas.scale(k);
    // 캐릭터에는 캐릭터 세기로 입힌다 (그려지는 범위만 레이어로)
    final tint = timeTintOf(look.phase, rules);
    if (tint != null) {
      canvas.saveLayer(
          const Rect.fromLTRB(-100, -160, 70, 20), _tintPaint(tint.color, tint.character));
    }

    final ink = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final limb = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // 그림자
    canvas.drawOval(const Rect.fromLTWH(-30, -5, 60, 10),
        Paint()..color = Palette.ink.withValues(alpha: 0.18));

    // 걸음 한 쌍(보폭 두 번)마다 다리가 한 바퀴
    final stride = running ? rules.runStrideM : rules.walkStrideM;
    final swing = standing ? 0.0 : math.sin(2 * math.pi * distanceM / (2 * stride));
    final legAngle = swing * (running ? 0.75 : 0.45);

    const hipY = -38.0;
    const legLen = 38.0;
    for (final s in const [1.0, -1.0]) {
      final a = legAngle * s;
      canvas.drawLine(Offset(s * 5, hipY),
          Offset(s * 5 + math.sin(a) * legLen, hipY + math.cos(a) * legLen), limb);
    }

    // 몸통부터는 엉덩이를 축으로 앞으로 기운다
    canvas.save();
    canvas.translate(0, hipY);
    canvas.rotate(running && !standing ? 0.22 : 0.04);
    canvas.translate(0, -hipY);

    // 배낭 (뒤)
    final pack = RRect.fromRectAndRadius(
        const Rect.fromLTRB(-30, -82, -10, -44), const Radius.circular(6));
    canvas.drawRRect(pack, Paint()..color = Palette.moss);
    canvas.drawRRect(pack, ink);

    // 팔
    final armA = -legAngle * 1.2;
    canvas.drawLine(const Offset(6, -78),
        Offset(6 + math.sin(armA) * 28, -78 + math.cos(armA) * 28), limb);

    // 몸통(코트)
    final torso = RRect.fromRectAndRadius(
        const Rect.fromLTRB(-16, -86, 16, -34), const Radius.circular(10));
    canvas.drawRRect(torso, Paint()..color = Palette.terracotta);
    canvas.drawRRect(torso, ink);

    // 머리: 2.5등신 느낌의 큰 머리
    const head = Offset(0, -106);
    canvas.drawCircle(head, 24, Paint()..color = Palette.card);
    canvas.drawCircle(head, 24, ink);
    canvas.drawCircle(const Offset(10, -106), 2.5, Paint()..color = Palette.ink);
    // 베레모
    final beret = Rect.fromCenter(center: const Offset(2, -126), width: 46, height: 18);
    canvas.drawOval(beret, Paint()..color = Palette.ink);
    canvas.restore();

    if (running && !standing) {
      for (final y in const [-90.0, -70.0, -50.0]) {
        canvas.drawLine(Offset(-44, y), Offset(-76, y),
            Paint()
              ..color = Palette.ink.withValues(alpha: 0.45)
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round);
      }
    }
    if (tint != null) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.look.phase != look.phase ||
      old.look.backdrop != look.backdrop ||
      old.look.season != look.season ||
      old.mode != mode ||
      old.distanceM != distanceM ||
      old.onSea != onSea ||
      old.running != running ||
      old.camp != camp ||
      old.rules != rules;
}
