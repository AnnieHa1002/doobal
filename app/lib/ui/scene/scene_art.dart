import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/boat.dart';
import '../../domain/camp_theme.dart';
import '../../domain/scene.dart';
import '../../domain/scene_plan.dart';
import 'scene_painter.dart';

export '../../domain/scene_plan.dart' show sceneArtHash;

/// 승인된 v10·v11의 파일/배치 목록. 옛 중간 들판 config와 분리한다.
class SceneArt {
  SceneArt(this.data, this.images, {this.boat, this.wideCamp, this.plan});
  final Map<String, dynamic> data;
  final Map<String, ui.Image> images;

  /// 조각 고르기·배치 (scene.json)
  final ScenePlan? plan;

  /// 그림 파일 이름 → assets 키 (scene.json은 파일 이름으로 적는다)
  late final Map<String, String> _keyOfFile = {
    for (final e in (data['assets'] as Map<String, dynamic>).entries)
      ((e.value as Map)['file'] as String).split('/').last: e.key,
  };

  String? assetKeyOf(String file) => _keyOfFile[file];

  final _placed = <String, List<PlacedPiece>>{};

  /// 주기 하나의 조각 배치. 주기당 한 번만 계산한다
  List<PlacedPiece> placed(
    SceneRow row, {
    required String seed,
    required String region,
    required String season,
    required int cycleIndex,
  }) =>
      _placed.putIfAbsent(
        '$seed:$region:$season:${row.name}:$cycleIndex',
        () => plan!.place(row, seed: seed, region: region, season: season, cycleIndex: cycleIndex),
      );

  /// 넓은 캠프 그림 4장. 아직 납품 전이면 null이고 v11 캠프 + 빈 땅으로 그린다
  final WideCampImages? wideCamp;

  /// 고른 배의 판 그림. 파일이 아직 없으면 null이고 옛 배 한 장(prop_boat_01)으로 그린다
  final BoatImages? boat;

  /// 배·물 그림은 [onSea](배 구간)일 때만 읽는다. 후경 이름이 sea여도 울릉도 섬 위라면
  /// 배에서 내린 땅이라 길·둑·나무를 읽는다 (그리는 쪽도 onSea로 고른다)
  static Future<SceneArt> load(
    AssetBundle bundle,
    SceneLook look,
    bool rest,
    double scale,
    double pixelRatio, {
    bool onSea = false,
    BoatArt? boat,
    double? restFarWidthPx,
  }) async {
    final data = jsonDecode(
      await bundle.loadString('assets/data/scene_art.json'),
    ) as Map<String, dynamic>;
    final assets = data['assets'] as Map<String, dynamic>;
    final plan = ScenePlan.fromJson(
      jsonDecode(await bundle.loadString('assets/data/scene.json')) as Map<String, dynamic>,
    );
    final region = (data['far'] as Map).containsKey(look.backdrop)
        ? look.backdrop
        : 'capital';
    final farParts = (data['far'][region] as List).cast<String>();
    // 쉼터는 후경이 앞쪽만 보인다 (restFarWidthPx: 보일 수 있는 폭, 그림 px)
    final keys = <String>{
      ...restFarWidthPx == null
          ? farParts
          : farParts.take(
              (restFarWidthPx / ((data['portrait']['farWidth'] as num) / farParts.length))
                  .ceil()
                  .clamp(1, farParts.length),
            ),
    };
    keys.addAll(
      assets.keys.where((k) => k.startsWith('sky_') && !k.contains('balloon')),
    );
    keys.addAll(['paper_grain_v01.png']);
    WideCampImages? wide;
    if (rest) {
      wide = await WideCampImages.load(bundle, scale * pixelRatio, data);
      // 완성 PNG를 중복 보관하지 않고 본판과 회색 풀에만 계절색을 입힌다.
      keys.addAll([
        if (wide == null) ...[
          'bg_rest_camp_back_v11_clean.png',
          'bg_rest_camp_back_grass_v11_clean.png',
          'bg_rest_camp_front_v11_clean.png',
          'bg_rest_camp_front_grass_v11_clean.png',
        ],
        for (final n in ['01', '02', '03'])
          'fx_campfire_flame_${n}_v11_clean.png',
      ]);
    } else if (onSea) {
      keys.add('bg_near_water_v11_clean.png');
    } else {
      keys.addAll([
        'bg_path_v11_clean.png',
        'bg_lower_bank_${look.season.name}_v11_clean.png',
        'bg_front_${look.season.name}_v11_clean.png',
        'bg_back_meadow_${look.season.name}_v10_preview.png',
      ]);
      // 이 지역·계절에 설 수 있는 조각만 읽는다
      final byFile = <String, String>{
        for (final e in assets.entries)
          ((e.value as Map)['file'] as String).split('/').last: e.key,
      };
      for (final row in SceneRow.values) {
        for (final piece in plan.eligible(row, region, look.season.name)) {
          final key = byFile[piece.file];
          if (key != null) keys.add(key);
        }
      }
    }
    final images = <String, ui.Image>{};
    BoatImages? boatImages;
    try {
      if (onSea && !rest) {
        if (boat != null) {
          boatImages = await _loadBoat(bundle, boat, scale * pixelRatio, data);
        }
        if (boatImages == null) keys.add('prop_boat_01_v11_clean.png');
      }
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
      return SceneArt(data, images, boat: boatImages, wideCamp: wide, plan: plan);
    } catch (_) {
      for (final image in images.values) {
        image.dispose();
      }
      boatImages?.dispose();
      wide?.dispose();
      rethrow;
    }
  }

