// 완결 동행 쉼터 돌아다니기 (16장 11/18 ④·11/19 ②, config companions.finaleRoam, 가안).
// 이야기 마지막 장까지 읽은 동행이 쉼터 땅 띠 위를 천천히 걷다 멈추고 가끔 앉는다. 물품과는 앞뒤 순서만(부딪힘 없음).
// 가는 곳은 정령·모닥불·수레 상자에 동행 상자가 걸리지 않는 띠 안 자리 (지나가는 길은 막지 않음, 앞뒤 순서로 그림)

import 'dart:math' as math;

import 'companion.dart' show RestLine;
import 'decor_place.dart';
import 'decor_rules.dart';

enum RoamPose { walk, stand, sit }

/// 동행 한 명의 지금 모습
class RoamState {
  const RoamState({
    required this.at,
    required this.pose,
    required this.target,
    required this.leftSec,
    this.facingLeft = false,
  });

  /// 발 자리 (장면 pt)
  final ScenePoint at;
  final RoamPose pose;

  /// 걸어가는 곳 (걷는 동안)
  final ScenePoint target;

  /// 멈춰 있는 남은 시간 (서기·앉기)
  final double leftSec;

  /// 왼쪽을 보고 있다 (왼쪽으로 걸었다)
  final bool facingLeft;
}

/// 돌아다니기 계산. [w]·[h]는 동행 상자 크기(장면 pt), 발이 아래 가운데
class FinaleRoamer {
  FinaleRoamer({
    required this.rules,
    required this.stage,
    required this.w,
    required this.h,
    required this.random,
  });

  final FinaleRoamRules rules;
  final DecorStage stage;
  final double w;
  final double h;

  /// 가는 곳·멈춤·앉기를 고른다 (시험은 씨앗을 준다)
  final math.Random random;

  SceneRect boxAt(ScenePoint foot) => SceneRect(foot.x - w / 2, foot.y - h, w, h);

  bool _free(ScenePoint p) => stage.inBand(p) && stage.blockedBy(boxAt(p)) == null;

  /// 띠 안의 빈 자리 하나 (막힌 자리만 있으면 띠 가운데)
  ScenePoint pickSpot() {
    final b = stage.band;
    for (var i = 0; i < 40; i++) {
      final p = ScenePoint(
        b.xMin + random.nextDouble() * (b.xMax - b.xMin),
        b.footYMin + random.nextDouble() * (b.footYMax - b.footYMin),
      );
      if (_free(p)) return p;
    }
    return ScenePoint((b.xMin + b.xMax) / 2, (b.footYMin + b.footYMax) / 2);
  }

  double _stopSec() => rules.stopMinSec + random.nextDouble() * (rules.stopMaxSec - rules.stopMinSec);

  /// 처음 모습: 빈 자리에 서서 잠깐 멈춤
  RoamState start() {
    final at = pickSpot();
    return RoamState(at: at, pose: RoamPose.stand, target: at, leftSec: _stopSec());
  }

  /// [dt]초 뒤. 걷다가 닿으면 멈추고(앉을 확률 sitChance), 멈춤이 끝나면 새 곳으로 걷는다
  RoamState step(RoamState s, double dt) {
    if (dt <= 0) return s;
    switch (s.pose) {
      case RoamPose.walk:
        final dx = s.target.x - s.at.x;
        final dy = s.target.y - s.at.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        final go = rules.walkPtPerSec * dt;
        if (dist <= go) {
          final sit = random.nextDouble() < rules.sitChance;
          return RoamState(
            at: s.target,
            pose: sit ? RoamPose.sit : RoamPose.stand,
            target: s.target,
            leftSec: _stopSec(),
            facingLeft: s.facingLeft,
          );
        }
        return RoamState(
          at: ScenePoint(s.at.x + dx / dist * go, s.at.y + dy / dist * go),
          pose: RoamPose.walk,
          target: s.target,
          leftSec: 0,
          facingLeft: dx < 0,
        );
      case RoamPose.stand || RoamPose.sit:
        final left = s.leftSec - dt;
        if (left > 0) {
          return RoamState(at: s.at, pose: s.pose, target: s.target, leftSec: left, facingLeft: s.facingLeft);
        }
        final next = pickSpot();
        return RoamState(
          at: s.at,
          pose: RoamPose.walk,
          target: next,
          leftSec: 0,
          facingLeft: next.x < s.at.x,
        );
    }
  }
}

/// 말풍선에 띄울 한마디 번호 ([lines] 중 무작위, [noRepeat]이면 바로 앞 [last]는 빼고). 줄이 없으면 null
int? pickRestLine(List<RestLine> lines, int? last, math.Random random, {required bool noRepeat}) {
  if (lines.isEmpty) return null;
  if (lines.length == 1 || !noRepeat || last == null || last < 0 || last >= lines.length) {
    return random.nextInt(lines.length);
  }
  final i = random.nextInt(lines.length - 1);
  return i >= last ? i + 1 : i;
}
