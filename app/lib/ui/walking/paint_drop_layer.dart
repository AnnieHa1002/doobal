import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/catalog_providers.dart';
import '../../domain/paint_color.dart';
import '../../domain/paint_trail.dart';
import '../../domain/rules.dart';
import '../common/app_text.dart';
import '../common/paint_art.dart';
import '../common/palette.dart';
import '../scene/scene_view.dart' show SceneCompanionSpot, SceneTinted;

/// 주운 럭이 머리 위로 떠오르는 높이 (정령 키 비율, 화면 구성값)
const _gainRise = 0.2;

/// 물감 통 (지시서 codex_paint_tube_v01·캔버스 3-1 메모, 화면 구성값): 길 위 통 32pt를 방울 바로 뒤(오른쪽 18pt)에,
/// 주우면 `+1 럭` 옆에 통 아이콘 24pt
const _tubeRoadPt = 32.0;
const _tubeBehindPt = 18.0;
const _tubeIconPt = 24.0;

/// 걷는 중 땅 위 물감 방울 (M2~M6 명세 v0.17 T②, 캔버스 3-1, 디자인기획/물감길_개발인계 2장): 이번 물감 길 거리
/// config paintDrop.spacingM마다 방울 하나(그림 A·B 중 방울 번호로 고른 것)가 땅과 같이 흘러온다.
/// 정령 가운데 x에 닿으면 config paintDrop.pickup대로: 눌린 방울(C)이 pressedSec초, 그 뒤 튐이 splashSec초 동안
/// splashScale 배율로 퍼지며 사라지고, 닿은 순간부터 `+n 럭`(paintDrop.coinsPerDrop)이 gainFloatSec초 동안 머리 위로
/// 떠오른다 (토스트 없음). 동작 줄이기면 눌린 방울·튐 없이 지우고 `+n 럭`만 제자리에서 흐려진다.
/// 방울 그림은 회색 그림에 그 순간 물감 색 [color]를 곱하고(tint multiplyRgb, 시간대·날씨·뛰기 × 그날 계절, 16장 11/14·11/15),
/// 보상 표에서 물감 통이 나오는 방울(물감 길 [trailId]·방울 번호로 정함, M1 v0.7)은 바로 뒤에 같은 색 물감 통을 놓고
/// 주울 때 `+n 럭` 옆에 통 아이콘이 함께 떠오른다 ([tubeAllowed]가 false면, 그 색 통이 상한이라 안 나온다).
/// 지역 색으로 나오는 통(M1 v0.8)은 지금 권역의 지역 색 [regionColor]다 ([regionAllowed]가 false면 안 나온다).
/// 밤에는 정령과 같은 시간대 보정을 받는다 (night sameAsSpirit). 글자는 보정하지 않는다.
/// 연출만이고 저장하지 않는다 (럭은 물감 길 거리로 따로 센다, M1 v0.5 ③).
/// 그림(assets/ui/의 ui_paint_pickup_a·b·c, fx_paint_splash)이 오기 전에는 코드로 그린 임시다 (파일만 넣으면 읽는다)
class PaintDropLayer extends ConsumerStatefulWidget {
  const PaintDropLayer({
    super.key,
    required this.spot,
    required this.shownM,
    required this.rules,
    this.color,
    this.trailId,
    this.tubeAllowed = true,
    this.regionColor,
    this.regionAllowed = true,
  });

  final SceneCompanionSpot spot;

  /// 그 순간 물감 색 (불투명 ARGB). null이면 기본 물감 색
  final int? color;

  /// 이번 물감 길 번호 (방울 보상을 정한다). null이면 물감 통을 보이지 않는다
  final int? trailId;

  /// 그 순간 색 통을 더 주울 수 있는가 (가진 통이 config paintColor.stock.maxTubesPerColor 아래)
  final bool tubeAllowed;

  /// 지금 권역의 지역 색 (불투명 ARGB, 없으면 지역 색 통도 그 순간 색)과 그 색 통을 더 주울 수 있는가
  final int? regionColor;
  final bool regionAllowed;

  /// 화면에 보이는 이번 물감 길 거리(m). 방울 k는 k × spacingM에 있다
  final double shownM;
  final Rules rules;

  @override
  ConsumerState<PaintDropLayer> createState() => _PaintDropLayerState();
}

