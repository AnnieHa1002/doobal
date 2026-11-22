import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/motion_rules.dart';
import '../common/motion.dart';

/// 꾸밈 물품 누르면 흔들림 (연출 ②, 16장 11/20 Q008, config ui.motion.decorWiggle, 캔버스 2-2 메모).
/// 한 번에 물품 하나만 흔든다: 흔드는 중에 다른(또는 같은) 물품을 누르면 앞 것은 끝 상태(0도)로 두고 처음부터
/// (repeat skipToEndThenRestart). 꾸미기 중(서랍이 열렸거나 물품을 집음)에는 쉼터가 [start]를 부르지 않고 [stop]한다.
/// 기울기는 발(땅에 닿는 자리, groundAt)이 축이다 ([DecorWiggle])
class DecorWiggler {
  DecorWiggler({required TickerProvider vsync, DecorWiggleMotion? rules})
      : _rules = rules,
        controller = motionController(vsync, rules?.sec ?? 1);

  final AnimationController controller;

  /// 흔들기 값 (규칙을 늦게 읽는 화면이 나중에 넣는다). null이면 흔들지 않는다
  DecorWiggleMotion? get rules => _rules;
  DecorWiggleMotion? _rules;
  set rules(DecorWiggleMotion? r) {
    if (r == _rules) return;
    _rules = r;
    if (r != null) controller.duration = motionDuration(r.sec);
  }

  /// 지금 흔드는 물품 id. 없으면 null
  String? get id => _id;
  String? _id;

  /// 물품 [id]를 흔든다. 움직임 줄이기([still])거나 규칙이 없으면 흔들지 않는다 (끝 상태 = 그대로)
  void start(String id, {bool still = false}) {
    if (rules == null || still) return;
    _id = id;
    controller.forward(from: 0);
  }

  /// 흔들기를 멈추고 끝 상태로
  void stop() {
    _id = null;
    controller.value = 1;
  }

  /// 물품 [id]의 지금 기울기(라디안). 흔드는 물품이 아니면 0
  double angleOf(String id) {
    final r = rules;
    if (r == null || id != _id) return 0;
    return r.angleAt(motionTime(controller, r.sec)) * math.pi / 180;
  }

  void dispose() => controller.dispose();
}

/// 물품 그림 [child]를 [wiggler]가 흔드는 차례면 [pivot](이 상자 안 발 자리)을 축으로 기울인다
class DecorWiggle extends StatelessWidget {
  const DecorWiggle({super.key, required this.wiggler, required this.id, required this.pivot, required this.child});

  final DecorWiggler wiggler;
  final String id;
  final Offset pivot;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: wiggler.controller,
        child: child,
        builder: (context, child) => Transform.rotate(
          angle: wiggler.angleOf(id),
          alignment: Alignment.topLeft,
          origin: pivot,
          child: child,
        ),
      );
}
