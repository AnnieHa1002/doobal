import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle;

import '../../domain/boat.dart';

// 배 판 그림 읽기 (T4c). 걷는 중 배 구간 장면과 상점 색 시트 미리보기가 같이 쓴다: 같은 그림·같은 계산이라
// 두 곳의 색이 같다. 고른 색이 있으면 boats.json recolor대로 색 입힌 뒤판·앞판을 만든다.
// 색 층 그림이 없거나 읽지 못하면 원래 그림 그대로 (토스트 없이 로그만)

/// 읽은 배 판 (같은 캔버스·같은 원점). 받은 쪽이 dispose한다
typedef BoatLayerImages = ({ui.Image rear, ui.Image front, ui.Image? night});

/// [art]의 뒤판·앞판·창 불빛을 가로 [width]px로 읽는다. 고른 색([BoatArt.colors])이 있으면 색 입힌 판.
/// 뒤판이나 앞판 파일이 없으면 null
Future<BoatLayerImages?> loadBoatLayers(AssetBundle bundle, BoatArt art, int width) async {
  final rearBytes = await _assetOrNull(bundle, art.rear);
  final frontBytes = rearBytes == null ? null : await _assetOrNull(bundle, art.front);
  if (rearBytes == null || frontBytes == null) return null;
  final nightBytes = art.nightOverlay == null ? null : await _assetOrNull(bundle, art.nightOverlay!);
  final decoded = <ui.Image>[];
  try {
    for (final bytes in [rearBytes, frontBytes, ?nightBytes]) {
      decoded.add(await _decode(bytes, width: width));
    }
  } catch (_) {
    for (final image in decoded) {
      image.dispose();
    }
    rethrow;
  }
  var rear = decoded[0];
  var front = decoded[1];
  final night = nightBytes == null ? null : decoded[2];
  if (art.recolor != null && art.colors.isNotEmpty) {
    try {
      final painted = await paintBoatSides(bundle, art, rear, front);
      if (painted != null) {
        rear.dispose();
        front.dispose();
        (rear, front) = painted;
      }
    } catch (e) {
      debugPrint('배 색을 입히지 못했다 (${art.id}, 원래 색으로): $e');
    }
  }
  return (rear: rear, front: front, night: night);
}

/// 원래 그림 [rear]·[front](같은 크기)에 [art]의 고른 색을 입힌 두 판. 색 층 그림이 하나라도 없으면 null.
/// 원래 그림은 그대로 둔다 (부른 쪽 것)
Future<(ui.Image, ui.Image)?> paintBoatSides(
  AssetBundle bundle,
  BoatArt art,
  ui.Image rear,
  ui.Image front,
) async {
  final recolor = art.recolor!;
  final dir = art.recolorDir!;
  final out = <ui.Image>[];
  try {
    for (final (side, image) in [(BoatSide.rear, rear), (BoatSide.front, front)]) {
      final w = image.width;
      final h = image.height;
      final clean = await _pixels(image);
      final Uint8List painted;
      switch (recolor.method) {
        case RecolorMethod.materialIds:
          final fixed = await _layer(bundle, '$dir${recolor.fixed[side]}', w, h);
          final shading = <BoatZone, Uint8List>{};
          for (final z in recolor.zones) {
            final s = await _layer(bundle, '$dir${recolor.shading[side]![z]}', w, h);
            if (s == null) return null;
            shading[z] = s;
          }
          if (fixed == null) return null;
          final colors = art.colors;
          final midpoint = recolor.neutralMidpoint;
          final order = recolor.zones;
          painted = await Isolate.run(() => recolorByShading(
                clean: clean,
                fixed: fixed,
                shading: shading,
                colors: colors,
                midpoint: midpoint,
                order: order,
              ));
        case RecolorMethod.meanLuminance:
          final neutral = await _firstLayer(bundle, [for (final f in recolor.neutralFiles(side)) '$dir$f'], w, h);
          if (neutral == null) return null;
          final masks = <BoatZone, Uint8List>{};
          for (final z in recolor.zones) {
            if (!art.colors.containsKey(z)) continue;
            final m = await _firstLayer(
                bundle, [for (final f in recolor.maskFiles(side, z)) '$dir$f'], w, h,
                nearest: true);
            if (m == null) return null;
            masks[z] = m;
          }
          final colors = art.colors;
          final order = recolor.zones;
          painted = await Isolate.run(() {
            final means = <BoatZone, double>{
              for (final e in masks.entries) e.key: ?zoneMeanLuminance(neutral, e.value),
            };
            return recolorByNeutral(
              clean: clean,
              neutral: neutral,
              masks: masks,
              colors: colors,
              means: means,
              order: order,
            );
          });
      }
      out.add(await _image(painted, w, h));
    }
    return (out[0], out[1]);
  } catch (_) {
    for (final image in out) {
      image.dispose();
    }
    rethrow;
  }
}

/// 색 층 그림 한 장을 [w]×[h] 프리멀티플라이 RGBA로. 파일이 없으면 null.
/// [nearest]면 원래 크기로 읽은 뒤 가장 가까운 픽셀로 맞춘다 (마스크·인덱스는 보간하지 않는다)
Future<Uint8List?> _layer(AssetBundle bundle, String path, int w, int h, {bool nearest = false}) async {
  final key = (path, w, h, nearest);
  if (_cache.get(key) case final hit?) return hit;
  final bytes = await _assetOrNull(bundle, path);
  if (bytes == null) return null;
  Uint8List pixels;
  if (nearest) {
    final image = await _decode(bytes);
    try {
      pixels = resampleNearest(await _pixels(image), image.width, image.height, w, h);
    } finally {
      image.dispose();
    }
  } else {
    final image = await _decode(bytes, width: w, height: h);
    try {
      pixels = await _pixels(image);
    } finally {
      image.dispose();
    }
  }
  _cache.put(key, pixels);
  return pixels;
}

Future<Uint8List?> _firstLayer(AssetBundle bundle, List<String> paths, int w, int h,
    {bool nearest = false}) async {
  for (final p in paths) {
    if (await _layer(bundle, p, w, h, nearest: nearest) case final found?) return found;
  }
  return null;
}

Future<ui.Image> _decode(ByteData bytes, {int? width, int? height}) async {
  final codec = await ui.instantiateImageCodec(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    targetWidth: width,
    targetHeight: height,
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('배 그림을 픽셀로 읽지 못했다');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<ui.Image> _image(Uint8List pixels, int w, int h) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

Future<ByteData?> _assetOrNull(AssetBundle bundle, String path) async {
  try {
    return await bundle.load(path);
  } on FlutterError {
    return null;
  }
}

/// 읽은 색 층 (경로·크기마다). 색 시트에서 견본을 바꿀 때마다 그림을 다시 읽지 않게. 바이트 합이 넘치면 오래된 것부터 버린다
final _cache = _LayerCache(24 * 1024 * 1024);

@visibleForTesting
void clearBoatLayerCache() => _cache.clear();

class _LayerCache {
  _LayerCache(this.maxBytes);

  final int maxBytes;
  final _map = <Object, Uint8List>{};
  var _bytes = 0;

  Uint8List? get(Object key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v;
    return v;
  }

  void put(Object key, Uint8List v) {
    if (v.length > maxBytes) return;
    if (_map.remove(key) case final old?) _bytes -= old.length;
    _map[key] = v;
    _bytes += v.length;
    while (_bytes > maxBytes && _map.isNotEmpty) {
      final first = _map.keys.first;
      _bytes -= _map.remove(first)!.length;
    }
  }

  void clear() {
    _map.clear();
    _bytes = 0;
  }
}
