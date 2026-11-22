import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/motion_rules.dart';
import '../common/motion.dart';
import '../common/palette.dart';

// 연출 ⑤ 화집 종이 넘김 (T19, config ui.motion.albumFlip, 캔버스 6-1 메모 ‘일기·전체 보기를 바꿀 때·달을 넘길 때’):
// 오른쪽 끝을 축으로 가로 크기 1 → 0 → 1, 가운데에 잉크 그림자. 3D 말림 없음, 그림 크게 보기에는 안 씀

/// 슬리버 묶음([sliver])을 오른쪽 끝(가로 끝)을 축으로 가로 [scaleX]배로 그리고, 그 위에 잉크 [shadow] 진하기 그림자.
/// 넘기는 동안(1배가 아니거나 그림자가 있으면)은 누를 수 없다
class SliverFlip extends SingleChildRenderObjectWidget {
  const SliverFlip({super.key, required this.scaleX, required this.shadow, required Widget sliver})
      : super(child: sliver);

  final double scaleX;
  final double shadow;

  @override
  RenderSliverFlip createRenderObject(BuildContext context) => RenderSliverFlip(scaleX, shadow);

  @override
  void updateRenderObject(BuildContext context, RenderSliverFlip renderObject) => renderObject
    ..scaleX = scaleX
    ..shadow = shadow;
}

class RenderSliverFlip extends RenderProxySliver {
  RenderSliverFlip(this._scaleX, this._shadow);

  double get scaleX => _scaleX;
  double _scaleX;
  set scaleX(double v) {
    if (v == _scaleX) return;
    _scaleX = v;
    markNeedsPaint();
  }

  double get shadow => _shadow;
  double _shadow;
  set shadow(double v) {
    if (v == _shadow) return;
    _shadow = v;
    markNeedsPaint();
  }

  bool get _flipping => _scaleX != 1 || _shadow != 0;

  /// 오른쪽 끝 축 가로 크기 (슬리버 왼쪽 위 기준)
  Matrix4 get _transform {
    final w = constraints.crossAxisExtent;
    return Matrix4.translationValues(w * (1 - _scaleX), 0, 0)..multiply(Matrix4.diagonal3Values(_scaleX, 1, 1));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null || !c.geometry!.visible) {
      layer = null;
      return;
    }
    if (!_flipping) {
      layer = null;
      context.paintChild(c, offset);
      return;
    }
    layer = context.pushTransform(needsCompositing, offset, _transform, (context, offset) {
      context.paintChild(c, offset);
      if (_shadow > 0) {
        context.canvas.drawRect(
          offset & Size(constraints.crossAxisExtent, geometry!.paintExtent),
          Paint()..color = Palette.ink.withValues(alpha: _shadow),
        );
      }
    }, oldLayer: layer is TransformLayer ? layer! as TransformLayer : null);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    if (_flipping) transform.multiply(_transform);
  }

  @override
  bool hitTest(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) =>
      !_flipping && super.hitTest(result, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
}

/// 상자 하나([child])를 오른쪽 끝을 축으로 가로 [scaleX]배, 위에 잉크 [shadow] 그림자
class FlipBox extends StatelessWidget {
  const FlipBox({super.key, required this.scaleX, required this.shadow, required this.child});

  final double scaleX;
  final double shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) => Transform(
        alignment: Alignment.centerRight,
        transform: Matrix4.diagonal3Values(scaleX, 1, 1),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(color: Palette.ink.withValues(alpha: shadow)),
          child: child,
        ),
      );
}

/// 일기 달 머리줄 넘김 (albumFlip.on monthHeader, 가안): 스크롤하다 머리줄이 화면 밖에서 안으로 들어오면 한 번 넘긴다.
/// 화집을 열었을 때(처음 그린 때) 이미 보이는 머리줄은 넘기지 않는다. 움직임 줄이기면 넘기지 않는다
class MonthFlip extends StatefulWidget {
  const MonthFlip({super.key, required this.motion, required this.child});

  final AlbumFlipMotion motion;
  final Widget child;

  @override
  State<MonthFlip> createState() => _MonthFlipState();
}

class _MonthFlipState extends State<MonthFlip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = motionController(this, widget.motion.sec);
  ScrollPosition? _position;

  /// 지난번에 화면 안이었나. 처음 그리기 전에는 null
  bool? _visible;

  /// 스크롤 뒤 자리 재기를 이번 프레임 끝으로 미뤄 두었나
  var _pending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visible = _onScreen();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (p == _position) return;
    _position?.removeListener(_onScroll);
    _position = p?..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MonthFlip old) {
    super.didUpdateWidget(old);
    _c.duration = motionDuration(widget.motion.sec);
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    _c.dispose();
    super.dispose();
  }

  /// 스크롤 알림 때는 아직 새 자리로 배치되기 전이라, 그 프레임의 배치가 끝난 뒤에 잰다
  void _onScroll() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      _check();
    });
  }

  void _check() {
    final was = _visible;
    if (!mounted || was == null) return;
    final now = _onScreen();
    _visible = now;
    if (now && !was && !motionReduced(context)) _c.forward(from: 0);
  }

  /// 이 머리줄이 스크롤 화면 안에 조금이라도 보이는가
  bool _onScreen() {
    final box = context.findRenderObject();
    final view = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || view is! RenderBox || !box.attached || !box.hasSize || !view.hasSize) return false;
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    return top < view.size.height && top + box.size.height > 0;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.motion;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, child) {
        final t = motionTime(_c, m.sec);
        return FlipBox(scaleX: m.scaleXAt(t), shadow: m.shadowAt(t), child: child!);
      },
      child: widget.child,
    );
  }
}
