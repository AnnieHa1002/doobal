import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../domain/boat.dart';
import '../../domain/camp_theme.dart';
import '../../domain/scene.dart';
import '../../domain/scene_plan.dart';
import 'scene_painter.dart';

export '../../domain/scene_plan.dart' show sceneArtHash;

/// 승인된 v10·v11의 파일/배치 목록. 옛 중간 들판 config와 분리한다.
/// 하늘에 쓰는 그림 (해·달·별 한 점·구름·지나가는 것·텍스처). 나머지 sky_ 파일은 안 읽는다
const _skyKeys = [
  'sky_sun_v11_clean.png',
  'sky_moon_full_v11_clean.png',
  'sky_star_dot_v01_clean.png',
  'sky_cloud_01_v11_clean.png',
  'sky_cloud_02_v11_clean.png',
  'sky_birds_flock_v11_clean.png',
  'sky_star_shooting_v11_clean.png',
  'sky_wash_v01.png',
  'paper_grain_v01.png',
];

/// 별 한 점의 가장 큰 지름 (그림 px)
const starDotMaxPx = 8.0;

/// 하늘 한 장을 구워 둘 때의 배율 (기기 pt 기준). 그라데이션·옅은 결이라 낮아도 된다
const _skyBakeScale = 1.5;

class SceneArt {
  SceneArt(
    this.data,
    this.images, {
    this.boat,
    this.wideCamp,
    this.plan,
    this.grass,
    this.bankGray,
    this.meadowGray,
  });
  final Map<String, dynamic> data;
  final Map<String, ui.Image> images;

  /// 조각 고르기·배치 (scene.json)
  final ScenePlan? plan;

  /// 회색조 풀에 입힐 값 (palette.json grass). 없으면 칠하지 않는다
  final GrassPalette? grass;

  /// 아래 둑·들판의 회색조 두 장 (바탕, 풀). 파일이 없으면 null이고 계절 완성 그림을 쓴다
  final List<String>? bankGray;
  final List<String>? meadowGray;

  /// 그림 파일 이름 → assets 키 (scene.json은 파일 이름으로 적는다)
  late final Map<String, String> _keyOfFile = {
    for (final e in (data['assets'] as Map<String, dynamic>).entries)
      ((e.value as Map)['file'] as String).split('/').last: e.key,
  };

  String? assetKeyOf(String file) => _keyOfFile[file];

  ui.Image? _skyImage;
  Object? _skyKey;

