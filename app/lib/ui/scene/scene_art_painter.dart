import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/boat.dart';
import '../../domain/camp_theme.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
import '../../domain/scene_color.dart';
import '../../domain/scene_plan.dart';
import '../../domain/sky.dart';
import '../../domain/time_tint.dart';
import '../../domain/tint.dart';
import 'scene_art.dart';
import 'scene_painter.dart';
import 'sky_painter.dart';

/// 뒷줄 안개 색
const _hazeColor = 0xffd6e0d6;

/// 조각이 화면 왼쪽 밖으로 나가도 걸쳐 있을 수 있는 폭 (그림 px). 가장 넓은 조각보다 크다
const _maxPieceWidth = 2400.0;

/// 원화 PNG만 배치한다. 임시 능선·중간 들판·바다 면을 함께 그리지 않는다.
class SceneArtPainter extends CustomPainter {
  SceneArtPainter({
    required this.art,
    required this.look,
    required this.mode,
    required this.distanceM,
    required this.rules,
    required this.onSea,
    required this.pass,
    required this.elapsed,
    this.camp,
    this.seed = 'default',
    this.layoutSize,
  });
  final SceneArt art;
  final SceneLook look;
  final SceneMode mode;
  final double distanceM, elapsed;
  final Rules rules;
  final bool onSea;
  final ScenePass pass;
  final CampTheme? camp;
  final String seed;

  /// 배치 기준 화면. 쉼터 층은 화면보다 넓게 그리므로 따로 준다 (없으면 그리는 크기)
  final Size? layoutSize;
  late Canvas _canvas;
  late SceneArtLayout _layout;
  late Size _size;

  /// 지금 시간대 보정 (낮은 null)
  List<double>? _time;
  SeasonTint? _season;
  double get _k => _layout.scale;
  double get _groundScale => _layout.groundScale;
  Map get _assets => art.data['assets'] as Map;

  @override
  void paint(Canvas canvas, Size size) {
    _canvas = canvas;
    _size = size;
    _layout = SceneArtLayout(art, layoutSize ?? size, mode, onSea, camp);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final factor = tintFactorAt(look.mix, rules, character: false);
    _time = factor == 0xffffffff ? null : factorMatrix(factor);
    _season = rules.seasonTint[look.season.name];
    switch (pass) {
      case ScenePass.restSky:
        _skyStill();
      case ScenePass.restClouds:
        _clouds();
      case ScenePass.restFar:
        _far();
      case ScenePass.restBack:
        _campBack();
      case ScenePass.restFront:
        _campFront();
      case ScenePass.restFire:
        _campFire();
      case ScenePass.foreground:
        if (_layout.sea) {
          _boatFront();
          _water();
        } else if (!_layout.rest) {
          _tile(
            'bg_front_${look.season.name}_v11_clean.png',
            _layout.n('frontY'),
            rules.layers[SceneLayerId.foreground]!.speed,
          );
        }
      case ScenePass.background || ScenePass.all:
        _sky();
        _far();
        if (_layout.sea) {
          _boat();
          _boatLight();
        } else if (!_layout.rest) {
          _land();
        }
    }
    canvas.restore();
  }

  double _scroll(double speed) => _layout.rest
      ? 0
      : math.max(0, distanceM.isFinite ? distanceM : 0) *
            rules.groundPxPerM *
            speed;

  /// 입힐 색 행렬을 칠에 담는다. 입힐 것이 없으면 그대로.
  /// saveLayer 없이 그림마다 입힌다 (곱하기는 그림별로 입혀도 묶어 입힌 것과 결과가 같다)
  Paint _tinted(List<double>? matrix, [Paint? paint]) {
    final out = paint ?? Paint();
    if (matrix != null) out.colorFilter = ColorFilter.matrix(matrix);
    return out;
  }

  /// 시간대 보정만 입히는 칠 (길·앞풀·캠프)
  Paint _timePaint() => _tinted(_time);

  /// 계절 보정 → 시간대 보정 (후경·군락·들판)
  Paint _layerPaint(SceneLayerId layer) =>
      _tinted(chainAll([seasonTintMatrix(_season, layer), _time]));

