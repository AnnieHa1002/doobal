import 'dart:math' as math;
import 'dart:ui';

import 'package:rive/rive.dart' as rive;

import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
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

/// 머리·배 눌림 반응 시간(초)과 트리거마다 반응 시간 (riv 클립 길이에 맞춘 값, v25 연결 때부터)
const _pressSec = 1.2;
const _triggerSec = {'greet': 2.4, 'joy': 1.8, 'tapHead': _pressSec, 'tapBelly': _pressSec, 'angry': .6};

final class SpiritController extends rive.RiveWidgetController {
  SpiritController(super.file)
    : super(
        stateMachineSelector: rive.StateMachineNamed('WardrobeController'),
      ) {
    instance = dataBind(rive.DataBind.auto());
    _pose = instance.number('poseChoice')!;
    _expr = instance.number('expr');
  }
  late final rive.ViewModelInstance instance;
  late final rive.ViewModelInstanceNumber _pose;

  /// 표정 입력 expr (0 기본·1 행복·2 놀람·3 울먹임·4 졸림·5 화남, 정령 계약 2·4장). riv에 없으면 null
  late final rive.ViewModelInstanceNumber? _expr;
  SpiritMotion _motion = SpiritMotion.idle, _baseline = SpiritMotion.idle;
  int _direction = 0, _baselineDirection = 0;
  bool _head = false, _belly = false, _cape = false;
  double _actionLeft = 0;

  /// 화면이 정한 자세 (config character.rive.screens·restSwap). null이면 장면(속도·앉기)이 정한다
  int? _fixedPose;

  /// 늘 두는 표정([setBaseExpression])과 지금 표정, 잠깐 표정([cue])이 남은 시간
  int _baseExpr = 0, _exprNow = 0;
  double _exprLeft = 0;

  /// 연타 화남 표정이 보이는 중
  bool _angry = false;
  Rules? tapRules;

  /// 누르기 행복·연타 화남의 표정 (palette customPartsV33 tap·rapidTap). 없으면 동작만
  SpiritCues? cues;
  DateTime Function() clock = DateTime.now;
  final _taps = <DateTime>[];
  SpiritMotion get motion => _motion;
  int get direction => _direction;

  /// 지금 Rive expr 값
  int get expression => _exprNow;
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
        if (slot == 'bag') {
          choice = look.bag == 1
              ? 1
              : look.bag == 2
              ? 5
              : 0;
        }
        if (slot == 'cloth') {
          choice = look.outfit == 1
              ? 4
              : look.outfit == 2
              ? 1
              : _cape
              ? 1
              : 0;
        }
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
    _pose.value = (_fixedPose ?? _poseFor(_baseline, _baselineDirection)).toDouble();
    scheduleRepaint();
  }

  /// 화면이 정한 자세 번호(poseChoice)를 늘 둔다. null이면 장면(속도·앉기)이 정한 자세로.
  /// 반응(누르기·기쁨) 중이면 반응이 끝난 뒤 이 자세로 돌아간다
  void setPose(int? choice) {
    if (choice == _fixedPose) return;
    _fixedPose = choice;
    if (_actionLeft <= 0) _restore();
  }

  void _setExpr(int value) {
    _exprNow = value;
    _expr?.value = value.toDouble();
    scheduleRepaint();
  }

  /// 늘 둘 표정 (밤 쉼터 졸림 등, 끝낼 때 0). 잠깐 표정이 보이는 중이면 그것이 끝난 뒤 바뀐다
  void setBaseExpression(int value) {
    _baseExpr = value;
    if (_exprLeft <= 0) _setExpr(value);
  }

  /// 표정 신호 (도착·만남·새 소품 …, 정령 계약 4장): 트리거가 있으면 울리고, 표정을 holdSec 동안 둔 뒤
  /// 늘 두는 표정으로 돌아간다. holdSec이 없으면 늘 두는 표정이 된다
  void cue(SpiritCue c) {
    if (c.trigger case final t?) _fire(t, _triggerSec[t] ?? _pressSec);
    _angry = false;
    final hold = c.holdSec;
    if (hold == null) {
      _exprLeft = 0;
      setBaseExpression(c.expr);
      return;
    }
    _setExpr(c.expr);
    _exprLeft = hold;
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
    _fixedPose = null;
    _direction =
        direction ??
        (value == SpiritMotion.walk || value == SpiritMotion.run ? 1 : 0);
    _motion = value;
    if (value == SpiritMotion.wave) {
      _fire('greet', _triggerSec['greet']!);
      return;
    }
    if (value == SpiritMotion.jump || value == SpiritMotion.laugh) {
      _fire('joy', _triggerSec['joy']!);
      return;
    }
    instance.trigger('resetMotion')!.trigger();
    stateMachine.advanceAndApply(0);
    // 확정본에 없는 넘어짐은 기본 부유로 복귀한다.
    _baseline = value == SpiritMotion.fall ? SpiritMotion.idle : value;
    _baselineDirection = _direction;
    _restore();
  }

  /// 시선은 눈 파츠 안의 작은 이동에만 연결한다. NaN·무한대는 중앙으로 복귀한다.
  /// v32·v33(16장 11/13)에는 시선 입력이 없어서, 파일에 없으면 아무것도 하지 않는다
  void setLook(double x, double y) {
    final lookX = instance.number('lookX');
    final lookY = instance.number('lookY');
    if (lookX == null || lookY == null) return;
    lookX.value = x.isFinite ? x.clamp(-1.0, 1.0) : 0;
    lookY.value = y.isFinite ? y.clamp(-1.0, 1.0) : 0;
    scheduleRepaint();
  }

  void press(SpiritPress region) {
    _head = region == SpiritPress.head;
    _belly = !_head;
    _fire(_head ? 'tapHead' : 'tapBelly', _pressSec);
    // 한두 번 누르기는 행복 (config tapReaction, palette tap). 화난 동안 누르면 화남 그대로
    if (cues?.of('tap') case final c? when !_angry) {
      _setExpr(c.expr);
      _exprLeft = c.holdSec ?? 0;
    }
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
      // 화남 표정은 config tapReaction.angry.holdSec 동안 (palette rapidTap)
      if (cues?.of('rapidTap') case final c?) {
        _setExpr(c.expr);
        _exprLeft = rules.tapReaction.angryHoldSec;
        _angry = true;
      }
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
    if (_exprLeft > 0) {
      _exprLeft = math.max(0, _exprLeft - dt);
      if (_exprLeft == 0) {
        _angry = false;
        _setExpr(_baseExpr);
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
