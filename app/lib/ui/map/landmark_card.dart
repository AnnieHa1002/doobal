import 'package:flutter/material.dart';

import '../../domain/journey.dart';
import '../../domain/landmark.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/frame_style.dart';
import '../common/game_button.dart';
import '../common/palette.dart';

/// 지도 아래 카드: 이름, 시도·지형, 남은 거리, 그림 칸 3개, 버튼.
/// [frame]은 그 명소의 그림을 얻었으면 지금 액자, 아니면 null.
/// [distance]는 `남은 거리 …` 줄 (아직 계산 중이면 null).
/// 버튼은 주 [primaryLabel](`출발하기`)과 보조 [secondaryLabel](`목적지 바꾸기`·`여정 멈추기`, 없으면 안 보임)
class LandmarkCard extends StatelessWidget {
  const LandmarkCard({
    super.key,
    required this.landmark,
    required this.frame,
    required this.distance,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final Landmark landmark;
  final Frame? frame;
  final String? distance;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 한 줄이 기본이고, 글자 크기를 키워 이름이 길어지면 두 줄까지 보여 준다
          Text(
            landmark.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.display(18),
          ),
          const SizedBox(height: 2),
          Text(
            '${landmark.sido} · ${terrainLabels[landmark.terrain] ?? landmark.terrain}',
            style: const TextStyle(fontSize: 14, color: Palette.subInk),
          ),
          const SizedBox(height: 8),
          // 계산 중에도 줄 높이는 그대로 둔다 (글자 크기를 키워 줄이 늘면 같이 늘어난다)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: Text(
              distance ?? '',
              style: context.display(14),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // MVP는 그림이 첫 방문 한 점뿐이라 2·3번째 칸은 늘 잠겨 있다
              PaintingSlot(frame: f),
              const SizedBox(width: 8),
              const PaintingSlot(),
              const SizedBox(width: 8),
              const PaintingSlot(),
              if (f != null) ...[
                const SizedBox(width: 12),
                // 좁은 화면에서 글자가 커지면 줄바꿈한다
                Flexible(
                  child: Text(
                    frameLabel(f),
                    style: context.display(14),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          GameButton(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            GameButton(
              label: secondaryLabel!,
              kind: GameButtonKind.secondary,
              onPressed: onSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

/// 그림 칸 하나 (44×56pt). [frame]이 있으면 그 액자 색, 없으면 잠긴 칸
class PaintingSlot extends StatelessWidget {
  const PaintingSlot({super.key, this.frame});

  final Frame? frame;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    return Container(
      width: 44,
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: f == null ? Palette.paper : frameColors[f],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: f == null ? Palette.subInk : Palette.ink, width: InkLine.panel),
      ),
      child: Container(
        color: Palette.paper,
        alignment: Alignment.center,
        // 아직 얻지 못한 칸은 자물쇠 없이 흐린 점 (11/3 ‘잠금 표시 없음’, UI 명세 v3 7장)
        child: f == null
            ? Container(
                key: const ValueKey('painting-slot-dot'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Palette.ink.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              )
            : const Icon(Icons.landscape_outlined, size: 18, color: Palette.subInk),
      ),
    );
  }
}