  /// 회색조 풀: 풀 계절색 → (있으면) 계절 보정 → 시간대 보정을 한 행렬로
  Paint _grassPaint({SceneLayerId? layer}) {
    final grass = art.grass;
    final swatch = grass?.seasons[look.season.name];
    return _tinted(
      chainAll([
        if (grass != null && swatch != null) tintMatrix(swatch, grass.base),
        if (layer != null) seasonTintMatrix(_season, layer),
        _time,
      ]),
    );
  }

  void _draw(String key, Rect target, {bool crop = false, Paint? paint}) {
    final image = art.images[key];
    if (image == null || target.width <= 0 || target.height <= 0) return;
    final spec = _assets[key] as Map;
    final scaleX = image.width / (spec['canvas'][0] as num);
    final scaleY = image.height / (spec['canvas'][1] as num);
    final b = (spec['bbox'] as List).cast<num>();
    final source = crop
        ? Rect.fromLTWH(
            b[0] * scaleX,
            b[1] * scaleY,
            b[2] * scaleX,
            b[3] * scaleY,
          )
        : Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    _canvas.drawImageRect(
      image,
      source,
      target,
      (paint ?? Paint())..filterQuality = FilterQuality.medium,
    );
  }

  void _tile(String key, double y, double speed, {Paint? paint}) {
    final spec = _assets[key] as Map;
    final w = (spec['canvas'][0] as num) * _k * _groundScale;
    final h = (spec['canvas'][1] as num) * _k * _groundScale;
    final tinted = paint ?? _timePaint();
    for (var x = -(_scroll(speed) * _k * _groundScale % w); x < _size.width; x += w) {
      _draw(key, Rect.fromLTWH(x, _layout.y(y), w + .1, h), paint: tinted);
    }
  }

  void _far() {
    final region = (art.data['far'] as Map).containsKey(look.backdrop)
        ? look.backdrop
        : 'capital';
    final keys = (art.data['far'][region] as List).cast<String>();
    final width = _layout.n('farWidth') * _k;
    final height = _layout.n(_layout.sea ? 'seaFarHeight' : 'farHeight') * _k;
    final offset = _scroll(rules.layers[SceneLayerId.backdrop]!.speed) * _k % width;
    // 겨울은 겨울판으로 바꾸므로 후경에 계절 보정이 없다 (config seasonTint.winter.layers)
    final paint = _layerPaint(SceneLayerId.backdrop);
    for (var x = -offset; x < _size.width; x += width) {
      for (var i = 0; i < keys.length; i++) {
        _draw(
          keys[i],
          Rect.fromLTWH(
            x + i * width / 3,
            _layout.y(_layout.n('farY')),
            width / 3 + .1,
            height,
          ),
          paint: paint,
        );
      }
    }
  }

  /// 조각 한 줄을 그린다. 주기 번호를 시드에 넣어 먼 거리를 가도 같은 배열만 되풀이하지 않고,
  /// 앞뒤 주기를 함께 계산하므로 경계에서 갑자기 바뀌지 않는다
  void _row(SceneRow row) {
    final plan = art.plan!;
    final spec = plan.spec(row);
    final offset = _scroll(spec.speed);
    final first = ((offset - _maxPieceWidth) / plan.cycle).floor();
    final last = ((offset + _size.width / (_k * _groundScale)) / plan.cycle).floor();
    for (var c = first; c <= last; c++) {
      for (final p in art.placed(
        row,
        seed: seed,
        region: look.backdrop,
        season: look.season.name,
        cycleIndex: c,
      )) {
        final key = art.assetKeyOf(p.piece.file);
        if (key == null) continue;
        _sprite(
          key,
          (p.x - offset) * _k,
          p.height,
          spec.feetY,
          row: row,
          haze: spec.haze,
          tall: p.piece.tall,
        );
      }
    }
  }

