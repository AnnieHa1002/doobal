import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/journey.dart';
import '../../domain/landmark.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/frame_style.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import 'map_painter.dart' show pinHeadColors;

/// 지도 아래 카드: 이름, 시도·지형, 남은 거리, 그림 칸, 버튼.
/// [frame]은 그 명소의 그림을 얻었으면 지금 액자, 아니면 null.
/// [distance]는 `남은 거리 …` 줄 (아직 계산 중이면 null).
/// 그림 칸은 [slots]개(config map.card.paintingSlot.count, MVP 1, 16장 11/19 밤 창구 Q004): 받기 전엔 연필 점선 빈 칸,
/// 받으면 그 그림 액자 색 칸 + 썸네일, 글 없음(‘그림 n / 3’·액자 안내 없음). 받은 칸을 누르면 [onPainting](크게 보기).
/// 버튼은 주 [primaryLabel](`출발하기`)과 보조 [secondaryLabel](`목적지 바꾸기`·`여정 멈추기`, 없으면 안 보임).
/// [stampScale]은 도착 연출(① config ui.motion.arrivalPin)에서 받은 첫 칸이 찍히는 크기 (1.3 → 1, 보통 1)
class LandmarkCard extends StatelessWidget {
  const LandmarkCard({
    super.key,
    required this.landmark,
    required this.frame,
    required this.distance,
    required this.primaryLabel,
    required this.onPrimary,
    this.slots = 1,
    this.stampScale = 1,
    this.onPainting,
    this.secondaryLabel,
    this.onSecondary,
  });

  final Landmark landmark;
  final Frame? frame;
  final String? distance;
  final int slots;
  final double stampScale;
  final VoidCallback? onPainting;
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
              // 첫 칸이 첫 방문 그림. 나머지 칸(출시 뒤 원경·근경·장면)은 늘 빈 칸
              for (var i = 0; i < slots; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                PaintingSlot(
                  key: ValueKey('painting-slot-$i'),
                  landmark: i == 0 && f != null ? landmark : null,
                  frame: i == 0 ? f : null,
                  scale: i == 0 ? stampScale : 1,
                  onTap: i == 0 && f != null ? onPainting : null,
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

/// 그림 칸 지름과 테두리 (캔버스 4-1 stamps: 40pt 동그라미, 빈 칸은 1.6pt 연필 점선, 받은 칸은 잉크 1.6pt·−8° 기울임)
const _slotSize = 40.0;
const _slotLine = 1.6;
const _slotTilt = -8 * math.pi / 180;

/// 받은 칸 안 액자 색 띠 두께
const _slotBand = 3.0;

/// 그림 칸 하나 (지름 40pt, 누르는 자리는 44pt). [frame]이 있으면 그 액자 색(지도 핀 머리와 같은 색) 테두리 안에
/// [landmark] 그림 썸네일, 없으면 연필 점선 빈 칸(자물쇠·글 없음). 받은 칸은 [scale]배로 (도장 찍힘)
class PaintingSlot extends StatelessWidget {
  const PaintingSlot({super.key, this.landmark, this.frame, this.scale = 1, this.onTap});

  final Landmark? landmark;
  final Frame? frame;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    final l = landmark;
    if (f == null || l == null) {
      return const SizedBox.square(
        dimension: 44,
        child: Center(
          child: CustomPaint(
            key: ValueKey('painting-slot-empty'),
            size: Size.square(_slotSize),
            painter: _DashedCirclePainter(),
          ),
        ),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumb = l.painting.isEmpty
        ? ColoredBox(color: paintingTint(l))
        : Image.asset(
            'assets/paintings/${l.painting}.webp',
            fit: BoxFit.cover,
            cacheWidth: (_slotSize * dpr).ceil(),
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => ColoredBox(color: paintingTint(l)),
          );
    return Semantics(
      button: onTap != null,
      label: '${l.name} 그림, ${frameLabel(f)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Transform(
              key: const ValueKey('painting-slot-stamp'),
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(_slotTilt)..scaleByDouble(scale, scale, 1, 1),
              child: Container(
                key: const ValueKey('painting-slot-filled'),
                width: _slotSize,
                height: _slotSize,
                padding: const EdgeInsets.all(_slotBand),
                decoration: BoxDecoration(
                  color: pinHeadColors[f],
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.ink, width: _slotLine),
                ),
                child: ClipOval(child: thumb),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 빈 그림 칸: 연필 점선 동그라미 (#B8A385)
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Palette.lineDashed
      ..strokeWidth = _slotLine;
    final r = size.shortestSide / 2 - _slotLine / 2;
    final c = size.center(Offset.zero);
    final count = (2 * math.pi * r / (_dash + _gap)).floor();
    final step = 2 * math.pi / count;
    final sweep = step * _dash / (_dash + _gap);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * step, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => false;
}
