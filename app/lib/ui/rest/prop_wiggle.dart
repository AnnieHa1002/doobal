import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 쉼터 물건 흔들림의 연출 값 (UI 명세 2장: 3~6초 간격으로 하나씩 살짝). 화면 연출이라 코드 상수다.
/// 테스트는 [WiggleSpec.off]로 끄거나, 짧은 간격과 고정 [random]을 넣는다
class WiggleSpec {
  const WiggleSpec({
    this.minGap = const Duration(seconds: 3),
    this.maxGap = const Duration(seconds: 6),
    this.duration = const Duration(milliseconds: 600),
    this.degrees = 4,
    this.swings = 3,
    this.enabled = true,
    this.random,
  });

  /// 흔들지 않는다
  const WiggleSpec.off() : this(enabled: false);

  /// 한 번 흔들고 다음에 흔들 때까지의 간격 범위
  final Duration minGap;
  final Duration maxGap;

  /// 한 번 흔드는 시간
  final Duration duration;

  /// 가장 크게 기울 때의 각도 (도)
  final double degrees;

  /// 한 번 흔드는 동안 좌우로 오가는 횟수
  final int swings;
  final bool enabled;

  /// 물건과 간격을 고르는 난수. null이면 매번 무작위
  final math.Random? random;
}

final restWiggleProvider = Provider<WiggleSpec>((ref) => const WiggleSpec());

/// 흔들 물건 고르기: 알림 점이 있는 물건이 있으면 그 중에서, 없으면 전체에서. 물건이 없으면 null
String? pickWiggleTarget(List<String> all, Set<String> notice, math.Random random) {
  final noticed = [for (final id in all) if (notice.contains(id)) id];
  final from = noticed.isEmpty ? all : noticed;
  return from.isEmpty ? null : from[random.nextInt(from.length)];
}

/// 다음 흔들림까지의 간격: [WiggleSpec.minGap]~[WiggleSpec.maxGap] 사이
Duration wiggleGap(WiggleSpec spec, math.Random random) {
  final span = spec.maxGap - spec.minGap;
  return spec.minGap + span * random.nextDouble();
}

/// 흔드는 동안 [t](0~1)에서의 기울기(라디안). 좌우로 오가며 점점 줄어 0에서 끝난다
double wiggleAngle(double t, WiggleSpec spec) =>
    spec.degrees * math.pi / 180 * math.sin(2 * math.pi * spec.swings * t) * (1 - t);

/// 물건 하나씩 가끔 흔든다. 간격이 지나면 물건 하나를 골라 [WiggleSpec.duration] 동안 흔들고,
/// 끝나면 다음 간격을 센다. [pool]은 흔들 때마다 그때 보이는 물건을 읽는다 (알림 점 우선).
/// 타이머와 애니메이션이 남지 않도록 [dispose]를 꼭 부른다
class PropWiggler {
  PropWiggler({required TickerProvider vsync, required this.spec, required this.pool})
      : _random = spec.random ?? math.Random(),
        controller = AnimationController(vsync: vsync, duration: spec.duration) {
    controller.addStatusListener(_onStatus);
    _schedule();
  }

  final WiggleSpec spec;
  final ({List<String> all, Set<String> notice}) Function() pool;
  final AnimationController controller;
  final math.Random _random;
  Timer? _timer;

  /// 지금 흔들리는 물건 id. 흔들리지 않으면 null
  String? target;

  void _schedule() {
    if (!spec.enabled) return;
    _timer = Timer(wiggleGap(spec, _random), _start);
  }

  void _start() {
    final now = pool();
    target = pickWiggleTarget(now.all, now.notice, _random);
    if (target == null) return _schedule();
    controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    target = null;
    _schedule();
  }

  void dispose() {
    _timer?.cancel();
    controller.dispose();
  }
}

/// 물건 [id]가 흔들릴 차례면 아래 가운데(땅에 선 자리)를 축으로 기울인다. 아니면 그대로(각도 0)
class PropWiggle extends StatelessWidget {
  const PropWiggle({super.key, required this.wiggler, required this.id, required this.child});

  final PropWiggler wiggler;
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: wiggler.controller,
      child: child,
      builder: (context, child) => Transform.rotate(
        angle: wiggler.target == id ? wiggleAngle(wiggler.controller.value, wiggler.spec) : 0,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    );
  }
}
