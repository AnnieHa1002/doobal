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
  /// 아트보드 `Spirit`·상태 머신 `WardrobeController`·뷰 모델 `WardrobeColors`를 이름으로 묶는다 (config character.rive,
  /// 정령 계약 v0.11). rive 0.15는 만들 때 묶으므로 기본 인스턴스를 먼저 만들어 넘긴다
  factory SpiritController(rive.File file) {
    final model = file.viewModelByName('WardrobeColors')!;
    try {
      return SpiritController._(file, model.createDefaultInstance()!);
    } finally {
      model.dispose();
    }
  }
  SpiritController._(super.file, this.instance)
    : super(
        artboardSelector: rive.ArtboardNamed('Spirit'),
        stateMachineSelector: rive.StateMachineNamed('WardrobeController'),
        main: rive.DataBind.byInstance(instance),
      ) {
    _pose = instance.number('poseChoice')!;
    _expr = instance.number('expr');
  }
  final rive.BindableViewModelInstance instance;
  late final rive.ViewModelInstanceNumber _pose;

  /// 표정 입력 expr (0 기본·1 행복·2 놀람·3 울먹임·4 졸림·5 화남, 정령 계약 2·4장). riv에 없으면 null
  late final rive.ViewModelInstanceNumber? _expr;
  SpiritMotion _motion = SpiritMotion.idle, _baseline = SpiritMotion.idle;
  int _direction = 0, _baselineDirection = 0;
  bool _head = false, _belly = false;
  double _actionLeft = 0;

  // rive 0.15 재생기는 뷰 모델 입력으로 도는 자세·반응 전이가 0.14 때와 달라 (Codex 앱 패치 11/20, 개발인계_20261120 2장),
  // riv 안의 같은 원본 클립(자세 `Pose_<n>_stable`, 반응 클립)을 상태 머신 다음에 직접 얹는다. riv는 바꾸지 않는다.
  // 트리거도 그대로 울려 친구 스크립트(누름 반응 등)는 riv가 받는다
  rive.Animation? _reactionClip, _poseClip;
  int _appliedPose = -1;

  /// 지금 자세(poseChoice)의 고정 클립을 얹는다. 자세가 바뀔 때만 클립을 새로 찾는다
  void _applyPoseClip() {
    final pose = poseChoice;
    if (_appliedPose != pose) {
      _poseClip?.dispose();
      _poseClip = artboard.animationNamed('Pose_${pose}_stable');
      _appliedPose = pose;
    }
    _poseClip?.apply();
  }

  /// 트리거 → riv 원본 반응 클립 이름
  static const _reactionNames = {
    'greet': 'GreetOneShot',
    'joy': 'JoyOneShot',
    'tapHead': 'ImportedHeadPress',
    'tapBelly': 'ImportedBellyPress',
    'angry': 'ImportedAngryOneShot',
  };

  /// 반응 클립을 놓고 기본 떠 있기(`MotionIdle`) 첫 장면으로 되돌린다
  void _clearReaction() {
    _reactionClip?.dispose();
    _reactionClip = null;
    final idle = artboard.animationNamed('MotionIdle');
    idle?.apply();
    idle?.dispose();
  }

  /// 화면이 정한 자세 (config character.rive.screens·restSwap). null이면 장면(속도·앉기)이 정한다
  int? _fixedPose;

  /// 늘 두는 표정([setBaseExpression])과 지금 표정, 잠깐 표정([cue])이 남은 시간
  int _baseExpr = 0, _exprNow = 0;
  double _exprLeft = 0;

  /// 연타 화남 표정이 보이는 중
  bool _angry = false;

  /// 앱이 뒤로 가 있는 중([setAway])과, 돌아온 뒤 첫 프레임의 지난 시간을 버릴지
  bool _away = false, _skipGap = false;

  /// 걷기·뛰기 동작의 재생 빠르기 ([setPlayback], 16장 11/19)
  double _playback = 1;
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
  int get poseChoice => _pose.value.round();
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
      // 칸 번호는 spiritLookOf가 채운다 (unified_wardrobe.dart). 없는 칸은 안 입음 0
      instance.number('${slot}Choice')!.value = (look.choices[slot] ?? 0).toDouble();
    }
    instance.color('bodyColor')!.value = Color(look.bodyArgb ?? 0xfff2dfc6);
    for (final p in unifiedProps) {
      if (p.colorField case final field?) {
        instance.color(field)!.value = Color(look.colors[field] ?? p.argb);
      }
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
    // 트리거 전이와 따로 같은 원본 반응 클립을 처음부터 얹는다 (위 주석). 그림·타이밍은 riv 원본
    _clearReaction();
    // 표에 없는 트리거면 클립 없이 트리거만 (지금 부르는 것은 greet·joy·tapHead·tapBelly·angry)
    final clip = _reactionNames[trigger];
    _reactionClip = clip == null ? null : artboard.animationNamed(clip);
    _reactionClip?.time = 0;
    _reactionClip?.apply();
    _actionLeft = seconds;
    scheduleRepaint();
  }

  void play(SpiritMotion value, {int? direction}) {
    _head = false;
    _belly = false;
    _actionLeft = 0;
    _clearReaction();
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

  /// 걷기·뛰기 동작의 재생 빠르기 (config character.rive.walkPlayback, 분당 걸음에 맞춘 값). 걷기·뛰기 동안만
  /// Rive를 이 배로 돌리고, 반응(트리거)이 도는 동안과 다른 동작은 1배다. 표정·반응이 남은 시간은 늘 실제 시간으로 잰다
  void setPlayback(double rate) {
    _playback = rate.isFinite && rate > 0 ? rate : 1;
  }

  /// 지금 Rive를 돌리는 배 (걷기·뛰기이고 반응이 없을 때만 [setPlayback] 값)
  double get playbackRate =>
      (_motion == SpiritMotion.walk || _motion == SpiritMotion.run) && _actionLeft <= 0 ? _playback : 1;

  /// 앱이 뒤로 갔다(true)·돌아왔다(false). 뒤에 있는 동안은 프레임이 없어 그리지 않는데, Rive 타이머는 켜진 채라
  /// 돌아온 첫 프레임이 뒤에 있던 시간 전체를 들고 온다. 그 한 번을 버려 떠 있기·반응·표정 시간을 멈춘 자리에서 잇는다.
  /// (다른 화면에 덮이면 Navigator가 TickerMode를 꺼서 Rive 타이머가 멈추고, 다시 켜면 0초부터 잰다)
  void setAway(bool away) {
    if (_away && !away) _skipGap = true;
    _away = away;
  }

  @override
  bool advance(double elapsedSeconds) {
    var dt = elapsedSeconds.isFinite ? math.max(0.0, elapsedSeconds) : 0.0;
    if (_away) {
      dt = 0;
    } else if (_skipGap && dt > 0) {
      _skipGap = false;
      dt = 0;
    }
    final active = super.advance(dt * playbackRate);
    _applyPoseClip();
    _reactionClip?.advanceAndApply(dt);
    // 얹은 클립이 바꾼 표시·변환을 같은 프레임에 반영한다
    artboard.advance(0);
    if (_actionLeft > 0) {
      _actionLeft = math.max(0, _actionLeft - dt);
      if (_actionLeft == 0) {
        _clearReaction();
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
    _reactionClip?.dispose();
    _poseClip?.dispose();
    super.dispose();
    instance.dispose();
  }
}
