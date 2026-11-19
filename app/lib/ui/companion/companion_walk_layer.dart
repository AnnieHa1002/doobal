import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/companion.dart';
import '../../domain/companion_pace.dart';
import '../scene/scene_view.dart';
import '../common/notice_dot.dart';
import 'companion_art.dart';

// 걷는 중 장면의 동행 (캔버스 3-1 ‘뒤따르는 퐁이’). 자리표시 그림이라 동작은 위아래 둥실로만 보인다
// (걷기·뛰기 동작 그림은 동행 Rive, T2c)

/// 동행 발이 정령 발에서 얼마나 뒤(왼쪽)인가: 정령 키에 대한 비율
/// (캔버스 3-1: 정령 가운데 194.5pt, 동행 가운데 74.5pt, 정령 키 180pt)
const walkBehindToSpirit = 120 / 180;

/// 둥실 높이: 정령 키에 대한 비율 (캔버스 3-1 bob 6pt ÷ 180pt)
const _bobToSpirit = 6 / 180;

/// 둥실 한 번 (캔버스 3-1: 걷기 .mate 0.62초, 뛰기 .runner 0.3초)
const _bobWalk = Duration(milliseconds: 620);
const _bobRun = Duration(milliseconds: 300);

/// [frame]일 때 동행 발의 x. 곁이면 정령 뒤(배 위면 배 그림의 동행 자리),
/// 앞서 나가면 화면 오른쪽 밖([width]는 동행 폭), 뒤처지면 그 땅 거리만큼 왼쪽
double walkCompanionFootX(PaceFrame frame, SceneCompanionSpot spot, double width) {
  final home = spot.boatFoot?.dx ?? spot.spiritFoot.dx - walkBehindToSpirit * spot.figureHeight;
  final away = spot.size.width + width / 2;
  return home + (away - home) * frame.aheadT - frame.lagM * spot.groundPtPerM;
}

/// 걷는 중 장면 위의 동행 하나. [pace]가 바뀔 때만 자리를 다시 잡는다 (장면은 다시 그리지 않는다).
/// 화면 밖이면 그리지 않는다
class WalkCompanionLayer extends StatefulWidget {
  const WalkCompanionLayer({
    super.key,
    required this.companion,
    required this.pace,
    required this.spot,
    this.onTap,
    this.notice = false,
  });

  final Companion companion;
  final ValueListenable<PaceFrame> pace;
  final SceneCompanionSpot spot;

  /// 누르면 (걷기 탭 → 동행 화면, config companions.walkTab.tap). 없으면 눌리지 않는다
  final VoidCallback? onTap;

  /// 동행 위 알림 점 (안 읽은 장, companions.walkTab.dot)
  final bool notice;

  @override
  State<WalkCompanionLayer> createState() => _WalkCompanionLayerState();
}

class _WalkCompanionLayerState extends State<WalkCompanionLayer>
    with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: _bobWalk);

  /// 지금 둥실의 동작 (서 있으면 멈춤)
  var _bobFor = PaceMotion.stand;

  /// 움직임 줄이기를 켠 기기면 둥실 없이
  var _still = false;

  @override
  void initState() {
    super.initState();
    widget.pace.addListener(_syncBob);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _syncBob();
  }

  @override
  void didUpdateWidget(WalkCompanionLayer old) {
    super.didUpdateWidget(old);
    if (old.pace != widget.pace) {
      old.pace.removeListener(_syncBob);
      widget.pace.addListener(_syncBob);
      _syncBob();
    }
  }

  @override
  void dispose() {
    widget.pace.removeListener(_syncBob);
    _bob.dispose();
    super.dispose();
  }

  void _syncBob() {
    final motion = _still ? PaceMotion.stand : widget.pace.value.motion;
    if (motion == _bobFor) return;
    _bobFor = motion;
    if (motion == PaceMotion.stand) {
      _bob.stop();
      _bob.value = 0;
    } else {
      _bob.duration = motion == PaceMotion.run ? _bobRun : _bobWalk;
      _bob.repeat();
    }
  }

  /// 누를 수 있으면 누름 상자와 알림 점을 붙인다. 아니면 눌림을 받지 않는다
  Widget _tappable(Widget figure) {
    final onTap = widget.onTap;
    if (onTap == null) return IgnorePointer(child: figure);
    return Semantics(
      button: true,
      label: widget.notice ? '${widget.companion.name} (새 이야기 있음)' : widget.companion.name,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('walk-companion-tap'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: figure),
            if (widget.notice)
              const Positioned(top: 0, right: 0, child: NoticeDot(key: ValueKey('walk-companion-dot'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final h = spot.figureHeight * companionToSpirit;
    final w = h * companionFigureAspect;
    final footY = spot.boatFoot?.dy ?? spot.spiritFoot.dy;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.pace, _bob]),
      child: _tappable(SceneTinted(
        tint: spot.tint,
        child: RepaintBoundary(child: CompanionFigure(companion: widget.companion, height: h)),
      )),
      builder: (context, child) {
        final x = walkCompanionFootX(widget.pace.value, spot, w);
        if (x + w / 2 < 0 || x - w / 2 > spot.size.width) return const SizedBox.shrink();
        final lift = spot.figureHeight * _bobToSpirit * (1 - math.cos(2 * math.pi * _bob.value)) / 2;
        return Stack(
          children: [
            Positioned(
              key: const ValueKey('walk-companion'),
              left: x - w / 2,
              top: footY - h - lift,
              width: w,
              height: h,
              child: child!,
            ),
          ],
        );
      },
    );
  }
}