  /// 고른 배의 뒤판·앞판·창 불빛을 읽는다. 뒤판이나 앞판 파일이 아직 없으면 null
  static Future<BoatImages?> _loadBoat(
    AssetBundle bundle,
    BoatArt art,
    double pixelsPerArtPx,
    Map<String, dynamic> data,
  ) async {
    final rear = await _assetOrNull(bundle, art.rear);
    final front = rear == null ? null : await _assetOrNull(bundle, art.front);
    if (rear == null || front == null) return null;
    final night = art.nightOverlay == null ? null : await _assetOrNull(bundle, art.nightOverlay!);
    final width = math
        .min(
          art.canvasWidth,
          math.min(
            (art.canvasWidth * pixelsPerArtPx).ceilToDouble(),
            (data['sky']['maxDecodeWidth'] as num).toDouble(),
          ),
        )
        .round()
        .clamp(1, 4096);
    final decoded = <ui.Image>[];
    try {
      for (final bytes in [rear, front, ?night]) {
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          targetWidth: width,
        );
        try {
          decoded.add((await codec.getNextFrame()).image);
        } finally {
          codec.dispose();
        }
      }
    } catch (_) {
      for (final image in decoded) {
        image.dispose();
      }
      rethrow;
    }
    return BoatImages(art, decoded[0], decoded[1], night == null ? null : decoded[2]);
  }

  static Future<ByteData?> _assetOrNull(AssetBundle bundle, String path) async {
    try {
      return await bundle.load(path);
    } on FlutterError {
      return null;
    }
  }

  void dispose() {
    for (final image in images.values) {
      image.dispose();
    }
    boat?.dispose();
    wideCamp?.dispose();
  }
}

/// 넓은 캠프 그림 4장 (scene.json rest.files). 파일 이름과 세로 자리는 scene.json이 정하고,
/// 모두 있어야 쓴다. WebP를 먼저 찾고 없으면 적힌 PNG를 찾는다
class WideCampImages {
  WideCampImages(this.back, this.backGrass, this.front, this.frontGrass, this.backY, this.frontY, this.widthPx);

  final ui.Image back, backGrass, front, frontGrass;

  /// 뒤판·앞판의 세로 자리와 장면 폭 (그림 px)
  final double backY, frontY, widthPx;

  static const dir = 'assets/backgrounds/v11';

  static Future<WideCampImages?> load(
    AssetBundle bundle,
    double pixelsPerArtPx,
    Map<String, dynamic> data,
  ) async {
    final rest = (jsonDecode(await bundle.loadString('assets/data/scene.json')) as Map)['rest'] as Map;
    final files = rest['files'] as Map;
    final widthPx = (rest['widthPx'] as num).toDouble();
    final found = <ByteData>[];
    for (final key in ['back', 'backGrass', 'front', 'frontGrass']) {
      final name = files[key] as String;
      final bytes = await SceneArt._assetOrNull(bundle, '$dir/${name.replaceAll('.png', '.webp')}') ??
          await SceneArt._assetOrNull(bundle, '$dir/$name');
      if (bytes == null) return null;
      found.add(bytes);
    }
    final width = math
        .min(
          widthPx,
          math.min(
            (widthPx * pixelsPerArtPx).ceilToDouble(),
            (data['sky']['maxDecodeWidth'] as num).toDouble(),
          ),
        )
        .round()
        .clamp(1, 4096);
    final decoded = <ui.Image>[];
    try {
      for (final bytes in found) {
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          targetWidth: width,
        );
        try {
          decoded.add((await codec.getNextFrame()).image);
        } finally {
          codec.dispose();
        }
      }
    } catch (_) {
      for (final image in decoded) {
        image.dispose();
      }
      rethrow;
    }
    return WideCampImages(
      decoded[0],
      decoded[1],
      decoded[2],
      decoded[3],
      (files['backY'] as num).toDouble(),
      (files['frontY'] as num).toDouble(),
      widthPx,
    );
  }

  void dispose() {
    back.dispose();
    backGrass.dispose();
    front.dispose();
    frontGrass.dispose();
  }
}

