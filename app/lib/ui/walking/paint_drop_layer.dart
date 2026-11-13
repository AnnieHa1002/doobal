import 'package:flutter/material.dart';

import '../../domain/paint_trail.dart';
import '../../domain/rules.dart';
import '../common/app_text.dart';
import '../common/palette.dart';
import '../scene/scene_view.dart' show SceneCompanionSpot;

/// 방울 색 두 가지 (캔버스 3-1 메모, 물감 방울 v01 납품 전 임시: 하늘·테라코타를 번갈아)
const dropColors = [Color(0xFF6FA8C9), Color(0xFFC97B54)];

/// 방울 지름 = 정령 키 × 이 값 (캔버스 3-1: 정령 180pt에 방울 28pt)
const _dropOfFigure = 28 / 180;

/// 주운 럭이 머리 위로 떠올라 사라지는 시간과 높이(정령 키 비율)
const _gainDuration = Duration(milliseconds: 1200);
const _gainRise = 0.2;

/// 걷는 중 땅 위 물감 방울 (M2~M6 명세 v0.17 T②, 캔버스 3-1): 이번 물감 길 거리 config paintDrop.spacingM마다
/// 방울 하나가 땅과 같이 흘러와 정령 가운데에 닿으면 사라지고, 정령 머리 위로 `+n 럭`(paintDrop.coinsPerDrop)이
/// 떠오른다. 연출만이고 저장하지 않는다 (럭은 물감 길 거리로 따로 센다, M1 v0.5 ③).
/// 방울 그림(codex_paint_trail_v01)이 오기 전에는 코드로 그린 수채 점이다
class PaintDropLayer extends StatefulWidget {
  const PaintDropLayer({
    super.key,
    required this.spot,
    required this.shownM,
    required this.rules,
  });

  final SceneCompanionSpot spot;

  /// 화면에 보이는 이번 물감 길 거리(m). 방울 k는 k × spacingM에 있다
  final double shownM;
  final Rules rules;

  @override
  State<PaintDropLayer> createState() => _PaintDropLayerState();
}

class _PaintDropLayerState extends State<PaintDropLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _gain =
      AnimationController(vsync: this, duration: _gainDuration);
  int? _picked;

  @override
  void dispose() {
    _gain.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PaintDropLayer old) {
    super.didUpdateWidget(old);
    final picked = paintDrops(widget.shownM, widget.rules);
    final last = _picked;
    // 처음 보거나(화면을 다시 열었다) 줄었으면 떠오르는 연출 없이 맞춘다
    if (last != null && picked > last) _gain.forward(from: 0);
    _picked = picked;
  }

  @override
  Widget build(BuildContext context) {
    _picked ??= paintDrops(widget.shownM, widget.rules);
    final spot = widget.spot;
    final size = spot.figureHeight * _dropOfFigure;
    final head = spot.spiritFoot.dy - spot.figureHeight;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _DropPainter(
              foot: spot.spiritFoot,
              ptPerM: spot.groundPtPerM,
              shownM: widget.shownM,
              spacingM: widget.rules.paintDropSpacingM,
              size: size,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _gain,
          builder: (context, _) {
            final t = _gain.value;
            if (!_gain.isAnimating || t <= 0) return const SizedBox.shrink();
            final rise = spot.figureHeight * _gainRise * Curves.easeOut.transform(t);
            return Positioned(
              left: spot.spiritFoot.dx - 60,
              width: 120,
              top: head - size - rise,
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Center(
                  child: Text(
                    '+${widget.rules.paintDropCoinsPerDrop} 럭',
                    key: const ValueKey('paint-drop-gain'),
                    style: context.display(16, color: Palette.ink),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 아직 안 주운 방울 중 화면 안에 든 것을 그린다 (정령 발 줄 위, 오른쪽에서 흘러온다)
class _DropPainter extends CustomPainter {
  _DropPainter({
    required this.foot,
    required this.ptPerM,
    required this.shownM,
    required this.spacingM,
    required this.size,
  });

  final Offset foot;
  final double ptPerM;
  final double shownM;
  final double spacingM;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    if (spacingM <= 0 || ptPerM <= 0) return;
    // 정령 가운데보다 오른쪽(아직 안 닿은 것)부터 화면 오른쪽 끝까지
    var k = (shownM / spacingM).floor() + 1;
    final r = size / 2;
    while (true) {
      final x = foot.dx + (k * spacingM - shownM) * ptPerM;
      if (x - r > box.width) break;
      _drop(canvas, Offset(x, foot.dy - r), r, dropColors[k % dropColors.length]);
      k++;
    }
  }

  void _drop(Canvas canvas, Offset c, double r, Color color) {
    // 땅 그림자, 번진 테, 진한 속, 밝은 점
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, r * 0.95), width: r * 1.4, height: r * 0.35),
      Paint()..color = Palette.ink.withValues(alpha: 0.15),
    );
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawCircle(
      c.translate(0, r * 0.08),
      r * 0.68,
      Paint()..color = color.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      c.translate(-r * 0.25, -r * 0.22),
      r * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      old.shownM != shownM ||
      old.foot != foot ||
      old.ptPerM != ptPerM ||
      old.size != size ||
      old.spacingM != spacingM;
}