  void _sprite(
    String id,
    double x,
    double height,
    double feet, {
    required SceneRow row,
    double haze = 0,
    bool tall = false,
  }) {
    final b = (_assets[id]['bbox'] as List).cast<num>();
    x *= _groundScale;
    final h = height * _k * _groundScale, w = b[2] * h / b[3];
    feet = _layout.n('groundY') + (feet - (art.data['portrait']['groundY'] as num)) * _groundScale;
    if (x > _size.width || x + w < 0) return;
    final rect = Rect.fromLTWH(x, _layout.y(feet) - h, w, h);
    final plan = art.plan!;
    // 키 큰 조각은 정령 뒤를 지나는 동안 흐려진다 (scene.json tallObjectClearX)
    final opacity = tall
        ? ScenePlan.tallOpacity(
            left: rect.left,
            right: rect.right,
            center: _layout.foot.dx,
            clear: plan.tallClearX * _k * _groundScale,
            near: plan.tallNearOpacity,
            fade: plan.tallFadePx * _k * _groundScale,
          )
        : 1.0;
    final paint = _tinted(
      chainAll([
        if (row == SceneRow.grove) seasonTintMatrix(_season, SceneLayerId.grove),
        // 안개는 그림의 알파 안에서만 색을 섞는다
        if (haze > 0) hazeMatrix(_hazeColor, haze),
        _time,
      ]),
    );
    if (opacity < 1) paint.color = Colors.white.withValues(alpha: opacity);
    _draw(id, rect, crop: true, paint: paint);
  }

  void _land() {
    _row(SceneRow.grove);
    _row(SceneRow.back);
    _row(SceneRow.front);
    final season = look.season.name;
    final meadowSpeed = rules.layers[SceneLayerId.meadow]!.speed;
    final groundSpeed = rules.layers[SceneLayerId.ground]!.speed;
    final meadow = art.meadowGray;
    if (meadow != null) {
      _tile(meadow[0], _layout.n('meadowY'), meadowSpeed, paint: _layerPaint(SceneLayerId.meadow));
      _tile(meadow[1], _layout.n('meadowY'), meadowSpeed, paint: _grassPaint(layer: SceneLayerId.meadow));
    } else {
      _tile(
        'bg_back_meadow_${season}_v10_preview.png',
        _layout.n('meadowY'),
        meadowSpeed,
        paint: _layerPaint(SceneLayerId.meadow),
      );
    }
    _tile('bg_path_v11_clean.png', _layout.n('groundY'), groundSpeed);
    final bank = art.bankGray;
    if (bank != null) {
      _tile(bank[0], _layout.n('groundY'), groundSpeed);
      _tile(bank[1], _layout.n('groundY'), groundSpeed, paint: _grassPaint());
    } else {
      _tile('bg_lower_bank_${season}_v11_clean.png', _layout.n('groundY'), groundSpeed);
    }
  }

  void _boat() {
    if (art.boat case final layers?) {
      _boatLayer(layers.rear, layers);
      return;
    }
    final boat = art.data['boat'] as Map;
    final scale =
        _layout.figureHeight /
        ((boat['charFootY'] as num) - (boat['charTopY'] as num));
    final foot = _layout.foot + Offset(0, _layout.boatSwayY(elapsed));
    _draw(
      'prop_boat_01_v11_clean.png',
      Rect.fromLTWH(
        foot.dx - 1536 * scale,
        foot.dy - (boat['deckY'] as num) * scale,
        3072 * scale,
        1536 * scale,
      ),
      paint: _timePaint(),
    );
  }

  /// 창 불빛은 밤·새벽에만, 시간대 보정 없이 뒤판 위에 얹는다
  void _boatLight() {
    final layers = art.boat;
    final night = layers?.night;
    if (layers == null || night == null || !boatLightOn(look.phase)) return;
    _boatLayer(night, layers, tint: false);
  }

  void _boatFront() {
    if (art.boat case final layers?) _boatLayer(layers.front, layers);
  }

