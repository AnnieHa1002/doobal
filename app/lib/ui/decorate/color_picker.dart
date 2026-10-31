import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/color.dart';
import '../common/palette.dart';

/// 직접 고르기의 채도. 색상환은 색조만 고르므로 채도는 이 값으로 고정한다 (가안)
const customSaturation = 0.6;

const _ringSize = 176.0;
const _ringWidth = 30.0;
const _barHeight = 28.0;
const _thumb = 32.0;

/// 직접 고르기: 색조 링(색상환)과 밝기 막대. 밝기 막대는 [minPercent]~[maxPercent]%(HSL) 안에서만 움직인다.
/// 고를 때마다 [onChanged]에 "#RRGGBB"를 알린다. [hex]가 바깥에서 바뀌면(되돌리기 등) 거기서 다시 시작한다
class ColorPickerPanel extends StatefulWidget {
  const ColorPickerPanel({
    super.key,
    required this.hex,
    required this.minPercent,
    required this.maxPercent,
    required this.onChanged,
  });

  final String hex;
  final int minPercent;
  final int maxPercent;
  final ValueChanged<String> onChanged;

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  // 색조(도)와 밝기(0~1)는 손가락을 따라 실수로 들고 있는다. 색(hex)에서 매번 되읽으면
  // 8비트 반올림 오차가 끌 때마다 쌓인다
  late double _hue;
  late double _light;

  /// 마지막으로 바깥에 알린 색. 이것과 다른 hex가 오면 바깥에서 바뀐 것이다
  String? _emitted;

  double get _lo => widget.minPercent / 100;
  double get _hi => widget.maxPercent / 100;

  @override
  void initState() {
    super.initState();
    _readHex();
    // 안쪽 스크롤 아래에서 열려도 바로 보이게 한다 (밑이 보일 만큼만 민다)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void didUpdateWidget(ColorPickerPanel old) {
    super.didUpdateWidget(old);
    if (widget.hex != _emitted) _readHex();
  }

  void _readHex() {
    final c = hslOfArgb(argbFromHex(widget.hex));
    _hue = c.h;
    _light = c.l.clamp(_lo, _hi);
    _emitted = widget.hex;
  }

  void _emit() {
    final hex = hexFromArgb(argbOfHsl(_hue, customSaturation, _light));
    _emitted = hex;
    widget.onChanged(hex);
  }

  void _setHue(double hue) {
    setState(() => _hue = hue % 360);
    _emit();
  }

  void _setLight(double t) {
    setState(() => _light = _lo + (_hi - _lo) * t.clamp(0.0, 1.0));
    _emit();
  }

