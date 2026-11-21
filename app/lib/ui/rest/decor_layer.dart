import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/decor_service.dart';
import '../../app/sync_service.dart' show OwnedPaintingView;
import '../../domain/asset_index.dart';
import '../../domain/decor.dart';
import '../../domain/decor_place.dart';
import '../../domain/decor_rules.dart';
import '../../domain/rest_camera.dart';
import '../common/framed_painting.dart';
import '../common/item_cell.dart' show DashedBoxPainter;
import '../common/palette.dart';
import 'decor_edit.dart';

// 쉼터 장면 위의 꾸밈 물품 (16장 11/18 ③·11/19, M2~M6 AB). 그림 층(정령 뒤·앞)과 빛·누름 상자(맨 위)를 따로 둔다:
// 누르기 순서는 집은 물품 > 앞쪽 물품 > 정령 > 장면 밀기라서 누름 상자는 정령 위에 쌓는다.
// 좌표는 쉼터 장면 층(확대·밀기 전 기기 pt, RestGeometry.sx·sy)이고, 집은 물품만 화면 맨 위에 따로 그린다

/// 놓인 물품 하나를 그릴 값
class DecorView {
  const DecorView({required this.item, required this.spot, required this.layout, this.art, this.hung = const []});

  final DecorItem item;
  final DecorSpot spot;
  final DecorLayout layout;

  /// 그림 파일 (없으면 점선 자리표시 + 이름)
  final String? art;

  /// 칸마다 건 그림 (안 건 칸은 null)
  final List<OwnedPaintingView?> hung;

  String get id => item.id;

  /// 건 그림이 하나라도 있는가
  bool get hasHung => hung.any((p) => p != null);
}

/// 놓인 물품을 그리는 순서(뒤 → 앞)대로. 크기 값이 없는 물품·가지지 않은 물품은 뺀다
List<DecorView> decorViews({
  required DecorState state,
  required DecorCatalog catalog,
  required DecorStage stage,
  AssetIndex? assets,
  Map<String, OwnedPaintingView> paintings = const {},
}) {
  final spots = <DecorSpot>[
    for (final e in state.placed.entries)
      if (catalog.byId(e.key) case final item? when stage.canPlace(item))
        DecorSpot(
          decorId: e.key,
          foot: stage.fromRatio(e.value.xRatio, e.value.yRatio),
          flipped: e.value.flipped,
          placedUtc: e.value.placedUtc,
        ),
  ];
  return [
    for (final s in stage.drawOrder(spots))
      decorViewOf(catalog.byId(s.decorId)!, s, stage: stage, state: state, assets: assets, paintings: paintings),
  ];
}

DecorView decorViewOf(
  DecorItem item,
  DecorSpot spot, {
  required DecorStage stage,
  required DecorState state,
  AssetIndex? assets,
  Map<String, OwnedPaintingView> paintings = const {},
}) {
  final hungKeys = state.paintings[item.id] ?? const {};
  return DecorView(
    item: item,
    spot: spot,
    layout: stage.layout(item, spot.foot, flipped: spot.flipped),
    art: assets?.decorArt(item.art),
    hung: [for (var i = 0; i < item.paintingSlots; i++) paintings[hungKeys[i]]],
  );
}

/// 물품 그림 하나 ([layout.art] 상자를 꽉 채운다, 기기 pt ÷ 장면 pt = [k]).
/// 그림 파일이 없으면 보이는 상자에 점선 + 이름. 건 그림은 칸 자리에 액자째 (액자·그림은 앱이 얹는다)
class DecorPiece extends StatelessWidget {
  const DecorPiece({
    super.key,
    required this.view,
    required this.k,
    this.tint,
    this.selected = false,
    this.faded = false,
  });

  final DecorView view;
  final double k;

  /// 계절·시간대 보정 (config rest.decor.tint)
  final List<double>? tint;

  /// 고른 물품 (점선 테두리)
  final bool selected;

  /// 서랍 위로 끌어 치우려는 중 (흐리게)
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final l = view.layout;
    final art = l.art;
    Rect rel(SceneRect r) => Rect.fromLTWH((r.left - art.left) * k, (r.top - art.top) * k, r.width * k, r.height * k);
    final box = rel(l.box);
    final path = view.art;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    Widget body = Stack(
      clipBehavior: Clip.none,
      children: [
        if (path != null)
          Positioned.fill(
            child: Transform.flip(
              flipX: view.spot.flipped,
              child: Image.asset(
                path,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.medium,
                cacheWidth: (art.width * k * ratio).ceil().clamp(1, 2048),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          )
        else
          Positioned.fromRect(rect: box, child: _Placeholder(name: view.item.name)),
        for (final (i, slot) in l.slots.indexed)
          if (i < view.hung.length)
            Positioned.fromRect(
              rect: rel(slot),
              child: _HungPainting(painting: view.hung[i], showEmpty: path == null),
            ),
      ],
    );
    if (tint case final m?) body = ColorFiltered(colorFilter: ColorFilter.matrix(m), child: body);
    return Opacity(
      opacity: faded ? 0.45 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: body),
          if (selected)
            Positioned.fromRect(
              rect: box.inflate(4),
              child: const IgnorePointer(child: CustomPaint(painter: _SelectRing())),
            ),
        ],
      ),
    );
  }
}