  /// 하늘(그라데이션·별·텍스처)을 그림 한 장으로 구워 둔다. 값이 같으면 다시 안 굽는다.
  /// 텍스처의 softLight 겹치기를 프레임마다 다시 하지 않기 위해서다
  void drawSkyBaked(Canvas canvas, Size size, Object key, void Function(Canvas) draw) {
    if (_skyKey != key || _skyImage == null) {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder)..scale(_skyBakeScale));
      final picture = recorder.endRecording();
      final image = picture.toImageSync(
        (size.width * _skyBakeScale).ceil().clamp(1, 4096),
        (size.height * _skyBakeScale).ceil().clamp(1, 4096),
      );
      picture.dispose();
      _skyImage?.dispose();
      _skyImage = image;
      _skyKey = key;
    }
    canvas.save();
    canvas.scale(1 / _skyBakeScale);
    canvas.drawImage(_skyImage!, Offset.zero, Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
  }

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
    CampTheme? camp,
  }) async {
    final data = jsonDecode(
      await bundle.loadString('assets/data/scene_art.json'),
    ) as Map<String, dynamic>;
    final assets = data['assets'] as Map<String, dynamic>;
    final scene = jsonDecode(await bundle.loadString('assets/data/scene.json')) as Map<String, dynamic>;
    final plan = ScenePlan.fromJson(scene);
    final grass = GrassPalette.fromJson(
      (jsonDecode(await bundle.loadString('assets/data/palette.json')) as Map)['grass'] as Map<String, dynamic>,
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
    keys.addAll(_skyKeys);
    WideCampImages? wide;
    List<String>? bankGray, meadowGray;
    if (rest) {
      wide = await WideCampImages.load(bundle, scene['rest'] as Map, scale * pixelRatio, data);
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
      final ground = scene['ground'] as Map<String, dynamic>;
      final bankFiles = [ground['lowerBankBase'] as String, ground['lowerBankGrass'] as String];
      if (bankFiles.every(assets.containsKey)) bankGray = bankFiles;
      meadowGray = await _meadowFiles(bundle, scene['meadow'] as Map<String, dynamic>, assets);
      keys.addAll([
        'bg_path_v11_clean.png',
        'bg_front_${look.season.name}_v11_clean.png',
        // 땅·들판은 회색조 풀 + 계절색. 회색조 파일이 없으면 계절별 완성 그림을 쓴다
        ...bankGray ?? ['bg_lower_bank_${look.season.name}_v11_clean.png'],
        ...meadowGray ?? ['bg_back_meadow_${look.season.name}_v10_preview.png'],
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
      final farFiles = await _farFiles(bundle, scene, region, look.season, farParts);
      final shrink = _displayRatios(data, plan, region, look.season.name, camp);
      // 순차 디코딩으로 로드 순간의 메모리 급증을 제한한다.
      for (final key in keys) {
        final spec = assets[key] as Map<String, dynamic>;
        final bytes = farFiles[key] ?? await bundle.load(spec['file'] as String);
        final width = (spec['canvas'][0] as num).toDouble();
        // 화면에 가장 크게 그려지는 크기까지만 푼다
        final target = math
            .min(
              width,
              math.min(
                (width * (shrink[key] ?? 1) * scale * pixelRatio).ceilToDouble(),
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
      return SceneArt(
        data,
        images,
        boat: boatImages,
        wideCamp: wide,
        plan: plan,
        grass: grass,
        bankGray: bankGray,
        meadowGray: meadowGray,
      );
    } catch (_) {
      for (final image in images.values) {
        image.dispose();
      }
      boatImages?.dispose();
      wide?.dispose();
      rethrow;
    }
  }

  /// 그림 키 → 화면에 가장 크게 그려질 때 캔버스의 몇 배인가. 없으면 1배.
  /// 이보다 크게 풀어 봐야 메모리만 쓴다
  static Map<String, double> _displayRatios(
    Map<String, dynamic> data,
    ScenePlan plan,
    String region,
    String season,
    CampTheme? camp,
  ) {
    final assets = data['assets'] as Map<String, dynamic>;
    final sky = data['sky'] as Map<String, dynamic>;
    final byFile = {
      for (final e in assets.entries) ((e.value as Map)['file'] as String).split('/').last: e.key,
    };
    double canvasW(String key) => ((assets[key] as Map)['canvas'][0] as num).toDouble();
    final out = <String, double>{
      'sky_sun_v11_clean.png': (sky['sunSize'] as num) / canvasW('sky_sun_v11_clean.png'),
      'sky_moon_full_v11_clean.png': (sky['moonSize'] as num) / canvasW('sky_moon_full_v11_clean.png'),
      'sky_star_dot_v01_clean.png': starDotMaxPx / canvasW('sky_star_dot_v01_clean.png'),
    };
    final farWidth = (data['portrait']['farWidth'] as num).toDouble();
    final parts = (data['far'][region] as List).cast<String>();
    for (final key in parts) {
      out[key] = farWidth / parts.length / canvasW(key);
    }
    if (camp != null) {
      final flameWidth = camp.campfire.box.w * (data['portrait']['width'] as num) / camp.refW;
      for (final n in const ['01', '02', '03']) {
        final key = 'fx_campfire_flame_${n}_v11_clean.png';
        out[key] = flameWidth / canvasW(key);
      }
    }
    for (final piece in plan.eligible(SceneRow.grove, region, season)) {
      final key = byFile[piece.file];
      if (key != null) out[key] = (piece.heightPx ?? plan.smallHeight[1]) / _boxHeight(assets, key);
    }
    for (final piece in plan.eligible(SceneRow.front, region, season)) {
      final key = byFile[piece.file];
      if (key != null) {
        out[key] = (piece.big ? plan.bigHeight[1] : plan.smallHeight[1]) / _boxHeight(assets, key);
      }
    }
    return out;
  }

  static double _boxHeight(Map<String, dynamic> assets, String key) =>
      ((assets[key] as Map)['bbox'][3] as num).toDouble();

  /// 들판 회색조 두 장(scene.json meadow)이 그림 폴더에 있으면 그림 목록에 더하고 그 키를 돌려준다
  static Future<List<String>?> _meadowFiles(
    AssetBundle bundle,
    Map<String, dynamic> meadow,
    Map<String, dynamic> assets,
  ) async {
    final canvas = meadow['canvas'] as List;
    final names = [meadow['file'] as String, meadow['grass'] as String];
    for (final name in names) {
      final path = await _firstExisting(bundle, name);
      if (path == null) return null;
      assets[name] = {
        'file': path,
        'canvas': canvas,
        'bbox': [0, 0, canvas[0], canvas[1]],
      };
    }
    return names;
  }

  /// 그림 폴더에서 [name]을 찾는다. WebP를 먼저 본다
  static Future<String?> _firstExisting(AssetBundle bundle, String name) async {
    for (final path in [
      '${WideCampImages.dir}/${name.replaceAll('.png', '.webp')}',
      '${WideCampImages.dir}/$name',
    ]) {
      if (await _assetOrNull(bundle, path) != null) return path;
    }
    return null;
  }

  /// 이 지역 후경을 대신할 파일: 겨울이면 겨울판(scene.json winterTiles), 이음새 수정본이 채택됐으면 그것.
  /// 키 → 파일 내용. 세 장이 다 있어야 쓰고, 없으면 빈 맵이라 기본판을 그대로 읽는다.
  /// 새 그림은 그림 폴더에 넣는다. WebP를 먼저 찾는다
  static Future<Map<String, ByteData>> _farFiles(
    AssetBundle bundle,
    Map<String, dynamic> scene,
    String region,
    Season season,
    List<String> parts,
  ) async {
    final backdrop = (scene['backdrops'] as Map)[region] as Map?;
    if (backdrop == null) return const {};
    final seam = backdrop['seamFixTiles'] as Map?;
    final List? files = season == Season.winter && backdrop['winterTiles'] != null
        ? backdrop['winterTiles'] as List
        : seam != null && seam['adopted'] == true
        ? seam['files'] as List
        : null;
    if (files == null || files.length != parts.length) return const {};
    final found = <String, ByteData>{};
    for (var i = 0; i < parts.length; i++) {
      final path = await _firstExisting(bundle, files[i] as String);
      if (path == null) return const {};
      found[parts[i]] = await bundle.load(path);
    }
    return found;
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
    _skyImage?.dispose();
  }
}

/// 회색조 풀에 입힐 값 (palette.json grass): 계절 견본색과 기준 밝기
class GrassPalette {
  const GrassPalette(this.base, this.seasons);

  final double base;

  /// 계절 이름 → 불투명 ARGB
  final Map<String, int> seasons;

  factory GrassPalette.fromJson(Map<String, dynamic> j) => GrassPalette(
        (j['base'] as num).toDouble(),
        {
          for (final e in (j['seasons'] as Map<String, dynamic>).entries)
            e.key: 0xFF000000 | int.parse((e.value as String).substring(1), radix: 16),
        },
      );
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
    Map rest,
    double pixelsPerArtPx,
    Map<String, dynamic> data,
  ) async {
    final files = rest['files'] as Map;
    final widthPx = (rest['widthPx'] as num).toDouble();
    final found = <ByteData>[];
    for (final key in ['back', 'backGrass', 'front', 'frontGrass']) {
      final path = await SceneArt._firstExisting(bundle, files[key] as String);
      if (path == null) return null;
      found.add(await bundle.load(path));
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

  /// 땅·길 그림 배율 (가로 화면은 줄인다). 땅 1m의 화면 길이 = groundPxPerM × [scale] × 이것
  double get groundScale => size.width > size.height ? .78 : 1;
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

  /// 그릴 것을 만든다. 시계([ValueListenable], 초)가 흐를 때 다시 부르지 않으므로 움직이는 층만 시계를 듣는다
  final Widget Function(BuildContext, SceneArt?, ValueListenable<double>) builder;
  @override
  State<SceneArtHost> createState() => _SceneArtHostState();
}

class _SceneArtHostState extends State<SceneArtHost> {
  SceneArt? _art;
  Object? _key;
  Object? _loadedKey;
  Widget Function(BuildContext, SceneArt?, ValueListenable<double>)? _activeBuilder;
  int _generation = 0;
  final _clock = ValueNotifier<double>(0);
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
      camp: theme,
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
        if (mounted) _clock.value += .1;
      });
    } else if (!enabled) {
      _timer?.cancel();
      _timer = null;
    }
    // 새 이미지가 준비될 때까지 계절·배·자세도 이전 완성 장면과 함께 유지한다.
    return (_activeBuilder ?? widget.builder)(context, _art, _clock);
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _clock.dispose();
    _art?.dispose();
    super.dispose();
  }
}