  /// 배 판 한 장. 어느 판이든 같은 자리·같은 흔들림으로 그린다
  void _boatLayer(ui.Image image, BoatImages layers, {bool tint = true}) {
    final foot = _layout.foot;
    final at = placeBoat(
      layers.art,
      footX: foot.dx,
      footY: foot.dy + _layout.boatSwayY(elapsed),
      scale: _layout.figureHeight / rules.characterCanvasHeightPx,
    );
    _canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(at.left, at.top, at.width, at.height),
      (tint ? _timePaint() : Paint())..filterQuality = FilterQuality.medium,
    );
  }

  void _water() =>
      _tile('bg_near_water_v11_clean.png', _layout.n('pathY') - 279 * _groundScale, 1);

  /// 캠프 뒤판: 넓은 그림이 있으면 그것, 없으면 v11을 왼쪽에 두고 나머지는 빈 땅
  void _campBack() {
    if (art.wideCamp case final wide?) {
      _wide(wide.back, wide.backY, wide, paint: _timePaint());
      _wide(wide.backGrass, wide.backY, wide, paint: _grassPaint());
      return;
    }
    _campFill();
    _v11Back();
  }

  /// v11 뒤판과 풀. 아래쪽을 늘여 화면 아래까지 닿게 한다 (뒤판을 올려 둔 만큼)
  void _v11Back() {
    final config = art.data['camp'] as Map;
    final top = _layout.y((config['backY'] as num).toDouble());
    final from = ((config['fill'] as Map)['stretchFromY'] as num).toDouble();
    for (final (key, paint) in [
      ('bg_rest_camp_back_v11_clean.png', _timePaint()),
      ('bg_rest_camp_back_grass_v11_clean.png', _grassPaint()),
    ]) {
      final image = art.images[key];
      if (image == null) continue;
      final canvas = (_assets[key] as Map)['canvas'] as List;
      final w = (canvas[0] as num).toDouble(), h = (canvas[1] as num).toDouble();
      final imageScale = image.width / w;
      paint.filterQuality = FilterQuality.medium;
      final split = top + from * _k;
      _canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), from * imageScale),
        Rect.fromLTWH(0, top, w * _k, from * _k),
        paint,
      );
      _canvas.drawImageRect(
        image,
        Rect.fromLTRB(0, from * imageScale, image.width.toDouble(), h * imageScale),
        // 이음매가 안 보이게 살짝 겹친다
        Rect.fromLTRB(0, split - .5, w * _k, math.max(_layout.size.height, top + h * _k)),
        paint,
      );
    }
  }

  void _campFront() {
    if (art.wideCamp case final wide?) {
      _wide(wide.front, wide.frontY, wide, paint: _timePaint());
      _wide(wide.frontGrass, wide.frontY, wide, paint: _grassPaint());
      return;
    }
    final rect = _v11Rect(((art.data['camp'] as Map)['frontY'] as num).toDouble());
    _draw('bg_rest_camp_front_v11_clean.png', rect, paint: _timePaint());
    _draw('bg_rest_camp_front_grass_v11_clean.png', rect, paint: _grassPaint());
  }

  /// 불꽃 지금 프레임. 자리와 프레임 시간은 테마가 정한다
  void _campFire() {
    final theme = camp;
    final restK = _layout.restK;
    if (theme == null || restK == null) return;
    final fire = theme.campfire;
    final frame = (elapsed / fire.frameSec).floor() % fire.frames + 1;
    _draw(
      'fx_campfire_flame_0${frame}_v11_clean.png',
      Rect.fromLTWH(
        fire.box.x * restK,
        _size.height - (theme.refH - fire.box.y) * restK,
        fire.box.w * restK,
        fire.box.h * restK,
      ),
      paint: _timePaint(),
    );
  }

  /// 지금 v11 캠프 그림의 자리 (왼쪽에 붙인다)
  Rect _v11Rect(double artY) {
    final spec = _assets['bg_rest_camp_back_v11_clean.png'] as Map;
    return Rect.fromLTWH(
      0,
      _layout.y(artY),
      (spec['canvas'][0] as num) * _k,
      (spec['canvas'][1] as num) * _k,
    );
  }

  /// 빈 땅 (넓은 그림이 오면 안 쓴다): v11 오른쪽에 맨땅을 깔고 뒤판을 좌우로 뒤집어 이어 붙여
  /// 경계를 없앤다. 뒤집은 이정표는 땅 윗선(ridgeY)에서 잘린다
  void _campFill() {
    const back = 'bg_rest_camp_back_v11_clean.png';
    final image = art.images[back];
    if (image == null) return;
    final config = art.data['camp'] as Map;
    final fill = config['fill'] as Map;
    final s = (fill['source'] as List).cast<num>();
    final ridge = (fill['ridgeY'] as List).cast<num>();
    final imageScale = image.width / ((_assets[back] as Map)['canvas'][0] as num);
    final seam = ((_assets[back] as Map)['canvas'][0] as num) * _k;
    final width = _size.width, bottom = _size.height;
    final top0 = _layout.y(ridge[0].toDouble());
    final top1 = _layout.y(ridge[1].toDouble());
    final top2 = _layout.y(ridge[2].toDouble());
    final right = Path()
      ..moveTo(seam, top0)
      ..quadraticBezierTo((seam + width) / 2, top1 * 2 - (top0 + top2) / 2, width, top2)
      ..lineTo(width, bottom)
      ..lineTo(seam, bottom)
      ..close();
    // 맨땅
    _canvas.save();
    _canvas.clipPath(right);
    _canvas.drawImageRect(
      image,
      Rect.fromLTWH(s[0] * imageScale, s[1] * imageScale, s[2] * imageScale, s[3] * imageScale),
      Rect.fromLTRB(seam, math.min(top0, top1), width, bottom),
      _timePaint()..filterQuality = FilterQuality.medium,
    );
    _canvas.restore();
    // 좌우로 뒤집기 (풀까지)
    _canvas.save();
    _canvas.clipPath(right);
    _canvas.translate(seam * 2, 0);
    _canvas.scale(-1, 1);
    _v11Back();
    _canvas.restore();
  }

  /// 넓은 그림 한 장: 장면 폭에 맞추고 세로는 비율대로
  void _wide(ui.Image image, double artY, WideCampImages wide, {Paint? paint}) {
    final w = wide.widthPx * _k;
    _canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, _layout.y(artY), w, w * image.height / image.width),
      (paint ?? Paint())..filterQuality = FilterQuality.medium,
    );
  }

  void _sky() {
    _skyStill();
    _clouds();
  }

  /// 시간이 흘러도 그대로인 하늘: 구워 둔 한 장(그라데이션·별·텍스처)과 해·달
  void _skyStill() {
    final sky = look.sky;
    final c = look.celestial;
    final s = art.data['sky'] as Map;
    art.drawSkyBaked(
      _canvas,
      _size,
      // 해 위치는 빛무리 자리라 천천히 바뀌는 만큼만 다시 굽는다
      (
        _size,
        _layout.size,
        sky.top,
        sky.mid,
        sky.horizon,
        sky.glow,
        (sky.glowStrength * 100).round(),
        (sky.stars * 100).round(),
        (c.progress * 500).round(),
      ),
      (canvas) {
        final saved = _canvas;
        _canvas = canvas;
        paintSky(
          canvas,
          _size,
          _k,
          sky: SkyLook(
            top: sky.top,
            mid: sky.mid,
            horizon: sky.horizon,
            glow: sky.glow,
            glowStrength: sky.glowStrength,
            stars: 0,
          ),
          celestial: Celestial(SkyBody.none, c.progress),
          rules: rules,
        );
        if (sky.stars > 0) {
          for (var i = 0; i < (s['starCount'] as num); i++) {
            final hx = sceneArtHash('stars-x', i) / 0x80000000;
            final hy = sceneArtHash('stars-y', i) / 0x80000000;
            final r = (i % 3 + 2) * _k;
            _draw(
              'sky_star_dot_v01_clean.png',
              Rect.fromLTWH(
                hx * _layout.size.width,
                hy * _layout.y(rules.horizonY) * .65,
                r * 2,
                r * 2,
              ),
              paint: Paint()..color = Colors.white.withValues(alpha: sky.stars),
            );
          }
        }
        _textures();
        _canvas = saved;
      },
    );
    if (c.body != SkyBody.none) {
      final cx =
          (rules.skyArc.leftX +
              (rules.skyArc.rightX - rules.skyArc.leftX) * c.progress) *
          _layout.size.width;
      final cy = _layout.y(
        rules.horizonY -
            (rules.horizonY - rules.skyArc.peakY) *
                math.sin(math.pi * c.progress),
      );
      final key = c.body == SkyBody.sun
          ? 'sky_sun_v11_clean.png'
          : 'sky_moon_full_v11_clean.png';
      final width =
          (s[c.body == SkyBody.sun ? 'sunSize' : 'moonSize'] as num) * _k;
      _draw(
        key,
        Rect.fromCenter(center: Offset(cx, cy), width: width, height: width),
      );
    }
  }

  /// 시간에 따라 움직이는 하늘: 구름과 가끔 지나가는 것
  void _clouds() {
    final s = art.data['sky'] as Map;
    final width = (s['cloudWidth'] as num) * _k;
    final period = 3400 * _k;
    final offset = (_scroll(rules.layers[SceneLayerId.sky]!.speed) + (elapsed * (s['cloudSpeed'] as num))) * _k;
    final cloudPaint = _timePaint();
    for (var i = 0; i < 2; i++) {
      final x = ((i * 1700 * _k - offset) % period) - width;
      final key = 'sky_cloud_0${i + 1}_v11_clean.png';
      final spec = _assets[key] as Map;
      final h = width * (spec['canvas'][1] as num) / (spec['canvas'][0] as num);
      for (final xx in [x, x + period]) {
        _draw(
          key,
          Rect.fromLTWH(xx, _layout.y((s['cloudY'] as num).toDouble() + i * 180), width, h),
          paint: cloudPaint,
        );
      }
    }
    _passer(s);
  }

  void _textures() {
    final s = art.data['sky'] as Map;
    _canvas.save();
    _canvas.clipRect(
      Rect.fromLTRB(
        0,
        0,
        _size.width,
        math.max(0, math.min(_size.height, _layout.y(rules.horizonY))),
      ),
    );
    final tile = 512 * _k;
    for (final entry in [
      ('sky_wash_v01.png', 'textureWash'),
      ('paper_grain_v01.png', 'textureGrain'),
    ]) {
      final paint = Paint()
        ..blendMode = BlendMode.softLight
        ..color = Colors.white.withValues(
          alpha: (s[entry.$2] as num).toDouble(),
        );
      for (var x = 0.0; x < _size.width; x += tile) {
        for (var y = 0.0; y < _size.height; y += tile) {
          _draw(entry.$1, Rect.fromLTWH(x, y, tile, tile), paint: paint);
        }
      }
    }
    _canvas.restore();
  }

  void _passer(Map config) {
    final period = (config['passerMeanSeconds'] as num).toDouble();
    final slot = (elapsed / period).floor();
    final start =
        slot * period +
        sceneArtHash('passer:$seed', slot) % math.max(1, (period - 10).floor());
    final night = look.phase == SkyPhase.night || look.phase == SkyPhase.dawn;
    final duration = (config[night ? 'shootingSeconds' : 'birdSeconds'] as num)
        .toDouble();
    final t = (elapsed - start) / duration;
    if (t < 0 || t > 1) return;
    final key = night
        ? 'sky_star_shooting_v11_clean.png'
        : 'sky_birds_flock_v11_clean.png';
    final spec = _assets[key] as Map;
    final w = 420 * _k,
        h = w * (spec['canvas'][1] as num) / (spec['canvas'][0] as num);
    _draw(
      key,
      Rect.fromLTWH(
        -w + (_size.width + w) * t,
        _layout.y(600) + t * 120 * _k,
        w,
        h,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant SceneArtPainter old) =>
      old.art != art ||
      old.look != look ||
      old.mode != mode ||
      old.onSea != onSea ||
      old.pass != pass ||
      old.distanceM != distanceM ||
      old.camp != camp ||
      old.seed != seed ||
      old.rules != rules ||
      old.layoutSize != layoutSize ||
      _elapsedChanged(old);

  /// 쉼터 판은 시간이 흘러도 그대로, 불꽃은 프레임이 바뀔 때만 다시 그린다
  bool _elapsedChanged(SceneArtPainter old) => switch (pass) {
        ScenePass.restSky || ScenePass.restFar || ScenePass.restBack || ScenePass.restFront => false,
        ScenePass.restFire when camp != null =>
          (old.elapsed / camp!.campfire.frameSec).floor() != (elapsed / camp!.campfire.frameSec).floor(),
        _ => old.elapsed != elapsed,
      };
}
