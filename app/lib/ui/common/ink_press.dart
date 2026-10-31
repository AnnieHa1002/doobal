import 'package:flutter/material.dart';

import 'palette.dart';

const _border = 2.5;
const _shadow = 4.0;
const _pressDuration = Duration(milliseconds: 80);

/// 잉크 테두리 + 아래로 4pt 그림자. 누르면 그림자가 0이 되고 4pt 내려간다 (0.08초).
/// 높이는 그림자 자리까지 [height] + 4이고, 안의 글자가 커지면(글자 크기 설정) 그만큼 늘어난다.
/// [onPressed]가 null이면 눌리지 않는 비활성
class InkPress extends StatefulWidget {
  const InkPress({
    super.key,
    required this.onPressed,
    required this.fill,
    required this.child,
    required this.height,
    this.width,
    this.radius = 12,
    this.circle = false,
  });

  final VoidCallback? onPressed;
  final Color fill;
  final Widget child;

  /// 이 높이가 최소다 (그림자 자리는 따로 4pt)
  final double height;

  /// null이면 부모 너비를 꽉 채운다
  final double? width;
  final double radius;
  final bool circle;

  @override
  State<InkPress> createState() => _InkPressState();
}

class _InkPressState extends State<InkPress> {
  var _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  void didUpdateWidget(InkPress old) {
    super.didUpdateWidget(old);
    // 눌린 채로 비활성이 되면 풀어 준다
    if (widget.onPressed == null) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onPressed,
        child: SizedBox(
          width: widget.width,
          // 눌리면 4pt 내려간다. 위아래 합이 늘 4pt라 전체 높이는 그대로다
          child: AnimatedPadding(
            duration: _pressDuration,
            padding: EdgeInsets.only(top: _pressed ? _shadow : 0, bottom: _pressed ? 0 : _shadow),
            child: AnimatedContainer(
              duration: _pressDuration,
              width: widget.width ?? double.infinity,
              constraints: BoxConstraints(minHeight: widget.height),
              decoration: BoxDecoration(
                color: widget.fill,
                shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
                border: Border.all(color: Palette.ink, width: _border),
                boxShadow: [
                  BoxShadow(
                    color: Palette.ink,
                    offset: Offset(0, _pressed ? 0 : _shadow),
                  ),
                ],
              ),
              // 안이 최소 높이보다 작으면 가운데, 크면 안이 높이를 정한다
              child: Center(heightFactor: 1, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
