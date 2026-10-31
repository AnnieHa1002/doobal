import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../app/sync_service.dart';
import '../../domain/sketch.dart';

/// 공유 이미지의 화질: 화면 크기의 몇 배로 그릴지
const sharePixelRatio = 3.0;

/// 공유 글. TODO: 문구는 가안이다 (기획 확정 전)
String paintingShareText(OwnedPaintingView p) => p.isFirstPack
    ? '두발 첫 그림: $firstPackName'
    : '두발에서 걸어서 얻은 그림: ${p.landmark.name}';

final _badFileChars = RegExp(r'[\\/:*?"<>|]');

/// 공유할 파일 이름: 명소 이름, 첫 그림은 `첫 그림`. 파일 이름에 못 쓰는 글자는 `_`로 바꾼다
String paintingShareFileName(OwnedPaintingView p) {
  final name = p.isFirstPack ? firstPackLabel : p.landmark.name;
  return '${name.replaceAll(_badFileChars, '_')}.png';
}

/// [key]를 단 RepaintBoundary가 그린 것을 PNG 바이트로 만든다. 아직 그려지지 않았으면 null
Future<Uint8List?> capturePng(GlobalKey key, {double pixelRatio = sharePixelRatio}) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
