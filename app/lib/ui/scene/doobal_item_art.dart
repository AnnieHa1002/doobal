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
      await loadSeatedArt();
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

  final _poseAssets = <String, rive.ImageAsset>{};
  final _poseOriginals = <String, rive.RenderImage>{};
  bool _seated = false;
  static const _bodyRestore = [
    'char_body_torso',
    'char_body_leg_upper_l',
    'char_body_leg_upper_r',
  ];
  Future<void> loadSeatedArt() async {
    for (final name in [
      'sit_lower_v04',
      'sit_torso_v04',
      'sit_body_torso_v04',
      'sit_hidden_v04',
      ..._bodyRestore.map((n) => '${n}_restore'),
    ]) {
      final bytes = await rootBundle.load('$root$name.png');
      final image = await rive.Factory.flutter.decodeImage(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      if (image == null) throw StateError('앉기 파츠 로딩 실패: $name');
      images[name] = image;
    }
  }

  bool get supportsSeatedArt => _poseAssets.length == 10;
  void setSeatedArt(bool value) {
    if (_seated == value) return;
    if (!supportsSeatedArt) throw StateError('앉기 파츠 연결이 빠졌어요');
    for (final entry in _poseAssets.entries) {
      final key = entry.key;
      final image = value
          ? images[key == 'item_cloth_01_torso'
                ? 'sit_torso_v04'
                : key == 'char_body_torso'
                ? 'sit_body_torso_v04'
                : 'sit_hidden_v04']!
          : _poseOriginals[key]!;
      if (!entry.value.renderImage(image)) {
        throw StateError('앉기 파츠 전환 실패: $key');
      }
    }
    _seated = value;
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
    if (_bodyRestore.contains(asset.name)) {
      final image = images['${asset.name}_restore']!;
      _poseAssets[asset.name] = asset;
      _poseOriginals[asset.name] = image;
      if (!asset.renderImage(image)) throw StateError('몸 파츠 연결 실패');
      return true;
    }
    for (final side in ['l', 'r']) {
      if (asset.name == 'char_body_leg_lower_$side') {
        _poseAssets[asset.name] = asset;
        _poseOriginals[asset.name] = images['foot_$side']!;
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
        if (key == 'cloth_torso' ||
            key.startsWith('cloth_leg_') ||
            key.startsWith('shoe_')) {
          _poseAssets[asset.name] = asset;
          _poseOriginals[asset.name] = images[key]!;
        }
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
    _poseAssets.clear();
    _poseOriginals.clear();
  }
}
