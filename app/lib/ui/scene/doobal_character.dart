import 'package:flutter/material.dart';

import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
import '../../domain/spirit_look.dart';
import 'doobal_controller.dart';
import 'spirit_character.dart';
export 'doobal_controller.dart' show DoobalPose;

/// 쉼터·이동 장면의 정령. 기존 화면의 속도·자세 호출을 유지한다.
class DoobalCharacter extends StatelessWidget {
  const DoobalCharacter({
    super.key,
    required this.speed,
    this.pose = DoobalPose.standing,
    this.lookX = 0,
    this.lookY = 0,
    this.spirit = SpiritLook.base,
    this.tapRules,
    this.posePick,
    this.mirrored = false,
    this.expression = 0,
    this.cue,
    this.cues,
  });
  final double speed, lookX, lookY;
  final DoobalPose pose;
  final SpiritLook spirit;

  /// 주면 정령 연타 화남이 켜진다 (쉼터)
  final Rules? tapRules;

  /// 화면이 정한 자세·좌우 뒤집기·표정 ([SpiritCharacter]와 같다)
  final int? posePick;
  final bool mirrored;
  final int expression;
  final SpiritCue? cue;
  final SpiritCues? cues;
  // 이전 화가 파일은 기존 소품 시험과 복구용으로 남겨 둔다.
  static const asset = 'assets/rive/doobal_custom.riv';
  @override
  Widget build(BuildContext context) => SpiritCharacter(
    speed: speed,
    sitting: pose == DoobalPose.sitting,
    boat: pose == DoobalPose.boat,
    lookX: lookX / 5,
    lookY: lookY / 5,
    look: spirit,
    tapRules: tapRules,
    pose: posePick,
    mirrored: mirrored,
    expression: expression,
    cue: cue,
    cues: cues,
  );
}