/// 그림 없는 물품: 종이색 점선 상자 + 이름 (16장 11/6 그림 없는 소품 규칙)
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const ValueKey('decor-placeholder'),
        painter: DashedBoxPainter(fill: Palette.card.withValues(alpha: 0.72)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                maxLines: 1,
                style: const TextStyle(fontSize: 11, height: 1.2, color: Palette.subInk),
              ),
            ),
          ),
        ),
      );
}

/// 칸에 건 그림 (액자 등급은 그 그림 그대로). 안 건 칸은 자리표시일 때만 흐린 점선
class _HungPainting extends StatelessWidget {
  const _HungPainting({required this.painting, required this.showEmpty});

  final OwnedPaintingView? painting;
  final bool showEmpty;

  @override
  Widget build(BuildContext context) {
    final p = painting;
    if (p == null) {
      return showEmpty ? const CustomPaint(painter: DashedBoxPainter()) : const SizedBox.shrink();
    }
    return LayoutBuilder(builder: (context, box) {
      // 칸이 작아서 액자 띠도 칸 크기에 맞춘다 (화집 6pt는 100pt쯤 그림 기준)
      final thickness = (box.maxHeight * 0.06).clamp(1.0, 6.0);
      return p.isFirstPack
          ? FramedPainting.firstPack(thickness: thickness)
          : FramedPainting(landmark: p.landmark, frame: p.frame, thickness: thickness);
    });
  }
}

/// 고른 물품 둘레 점선 (테라코타)
class _SelectRing extends CustomPainter {
  const _SelectRing();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = InkLine.pill
      ..color = Palette.terracotta;
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    for (final m in (Path()..addRRect(box)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SelectRing old) => false;
}

/// 장면 층에 물품 그림을 놓는다 ([hidden]은 지금 집어서 화면 맨 위에 따로 그리는 물품)
List<Widget> decorArtWidgets(
  RestGeometry g,
  Iterable<DecorView> views, {
  List<double>? tint,
  String? selected,
  String? hidden,
}) => [
      for (final v in views)
        Positioned(
          key: ValueKey('decor-art-${v.id}'),
          left: g.sx(v.layout.art.left),
          top: g.sy(v.layout.art.top),
          width: v.layout.art.width * g.k,
          height: v.layout.art.height * g.k,
          child: IgnorePointer(
            child: Visibility(
              visible: v.id != hidden,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: DecorPiece(view: v, k: g.k, tint: tint, selected: v.id == selected),
            ),
          ),
        ),
    ];

/// 등불·석등 밤 빛 (반딧불 빛 RadialGradient 더하기를 물품 자리에서, 깜빡이지 않음). 낮이면 빈 목록
List<Widget> decorLightWidgets(RestGeometry g, Iterable<DecorView> views, DecorNightLight light, {required bool on}) => [
      if (on)
        for (final v in views)
          if (v.layout.lightAt case final at? when light.items.contains(v.id))
            Positioned(
              key: ValueKey('decor-light-${v.id}'),
              left: g.sx(at.x) - v.layout.lightRadius! * g.k,
              top: g.sy(at.y) - v.layout.lightRadius! * g.k,
              width: v.layout.lightRadius! * g.k * 2,
              height: v.layout.lightRadius! * g.k * 2,
              child: IgnorePointer(child: CustomPaint(painter: DecorGlowPainter(light))),
            ),
    ];

/// 빛 한 점: 가운데 [DecorNightLight.centerAlpha], 가장자리 0. 더하기로 합성
class DecorGlowPainter extends CustomPainter {
  const DecorGlowPainter(this.light);

