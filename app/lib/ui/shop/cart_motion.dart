import 'package:flutter/material.dart';

import '../../domain/motion_rules.dart';
import '../common/item_cell.dart' show DashedBoxPainter;
import '../common/motion.dart';
import '../common/palette.dart';

// 수레 칸 연출 (연출 ③, T19, 16장 11/20 Q008, config ui.motion.cartSlot, 캔버스 8-1 메모):
// 새 칸이 열리면 자물쇠가 풀리며 물건이 선반에 톡, 산 물건은 위로 떠올라 사라지고 SOLD 도장이 찍힌다.
// 둘 다 [play]가 true로 처음 그려질 때 한 번만 돈다. 움직임 줄이기면 끝 상태만 (자물쇠 없이 물건, 도장만).
// 팔린 칸은 연출 중에도 뒤에도 누름이 없다 (그림은 IgnorePointer, 칸에 onTap 없음)

/// 칸 그림 상자 (ItemCell 84pt, 그림은 아래 5pt에 가운데)
const _cellBox = 84.0;
const _artBottom = 5.0;

/// 도장 자리 (ItemCell stamp: 상자 왼쪽 위 14pt)
const _stampInset = 14.0;

/// 새로 열린 칸의 그림 [child]: 자물쇠(점선 상자 + 자물쇠)가 흐려진 뒤 물건이 위에서 떨어진다
class CartUnlockArt extends StatefulWidget {
  const CartUnlockArt({super.key, required this.motion, required this.play, required this.child});

  final CartSlotMotion? motion;
  final bool play;
  final Widget child;

  @override
  State<CartUnlockArt> createState() => _CartUnlockArtState();
}

class _CartUnlockArtState extends State<CartUnlockArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = motionController(this, widget.motion?.unlockSec ?? 1);
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.play && widget.motion != null && !motionReduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.motion;
    if (m == null) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final f = m.unlockAt(motionTime(_c, m.unlockSec));
        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            if (f.lockOpacity > 0)
              Positioned.fill(
                child: Opacity(
                  key: const ValueKey('cart-unlock-lock'),
                  opacity: f.lockOpacity,
                  child: const CustomPaint(
                    painter: DashedBoxPainter(),
                    child: Center(child: Icon(Icons.lock_outline, size: 18, color: Palette.subInk)),
                  ),
                ),
              ),
            Visibility(
              visible: f.itemShown,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Transform.translate(
                key: const ValueKey('cart-unlock-item'),
                offset: Offset(0, f.itemDy),
                child: Transform.scale(scale: f.itemScale, alignment: Alignment.bottomCenter, child: child),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 팔린 칸의 도장 자리 (ItemCell stamp): 물건 그림 [art]가 떠오르며 사라진 뒤 [stamp]가 크게서 작게 찍힌다.
/// 그림은 도장 상자 밖(칸 그림 자리)에 그린다
class CartSoldStamp extends StatefulWidget {
  const CartSoldStamp({
    super.key,
    required this.motion,
    required this.play,
    required this.stamp,
    required this.art,
    required this.size,
  });

  final CartSlotMotion? motion;
  final bool play;
  final Widget stamp;
  final Widget art;

  /// 도장 상자 크기 (지름)
  final double size;

  @override
  State<CartSoldStamp> createState() => _CartSoldStampState();
}

class _CartSoldStampState extends State<CartSoldStamp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = motionController(this, widget.motion?.soldSec ?? 1);
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.play && widget.motion != null && !motionReduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.motion;
    final d = widget.size;
    if (m == null) return SizedBox(width: d, height: d, child: widget.stamp);
    // 도장 상자(칸 그림 상자 왼쪽 위 14pt) 안에서 본 칸 그림 자리: 칸 상자 가로 가운데, 그림 아래 끝은 칸 위에서 84 − 5pt
    final artBottom = d - (_cellBox - _artBottom - _stampInset);
    final artRight = -(_cellBox - _stampInset - d);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final f = m.soldAt(motionTime(_c, m.soldSec));
        return SizedBox(
          width: d,
          height: d,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (f.itemOpacity > 0)
                Positioned(
                  left: -_stampInset,
                  right: artRight,
                  bottom: artBottom,
                  child: IgnorePointer(
                    child: Opacity(
                      key: const ValueKey('cart-sold-item'),
                      opacity: f.itemOpacity,
                      child: Transform.translate(
                        offset: Offset(0, f.itemDy),
                        child: Align(alignment: Alignment.bottomCenter, heightFactor: 1, child: widget.art),
                      ),
                    ),
                  ),
                ),
              if (f.stampShown)
                Positioned.fill(
                  child: Transform.scale(
                    key: const ValueKey('cart-sold-stamp-scale'),
                    scale: f.stampScale,
                    child: widget.stamp,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
