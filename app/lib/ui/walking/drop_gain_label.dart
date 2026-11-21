import 'package:flutter/material.dart';

import '../../domain/motion_rules.dart';
import '../common/app_text.dart';
import '../common/palette.dart';

/// 물감 방울을 주울 때 머리 위로 떠오르는 ‘+n 럭’의 글자와 통 아이콘 (연출 ④, T19, 16장 11/20 Q008,
/// config ui.motion.dropPickup, 캔버스 3-1 메모 ‘럭 숫자가 0.3초 동안 올라가며 1.15배 튀김’).
/// 줍기 연출이 시작된 뒤 [sec]초의 모습만 그린다 (떠오름·흐려짐은 부르는 쪽 그대로, plusOne unchanged):
/// 숫자는 한 방울 몫([from])에서 이번에 주운 몫([to])까지 [DropPickupMotion.luxStep]씩 [DropPickupMotion.luxCountSec]초
/// 동안 오르며 1 → [DropPickupMotion.luxBounceScale] → 1배로 튀고, 통 아이콘([tube])은
/// [DropPickupMotion.tubeDelaySec]초 뒤에 나타난다 (자리는 처음부터 잡아 글자가 밀리지 않게).
/// [still](움직임 줄이기)이거나 [motion]이 없으면 끝 상태: 다 오른 숫자·1배·통 바로
class DropGainLabel extends StatelessWidget {
  const DropGainLabel({
    super.key,
    required this.motion,
    required this.sec,
    required this.from,
    required this.to,
    required this.still,
    this.tube,
  });

  final DropPickupMotion? motion;
  final double sec;
  final int from;
  final int to;
  final bool still;
  final Widget? tube;

  @override
  Widget build(BuildContext context) {
    final m = still ? null : motion;
    final n = m == null ? to : m.countAt(from, to, sec);
    final scale = m == null ? 1.0 : m.scaleAt(sec);
    final tubeOn = m == null || sec >= m.tubeDelaySec;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          key: const ValueKey('paint-drop-gain-scale'),
          scale: scale,
          child: Text(
            '+$n 럭',
            key: const ValueKey('paint-drop-gain'),
            style: context.display(16, color: Palette.ink),
          ),
        ),
        if (tube case final t?) ...[
          const SizedBox(width: 4),
          Visibility(
            visible: tubeOn,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: t,
          ),
        ],
      ],
    );
  }
}
