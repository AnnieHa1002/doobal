import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/camp_theme.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
import '../../domain/sky.dart';
import '../../domain/time_tint.dart';
import 'scene_art.dart';
import 'scene_painter.dart';
import 'sky_painter.dart';

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
  late Canvas _canvas;
  late SceneArtLayout _layout;
  late Size _size;
  double get _k => _layout.scale;
  double get _groundScale => _size.width > _size.height ? .78 : 1;
  Map get _assets => art.data['assets'] as Map;
  double _number(String key) => (art.data[key] as num).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    _canvas = canvas;
    _size = size;
    _layout = SceneArtLayout(art, size, mode, onSea, camp);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (pass == ScenePass.background) {
      _sky();
      _tinted(() {
        _far();
        if (_layout.rest) {
          if (camp != null) _camp(false);
        } else if (_layout.sea) {
          _boat();
        } else {
          _land();
        }
      });
    } else {
      _tinted(() {
        if (_layout.rest) {
          if (camp != null) _camp(true);
        } else if (_layout.sea) {
          _water();
        } else {
          _tile(
            'bg_front_${look.season.name}_v11_clean.png',
            _layout.n('frontY'),
            1,
          );
        }
      });
    }
    canvas.restore();
  }

  double _scroll(double speed) => _layout.rest
      ? 0
      : math.max(0, distanceM.isFinite ? distanceM : 0) *
            rules.groundPxPerM *
            speed;

  void _tinted(VoidCallback draw) {
    final factor = tintFactorAt(look.mix, rules, character: false);
    if (factor == 0xffffffff) {
      draw();
      return;
    }
    _canvas.saveLayer(
      Offset.zero & _size,
      Paint()
        ..colorFilter = ColorFilter.mode(Color(factor), BlendMode.modulate),
    );
    draw();
    _canvas.restore();
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

  void _tile(String key, double y, double speed) {
    final spec = _assets[key] as Map;
    final w = (spec['canvas'][0] as num) * _k * _groundScale;
    final h = (spec['canvas'][1] as num) * _k * _groundScale;
    for (var x = -(_scroll(speed) * _k * _groundScale % w); x < _size.width; x += w) {
      _draw(key, Rect.fromLTWH(x, _layout.y(y), w + .1, h));
    }
  }

  void _far() {
    final region = (art.data['far'] as Map).containsKey(look.backdrop)
        ? look.backdrop
        : 'capital';
    final keys = (art.data['far'][region] as List).cast<String>();
    final width = _layout.n('farWidth') * _k;
    final height = _layout.n(_layout.sea ? 'seaFarHeight' : 'farHeight') * _k;
    final offset = _scroll(.05) * _k % width;
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
        );
      }
    }
  }

  /// 구간 번호를 시드에 포함해 먼 거리를 가도 같은 배열만 반복하지 않는다.
  /// 앞뒤 조각을 함께 계산하므로 구간 경계에서 갑자기 바뀌지 않는다.
  void _clusters() {
    final tags = (art.data['tags'][look.backdrop] as List? ?? [])
        .cast<String>();
    final eligible = (art.data['clusters'] as List)
        .where((item) => (item['tags'] as List).any(tags.contains))
        .toList();
    if (eligible.isEmpty) return;
    final gap = _number('clusterGap');
    final offset = _scroll(.1);
    final start = ((offset - 2200) / gap).floor();
    final end = ((offset + _size.width / _k + 2200) / gap).ceil();
    for (var n = start; n <= end; n++) {
      final hash = sceneArtHash('$seed:${look.backdrop}', n);
      final item = eligible[hash % eligible.length];
      final x = n * gap + 300 + (hash % 700);
      _sprite(
        item['id'] as String,
        (x - offset) * _k,
        (item['height'] as num).toDouble(),
        _number('clusterFeet'),
      );
    }
  }

  void _sprite(
    String id,
    double x,
    double height,
    double feet, {
    double haze = 0,
  }) {
    final b = (_assets[id]['bbox'] as List).cast<num>();
    x *= _groundScale;
    final h = height * _k * _groundScale, w = b[2] * h / b[3];
    feet = _layout.n('groundY') + (feet - (art.data['portrait']['groundY'] as num)) * _groundScale;
    if (x > _size.width || x + w < 0) return;
    final rect = Rect.fromLTWH(x, _layout.y(feet) - h, w, h);
    _draw(id, rect, crop: true);
    if (haze > 0) {
      // 같은 PNG의 알파로만 안개색을 입혀 투명 여백에 벽이 생기지 않게 한다.
      _canvas.saveLayer(
        rect,
        Paint()..color = Colors.white.withValues(alpha: haze),
      );
      _draw(
        id,
        rect,
        crop: true,
        paint: Paint()
          ..colorFilter = const ColorFilter.mode(
            Color(0xffd6e0d6),
            BlendMode.srcIn,
          ),
      );
      _canvas.restore();
    }
  }

  void _tree(List tree, double feet, double speed, {double haze = 0}) {
    final cycle = _number('cycle');
    final x = (tree[1] as num).toDouble();
    final height = (tree[2] as num).toDouble();
    final offset = _scroll(speed);
    final first = ((offset - x - 2400) / cycle).floor();
    final last = ((offset + _size.width / _k - x) / cycle).ceil();
    for (var i = first; i <= last; i++) {
      _sprite(
        tree[0] as String,
        (x + i * cycle - offset) * _k,
        height,
        feet,
        haze: haze,
      );
    }
  }

  void _land() {
    _clusters();
    for (final tree in art.data['backTrees'] as List) {
      _tree(
        tree as List,
        _number('treeBackFeet'),
        .2,
        haze: _number('backTreeHaze'),
      );
    }
    for (final row in ['common', look.season.name]) {
      for (final tree in art.data['frontTrees'][row] as List) {
        _tree(tree as List, _number('treeFrontFeet'), .3);
      }
    }
    final tags = art.data['tags'][look.backdrop] as List? ?? [];
    if (tags.contains('도시') || tags.contains('평야')) {
      _tree(['bg_object_utility_pole_a_v10', 4200, 900], 2090, .3);
    }
    _tree(['bg_object_bush_a_v10', 1000, 250], 2110, .3);
    _tree(['bg_object_bush_b_v10', 7900, 280], 2110, .3);
    _tile(
      'bg_back_meadow_${look.season.name}_v10_preview.png',
      _layout.n('meadowY'),
      .5,
    );
    _tile('bg_path_v11_clean.png', _layout.n('groundY'), 1);
    _tile(
      'bg_lower_bank_${look.season.name}_v11_clean.png',
      _layout.n('groundY'),
      1,
    );
  }

  void _boat() {
    final boat = art.data['boat'] as Map;
    final scale =
        _layout.figureHeight /
        ((boat['charFootY'] as num) - (boat['charTopY'] as num));
    final foot = _layout.foot;
    _draw(
      'prop_boat_01_v11_clean.png',
      Rect.fromLTWH(
        foot.dx - 1536 * scale,
        foot.dy - (boat['deckY'] as num) * scale,
        3072 * scale,
        1536 * scale,
      ),
    );
  }

  void _water() =>
      _tile('bg_near_water_v11_clean.png', _layout.n('pathY') - 279 * _groundScale, 1);

  void _camp(bool front) {
    final config = art.data['camp'] as Map;
    if (!front && _size.width > _size.height) {
      const key = 'bg_rest_camp_back_landscape_v12_clean.png';
      final canvas = _assets[key]['canvas'] as List;
      final h = _size.width * (canvas[1] as num) / (canvas[0] as num);
      _draw(key, Rect.fromLTWH(0, _size.height - h, _size.width, h));
      return;
    }
    final k = _k * _groundScale;
    final y = _size.width > _size.height ? _size.height - 1400 * k : _layout.y((config['y'] as num).toDouble());
    if (front) {
      final frame = (elapsed / (config['frameSeconds'] as num)).floor() % 3 + 1;
      final key = 'fx_campfire_flame_0${frame}_v11_clean.png';
      _draw(
        key,
        Rect.fromLTWH(
          (_size.width - 1170 * k) / 2 + (config['fireX'] as num) * k,
          y + (config['fireY'] as num) * k,
          256 * k,
          384 * k,
        ),
      );
    }
    final id = front ? 'front' : 'back';
    final rect = Rect.fromLTWH(
      (_size.width - 1170 * k) / 2,
      y,
      1170 * k,
      1400 * k,
    );
    _draw('bg_rest_camp_${id}_v11_clean.png', rect);
    const palettes = {
      Season.spring: Color(0xffb5c98a),
      Season.summer: Color(0xff6f8f4e),
      Season.autumn: Color(0xffc79a5b),
      Season.winter: Color(0xffd8d6cc),
    };
    final c = palettes[look.season]!;
    _draw(
      'bg_rest_camp_${id}_grass_v11_clean.png',
      rect,
      paint: Paint()
        ..colorFilter = ColorFilter.matrix([
          c.r * 255 / 150,
          0,
          0,
          0,
          0,
          0,
          c.g * 255 / 150,
          0,
          0,
          0,
          0,
          0,
          c.b * 255 / 150,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
    );
  }

  void _sky() {
    final sky = look.sky;
    paintSky(
      _canvas,
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
      celestial: Celestial(SkyBody.none, look.celestial.progress),
      rules: rules,
    );
    final s = art.data['sky'] as Map;
    if (sky.stars > 0) {
      for (var i = 0; i < (s['starCount'] as num); i++) {
        final hx = sceneArtHash('stars-x', i) / 0x80000000;
        final hy = sceneArtHash('stars-y', i) / 0x80000000;
        final r = (i % 3 + 2) * _k;
        _draw(
          'sky_star_dot_v01_clean.png',
          Rect.fromLTWH(
            hx * _size.width,
            hy * _layout.y(rules.horizonY) * .65,
            r * 2,
            r * 2,
          ),
          paint: Paint()..color = Colors.white.withValues(alpha: sky.stars),
        );
      }
    }
    _textures();
    final c = look.celestial;
    if (c.body != SkyBody.none) {
      final cx =
          (rules.skyArc.leftX +
              (rules.skyArc.rightX - rules.skyArc.leftX) * c.progress) *
          _size.width;
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
    _tinted(() {
      final width = (s['cloudWidth'] as num) * _k;
      final period = 3400 * _k;
      final offset = (_scroll(.03) + (elapsed * (s['cloudSpeed'] as num))) * _k;
      for (var i = 0; i < 2; i++) {
        final x = ((i * 1700 * _k - offset) % period) - width;
        final key = 'sky_cloud_0${i + 1}_v11_clean.png';
        final spec = _assets[key] as Map;
        final h =
            width * (spec['canvas'][1] as num) / (spec['canvas'][0] as num);
        for (final xx in [x, x + period]) {
          _draw(
            key,
            Rect.fromLTWH(
              xx,
              _layout.y((s['cloudY'] as num).toDouble() + i * 180),
              width,
              h,
            ),
          );
        }
      }
    });
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
      old.elapsed != elapsed ||
      old.camp != camp ||
      old.seed != seed ||
      old.rules != rules;
}