class _PaintDropLayerState extends ConsumerState<PaintDropLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pick = AnimationController(vsync: this);
  int? _picked;

  /// 지금 줍는 연출 중인가 (닿은 순간부터 눌린 방울·튐·`+n 럭`이 다 끝날 때까지)
  var _picking = false;

  /// 줍는 연출 중인 방울의 물감 통 색 (`+n 럭` 옆 통 아이콘, 통이 없으면 null)
  Color? _pickedTube;

  /// [k]번째 방울의 물감 통 색 (통이 없거나 그 색 통이 상한이면 null)
  Color? _tubeAt(int k) {
    final id = widget.trailId;
    if (id == null) return null;
    final roll = rollDrop(id, k, widget.rules.paintColor);
    if (!roll.tube) return null;
    final region = widget.regionColor;
    if (roll.region && region != null) return widget.regionAllowed ? Color(region) : null;
    return widget.tubeAllowed ? Color(widget.color ?? widget.rules.paintDefaultColor) : null;
  }

  @override
  void initState() {
    super.initState();
    _pick.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _picking = false);
    });
  }

  @override
  void dispose() {
    _pick.dispose();
    super.dispose();
  }

  /// 줍기 연출 전체 길이(초): 눌린 방울 + 튐과 `+n 럭` 중 긴 쪽
  double get _totalSec {
    final p = widget.rules.paintPickup;
    return math.max(p.pressedSec + p.splashSec, p.gainFloatSec);
  }

  @override
  void didUpdateWidget(PaintDropLayer old) {
    super.didUpdateWidget(old);
    final picked = paintDrops(widget.shownM, widget.rules);
    final last = _picked;
    // 처음 보거나(화면을 다시 열었다) 줄었으면 줍는 연출 없이 맞춘다
    if (last != null && picked > last) {
      _picking = true;
      _pickedTube = [for (var k = last + 1; k <= picked; k++) _tubeAt(k)].nonNulls.lastOrNull;
      _pick
        ..duration = Duration(microseconds: (_totalSec * Duration.microsecondsPerSecond).round())
        ..forward(from: 0);
    }
    _picked = picked;
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked ??= paintDrops(widget.shownM, widget.rules);
    final rules = widget.rules;
    final pickup = rules.paintPickup;
    final spot = widget.spot;
    final size = pickup.sizePt;
    final r = size / 2;
    final foot = spot.spiritFoot;
    final color = Color(widget.color ?? rules.paintDefaultColor);
    final still = MediaQuery.disableAnimationsOf(context);
    final assets = ref.watch(assetIndexProvider).value;
    final drops = [for (final name in pickup.dropSprites) assets?.sprite(name)];
    final pressed = assets?.sprite(pickup.pressedSprite);
    final splash = assets?.sprite(pickup.splashSprite);

    // 정령 가운데보다 오른쪽(아직 안 닿은 것)부터 화면 오른쪽 끝까지
    final ground = <Widget>[];
    final spacing = rules.paintDropSpacingM;
    if (spacing > 0 && spot.groundPtPerM > 0) {
      // 물감 통은 방울 뒤라 방금 주운 방울의 통이 아직 정령에 안 닿았을 수 있다 (닿으면 사라진다)
      for (var k = math.max(1, picked);; k++) {
        final x = foot.dx + (k * spacing - widget.shownM) * spot.groundPtPerM + _tubeBehindPt;
        if (x - _tubeRoadPt / 2 > spot.size.width) break;
        final tube = x < foot.dx ? null : _tubeAt(k);
        if (tube == null) continue;
        ground.add(Positioned(
          key: ValueKey('paint-tube-$k'),
          left: x - _tubeRoadPt / 2,
          top: foot.dy - _tubeRoadPt,
          width: _tubeRoadPt,
          height: _tubeRoadPt,
          child: PaintTubeArt(color: tube, road: true),
        ));
      }
      for (var k = picked + 1;; k++) {
        final x = foot.dx + (k * spacing - widget.shownM) * spot.groundPtPerM;
        if (x - r > spot.size.width) break;
        final variant = k % drops.length;
        ground.add(Positioned(
          key: ValueKey('paint-drop-$k'),
          left: x - r,
          top: foot.dy - size,
          width: size,
          height: size,
          child: _art(drops[variant], color, _DropKind.values[variant % 2]),
        ));
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: SceneTinted(
            tint: spot.tint,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ...ground,
                if (_picking && !still)
                  AnimatedBuilder(
                    animation: _pick,
                    builder: (context, _) {
                      final t = _pick.value * _totalSec;
                      if (t < pickup.pressedSec) {
                        return Positioned(
                          key: const ValueKey('paint-drop-pressed'),
                          left: foot.dx - r,
                          top: foot.dy - size,
                          width: size,
                          height: size,
                          child: _art(pressed, color, _DropKind.pressed),
                        );
                      }
                      final u = (t - pickup.pressedSec) / pickup.splashSec;
                      if (u >= 1) return const SizedBox.shrink();
                      final scale = pickup.splashScaleFrom +
                          (pickup.splashScaleTo - pickup.splashScaleFrom) * u;
                      return Positioned(
                        key: const ValueKey('paint-drop-splash'),
                        left: foot.dx - size,
                        top: foot.dy - size * 1.5,
                        width: size * 2,
                        height: size * 2,
                        child: Opacity(
                          opacity: (1 - u).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale,
                            child: _art(splash, color, _DropKind.splash),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        if (_picking)
          AnimatedBuilder(
            animation: _pick,
            builder: (context, _) {
              final g = (_pick.value * _totalSec / pickup.gainFloatSec).clamp(0.0, 1.0);
              if (g >= 1) return const SizedBox.shrink();
              final head = foot.dy - spot.figureHeight;
              final rise = still ? 0.0 : spot.figureHeight * _gainRise * Curves.easeOut.transform(g);
              return Positioned(
                left: foot.dx - 60,
                width: 120,
                top: head - size - rise,
                child: Opacity(
                  opacity: 1 - g,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+${rules.paintDropCoinsPerDrop} 럭',
                          key: const ValueKey('paint-drop-gain'),
                          style: context.display(16, color: Palette.ink),
                        ),
                        if (_pickedTube case final tube?) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            key: const ValueKey('paint-drop-gain-tube'),
                            width: _tubeIconPt,
                            height: _tubeIconPt,
                            child: PaintTubeArt(color: tube),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// 그림 [path]에 물감 색 [color]를 곱해 그린다. 그림이 없거나 못 읽으면 코드로 그린 임시 [kind]
  Widget _art(String? path, Color color, _DropKind kind) {
    final temp = CustomPaint(painter: _DropPainter(color, kind));
    return path == null
        ? temp
        : Image.asset(
            path,
            color: color,
            colorBlendMode: BlendMode.modulate,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => temp,
          );
  }
}

/// 임시 그림의 종류: 방울 두 모양(A 둥근·B 조금 기운), 눌린 방울(C), 튐
enum _DropKind { a, b, pressed, splash }

/// 코드로 그린 임시 방울 (상자 크기에 맞춘다, 아래 가운데가 땅)
class _DropPainter extends CustomPainter {
  _DropPainter(this.color, this.kind);

  final Color color;
  final _DropKind kind;

  @override
  void paint(Canvas canvas, Size box) {
    final r = math.min(box.width, box.height) / 2;
    final c = Offset(box.width / 2, box.height - r);
    switch (kind) {
      case _DropKind.a:
      case _DropKind.b:
        final lean = kind == _DropKind.b ? r * 0.08 : 0.0;
        _shadow(canvas, c.translate(0, r * 0.95), r * 1.4, r * 0.35);
        canvas.drawCircle(c.translate(lean, 0), r, Paint()..color = color.withValues(alpha: 0.35));
        canvas.drawCircle(
            c.translate(lean, r * 0.08), r * 0.68, Paint()..color = color.withValues(alpha: 0.85));
        canvas.drawCircle(c.translate(lean - r * 0.25, -r * 0.22), r * 0.16,
            Paint()..color = Colors.white.withValues(alpha: 0.7));
      case _DropKind.pressed:
        // 밟혀 납작해진 방울
        final low = c.translate(0, r * 0.55);
        _shadow(canvas, c.translate(0, r * 0.95), r * 1.8, r * 0.35);
        canvas.drawOval(Rect.fromCenter(center: low, width: r * 2.2, height: r * 0.9),
            Paint()..color = color.withValues(alpha: 0.4));
        canvas.drawOval(Rect.fromCenter(center: low, width: r * 1.6, height: r * 0.6),
            Paint()..color = color.withValues(alpha: 0.85));
      case _DropKind.splash:
        // 가운데 번짐과 사방으로 튄 작은 방울
        canvas.drawCircle(c, r * 0.5, Paint()..color = color.withValues(alpha: 0.35));
        final dot = Paint()..color = color.withValues(alpha: 0.85);
        for (var i = 0; i < 7; i++) {
          final a = math.pi * (1.05 + i / 6 * 0.9);
          canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.85, r * 0.13, dot);
        }
    }
  }

  void _shadow(Canvas canvas, Offset at, double width, double height) => canvas.drawOval(
        Rect.fromCenter(center: at, width: width, height: height),
        Paint()..color = Palette.ink.withValues(alpha: 0.15),
      );

  @override
  bool shouldRepaint(_DropPainter old) => old.color != color || old.kind != kind;
}
