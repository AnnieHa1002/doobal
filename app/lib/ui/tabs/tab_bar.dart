import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../../domain/asset_index.dart';
import '../common/notice_dot.dart';
import '../common/palette.dart';
import 'home_tab.dart';

/// 탭 바 크기 (캔버스 부품 ‘아래 탭 바’ TabBar: 390×844 폰 84pt = 보이는 62 + 아래 22, 작은 폰 60 = 56 + 4)
abstract final class TabBarMetrics {
  static const content = 62.0;
  static const contentSmall = 56.0;

  /// 작은 폰 기준 (캔버스 375×667)
  static const smallScreenHeight = 700.0;
  static const icon = 28.0;
  static const underlineW = 18.0;
  static const underlineH = 3.0;

  /// 장면(쉼터·걷기 탭)이 탭 바 밑으로 들어가는 높이 (캔버스 2-2·3-1 sceneBottom = 탭 바 − 30)
  static const sceneOverlap = 30.0;

  /// 아래 여백: 안드로이드는 시스템 버튼 줄(3버튼 48dp·제스처 막대)을 다 비운다 (11/20 폰: 12pt 겹치면 탭 이름이
  /// 버튼 줄에 가렸다). iOS는 얇은 홈 막대라 12pt를 탭 바 안으로 겹친다 (캔버스: 홈 막대 34pt 폰에서 22).
  /// 안전 영역이 없는 폰은 4
  static double bottomPad(double safeBottom, [TargetPlatform? platform]) {
    if (safeBottom <= 0) return 4;
    if ((platform ?? defaultTargetPlatform) != TargetPlatform.iOS) return safeBottom < 4 ? 4 : safeBottom;
    return safeBottom > 16 ? safeBottom - 12 : 4;
  }

  /// 탭 바 전체 높이 (아래 여백 포함)
  static double height(Size screen, double safeBottom) =>
      (screen.height < smallScreenHeight ? contentSmall : content) + bottomPad(safeBottom);
}

/// 아래 탭 바 (16장 11/18 ①·11/19, 캔버스 TabBar): 쉼터·걷기·나. 카드색 바탕에 위 잉크 1.8 선,
/// 지금 탭은 잉크 글자 + 테라코타 밑줄 18×3, 나머지는 옅은 잉크.
/// 걷는 중이면 걷기 아이콘의 발자국 두 개가 0.9초에 번갈아 깜빡인다 (쉼터 위 글 없음, 움직임 줄이기면 멈춤).
/// 걷기 아이콘 점 = 안 읽은 이야기·방명록 쓸 기회 (config ui.tabs.dots.walk).
/// 나 아이콘은 정령 얼굴 자리 (앱이 Rive로 그릴 때까지 얼굴 모양 자리표시).
/// 쉼터·걷기 아이콘은 납품 그림([art])이 있으면 그것, 없으면 코드 그림
class DoobalTabBar extends StatelessWidget {
  const DoobalTabBar({
    super.key,
    required this.tabs,
    required this.labels,
    required this.current,
    required this.walking,
    required this.walkDot,
    required this.onTap,
    this.art = const TabIconArt(),
  });

  final TabIconArt art;

  final List<HomeTab> tabs;
  final Map<String, String> labels;
  final HomeTab current;

