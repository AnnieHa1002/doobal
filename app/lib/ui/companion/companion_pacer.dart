import 'package:flutter/foundation.dart';

import '../../domain/companion.dart';
import '../../domain/companion_pace.dart';
import '../../domain/rules.dart';

/// 걷는 중 동행 걸음 (M2 pace, 화면 연출만·저장 안 함). 걷는 중 화면이 프레임마다 [step]을 부르고
/// 장면의 동행 층이 [frame]을 듣는다. Riverpod 상태는 바꾸지 않고, 모습이 달라질 때만 알린다
class CompanionPacer {
  PaceState _state = const PaceState();
  String? _companionId;

  /// 지금 모습. 동작·앞선 정도·뒤처진 거리가 그대로면 알리지 않는다
  final frame = ValueNotifier(const PaceFrame(motion: PaceMotion.stand));

  /// 뒤처진 거리(m). 걷기를 마칠 때 쉼터 늦은 도착을 잰다
  double get lagM => _state.lagM;

  /// 프레임 하나([dt]초)만큼 나아간다. 함께 걷는 동행이 바뀌면 처음부터 (뒤처진 거리도 없어진다)
  void step({
    required Companion companion,
    required PaceMotion user,
    required double userMps,
    required bool onSea,
    required double dt,
    required Rules rules,
  }) {
    if (companion.id != _companionId) {
      _companionId = companion.id;
      _state = const PaceState();
    }
    _state = stepPace(
      _state,
      pace: companion.pace,
      user: user,
      userMps: userMps,
      onSea: onSea,
      dt: dt,
      rules: rules,
    );
    final next = paceFrame(_state, pace: companion.pace, user: user, onSea: onSea, rules: rules);
    final now = frame.value;
    if (next.motion != now.motion || next.aheadT != now.aheadT || next.lagM != now.lagM) {
      frame.value = next;
    }
  }

  void dispose() => frame.dispose();
}
