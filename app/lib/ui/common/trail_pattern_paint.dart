import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/paint_pattern_rules.dart';
import '../../domain/rules.dart';
import '../../domain/trail_layout.dart';

// 물감 길 무늬 그리기 (T17b, config mapTrail.paint·mapTrail.patterns): 지도와 하루 카드 엽서가 같이 쓴다.
// 무늬 그림(trails.json tile 512×64·cap 64×64 회색조, assets/ui/)이 있으면 그림 묶음을 그 자리 방향으로 돌려 붙이고
// RGB × 구간 색, 없으면(config paintPattern.missingArt drawAsDefault) 기본 방울 — 방울 그림도 없으면 코드로 그린 방울.
// 모든 모양 아래에 같은 모양을 테두리 색으로 조금 크게 먼저 깐다 (낮: 잉크 25% 1pt, 밤 지도: #D9E4EF 1.2pt)

/// 무늬 하나의 그림 두 장 (타일·끝)
class TrailPatternImages {
  const TrailPatternImages({required this.tile, required this.cap});

  final ui.Image tile;
  final ui.Image cap;
}

/// 읽어 둔 무늬 그림. 그림이 둘 다 있는 무늬만 든다
class TrailArt {
  const TrailArt({required this.defaultId, this.images = const {}});

  /// 그림이 하나도 없음 (모두 코드 방울)
  const TrailArt.none(this.defaultId) : images = const {};

  final String defaultId;
  final Map<String, TrailPatternImages> images;

  /// 구간 무늬 [patternId](null = 기본)를 실제로 그릴 무늬: 그림이 없는 무늬는 기본 무늬로 (missingArt drawAsDefault)
  String drawn(String? patternId) {
    final id = patternId ?? defaultId;
    return images.containsKey(id) ? id : defaultId;
  }

  TrailPatternImages? of(String id) => images[id];
}

/// 무늬 그림 읽기: trails.json 무늬마다 tile·cap 그림이 앱에 있으면(AssetIndex.sprite, assets/ui/) 읽는다.
/// 그림 묶음(trail_app_assets_v01)을 받기 전에는 비어 있다 (모든 구간이 코드 방울)
final trailArtProvider = FutureProvider<TrailArt>((ref) async {
  final catalog = await ref.watch(trailCatalogProvider.future);
  final assets = await ref.watch(assetIndexProvider.future);
  final images = <String, TrailPatternImages>{};
  for (final p in catalog.patterns) {
    final tile = assets.sprite(p.tile);
    final cap = assets.sprite(p.cap);
    if (tile == null || cap == null) continue;
    try {
      images[p.id] = TrailPatternImages(tile: await _loadImage(tile), cap: await _loadImage(cap));
    } catch (e) {
      debugPrint('무늬 그림 읽기 실패 (${p.id}, 기본 방울로): $e');
    }
  }
  return TrailArt(defaultId: catalog.defaultId, images: images);
});

