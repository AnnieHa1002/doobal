import 'package:flutter/material.dart';

import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
import '../../domain/spirit_look.dart';
import '../common/palette.dart';
import '../scene/spirit_character.dart';
import '../scene/spirit_controller.dart';

/// 미리보기를 [turn]번 돌린 자세: [order](config customizePreview.swipe, 정면 → 옆 → 뒤)를 돌아 가며
int turnedPose(List<int> order, int turn) => order[turn % order.length];

/// 손가락이 이만큼(pt) 옆으로 가면 한 번 돌린다 (빠르게 튕기면 짧아도 돌린다)
const _turnDragPt = 32.0;
const _turnFlingPtPerSec = 300.0;

/// 꾸미기 위 미리보기: 쉼터와 같은 정령을 풀밭 위에 세운다. 좌우로 밀면 정면·옆·뒤로 돌려 보고
/// (16장 11/13, 왼쪽으로 밀면 다음 자세), 머리·배를 누르면 반응하고 연타하면 화낸다. 표정 미리보기 단추는 없다.
/// 아래에 입고 있는 소품 요약 줄. 고르는 대로 얼굴·몸 색이 바뀌고, Rive에 붙은 소품(domain/spirit_look.dart)도 입는다
class SpiritPreview extends StatefulWidget {
  const SpiritPreview({
    super.key,
    required this.look,
    required this.summary,
    required this.onTurn,
    this.pose,
    this.tapRules,
    this.cues,
    this.onReady,
  });

  final ValueChanged<SpiritController>? onReady;
  final SpiritLook look;

  /// 입고 있는 소품 이름을 이은 줄 ("소품 없음"이면 비었다는 뜻)
  final String summary;

  /// 지금 보이는 자세 (poseChoice)
  final int? pose;

  /// 밀어서 돌렸다: +1 다음 자세(왼쪽으로 밂), -1 앞 자세(오른쪽으로 밂)
  final ValueChanged<int> onTurn;
  final Rules? tapRules;
  final SpiritCues? cues;

  @override
  State<SpiritPreview> createState() => _SpiritPreviewState();
}

class _SpiritPreviewState extends State<SpiritPreview> {
  var _dragDx = 0.0;

  void _endDrag(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dx = _dragDx;
    _dragDx = 0;
    if (dx.abs() >= _turnDragPt || v.abs() >= _turnFlingPtPerSec) {
      widget.onTurn((dx != 0 ? dx : v) < 0 ? 1 : -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: DecoratedBox(
        key: const ValueKey('preview'),
        decoration: BoxDecoration(
          color: const Color(0xFFE9DFC9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 풀밭 자리
              Positioned.fill(
                child: FractionallySizedBox(
                  heightFactor: 0.22,
                  alignment: Alignment.bottomCenter,
                  child: const ColoredBox(color: Color(0xFFD8CBB0)),
                ),
              ),
              Positioned.fill(
                child: Semantics(
                  label: '정령 돌려 보기',
                  onIncrease: () => widget.onTurn(1),
                  onDecrease: () => widget.onTurn(-1),
                  child: GestureDetector(
                    key: const ValueKey('preview-turn'),
                    // 정령 그림이 없는 자리(풀밭·빈 곳)를 밀어도 돈다
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _dragDx = 0,
                    onHorizontalDragUpdate: (d) => _dragDx += d.primaryDelta ?? 0,
                    onHorizontalDragEnd: _endDrag,
                    onHorizontalDragCancel: () => _dragDx = 0,
                    // 발이 요약 줄에 가리지 않게 올려 세운다
                    child: SpiritStanding(
                      look: look,
                      footAt: 0.82,
                      pose: widget.pose,
                      cues: widget.cues,
                      tapRules: widget.tapRules,
                      onReady: widget.onReady,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 10,
                right: 12,
                child: Container(
                  key: const ValueKey('summary'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.card.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Palette.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