  final DecorNightLight light;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = light.colors.isEmpty ? const [0xFFFFFFFF] : light.colors;
    final a = light.centerAlpha;
    final inner = Color(colors.first).withValues(alpha: a);
    final outer = Color(colors.last);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = light.additive ? BlendMode.plus : BlendMode.srcOver
        ..shader = RadialGradient(
          colors: [inner, outer.withValues(alpha: a * 0.5), outer.withValues(alpha: 0)],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(DecorGlowPainter old) => old.light != light;
}

/// 물품 누름 상자 (장면 맨 위, 앞쪽 물품이 위). 짧게 누르면 [onTap](누른 장면 자리), 길게 누르면 집기·끌기·놓기
List<Widget> decorHitWidgets(
  RestGeometry g,
  Iterable<DecorView> views, {
  required DecorDragger dragger,
  required void Function(DecorView v, ScenePoint at) onTap,
}) => [
      for (final v in views)
        Positioned(
          key: ValueKey('decor-hit-${v.id}'),
          left: g.sx(v.layout.box.left),
          top: g.sy(v.layout.box.top),
          width: v.layout.box.width * g.k,
          height: v.layout.box.height * g.k,
          child: Semantics(
            button: true,
            label: v.item.name,
            excludeSemantics: true,
            child: GestureDetector(
              key: ValueKey('decor-${v.id}'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => onTap(
                v,
                ScenePoint(v.layout.box.left + d.localPosition.dx / g.k, v.layout.box.top + d.localPosition.dy / g.k),
              ),
              onLongPressStart: (d) => dragger.pick(v.id, from: v.spot, global: d.globalPosition),
              onLongPressMoveUpdate: (d) => dragger.move(d.globalPosition),
              onLongPressEnd: (_) => dragger.drop(),
              onLongPressCancel: dragger.cancel,
            ),
          ),
        ),
    ];

/// 집은 물품과 뒤집기 버튼 (화면 맨 위, 손가락을 따라감). 장면 자리 → 화면 자리는 [toScreen]
class DecorHeldOverlay extends StatelessWidget {
  const DecorHeldOverlay({
    super.key,
    required this.edit,
    required this.dragger,
    required this.camera,
    required this.lift,
    required this.geometry,
    required this.viewOf,
    required this.placed,
    required this.flipButton,
    this.tint,
    this.onPaint,
  });

  final DecorEdit edit;
  final DecorDragger dragger;
  final ValueNotifier<RestCamera> camera;

  /// 장면을 들어 올린 만큼 (서랍이 열리면)
  final ValueListenable<double> lift;
  final RestGeometry geometry;

  /// [id]를 [foot]에 [flipped]로 둔 그릴 값 (놓인 물품이 아니어도)
  final DecorView? Function(String id, ScenePoint foot, bool flipped) viewOf;

  /// 놓인 물품 (고른 물품의 뒤집기 버튼 자리)
  final Map<String, DecorView> placed;

  /// 고른·집은 물품 옆 뒤집기 버튼 (config rest.decor.flipButton)
  final bool flipButton;
  final List<double>? tint;

  /// 고른 물품이 그림 거는 물품이면 ‘그림 걸기’ 버튼 (집은 동안은 없다)
  final void Function(DecorView v)? onPaint;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([edit, edit.foot, edit.overDrawer, camera, lift]),
      builder: (context, _) {
        final h = edit.held;
        final c = geometry.clamp(camera.value);
        final scale = geometry.k * c.zoom;
        ({double x, double y}) screen(double x, double y) {
          final p = geometry.toScreen(c, x, y);
          return (x: p.x, y: p.y - lift.value);
        }

        final children = <Widget>[];
        DecorView? tools;
        final foot = edit.foot.value;
        if (h != null && foot != null) {
          final v = viewOf(h.id, foot, h.flipped);
          if (v != null) {
            final a = v.layout.art;
            final at = screen(a.left, a.top);
            children.add(Positioned(
              key: const ValueKey('decor-held'),
              left: at.x,
              top: at.y,
              width: a.width * scale,
              height: a.height * scale,
              child: IgnorePointer(
                child: DecorPiece(view: v, k: scale, tint: tint, selected: true, faded: edit.overDrawer.value),
              ),
            ));
            tools = v;
          }
        } else if (edit.selected case final id?) {
          tools = placed[id];
        }
        final paint = onPaint;
        final buttons = <Widget>[
          if (flipButton && tools != null && !edit.overDrawer.value)
            _ToolButton(
              key: const ValueKey('decor-flip-button'),
              icon: Icons.swap_horiz,
              label: '좌우 뒤집기',
              onTap: dragger.flip,
            ),
          if (paint != null && h == null && tools != null && tools.item.paintingSlots > 0)
            _ToolButton(
              key: const ValueKey('decor-paint-button'),
              icon: Icons.image_outlined,
              label: '그림 걸기',
              onTap: () => paint(tools!),
            ),
        ];
        if (tools != null && buttons.isNotEmpty) {
          final b = tools.layout.box;
          final top = screen(b.centerX, b.top);
          children.add(Positioned(
            key: const ValueKey('decor-tools'),
            left: top.x - _ToolButton.size * buttons.length / 2,
            top: top.y - _ToolButton.size - 6,
            child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
          ));
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

/// 고른 물품 위 동그란 버튼 (44pt 누름 자리): 좌우 뒤집기·그림 걸기
class _ToolButton extends StatelessWidget {
  const _ToolButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Palette.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.ink, width: InkLine.pill),
                  boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
                ),
                child: Icon(icon, size: 20, color: Palette.ink),
              ),
            ),
          ),
        ),
      );
}
