import 'package:flutter/material.dart';

import '../../domain/journey.dart';
import '../../domain/landmark.dart';
import '../common/format.dart';
import '../common/frame_style.dart';
import '../common/game_button.dart';
import '../common/palette.dart';

/// 지도 아래 카드: 이름, 시도·지형, 남은 거리, 그림 칸 3개, 버튼.
/// [frame]은 그 명소의 그림을 얻었으면 지금 액자, 아니면 null.
/// [distance]는 `남은 거리 …` 줄 (아직 계산 중이면 null). [buttonLabel]이 null이면 버튼이 없고,
/// [secondary]이면 버튼을 보조 버튼(카드색)으로 그린다
class LandmarkCard extends StatelessWidget {
  const LandmarkCard({
    super.key,
    required this.landmark,
    required this.frame,
    required this.distance,
    required this.buttonLabel,
    required this.onPressed,
    this.secondary = false,
  });

  final Landmark landmark;
  final Frame? frame;
  final String? distance;
  final String? buttonLabel;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            landmark.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
          ),
          const SizedBox(height: 2),
          Text(
            '${landmark.sido} · ${terrainLabels[landmark.terrain] ?? landmark.terrain}',
            style: const TextStyle(fontSize: 14, color: Palette.subInk),
          ),
          const SizedBox(height: 8),
          // 계산 중에도 줄 높이는 그대로 둔다
          SizedBox(
            height: 20,
            child: Text(
              distance ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Palette.ink),
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
                Text(
                  frameLabel(f),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                  ),
                ),
              ],
            ],
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 16),
            GameButton(
              label: buttonLabel!,
              kind: secondary ? GameButtonKind.secondary : GameButtonKind.primary,
              onPressed: onPressed,
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
        border: Border.all(color: f == null ? Palette.subInk : Palette.ink, width: 2),
      ),
      child: Container(
        color: Palette.paper,
        alignment: Alignment.center,
        child: Icon(
          f == null ? Icons.lock_outline : Icons.landscape_outlined,
          size: 18,
          color: Palette.subInk,
        ),
      ),
    );
  }
}
