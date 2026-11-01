import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/camp_theme.dart';
import '../../domain/scene.dart';
import 'scene_painter.dart';

/// 승인된 v10·v11의 파일/배치 목록. 옛 중간 들판 config와 분리한다.
class SceneArt {
  SceneArt(this.data, this.images);
  final Map<String, dynamic> data;
  final Map<String, ui.Image> images;

  /// 배·물 그림은 [onSea](배 구간)일 때만 읽는다. 후경 이름이 sea여도 울릉도 섬 위라면
  /// 배에서 내린 땅이라 길·둑·나무를 읽는다 (그리는 쪽도 onSea로 고른다)
  static Future<SceneArt> load(
    AssetBundle bundle,
    SceneLook look,
    bool rest,
    double scale,
    double pixelRatio, {
    bool onSea = false,
  }) async {
    final data = jsonDecode(
      await bundle.loadString('assets/data/scene_art.json'),
    ) as Map<String, dynamic>;
    final assets = data['assets'] as Map<String, dynamic>;
    final region = (data['far'] as Map).containsKey(look.backdrop)
        ? look.backdrop
        : 'capital';
    final keys = <String>{...(data['far'][region] as List).cast<String>()};
    keys.addAll(
      assets.keys.where((k) => k.startsWith('sky_') && !k.contains('balloon')),
    );
    keys.addAll(['paper_grain_v01.png']);
    if (rest) {
      keys.addAll([
        'bg_rest_camp_back_${look.season.name}_preview',
        'bg_rest_camp_front_${look.season.name}_preview',
      ]);
      // 완성 PNG를 중복 보관하지 않고 본판과 회색 풀에만 계절색을 입힌다.
      keys.removeWhere((k) => k.endsWith('_preview'));
      keys.addAll([
        'bg_rest_camp_back_v11_clean.png',
        'bg_rest_camp_back_landscape_v12_clean.png',
        'bg_rest_camp_back_grass_v11_clean.png',
        'bg_rest_camp_front_v11_clean.png',
        'bg_rest_camp_front_grass_v11_clean.png',
        for (final n in ['01', '02', '03'])
          'fx_campfire_flame_${n}_v11_clean.png',
      ]);
    } else if (onSea) {
      keys.addAll([
        'bg_near_water_v11_clean.png',
        'prop_boat_01_v11_clean.png',
      ]);
    } else {
      keys.addAll([
        'bg_path_v11_clean.png',
        'bg_lower_bank_${look.season.name}_v11_clean.png',
        'bg_front_${look.season.name}_v11_clean.png',
        'bg_back_meadow_${look.season.name}_v10_preview.png',
      ]);
      for (final row in ['common', look.season.name]) {
        for (final tree in data['frontTrees'][row] as List) {
          keys.add(tree[0] as String);
        }
      }
      for (final tree in data['backTrees'] as List) {
        keys.add(tree[0] as String);
      }
      final tags = (data['tags'][region] as List).cast<String>();
      for (final item in data['clusters'] as List) {
        if ((item['tags'] as List).any(tags.contains)) {
          keys.add(item['id'] as String);
        }
      }
      for (final id in [
        'bg_object_utility_pole_a_v10',
        'bg_object_bush_a_v10',
        'bg_object_bush_b_v10',
      ]) {
        if (assets.containsKey(id)) keys.add(id);
      }
    }
    final images = <String, ui.Image>{};
    try {
      // 순차 디코딩으로 로드 순간의 메모리 급증을 제한한다.
      for (final key in keys) {
        final spec = assets[key] as Map<String, dynamic>;
        final bytes = await bundle.load(spec['file'] as String);
        final width = (spec['canvas'][0] as num).toDouble();
        final target = math
            .min(
              width,
              math.min(
                (width * scale * pixelRatio).ceilToDouble(),
                (data['sky']['maxDecodeWidth'] as num).toDouble(),
              ),
            )
            .round()
            .clamp(1, 4096);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          targetWidth: target,
        );
        try {
          images[key] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
      return SceneArt(data, images);
    } catch (_) {
      for (final image in images.values) {
        image.dispose();
      }
      rethrow;
    }
  }

  void dispose() {
    for (final image in images.values) {
      image.dispose();
    }
  }
}

/// 너비 기준으로 한 번 축소하고 바닥을 화면 아래에 맞춘다.
/// 짧은 폰·태블릿에서도 길과 캐릭터 발이 화면 아래로 빠지지 않는다.
class SceneArtLayout {
  SceneArtLayout(this.art, this.size, this.mode, this.onSea, this.camp) {
    final key = size.width > size.height ? 'landscape' : 'portrait';
    config = art.data[key] as Map<String, dynamic>;
    scale = key == 'portrait'
        ? size.width / n('width')
        : size.height / n('height');
    dy = size.height - n('height') * scale;
  }
  final SceneArt art;
  final Size size;
  final SceneMode mode;
  final bool onSea;
  final CampTheme? camp;
  late final Map<String, dynamic> config;
  late final double scale, dy;
  double n(String key) => (config[key] as num).toDouble();
  double y(double value) => dy + value * scale;
  bool get rest => mode == SceneMode.rest;
  bool get sea => onSea && !rest;
  double get figureHeight => n('figureHeight') * scale;
  Offset get foot {
    if (rest && camp != null) {
      return Offset(
        camp!.character.x * size.width,
        camp!.character.footY * size.height,
      );
    }
    final above = sea
        ? (art.data['boat']['deckAboveWater'] as num).toDouble()
        : 0;
    return Offset(size.width / 2, y(n('pathY') - above));
  }
}

/// 같은 여정·구간에서는 항상 같은 조각을 고른다. Dart hashCode에 의존하지 않는다.
int sceneArtHash(String seed, int segment) {
  var h = 2166136261;
  for (final c in '$seed:$segment'.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7fffffff;
  }
  return h;
}

class SceneArtHost extends StatefulWidget {
  const SceneArtHost({
    super.key,
    required this.look,
    required this.mode,
    required this.size,
    required this.builder,
    this.onSea = false,
  });
  final SceneLook look;
  final SceneMode mode;
  final Size size;

