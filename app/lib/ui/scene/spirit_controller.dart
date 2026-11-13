import 'dart:math' as math;
import 'dart:ui';

import 'package:rive/rive.dart' as rive;

import '../../domain/rules.dart';
import '../../domain/spirit_look.dart';
import '../../domain/tap_mood.dart';
import '../../domain/unified_wardrobe.dart';

/// 게임 호출 이름을 유지하고, 확정된 통합 파일의 자세·반응으로 대응한다.
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

final class SpiritController extends rive.RiveWidgetController {
  SpiritController(super.file)
    : super(
        stateMachineSelector: rive.StateMachineNamed('WardrobeController'),
      ) {
    instance = dataBind(rive.DataBind.auto());
    _pose = instance.number('poseChoice')!;
  }
  late final rive.ViewModelInstance instance;
  late final rive.ViewModelInstanceNumber _pose;
  SpiritMotion _motion = SpiritMotion.idle, _baseline = SpiritMotion.idle;
  int _direction = 0, _baselineDirection = 0, _expression = 0;
  bool _head = false, _belly = false, _cape = false;
  double _actionLeft = 0;
  Rules? tapRules;
  DateTime Function() clock = DateTime.now;
  final _taps = <DateTime>[];
  SpiritMotion get motion => _motion;
  int get direction => _direction;
  int get expression => _expression;
  bool get headPressed => _head;
  bool get bellyPressed => _belly;
  bool get capeEnabled => _cape;
  int get poseChoice => _pose.value.round();
  void setCape(bool enabled) {
    _cape = enabled;
  }

  void wear(SpiritLook look) {
    for (final entry in {
      'eye': look.eye + 1,
      'brow': look.brow,
      'nose': look.nose == 7 ? 0 : look.nose + 1,
      'mouth': look.mouth + 1,
    }.entries) {
      instance.number(entry.key)!.value = entry.value.toDouble();
    }

    for (final slot in [
      'hat',
      'face',
      'cloth',
      'shoe',
      'hand',
      'bag',
      'pet',
      'float',
    ]) {
      var choice = look.choices[slot] ?? 0;
      // 이전 디버그 미리보기 호출도 같은 확정 소품으로 대응한다.
      if (look.choices.isEmpty) {
        if (slot == 'bag')
          choice = look.bag == 1
              ? 1
              : look.bag == 2
              ? 5
              : 0;
        if (slot == 'cloth')
          choice = look.outfit == 1
              ? 4
              : look.outfit == 2
              ? 1
              : _cape
              ? 1
              : 0;
        if (slot == 'pet') choice = look.companion == 1 ? 5 : 0;
      }
      instance.number('${slot}Choice')!.value = choice.toDouble();
    }
    instance.color('bodyColor')!.value = Color(look.bodyArgb ?? 0xfff2dfc6);
    for (final p in unifiedProps) {
      instance.color(p.colorField)!.value = Color(
        look.colors[p.colorField] ?? p.argb,
      );
    }
    scheduleRepaint();
  }

  int _poseFor(SpiritMotion m, int direction) => switch (m) {
    SpiritMotion.sit => direction == 1 ? 3 : 2,
    SpiritMotion.lie || SpiritMotion.sleep => 4,
    SpiritMotion.walk || SpiritMotion.run => 6,
    _ =>
      direction == 2
          ? 5
          : direction == 1
          ? 1
          : 0,
  };
  void _restore() {
    _motion = _baseline;
    _direction = _baselineDirection;
    _pose.value = _poseFor(_baseline, _baselineDirection).toDouble();
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
    if (_actionLeft <= 0) _restore();
  }

  void _fire(String trigger, double seconds) {
    _pose.value = 0;
    // 같은 프레임에 자세 복귀와 새 반응이 연속 호출되어도 이전 입력을 먼저 소비한다.
    stateMachine.advanceAndApply(0);
    instance.trigger(trigger)!.trigger();
    stateMachine.advanceAndApply(0);
    _actionLeft = seconds;
    scheduleRepaint();
  }

  void play(SpiritMotion value, {int? direction}) {
    _head = false;
    _belly = false;
    _actionLeft = 0;
    _direction =
        direction ??
        (value == SpiritMotion.walk || value == SpiritMotion.run ? 1 : 0);
    _motion = value;
    if (value == SpiritMotion.wave) {
      _fire('greet', 2.4);
      return;
    }
    if (value == SpiritMotion.jump || value == SpiritMotion.laugh) {
      _fire('joy', 1.8);
      return;
    }
    instance.trigger('resetMotion')!.trigger();
    stateMachine.advanceAndApply(0);
    // 확정본에 없는 넘어짐은 기본 부유로 복귀한다.
    _baseline = value == SpiritMotion.fall ? SpiritMotion.idle : value;
    _baselineDirection = _direction;
    _restore();
  }

  void setExpression(int value, {bool force = false}) {
    if (!force && value == _expression) return;
    _expression = value.clamp(0, 6);
    if (value == 1) {
      _fire('joy', 1.8);
    } else if (value == 2) {
      _fire('greet', 2.4);
    } else if (value == 3) {
      _fire('tapBelly', 1.2);
    } else if (value == 6) {
      _fire('tapHead', 1.2);
    } else if (value == 5) {
      _fire('angry', .6);
    } else if (value == 4) {
      instance.trigger('resetMotion')!.trigger();
      stateMachine.advanceAndApply(0);
      _actionLeft = 0;
      _pose.value = 4;
      scheduleRepaint();
    } else {
      instance.trigger('resetMotion')!.trigger();
      stateMachine.advanceAndApply(0);
      _actionLeft = 0;
      _restore();
    }
  }

  /// 시선은 눈 파츠 안의 작은 이동에만 연결한다. NaN·무한대는 중앙으로 복귀한다.
  void setLook(double x, double y) {
    instance.number('lookX')!.value = x.isFinite ? x.clamp(-1.0, 1.0) : 0;
    instance.number('lookY')!.value = y.isFinite ? y.clamp(-1.0, 1.0) : 0;
    scheduleRepaint();
  }

  void press(SpiritPress region) {
    _head = region == SpiritPress.head;
    _belly = !_head;
    _fire(_head ? 'tapHead' : 'tapBelly', 1.2);
    _countTap();
  }

  void release() {
    _head = false;
    _belly = false;
  }

  void _countTap() {
    final rules = tapRules;
    if (rules == null) return;
    final now = clock();
    _taps.add(now);
    final windowMs = (rules.tapReaction.angryWindowSec * 1000).round();
    _taps.removeWhere((t) => now.difference(t).inMilliseconds > windowMs);
    if (tapMood(_taps, now, rules) == TapMood.angry) {
      _taps.clear();
      _fire('angry', .6);
    }
  }

  @override
  bool advance(double elapsedSeconds) {
    final dt = elapsedSeconds.isFinite ? math.max(0.0, elapsedSeconds) : 0.0;
    final active = super.advance(dt);
    if (_actionLeft > 0) {
      _actionLeft = math.max(0, _actionLeft - dt);
      if (_actionLeft == 0) {
        release();
        _restore();
      }
    }
    return active;
  }

  @override
  void dispose() {
    super.dispose();
    instance.dispose();
  }
}
