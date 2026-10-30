import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// 캐릭터 그림 (자리표시): 어깨와 얼굴 원, 고른 머리 모양·머리색. 정사각형 칸에 그린다.
/// 캐릭터 그림(쉼터 캠프에 서서 숨 쉬는 모습)이 나오면 바꾼다. 시작 ②와 나의 정보가 같이 쓴다
class FigurePainter extends CustomPainter {
  const FigurePainter(this.hair, this.hairColor);

  final int hair;
  final Color hairColor;

  /// 자리표시 얼굴색
  static const _skin = Color(0xFFF6E1D3);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height * 0.5);
    final r = s * 0.26;
    final fill = Paint()..color = hairColor;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Palette.ink;
    void hairShape(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, line);
    }

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

    // 몸 (어깨)
    final shoulders = RRect.fromRectAndCorners(
      Rect.fromLTRB(c.dx - r * 1.5, c.dy + r * 1.05, c.dx + r * 1.5, size.height),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(shoulders, Paint()..color = Palette.moss);
    canvas.drawRRect(shoulders, line);

    // 얼굴 뒤에 오는 머리: 2 단발 · 3 긴 머리 · 4 올림머리 · 5 두 갈래
    switch (hair) {
      case 2:
        hairShape(block(r * 0.15));
      case 3:
        hairShape(block(r * 1.1));
      case 4:
        hairShape(ball(c.translate(0, -r * 1.25), r * 0.4));
      case 5:
        hairShape(ball(c.translate(-r * 1.1, r * 0.2), r * 0.38));
        hairShape(ball(c.translate(r * 1.1, r * 0.2), r * 0.38));
    }

    final face = ball(c, r);
    canvas.drawPath(face, Paint()..color = _skin);
    canvas.drawPath(face, line);

    // 앞머리 (6은 짧게 친 머리라 얇게)
    hairShape(cap(hair == 6 ? s * 0.01 : s * 0.04));
  }

  @override
  bool shouldRepaint(FigurePainter old) => old.hair != hair || old.hairColor != hairColor;
}