  /// 물감 길이 열려 있다 (걸음이 이어지는 중)
  final bool walking;
  final bool walkDot;
  final ValueChanged<HomeTab> onTap;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pad = TabBarMetrics.bottomPad(mq.viewPadding.bottom);
    return Container(
      key: const ValueKey('tab-bar'),
      height: TabBarMetrics.height(mq.size, mq.viewPadding.bottom),
      padding: EdgeInsets.only(bottom: pad, left: mq.viewPadding.left, right: mq.viewPadding.right),
      decoration: const BoxDecoration(
        color: Palette.card,
        border: Border(top: BorderSide(color: Palette.ink, width: InkLine.panel)),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: _TabItem(
                tab: t,
                label: labels[t.id] ?? t.id,
                active: t == current,
                walking: walking,
                dot: t == HomeTab.walk && walkDot,
                art: art,
                onTap: () => onTap(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.label,
    required this.active,
    required this.walking,
    required this.dot,
    required this.art,
    required this.onTap,
  });

  final HomeTab tab;
  final String label;
  final bool active;
  final bool walking;
  final bool dot;
  final TabIconArt art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Palette.ink : Palette.subInk;
    final walkingNow = tab == HomeTab.walk && walking;
    final icon = switch (tab) {
      HomeTab.rest => switch (art.rest) {
          final file? => _TabMask(file, color),
          null => CustomPaint(painter: _TentPainter(active: active)),
        },
      HomeTab.walk => _Footprints(active: active, walking: walkingNow, art: art),
      HomeTab.me => _FacePlaceholder(color: color),
    };
    final semantics = [
      label,
      if (walkingNow) '(걷는 중)',
      if (dot) '(새 소식 있음)',
    ].join(' ');
    return Semantics(
      button: true,
      selected: active,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('tab-${tab.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          // 작은 폰(보이는 56pt)이나 큰 글자에서 칸보다 크면 통째로 줄인다 (넘치지 않게)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: TabBarMetrics.icon,
                height: TabBarMetrics.icon,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: icon),
                    // 캔버스: 탭 가운데에서 오른쪽 10pt, 위 6pt (아이콘 기준 오른쪽 위)
                    if (dot)
                      const Positioned(
                        left: TabBarMetrics.icon / 2 + 10,
                        top: -6,
                        child: NoticeDot(key: ValueKey('tab-walk-dot')),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600, color: color),
              ),
              const SizedBox(height: 2),
              Container(
                width: TabBarMetrics.underlineW,
                height: TabBarMetrics.underlineH,
                decoration: BoxDecoration(
                  color: active ? Palette.terracotta : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// 탭 아이콘 그림 (codex_camp_deco_v01 T05, config ui.tabs.icons, assets/ui/). 흰 마스크라 탭 색을 입혀 그린다.
/// 없는 것은 null (코드 그림). 걷는 중 발자국은 step1·step2(한 발씩)를 번갈아 켜고 walk(두 발)를 옅게 깐다
/// (step3은 두 발 = walk와 같은 그림이라 안 씀)
class TabIconArt {
  const TabIconArt({this.rest, this.walk, this.stepA, this.stepB});

  factory TabIconArt.from(AssetIndex? assets) => assets == null
      ? const TabIconArt()
      : TabIconArt(
          rest: assets.sprite('icon_tab_camp_v01'),
          walk: assets.sprite('icon_tab_walk_v01'),
          stepA: assets.sprite('icon_tab_walk_step1_v01'),
          stepB: assets.sprite('icon_tab_walk_step2_v01'),
        );

  final String? rest;
  final String? walk;
  final String? stepA;
  final String? stepB;

  /// 걷기 아이콘을 그림으로 그릴 수 있다 (셋 다 있어야)
  bool get hasWalk => walk != null && stepA != null && stepB != null;
}

/// 흰 마스크 탭 아이콘 그림에 [color]를 입힌 것
class _TabMask extends StatelessWidget {
  const _TabMask(this.file, this.color);

  final String file;
  final Color color;

  @override
  Widget build(BuildContext context) => Image.asset(
        file,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        gaplessPlayback: true,
        cacheWidth: (TabBarMetrics.icon * MediaQuery.devicePixelRatioOf(context)).ceil(),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
}

/// 쉼터 아이콘: 텐트와 작은 불 (캔버스 TabBar svg). 지금 탭이면 텐트 #e6c99a·불 테라코타로 칠하고, 아니면 선만
class _TentPainter extends CustomPainter {
  const _TentPainter({required this.active});

  final bool active;

  static const _tentFill = Color(0xFFE6C99A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 28);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = active ? Palette.ink : Palette.subInk;
    final tent = Path()
      ..moveTo(3, 23)
      ..lineTo(13, 5)
      ..lineTo(23, 23)
      ..close();
    final door = Path()
      ..moveTo(13, 5)
      ..lineTo(13, 23)
      ..moveTo(10, 23)
      ..lineTo(13, 15)
      ..lineTo(16, 23);
    final fire = Path()
      ..moveTo(21, 23)
      ..quadraticBezierTo(23, 18, 25, 23);
    if (active) {
      canvas.drawPath(tent, Paint()..color = _tentFill);
      canvas.drawPath(fire, Paint()..color = Palette.terracotta);
    }
    canvas
      ..drawPath(tent, stroke)
      ..drawPath(door, stroke)
      ..drawPath(fire, stroke);
  }

  @override
  bool shouldRepaint(_TentPainter old) => old.active != active;
}

/// 걷기 아이콘: 발자국 두 개. 걷는 중이면 0.9초에 왼발·오른발이 번갈아 밝다 (캔버스 tbStepL·tbStepR, steps(1))
class _Footprints extends StatefulWidget {
  const _Footprints({required this.active, required this.walking, required this.art});

  final bool active;
  final bool walking;
  final TabIconArt art;

  @override
  State<_Footprints> createState() => _FootprintsState();
}

class _FootprintsState extends State<_Footprints> with SingleTickerProviderStateMixin {
  late final _step = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Footprints old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.walking && !MediaQuery.disableAnimationsOf(context);
    if (run && !_step.isAnimating) {
      _step.repeat();
    } else if (!run && _step.isAnimating) {
      _step
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.art;
    return AnimatedBuilder(
      animation: _step,
      builder: (context, _) {
        final key = ValueKey(widget.walking ? 'tab-walk-steps' : 'tab-walk-still');
        // 걷는 중이 아니면 둘 다 밝다
        final leftLit = !_step.isAnimating || _step.value < 0.5;
        final rightLit = !_step.isAnimating || _step.value >= 0.5;
        if (!art.hasWalk) {
          return CustomPaint(
            key: key,
            painter: _FootprintPainter(active: widget.active, leftLit: leftLit, rightLit: rightLit),
          );
        }
        // 그림: 두 발을 꺼진 불투명도로 깔고 밝은 발만 위에 (발마다 그림이 따로라 바꿔 끼우지 않고 숨긴다)
        final color = widget.active ? Palette.terracotta : Palette.subInk;
        return Stack(
          key: key,
          fit: StackFit.expand,
          children: [
            _TabMask(art.walk!, color.withValues(alpha: _FootprintPainter._dim)),
            Opacity(opacity: leftLit ? 1 : 0, child: _TabMask(art.stepA!, color)),
            Opacity(opacity: rightLit ? 1 : 0, child: _TabMask(art.stepB!, color)),
          ],
        );
      },
    );
  }
}

class _FootprintPainter extends CustomPainter {
  const _FootprintPainter({required this.active, required this.leftLit, required this.rightLit});

  final bool active;
  final bool leftLit;
  final bool rightLit;

  /// 꺼진 발의 불투명도 (캔버스 .25)
  static const _dim = 0.25;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 28);
    _foot(canvas, 9, 17, leftLit);
    _foot(canvas, 19, 13, rightLit);
  }

  void _foot(Canvas canvas, double cx, double cy, bool lit) {
    final base = active ? Palette.terracotta : Palette.subInk;
    final a = lit ? 1.0 : _dim;
    final fill = Paint()..color = base.withValues(alpha: a);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Palette.ink.withValues(alpha: a);
    final sole = Rect.fromCenter(center: Offset(cx, cy), width: 7.2, height: 10.8);
    final toes = [Offset(cx - 2.4, cy - 7.4), Offset(cx, cy - 8), Offset(cx + 2.3, cy - 7.4)];
    canvas.drawOval(sole, fill);
    for (final t in toes) {
      canvas.drawCircle(t, 1.1, fill);
    }
    // 지금 탭일 때만 잉크 테두리
    if (!active) return;
    canvas.drawOval(sole, stroke);
    for (final t in toes) {
      canvas.drawCircle(t, 1.1, stroke);
    }
  }

  @override
  bool shouldRepaint(_FootprintPainter old) =>
      old.active != active || old.leftLit != leftLit || old.rightLit != rightLit;
}

/// 나 아이콘 자리: 28pt 원(종이색 바탕, 탭 색 1.4 테두리) 안의 얼굴 모양.
/// 캔버스는 꾸민 정령 얼굴(앱이 Rive로)이다. 탭 바에 정령 하나를 더 띄우는 일은 성능을 본 뒤에 한다
class _FacePlaceholder extends StatelessWidget {
  const _FacePlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.paper,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: InkLine.pill),
      ),
      child: Icon(Icons.face_outlined, size: 20, color: color),
    );
  }
}
