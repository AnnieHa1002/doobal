import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/catalog_providers.dart';
import 'palette.dart';

/// 물감 통 그림 이름 (확장자·버전 없이, assets/ui/ 에 넣으면 AssetIndex.sprite가 찾는다).
/// 지시서 codex_paint_tube_v01: 길 위 `ui_paint_tube_road`(128px)·배낭과 줍기 아이콘 `ui_paint_tube_icon`(256px).
/// 캔버스 3-1·6-1(11/15)은 물감 병 `ui_paint_bottle` 한 장을 함께 쓴다. 먼저 있는 것을 쓰고, 없으면 코드로 그린 임시
const paintTubeRoadSprites = ['ui_paint_tube_road_v01', 'ui_paint_bottle_v01'];
const paintTubeIconSprites = ['ui_paint_tube_icon_v01', 'ui_paint_bottle_v01'];

/// 물감 통 하나: 회색조 그림에 물감 색 [color]를 곱한다 (16장 11/14 디자인 기획: 그림 2장 × 앱 색, 아이콘 16장 안 그림).
/// [road]면 길 위 그림, 아니면 아이콘 그림. 크기는 부르는 쪽 상자에 맞춘다
class PaintTubeArt extends ConsumerWidget {
  const PaintTubeArt({super.key, required this.color, this.road = false});

  final Color color;
  final bool road;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetIndexProvider).value;
    String? path;
    for (final name in road ? paintTubeRoadSprites : paintTubeIconSprites) {
      path = assets?.sprite(name);
      if (path != null) break;
    }
    final temp = CustomPaint(painter: _TubePainter(color, road: road));
    if (path == null) return temp;
    return Image.asset(
      path,
      color: color,
      colorBlendMode: BlendMode.modulate,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => temp,
    );
  }
}

/// 코드로 그린 임시 물감 통: 길 위는 땅에 눕힌 튜브(뚜껑 오른쪽), 아이콘은 살짝 기울여 세운 튜브.
/// 몸통은 물감 색, 뚜껑은 진한 회색, 잉크 외곽선
class _TubePainter extends CustomPainter {
  _TubePainter(this.color, {required this.road});

  final Color color;
  final bool road;

  @override
  void paint(Canvas canvas, Size box) {
    final s = math.min(box.width, box.height);
    canvas.save();
    canvas.translate(box.width / 2, box.height / 2);
    if (road) {
      canvas.translate(0, s * 0.22);
    } else {
      canvas.rotate(-math.pi / 2 + 0.35);
    }
    final w = s * 0.82;
    final h = s * 0.34;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(-w / 2, -h / 2, w * 0.74, h),
      topLeft: Radius.circular(h * 0.2),
      bottomLeft: Radius.circular(h * 0.2),
      topRight: Radius.circular(h * 0.45),
      bottomRight: Radius.circular(h * 0.45),
    );
    final cap = RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2 + w * 0.74, -h * 0.3, w * 0.26, h * 0.6), Radius.circular(h * 0.12));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.04)
      ..color = Palette.ink;
    if (road) {
      canvas.drawOval(Rect.fromCenter(center: Offset(0, h * 0.62), width: w * 1.05, height: h * 0.35),
          Paint()..color = Palette.ink.withValues(alpha: 0.15));
    }
    canvas
      ..drawRRect(body, Paint()..color = color)
      ..drawRect(Rect.fromLTWH(-w * 0.18, -h / 2, w * 0.2, h),
          Paint()..color = Colors.white.withValues(alpha: 0.35))
      ..drawRRect(body, line)
      ..drawRRect(cap, Paint()..color = const Color(0xFF6B625B))
      ..drawRRect(cap, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TubePainter old) => old.color != color || old.road != road;
}