Future<ui.Image> _loadImage(String path) async {
  final data = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

/// 그리는 크기·테두리 (모두 화면 pt, [k]를 곱해 px)
class TrailPaintStyle {
  const TrailPaintStyle({
    required this.k,
    required this.heightPt,
    required this.capPt,
    required this.chunkPx,
    required this.outlineColor,
    required this.outlinePt,
    this.dropGap = 0.9,
  });

  /// 화면 1pt의 px
  final double k;

  /// 반복 무늬 높이 (= 선 두께)와 끝 모양 지름
  final double heightPt;
  final double capPt;

  /// 그림 묶음 가로 px (그림 높이 px에 맞춘 값, config mapTrail.patterns.curve.chunkPx)
  final double chunkPx;

  /// 모양 아래 테두리: 색(진하기 포함)과 바깥으로 더 크게 할 pt
  final Color outlineColor;
  final double outlinePt;

  /// 코드 방울 사이 = 지름 × 이 값 (그림 납품 전 화면 구성값)
  final double dropGap;
}

/// 지도·엽서 물감 길 그리기 값: 크기는 config mapTrail.paint(높이·끝), 묶음은 mapTrail.patterns.curve, 테두리는 낮이면
/// mapTrail.paint.border(잉크 25% 1pt), [night]면 mapTrail.patterns.night(#D9E4EF 1.2pt, 16장 11/20 Q010 ①)
TrailPaintStyle trailPaintStyle(MapTrailRules trail, PaintPatternRules patterns,
        {required double k, required bool night}) =>
    TrailPaintStyle(
      k: k,
      heightPt: trail.paintHeightPt,
      capPt: trail.paintCapPt,
      chunkPx: patterns.curveChunkPx,
      outlineColor: night
          ? Color(patterns.nightOutlineColor)
          : Color(trail.borderColor).withValues(alpha: trail.borderAlpha),
      outlinePt: night ? patterns.nightOutlinePt : trail.borderExtraPt,
    );

/// 무늬 놓기 규칙 (config mapTrail.paint.capPt·mapTrail.patterns)
TrailLayoutRules trailLayoutRules(MapTrailRules trail, PaintPatternRules patterns) => TrailLayoutRules(
      capPt: trail.paintCapPt,
      shortUnderPt: patterns.shortUnderPt,
      shortGapPt: patterns.shortGapPt,
      switchGapPt: patterns.switchGapPt,
    );

/// [layout] 한 줄을 그린다. [colorOf]는 물감 색 id → 색(불투명). 무늬 그림이 없는 구간은 [layout]을 만들 때 이미
/// 기본 무늬로 바뀌어 있다 ([TrailArt.drawn]). [skip]에 든 무늬는 그리지 않는다 (엽서는 기본 방울을 붓 선으로 따로)
void paintTrailRun(
  Canvas canvas,
  TrailRunLayout layout,
  TrailArt art,
  TrailPaintStyle style,
  Color Function(String colorId) colorOf, {
  Set<String> skip = const {},
}) {
  for (final outline in [true, false]) {
    for (final span in layout.spans) {
      if (skip.contains(span.patternId)) continue;
      final images = art.of(span.patternId);
      if (images == null) {
        _dropSpan(canvas, layout, span, style, colorOf, outline: outline);
      } else {
        _tileSpan(canvas, layout, span, images.tile, style, colorOf, outline: outline);
      }
    }
    for (final cap in layout.caps) {
      if (skip.contains(cap.patternId)) continue;
      final images = art.of(cap.patternId);
      final pose = layout.line.at(cap.d);
      final color = colorOf(cap.colorId);
      if (images == null) {
        _drop(canvas, Offset(pose.x, pose.y), style.capPt / 2 * style.k, style, color, outline: outline);
      } else {
        final size = style.capPt * style.k;
        _image(canvas, images.cap, Offset.zero & Size(images.cap.width.toDouble(), images.cap.height.toDouble()),
            Offset(pose.x, pose.y), cap.start ? pose.angle + math.pi : pose.angle, Size(size, size), style, color,
            outline: outline);
      }
    }
  }
}

/// 코드 방울: 옅은 번짐 + 진한 속, 테두리는 반지름 + outlinePt
void _drop(Canvas canvas, Offset at, double r, TrailPaintStyle style, Color color, {required bool outline}) {
  if (outline) {
    canvas.drawCircle(at, r + style.outlinePt * style.k, Paint()..color = style.outlineColor);
    return;
  }
  canvas
    ..drawCircle(at, r, Paint()..color = color.withValues(alpha: 0.35))
    ..drawCircle(at, r * 0.62, Paint()..color = color.withValues(alpha: 0.85));
}

void _dropSpan(Canvas canvas, TrailRunLayout layout, TrailSpan span, TrailPaintStyle style,
    Color Function(String) colorOf, {required bool outline}) {
  final r = style.heightPt / 2 * style.k;
  final step = style.heightPt * style.dropGap * style.k;
  for (var d = span.from; d <= span.to + 1e-9; d += step) {
    final pose = layout.line.at(d);
    _drop(canvas, Offset(pose.x, pose.y), r, style, colorOf(layout.colorAt(d)), outline: outline);
  }
}

/// 타일 그림을 묶음(chunkPx)마다 그 자리 방향으로 돌려 붙인다 (config mapTrail.patterns.curve perChunk)
void _tileSpan(Canvas canvas, TrailRunLayout layout, TrailSpan span, ui.Image tile, TrailPaintStyle style,
    Color Function(String) colorOf, {required bool outline}) {
  final h = style.heightPt * style.k;
  // 그림 1px = 화면 h / 그림 높이 px
  final pxPerSrc = h / tile.height;
  final chunkLen = style.chunkPx * pxPerSrc;
  for (final c in TrailRunLayout.chunks(span, chunkLen)) {
    final pose = layout.line.at(c.from + c.length / 2);
    final srcX = (c.index * style.chunkPx) % tile.width;
    final srcW = math.min(c.length / pxPerSrc, tile.width - srcX);
    _image(canvas, tile, Rect.fromLTWH(srcX, 0, srcW, tile.height.toDouble()), Offset(pose.x, pose.y),
        pose.angle, Size(srcW * pxPerSrc, h), style, colorOf(layout.colorAt(c.from + c.length / 2)),
        outline: outline);
  }
}

/// 그림 [src] 부분을 [at] 가운데·[angle] 방향·[size] 크기로. 테두리면 그 모양을 테두리 색으로 outlinePt 크게,
/// 아니면 RGB × [color] (config mapTrail.paint.tint segmentColor)
void _image(Canvas canvas, ui.Image image, Rect src, Offset at, double angle, Size size, TrailPaintStyle style,
    Color color, {required bool outline}) {
  var dst = Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (outline) {
    dst = dst.inflate(style.outlinePt * style.k);
    paint.colorFilter = ColorFilter.mode(style.outlineColor, BlendMode.srcIn);
  } else {
    paint.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
  }
  canvas
    ..save()
    ..translate(at.dx, at.dy)
    ..rotate(angle)
    ..drawImageRect(image, src, dst, paint)
    ..restore();
}

/// 무늬 그림을 아직 못 읽었으면(읽는 중·실패) 그림 없음 = 모두 기본 무늬 [defaultId]
TrailArt trailArtOrNone(AsyncValue<TrailArt> art, String defaultId) => art.value ?? TrailArt.none(defaultId);