  /// 배 구간인가. 바뀌면 배·물 그림과 땅 그림을 바꿔 읽는다
  final bool onSea;
  final Widget Function(BuildContext, SceneArt?, double) builder;
  @override
  State<SceneArtHost> createState() => _SceneArtHostState();
}

class _SceneArtHostState extends State<SceneArtHost> {
  SceneArt? _art;
  Object? _key;
  Object? _loadedKey;
  Widget Function(BuildContext, SceneArt?, double)? _activeBuilder;
  int _generation = 0;
  double _elapsed = 0;
  Timer? _timer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(SceneArtHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final bundle = DefaultAssetBundle.of(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final scale = widget.size.width > widget.size.height
        ? widget.size.height / 1170
        : widget.size.width / 1170;
    final key = (
      bundle,
      widget.look.backdrop,
      widget.look.season,
      widget.mode,
      widget.onSea,
      (scale * ratio * 100).round(),
    );
    if (_key == key) {
      if (_loadedKey == key) _activeBuilder = widget.builder;
      return;
    }
    _key = key;
    final generation = ++_generation;
    SceneArt.load(
      bundle,
      widget.look,
      widget.mode == SceneMode.rest,
      scale,
      ratio,
      onSea: widget.onSea,
    ).then(
      (art) {
        if (!mounted || generation != _generation) {
          art.dispose();
          return;
        }
        final previous = _art;
        setState(() {
          _art = art;
          _loadedKey = key;
          _activeBuilder = widget.builder;
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previous?.dispose(),
        );
      },
      onError: (Object error, StackTrace stack) {
        if (mounted && generation == _generation) {
          // 옛 장면 builder에 멈춰 있지 않게, 지금 값으로 그리는 builder로 돌아간다
          setState(() => _activeBuilder = null);
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: '두발 배경',
              context: ErrorDescription('배경 파일을 읽는 중'),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = TickerMode.valuesOf(context).enabled && _art != null;
    if (enabled && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() => _elapsed += .1);
      });
    } else if (!enabled) {
      _timer?.cancel();
      _timer = null;
    }
    // 새 이미지가 준비될 때까지 계절·배·자세도 이전 완성 장면과 함께 유지한다.
    return (_activeBuilder ?? widget.builder)(context, _art, _elapsed);
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _art?.dispose();
    super.dispose();
  }
}
