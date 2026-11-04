import 'dart:math' as math;

import 'package:rive/rive.dart' as rive;

import '../../domain/spirit_look.dart';

enum SpiritMotion {
  idle(0),
  walk(1),
  sit(2),
  lie(3),
  jump(4),
  run(5),
  sleep(6),
  wave(7),
  fall(8),
  laugh(9);

  const SpiritMotion(this.value);
  final double value;
  bool get oneShot =>
      this == jump || this == wave || this == fall || this == laugh;
}

enum SpiritPress { head, belly }

/// 승인한 정령 벡터의 동작·터치 제어. 시간은 화면이 재생될 때만 흐른다.
final class SpiritController extends rive.RiveWidgetController {
  SpiritController(super.file) {
    instance = dataBind(rive.DataBind.auto());
    _motion = instance.number('motion')!;
    _direction = instance.number('direction')!;
    _expression = instance.number('expression')!;
    _head = instance.boolean('headPressed')!;
    _belly = instance.boolean('bellyPressed')!;
  }
  late final rive.ViewModelInstance instance;
  late final rive.ViewModelInstanceNumber _motion, _direction, _expression;
  late final rive.ViewModelInstanceBoolean _head, _belly;
  SpiritMotion _baseline = SpiritMotion.idle;
  int _baselineDirection = 0;
  int _chosenExpression = 0;
  bool _action = false, _wasPressed = false;
  double _resumeIn = 0;
  SpiritMotion get motion =>
      SpiritMotion.values[_motion.value.round().clamp(0, 9)];
  bool get headPressed => _head.value;
  bool get bellyPressed => _belly.value;
  int get direction => _direction.value.round();
  int get expression => _expression.value.round();
  bool get capeEnabled => instance.boolean('cape')!.value;
  void setCape(bool enabled) {
    instance.boolean('cape')!.value = enabled;
    scheduleRepaint();
  }

  /// 고른 얼굴과 Rive에 붙은 소품을 입힌다. 옷은 [setCape]가 켜져 있어도 outfit이 0이 아니면 outfit이 먼저다
  void wear(SpiritLook look) {
    instance.number('eyeStyle')!.value = look.eye.toDouble();
    instance.number('browStyle')!.value = look.brow.toDouble();
    instance.number('noseStyle')!.value = look.nose.toDouble();
    instance.number('mouthStyle')!.value = look.mouth.toDouble();
    instance.number('bagStyle')!.value = look.bag.toDouble();
    instance.number('outfitStyle')!.value = look.outfit.toDouble();
    instance.number('companionStyle')!.value = look.companion.toDouble();
    scheduleRepaint();
  }

  void setScene({
    required double speed,
    required bool sitting,
    bool boat = false,
  }) {
    _baseline = boat
        ? SpiritMotion.idle
        : sitting
        ? SpiritMotion.sit
        : speed >= 1.5
        ? SpiritMotion.run
        : speed > 0
        ? SpiritMotion.walk
        : SpiritMotion.idle;
    _baselineDirection =
        _baseline == SpiritMotion.walk || _baseline == SpiritMotion.run ? 1 : 0;
    if (!_action &&
        !_wasPressed &&
        _resumeIn <= 0 &&
        !headPressed &&
        !bellyPressed) {
      _restore();
    }
  }

  void _restore() {
    _motion.value = _baseline.value;
    _direction.value = _baselineDirection.toDouble();
    _expression.value = _chosenExpression.toDouble();
    scheduleRepaint();
  }

  void play(SpiritMotion value, {int? direction}) {
    release();
    _resumeIn = 0;
    _wasPressed = false;
    _action = value.oneShot;
    if (!value.oneShot) {
      _baseline = value;
      _baselineDirection =
          direction ??
          (value == SpiritMotion.walk || value == SpiritMotion.run ? 1 : 0);
    }
    _motion.value = value.value;
    _direction.value =
        (direction ??
                (value == SpiritMotion.walk ||
                        value == SpiritMotion.run ||
                        value == SpiritMotion.lie
                    ? 1
                    : 0))
            .toDouble();
    _expression.value = value == SpiritMotion.laugh
        ? 1
        : value == SpiritMotion.fall
        ? 3
        : _chosenExpression.toDouble();
    scheduleRepaint();
  }

  void setExpression(int value) {
    _chosenExpression = value.clamp(0, 5);
    if (!_wasPressed && !_action) {
      _expression.value = _chosenExpression.toDouble();
    }
    scheduleRepaint();
  }

  void setLook(double x, double y) {
    instance.number('lookX')!.value = x.isFinite ? x.clamp(-1, 1) : 0;
    instance.number('lookY')!.value = y.isFinite ? y.clamp(-1, 1) : 0;
    scheduleRepaint();
  }

  void press(SpiritPress region) {
    if (motion == SpiritMotion.fall) return;
    _head.value = region == SpiritPress.head;
    _belly.value = region == SpiritPress.belly;
    scheduleRepaint();
  }

  void release() {
    _head.value = false;
    _belly.value = false;
    scheduleRepaint();
  }

  @override
  bool advance(double elapsedSeconds) {
    final dt = elapsedSeconds.isFinite ? math.max(0.0, elapsedSeconds) : 0.0;
    super.advance(dt);
    if (headPressed && bellyPressed) _belly.value = false;
    final pressed = headPressed || bellyPressed;
    if (pressed && !_wasPressed) {
      _action = false;
      _resumeIn = 0;
      _motion.value = _baseline == SpiritMotion.sit ? 2 : 0;
      _direction.value = 0;
      _expression.value = headPressed ? 1 : 3;
    } else if (!pressed && _wasPressed) {
      _resumeIn = .60;
      _expression.value = _chosenExpression.toDouble();
    }
    _wasPressed = pressed;
    if (!pressed && _resumeIn > 0) {
      _resumeIn = math.max(0, _resumeIn - dt);
      if (_resumeIn == 0) _restore();
    }
    if (_action && _motion.value == 0) {
      _action = false;
      _restore();
    }
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    instance.dispose();
  }
}
