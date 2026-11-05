import 'package:flutter/material.dart';

import '../../domain/rest_camera.dart';

/// 쉼터 장면을 끌어 밀고 두 손가락으로 확대한다. 손을 떼면 [RestGeometry.settle]이 정한 자리로 부드럽게 간다.
/// [camera] 값만 바꾸므로 그림은 다시 그리지 않는다
class RestGestures extends StatefulWidget {
  const RestGestures({super.key, required this.stage, required this.camera, required this.child});

  final RestGeometry stage;
  final ValueNotifier<RestCamera> camera;
  final Widget child;

  @override
  State<RestGestures> createState() => _RestGesturesState();
}

class _RestGesturesState extends State<RestGestures> with SingleTickerProviderStateMixin {
  late final AnimationController _settle;
  RestCamera _from = const RestCamera();
  RestCamera _to = const RestCamera();

  /// 손가락을 댄 때의 자리와 초점
  RestCamera _start = const RestCamera();
  double _startFocalX = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.stage.rules.snapSec * 1000).round()),
    )..addListener(_onSettle);
  }

  void _onSettle() {
    final t = Curves.easeOut.transform(_settle.value);
    widget.camera.value = RestCamera(
      x: _from.x + (_to.x - _from.x) * t,
      zoom: _from.zoom + (_to.zoom - _from.zoom) * t,
    );
  }

  void _onStart(ScaleStartDetails d) {
    _settle.stop();
    _start = widget.stage.clamp(widget.camera.value);
    _startFocalX = d.localFocalPoint.dx;
  }

  void _onUpdate(ScaleUpdateDetails d) {
    widget.camera.value = widget.stage.gesture(
      _start,
      scale: d.scale,
      fromX: _startFocalX,
      toX: d.localFocalPoint.dx,
    );
  }

  void _onEnd(ScaleEndDetails d) {
    // 손가락이 남아 있으면 곧 다시 시작한다
    if (d.pointerCount > 0) return;
    _from = widget.camera.value;
    _to = widget.stage.settle(_from);
    if (_to == _from) return;
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _onStart,
      onScaleUpdate: _onUpdate,
      onScaleEnd: _onEnd,
      child: widget.child,
    );
  }
}