  /// 링 위의 점 → 색조 (3시 방향이 0도, 시계 방향). 가운데 원 안은 무시한다
  void _onRing(Offset p) {
    final d = p - const Offset(_ringSize / 2, _ringSize / 2);
    if (d.distance < _ringSize / 2 - _ringWidth - 4) return;
    _setHue(math.atan2(d.dy, d.dx) * 180 / math.pi + 360);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(argbFromHex(widget.hex));
    final t = (_light - _lo) / (_hi - _lo);
    return Column(
      key: const ValueKey('picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Semantics(
            label: '색조',
            value: '${_hue.round()}도',
            increasedValue: '${((_hue + 15) % 360).round()}도',
            decreasedValue: '${((_hue - 15) % 360).round()}도',
            onIncrease: () => _setHue(_hue + 15),
            onDecrease: () => _setHue(_hue - 15),
            child: _PointDrag(
              key: const ValueKey('hue-ring'),
              onPoint: _onRing,
              child: CustomPaint(
                size: const Size.square(_ringSize),
                painter: _RingPainter(hue: _hue, color: color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '밝기 ${(_light * 100).round()}%',
          style: const TextStyle(fontSize: 14, color: Palette.ink),
        ),
        const SizedBox(height: 4),
        Semantics(
          label: '밝기',
          value: '${(_light * 100).round()}%',
          increasedValue: '${((_light + 0.1 * (_hi - _lo)).clamp(_lo, _hi) * 100).round()}%',
          decreasedValue: '${((_light - 0.1 * (_hi - _lo)).clamp(_lo, _hi) * 100).round()}%',
          onIncrease: () => _setLight(t + 0.1),
          onDecrease: () => _setLight(t - 0.1),
          child: LayoutBuilder(
            builder: (context, box) => _PointDrag(
              key: const ValueKey('light-bar'),
              onPoint: (p) => _setLight((p.dx - _thumb / 2) / (box.maxWidth - _thumb)),
              child: SizedBox(
                height: _thumb + 4,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BarPainter(hue: _hue, lo: _lo, hi: _hi, t: t, color: color),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 누르고 끄는 동안 손가락 위치(자기 안 좌표)를 [onPoint]로 알린다.
/// EagerGestureRecognizer가 누르는 순간 제스처를 가져가서, 바깥 스크롤이 끌림을 가로채지 못한다
class _PointDrag extends StatelessWidget {
  const _PointDrag({super.key, required this.onPoint, required this.child});

  final ValueChanged<Offset> onPoint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
          EagerGestureRecognizer.new,
          (_) {},
        ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => onPoint(e.localPosition),
        onPointerMove: (e) => onPoint(e.localPosition),
        child: child,
      ),
    );
  }
}

Paint _ink(double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..color = Palette.ink;

/// 색조 링: 둘레에 색조 순서로 칠하고, 고른 색조에 동그라미, 가운데는 지금 고른 색
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.hue, required this.color});

  final double hue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 2;
    final mid = outer - _ringWidth / 2;
    final inner = outer - _ringWidth;

    Color at(double h) => Color(argbOfHsl(h, customSaturation, 0.5));
    canvas.drawCircle(
      c,
      mid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth
        ..shader = SweepGradient(
          colors: [for (var h = 0; h <= 360; h += 30) at(h.toDouble())],
        ).createShader(Rect.fromCircle(center: c, radius: mid)),
    );
    canvas.drawCircle(c, outer, _ink(2.5));
    canvas.drawCircle(c, inner, _ink(2.5));

    canvas.drawCircle(c, inner - 14, Paint()..color = color);
    canvas.drawCircle(c, inner - 14, _ink(2.5));

    final a = hue * math.pi / 180;
    final m = c + Offset(math.cos(a), math.sin(a)) * mid;
    canvas.drawCircle(m, 13, Paint()..color = at(hue));
    canvas.drawCircle(m, 13, _ink(3.5));
    canvas.drawCircle(m, 16, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Palette.paper);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.hue != hue || old.color != color;
}

/// 밝기 막대: 허용 범위([lo]~[hi])의 밝기를 같은 색조·채도로 늘어놓은 띠와 손잡이 ([t] 0~1)
class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.hue,
    required this.lo,
    required this.hi,
    required this.t,
    required this.color,
  });

  final double hue;
  final double lo;
  final double hi;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(_thumb / 2, (size.height - _barHeight) / 2, size.width - _thumb, _barHeight),
      const Radius.circular(_barHeight / 2),
    );
    const steps = 4;
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(colors: [
          for (var i = 0; i <= steps; i++)
            Color(argbOfHsl(hue, customSaturation, lo + (hi - lo) * i / steps)),
        ]).createShader(track.outerRect),
    );
    canvas.drawRRect(track, _ink(2.5));

    final x = _thumb / 2 + (size.width - _thumb) * t;
    final c = Offset(x, size.height / 2);
    canvas.drawCircle(c, _thumb / 2 - 2, Paint()..color = color);
    canvas.drawCircle(c, _thumb / 2 - 2, _ink(3.5));
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.hue != hue || old.lo != lo || old.hi != hi || old.t != t || old.color != color;
}
