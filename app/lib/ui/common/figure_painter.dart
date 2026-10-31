import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/look.dart';
import '../../domain/look_palette.dart';
import 'palette.dart';

/// 머리 그러데이션: 끝 색과, 뿌리 색이 이어지는 곳·끝 색이 시작하는 곳 (머리카락 위 0 → 아래 1)
class HairGradient {
  const HairGradient({required this.tip, required this.rootUntil, required this.tipFrom});

  final Color tip;
  final double rootUntil;
  final double tipFrom;

  @override
  bool operator ==(Object other) =>
      other is HairGradient &&
      other.tip == tip &&
      other.rootUntil == rootUntil &&
      other.tipFrom == tipFrom;

  @override
  int get hashCode => Object.hash(tip, rootUntil, tipFrom);
}

/// 캐릭터 그림 (자리표시): 어깨와 얼굴 원, 고른 머리 모양·머리색(그러데이션이면 위아래로 이어서)·피부색.
/// 정사각형 칸에 그린다. 그림은 평면색이라 견본색을 바로 칠한다 (진짜 그림은 회색조에 tintMatrix를 입힌다).
/// 캐릭터 그림(쉼터 캠프에 서서 숨 쉬는 모습)이 나오면 바꾼다. 시작 ②·나의 정보·꾸미기가 같이 쓴다
class FigurePainter extends CustomPainter {
  const FigurePainter(this.hair, this.hairColor, {this.hairGradient, this.skin = defaultSkin});

  final int hair;

  /// 머리색. 그러데이션이면 뿌리 색
  final Color hairColor;
  final HairGradient? hairGradient;
  final Color skin;

  /// 처음 얼굴색 (피부 견본 1)
  static const defaultSkin = Color(0xFFF6E1D3);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height * 0.5);
    final r = s * 0.26;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Palette.ink;

    Path ball(Offset center, double radius) =>
        Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    Path block(double extraBottom) => Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(c.dx - r * 1.25, c.dy - r * 1.1, c.dx + r * 1.25, c.dy + r + extraBottom),
        Radius.circular(r * 0.6),
      ));
    // 앞머리: 얼굴 위쪽 반원
    Path cap(double extra) =>
        Path()..addArc(Rect.fromCircle(center: c, radius: r + extra), math.pi, math.pi);

    // 얼굴 뒤에 오는 머리: 2 단발 · 3 긴 머리 · 4 올림머리 · 5 두 갈래
    final behind = switch (hair) {
      2 => [block(r * 0.15)],
      3 => [block(r * 1.1)],
      4 => [ball(c.translate(0, -r * 1.25), r * 0.4)],
      5 => [
          ball(c.translate(-r * 1.1, r * 0.2), r * 0.38),
          ball(c.translate(r * 1.1, r * 0.2), r * 0.38),
        ],
      _ => <Path>[],
    };
    // 앞머리 (6은 짧게 친 머리라 얇게)
    final front = cap(hair == 6 ? s * 0.01 : s * 0.04);

    // 머리카락 위아래 범위: 그러데이션은 이 범위를 세로로 나눈다
    final bounds = behind.fold(front.getBounds(), (b, p) => b.expandToInclude(p.getBounds()));
    final fill = Paint()..color = hairColor;
    final g = hairGradient;
    if (g != null) {
      fill.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [hairColor, hairColor, g.tip, g.tip],
        stops: [0, g.rootUntil, g.tipFrom, 1],
      ).createShader(bounds);
    }
    void hairShape(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, line);
    }

    // 몸 (어깨)
    final shoulders = RRect.fromRectAndCorners(
      Rect.fromLTRB(c.dx - r * 1.5, c.dy + r * 1.05, c.dx + r * 1.5, size.height),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(shoulders, Paint()..color = Palette.moss);
    canvas.drawRRect(shoulders, line);

    behind.forEach(hairShape);

    final face = ball(c, r);
    canvas.drawPath(face, Paint()..color = skin);
    canvas.drawPath(face, line);

    hairShape(front);
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      old.hair != hair ||
      old.hairColor != hairColor ||
      old.hairGradient != hairGradient ||
      old.skin != skin;
}

/// 모습과 팔레트로 만든 자리표시 그림: 머리 모양, 머리색(그러데이션 포함), 피부색.
/// 꾸미기 미리보기와 나의 정보 초상이 쓴다
FigurePainter figureOf(Look look, LookPalette palette) {
  final tip = hairTipArgb(look.hairColor);
  return FigurePainter(
    look.hair,
    Color(hairArgb(look.hairColor, palette.hair.swatches)),
    hairGradient: tip == null
        ? null
        : HairGradient(
            tip: Color(tip),
            rootUntil: palette.hair.rootUntil,
            tipFrom: palette.hair.tipFrom,
          ),
    skin: Color(skinArgb(look.skin, palette.skin.swatches)),
  );
}
