import 'package:flutter/material.dart';

import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
import '../../domain/spirit_look.dart';
import 'spirit_character.dart';

/// 장면이 고르는 정령 자세. 앉기·배 위는 [SpiritCharacter]의 sitting·boat로 넘긴다
enum DoobalPose { standing, sitting, boat }

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
