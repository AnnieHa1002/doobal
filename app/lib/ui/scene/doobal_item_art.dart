import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

/// 각 캐릭터가 소유하는 이미지. 파일과 컨트롤러보다 오래 유지한다.
class DoobalItemArt {
  final images = <String, rive.RenderImage>{};
  static const root = 'assets/items/basic_v02/';
  static const parts = [
    'hat',
    'hand',
    'pet',
    'bag_back',
    'bag_strap',
    'cloth_torso',
    'cloth_arm_upper_l',
    'cloth_arm_upper_r',
    'cloth_arm_lower_l',
    'cloth_arm_lower_r',
    'cloth_leg_upper_l',
    'cloth_leg_upper_r',
    'cloth_shoulder_r',
    'shoe_l',
    'shoe_r',
  ];
  static String filename(String key) {
    final split = key.indexOf('_');
    return split < 0
        ? 'item_${key}_01_v02_clean.png'
        : 'item_${key.substring(0, split)}_01_${key.substring(split + 1)}_v02_clean.png';
  }

  Future<void> load() async {
    try {
      await loadFootMasks();
      for (final part in parts) {
        final data = await rootBundle.load('$root${filename(part)}');
        final image = await rive.Factory.flutter.decodeImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        if (image == null) throw StateError('소품 이미지를 읽지 못했어요: $part');
        images[part] = image;
      }
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  int replacements = 0;
  Future<void> loadFootMasks() async {
    for (final side in ['l', 'r']) {
      final data = await rootBundle.load(
        '${root}char_body_leg_lower_$side.png',
      );
      final image = await rive.Factory.flutter.decodeImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      if (image == null) throw StateError('신발 가림 이미지를 읽지 못했어요');
      images['foot_$side'] = image;
    }
  }

  bool assetLoader(rive.FileAsset asset, Uint8List? bytes) {
    if (asset is! rive.ImageAsset) return false;
    for (final side in ['l', 'r']) {
      if (asset.name == 'char_body_leg_lower_$side') {
        if (!asset.renderImage(images['foot_$side']!)) {
          throw StateError('신발 가림 연결 실패');
        }
        return true;
      }
    }
    for (final key in parts.where(
      (p) => p.startsWith('cloth_') || p.startsWith('shoe_'),
    )) {
      final name = filename(key).replaceFirst('_v02_clean.png', '');
      if (asset.name == name) {
        if (!asset.renderImage(images[key]!)) {
          throw StateError('소품 연결 실패: $name');
        }
        replacements++;
        return true;
      }
    }
    return false;
  }

  Future<void> decodeArm() async {
    final data = await rootBundle.load('${root}char_body_arm_lower_r.png');
    final image = await rive.Factory.flutter.decodeImage(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    if (image != null) images['arm'] = image;
  }

  void dispose() {
    for (final image in images.values) {
      image.dispose();
    }
    images.clear();
  }
}