/// 읽어 둔 배 판 그림. 모두 같은 캔버스·같은 원점이다
class BoatImages {
  BoatImages(this.art, this.rear, this.front, this.night);

  final BoatArt art;
  final ui.Image rear, front;
  final ui.Image? night;

  void dispose() {
    rear.dispose();
    front.dispose();
    night?.dispose();
  }
}

/// 너비 기준으로 한 번 축소하고 바닥을 화면 아래에 맞춘다.
/// 짧은 폰·태블릿에서도 길과 캐릭터 발이 화면 아래로 빠지지 않는다.
class SceneArtLayout {
  SceneArtLayout(this.art, this.size, this.mode, this.onSea, this.camp) {
    final theme = mode == SceneMode.rest ? camp : null;
    final key = theme == null && size.width > size.height ? 'landscape' : 'portrait';
    config = art.data[key] as Map<String, dynamic>;
    restK = theme?.scaleFor(size.width, size.height);
    scale = restK != null
        ? restK! * theme!.refW / n('width')
        : key == 'portrait'
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

  /// 쉼터 테마가 있을 때 기기 pt ÷ 장면 pt
  late final double? restK;
  double n(String key) => (config[key] as num).toDouble();
  double y(double value) => dy + value * scale;
  bool get rest => mode == SceneMode.rest;
  bool get sea => onSea && !rest;
  double get figureHeight =>
      restK != null ? camp!.character.heightPt * restK! : n('figureHeight') * scale;
  Offset get foot {
    if (restK != null) {
      final c = camp!.character;
      return Offset(c.footX * restK!, size.height - (camp!.refH - c.footY) * restK!);
    }
    final above = sea
        ? (art.data['boat']['deckAboveWater'] as num).toDouble()
        : 0;
    return Offset(size.width / 2, y(n('pathY') - above));
  }

  /// 배 흔들림(화면 px, 세로). 배 판·정령·동행이 모두 이 값을 쓴다.
  /// 값은 scene_art.json boat의 swayPx·swaySec이고, 없으면 흔들리지 않는다
  double boatSwayY(double elapsed) {
    if (!sea) return 0;
    final boat = art.data['boat'] as Map;
    final px = boat['swayPx'] as num?;
    final sec = boat['swaySec'] as num?;
    if (px == null || sec == null || sec <= 0) return 0;
    return px * scale * math.sin(elapsed * 2 * math.pi / sec);
  }
}

class SceneArtHost extends StatefulWidget {
  const SceneArtHost({
    super.key,
    required this.look,
    required this.mode,
    required this.size,
    required this.builder,
    this.onSea = false,
    this.boat,
    this.camp,
    this.restFarWidth,
  });
  final SceneLook look;
  final SceneMode mode;
  final Size size;

  /// 쉼터 테마. 있으면 그림 배율을 장면 배율로 잡는다
  final CampTheme? camp;

  /// 쉼터 후경이 보일 수 있는 폭 (기기 pt)
  final double? restFarWidth;

  /// 고른 배. 바뀌면 배 그림을 다시 읽는다
  final BoatArt? boat;

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
    final theme = widget.mode == SceneMode.rest ? widget.camp : null;
    final scale = theme != null
        ? theme.scaleFor(widget.size.width, widget.size.height) * theme.refW / 1170
        : widget.size.width > widget.size.height
        ? widget.size.height / 1170
        : widget.size.width / 1170;
    final key = (
      bundle,
      widget.look.backdrop,
      widget.look.season,
      widget.mode,
      widget.onSea,
      (scale * ratio * 100).round(),
      // 땅 위에서는 배가 바뀌어도 그림을 다시 읽지 않는다
      widget.onSea ? widget.boat?.id : null,
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
      boat: widget.boat,
      restFarWidthPx: widget.restFarWidth == null ? null : widget.restFarWidth! / scale,
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
