import 'package:flutter/material.dart';

import '../../domain/companion.dart';
import '../common/app_text.dart';
import '../common/palette.dart';

// 동행 그림 자리표시 (T2a). 원화·Rive가 오면(T2c) 이 파일만 바꾼다

/// 초상 동그라미·그림 자리 바탕
const _portraitBg = Color(0xFFE9DFC9);

/// 자리표시 몸 색 (그림이 오면 없어진다)
const _bodyColors = {
  'bright': Color(0xFFF2C84B),
  'rest': Color(0xFFD9A25A),
  'doctor': Color(0xFFE3CFA0),
};

/// 동행 종의 화면 이름. companions.json에 표시 이름이 없어 여기 둔다
const speciesNames = {'duck': '오리', 'cat': '고양이', 'ginseng': '산삼'};

/// 동행 전신 자리표시. [silhouette]이면 누구인지 안 보이는 검은 모습 (길 위 만남 첫 장면)
class CompanionFigure extends StatelessWidget {
  const CompanionFigure({
    super.key,
    required this.companion,
    required this.height,
    this.silhouette = false,
  });

  final Companion companion;
  final double height;
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    final color = silhouette
        ? Palette.ink.withValues(alpha: 0.78)
        : _bodyColors[companion.id] ?? Palette.card;
    return Semantics(
      image: true,
      label: silhouette ? '길 앞쪽의 실루엣' : companion.name,
      child: SizedBox(
        width: height * 0.77,
        height: height,
        child: CustomPaint(
          painter: _FigurePainter(color, outlined: !silhouette),
          child: silhouette
              ? null
              : Center(
                  child: ExcludeSemantics(
                    child: MediaQuery.withNoTextScaling(
                      child: Text(
                        companion.name.characters.first,
                        style: displayStyle(height * 0.24),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  const _FigurePainter(this.color, {required this.outlined});

  final Color color;
  final bool outlined;

  @override
  void paint(Canvas canvas, Size size) {
    final head = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.3),
      width: size.width * 0.8,
      height: size.height * 0.56,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(size.width * 0.16, size.height * 0.45, size.width * 0.84, size.height),
      Radius.circular(size.width * 0.3),
    );
    final path = Path()
      ..addOval(head)
      ..addRRect(body);
    canvas.drawPath(path, Paint()..color = color);
    if (outlined) {
      canvas.drawOval(head, _line);
      canvas.drawRRect(body, _line);
      canvas.drawOval(head.deflate(0.9), Paint()..color = color);
    }
  }

  static final _line = Paint()
    ..color = Palette.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = InkLine.panel;

  @override
  bool shouldRepaint(_FigurePainter old) => old.color != color || old.outlined != outlined;
}

/// 동그라미 초상 ([companion]이 null이면 빈 동그라미: 혼자 걷는 중)
class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({super.key, required this.companion, required this.size});

  final Companion? companion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = companion;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _portraitBg,
        shape: BoxShape.circle,
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.bottomCenter,
      child: c == null ? null : CompanionFigure(companion: c, height: size * 0.8),
    );
  }
}

/// 이야기 그림 자리표시 (그림 있는 장: 프롤로그·완결, 1536×1152라 4:3).
/// 그림 6장이 오면 정령 없는 뒷판 + 지금 입은 정령 뒷모습 얹기로 바뀐다 (T2c)
class StoryArt extends StatelessWidget {
  const StoryArt({super.key, required this.companion, this.radius = 18});

  final Companion companion;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        key: const Key('story-art'),
        decoration: BoxDecoration(
          color: _portraitBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Palette.ink, width: InkLine.panel),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.bottomCenter,
        child: LayoutBuilder(
          builder: (context, box) =>
              CompanionFigure(companion: companion, height: box.maxHeight * 0.62),
        ),
      ),
    );
  }
}
