import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../domain/motion_rules.dart';
import '../common/motion.dart';

/// 정령 600 캔버스(머리 위 y150~발 y440 잣대, 장면이 정령을 놓는 상자)에서 정령 몸이 있는 자리.
/// 짧게 누르기 머리·배 상자(spirit_character: x 200~400·y 135~300, x 230~380·y 300~445)를 합친 것이다.
/// 이 안에서 시작한 좌우 끌기만 쓰다듬기로 받고, 그 밖은 장면 밀기로 둔다 (정령 상자가 정령보다 훨씬 넓다)
const spiritBodyBox = Rect.fromLTRB(200, 135, 400, 445);

/// 정령 600 캔버스에서 발 디딤점 (300, 440). 기울기는 이 점을 축으로
const _canvas = 600.0;
const spiritFootAlignment = Alignment(0, 440 / (_canvas / 2) - 1);

/// 방향이 바뀐 것으로 볼 되돌아간 거리 (pt, 손 떨림 거르기, 화면 구성값)
const _rubJitterPt = 4.0;

/// 쉼터 정령 쓰다듬기 (연출 ②, 16장 11/20 Q008, config ui.motion.restPet, 정령 계약 4장, 캔버스 2-2 메모).
/// 정령 몸 위에서 좌우로 문질러 [RestPetMotion.rubFlipsWithinSec]초 안에 방향이 [RestPetMotion.rubFlips]번 바뀌면
/// [onPet](문지르는 쪽)을 부르고(쉼터가 행복 표정을 [RestPetMotion.exprSec]초 띄운다) 정령을 문지르는 쪽으로
/// [RestPetMotion.tiltDeg]도 기울였다 [RestPetMotion.returnSec]초에 되돌린다 (발을 축으로). 계속 문지르면 다시.
/// 짧게 누르기(머리·배·연타)와 길게 누르기는 안의 정령이 그대로 받는다 (tapRules unchanged): 손가락이 가로로
/// 움직여야(끌기) 이쪽이 이긴다. 정령 몸 위에서 시작한 좌우 끌기는 장면을 밀지 않는다(누르기 순서 정령 > 장면 밀기).
/// 움직임 줄이기면 기울이지 않고 표정만. [rules]가 없으면 아무것도 안 한다.
/// [child]는 600 캔버스 정사각 상자를 꽉 채운 정령이다
class RestPet extends StatefulWidget {
  const RestPet({super.key, required this.rules, required this.onPet, required this.child});

  final RestPetMotion? rules;
  final ValueChanged<int> onPet;
  final Widget child;

  @override
  State<RestPet> createState() => _RestPetState();
}

class _RestPetState extends State<RestPet> with SingleTickerProviderStateMixin {
  late final AnimationController _tilt = motionController(this, widget.rules?.returnSec ?? 0.3);
  RubCounter? _rub;
  var _side = 1;

  /// 끌기 시작한 뒤 시간 (이벤트 시각이 없을 때)
  final _watch = Stopwatch();
  Duration? _startStamp;

  @override
  void didUpdateWidget(RestPet old) {
    super.didUpdateWidget(old);
    if (old.rules != widget.rules) {
      _rub = null;
      _tilt.duration = motionDuration(widget.rules?.returnSec ?? 0.3);
    }
  }

  @override
  void dispose() {
    _tilt.dispose();
    super.dispose();
  }

  RubCounter? get _counter {
    final r = widget.rules;
    if (r == null) return null;
    return _rub ??= RubCounter(r, jitterPt: _rubJitterPt);
  }

  double _sec(Duration? stamp) {
    if (stamp != null) {
      _startStamp ??= stamp;
      return (stamp - _startStamp!).inMicroseconds / Duration.microsecondsPerSecond;
    }
    return _watch.elapsedMicroseconds / Duration.microsecondsPerSecond;
  }

  void _onStart(DragStartDetails d) {
    _counter?.reset();
    _startStamp = d.sourceTimeStamp;
    _watch
      ..reset()
      ..start();
  }

  void _onUpdate(DragUpdateDetails d) {
    final side = _counter?.move(d.delta.dx, _sec(d.sourceTimeStamp));
    if (side == null) return;
    widget.onPet(side);
    if (motionReduced(context)) return;
    // 기울이는 중에 또 쓰다듬으면 처음부터 (repeat skipToEndThenRestart)
    setState(() => _side = side);
    _tilt.forward(from: 0);
  }

  void _onEndDrag(DragEndDetails _) => _onEnd();

  void _onEnd() {
    _counter?.reset();
    _watch.stop();
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    if (rules == null) return widget.child;
    final tilted = AnimatedBuilder(
      animation: _tilt,
      child: widget.child,
      builder: (context, child) {
        final deg = rules.tiltAt(motionTime(_tilt, rules.returnSec), _side);
        return Transform.rotate(
          key: const ValueKey('rest-pet-tilt'),
          angle: deg * math.pi / 180,
          alignment: spiritFootAlignment,
          child: child,
        );
      },
    );
    return LayoutBuilder(builder: (context, box) {
      final k = math.min(box.maxWidth, box.maxHeight) / _canvas;
      final body = Rect.fromLTRB(
        spiritBodyBox.left * k,
        spiritBodyBox.top * k,
        spiritBodyBox.right * k,
        spiritBodyBox.bottom * k,
      );
      return RawGestureDetector(
        key: const ValueKey('rest-pet'),
        behavior: HitTestBehavior.translucent,
        gestures: {
          _BodyDrag: GestureRecognizerFactoryWithHandlers<_BodyDrag>(
            () => _BodyDrag(body),
            (g) => g
              ..body = body
              ..dragStartBehavior = DragStartBehavior.down
              ..onStart = _onStart
              ..onUpdate = _onUpdate
              ..onEnd = _onEndDrag
              ..onCancel = _onEnd,
          ),
        },
        child: tilted,
      );
    });
  }
}

/// 정령 몸([body], 이 상자 안 자리) 위에서 시작한 좌우 끌기만 받는다
class _BodyDrag extends HorizontalDragGestureRecognizer {
  _BodyDrag(this.body);

  Rect body;

  @override
  bool isPointerAllowed(PointerEvent event) => body.contains(event.localPosition) && super.isPointerAllowed(event);
}
