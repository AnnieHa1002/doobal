import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/camp_theme.dart';
import '../../domain/parallax.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
import '../../domain/sky.dart';
import '../../domain/time_tint.dart';
import '../common/palette.dart';
import 'scene_palette.dart';

enum SceneMode { rest, walking }

/// 캐릭터 그림의 키 (발 0 ~ 베레모 꼭대기, 그림 좌표). 이게 config characterHeightPx가 된다
const _figureHeight = 135.0;

/// 길 띠의 반폭 (기준 화면 px). 길 가운데는 config pathY
const _pathHalfWidth = 40.0;

/// 땅 한 장을 줄무늬 몇 칸으로 나눌지(짝수여야 한 바퀴 돌아도 무늬가 이어진다),
/// 숲 덩이·전경 풀 개수, 별 개수
const _groundStripes = 32;
const _groveCount = 16;
const _tuftCount = 28;
const _starCount = 40;

/// 바다 후경(울릉도 등)의 먼 산은 띠 안에서 이만큼만 오르내린다
const _seaHillFlatten = 0.35;

/// 쉼터 텐트 자리 (그림이 나오기 전 임시 위치)
const _tentSpot = FootSpot(0.52, 0.74);

const _white = 0xFFFFFFFF;

/// 쉼터·걷는 중 공용 장면을 칠한다. 그림 파일이 생기기 전의 임시 그림이다.
/// 걷는 중: 하늘 → 후경·능선·숲·풀밭·땅(배 구간은 후경 + 물결 + 고정된 배) → 캐릭터 → 전경.
/// 쉼터: 하늘 → 후경·능선·숲·풀밭·땅(안 움직임) → 캠프 뒤(텐트·이정표) → 캐릭터 → 캠프 앞(모닥불).
/// 크기는 모두 config의 기준 화면(screenHeightPx) px × k (k = 화면 높이 / 기준 높이).
/// 시간대 색(하늘 기준점을 따라 섞인다)은 하늘만 빼고 곱해 입힌다. 캐릭터는 따로 약하게
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.look,
    required this.mode,
    required this.distanceM,
    required this.rules,
    required this.onSea,
    required this.running,
    this.camp,
  });

  final SceneLook look;
  final SceneMode mode;

  /// 땅이 스크롤되는 거리(m). 쉼터에서는 쓰지 않는다
  final double distanceM;
  final Rules rules;
  final bool onSea;
  final bool running;

  /// 쉼터 테마. 없으면 캠프 물건 없이 캐릭터만 가운데에 그린다
  final CampTheme? camp;

  bool get _rest => mode == SceneMode.rest;

  /// 배 위 (쉼터에서는 바다가 아니다)
  bool get _sea => onSea && !_rest;

  /// 바다에서 숨기는 레이어가 아니면 true
  bool _shown(SceneLayerId id) => !(_sea && rules.seaHiddenLayers.contains(id));

  SceneLayer _layer(SceneLayerId id) => rules.layers[id]!;

  /// 캐릭터 그림 한 칸의 px. 텐트·배 같은 소품도 이 단위로 그려 캐릭터와 크기 비율을 지킨다
  double _unit(double k) => rules.characterHeightPx * k / _figureHeight;

  /// 레이어의 가로 스크롤(화면 px). 쉼터는 0
  double _offset(SceneLayerId id, double k) {
    if (_rest) return 0;
    final layer = _layer(id);
    return layerOffsetPx(distanceM, layer.speed, rules.groundPxPerM, layer.widthPx!) * k;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / rules.screenHeightPx;
    final u = _unit(k);
    _sky(canvas, size, k);
    if (_rest) {
      // 쉼터에 능선·숲·풀밭(L2~L4)을 보일지는 아직 정하지 않았다 (지금은 다 보인다)
      _tinted(canvas, size, () {
        _scenery(canvas, size, k);
        if (camp != null) {
          _tent(canvas, size, u, _tentSpot);
          _signpost(canvas, size, u, camp!.signpost);
        }
      });
      final spot = camp?.character ?? FootSpot(0.5, rules.pathY / rules.screenHeightPx);
      _character(canvas, k, spot.x * size.width, spot.footY * size.height, standing: true);
      if (camp != null) _tinted(canvas, size, () => _fire(canvas, size, u, camp!));
      return;
    }
    _tinted(canvas, size, () => _scenery(canvas, size, k));
    _character(canvas, k, size.width / 2, rules.pathY * k, standing: _sea);
    // 물 위에는 풀이 없다
    if (_shown(SceneLayerId.foreground)) {
      _tinted(canvas, size, () => _foreground(canvas, size, k));
    }
  }

  /// 캐릭터 뒤 레이어: 후경 → 능선 → 숲 → 풀밭 → 땅(배 구간은 물결). 바다에서는 숨기는 레이어를 건너뛴다
  void _scenery(Canvas canvas, Size size, double k) {
    if (_shown(SceneLayerId.backdrop)) _backdrop(canvas, size, k);
    if (_shown(SceneLayerId.ridge)) _ridge(canvas, size, k);
    if (_shown(SceneLayerId.grove)) _grove(canvas, size, k);
    if (_shown(SceneLayerId.meadow)) _meadow(canvas, size, k);
    if (_sea) {
      _seaGround(canvas, size, k);
    } else {
      _ground(canvas, size, k);
    }
  }

  /// [draw]가 그린 것에 시간대 색(배경 세기)을 곱한다. 낮은 그대로 그린다.
  /// 투명한 곳(하늘이 비치는 곳)은 그대로 두려고 곱하기 중 알파도 곱하는 modulate를 쓴다.
  /// 불투명한 그림 위에서는 multiply와 같다
  void _tinted(Canvas canvas, Size size, VoidCallback draw) {
    final factor = tintFactorAt(look.mix, rules, character: false);
    if (factor == _white) return draw();
    canvas.saveLayer(Offset.zero & size, _tintPaint(factor));
    draw();
    canvas.restore();
  }

  Paint _tintPaint(int factor) =>
      Paint()..colorFilter = ColorFilter.mode(Color(factor), BlendMode.modulate);

  /// 하늘: 지평선까지 세로 그라디언트(위·가운데·지평선), 그 아래는 지평선 색.
  /// 별 → 빛무리 → 해·달 순. 시간대 색은 입히지 않는다
  void _sky(Canvas canvas, Size size, double k) {
    final s = look.sky;
    final horizon = rules.horizonY * k;
    final skyRect = Rect.fromLTRB(0, 0, size.width, horizon);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(s.top), Color(s.mid), Color(s.horizon)],
          stops: [0, rules.skyMidStop, 1],
        ).createShader(skyRect),
    );
    canvas.drawRect(Rect.fromLTRB(0, horizon, size.width, size.height),
        Paint()..color = Color(s.horizon));

    canvas.save();
    canvas.clipRect(skyRect);
    _stars(canvas, size, horizon, k);
    _celestial(canvas, size, k);
    canvas.restore();
  }

  /// 별: 번호로만 정해지는 고정 위치(번호를 섞은 값이라 줄지어 서지 않는다). 하늘 위쪽 절반에 불투명도 sky.stars로
  void _stars(Canvas canvas, Size size, double horizon, double k) {
    final alpha = look.sky.stars;
    if (alpha <= 0) return;
    final paint = Paint()..color = starColor.withValues(alpha: alpha);
    for (var i = 0; i < _starCount; i++) {
      final fx = _scatter(i, 1);
      final fy = _scatter(i, 2);
      final r = (1 + i * 7 % 3) * 2.5 * k;
      canvas.drawCircle(Offset(fx * size.width, horizon * (0.03 + 0.5 * fy)), r, paint);
    }
  }

  /// 번호 [i]를 섞어 [0, 1)로. 같은 번호·[salt]면 늘 같은 값
  static double _scatter(int i, int salt) {
    var x = (i * 374761393 + salt * 668265263) & 0x7FFFFFFF;
    x = ((x ^ (x >> 13)) * 1274126177) & 0x7FFFFFFF;
    return (x ^ (x >> 16)) / 0x80000000;
  }

  /// 빛무리와 해·달. 호: x는 leftX → rightX, y는 지평선에서 peakY까지 올랐다 내려온다.
  /// 해도 달도 없을 때(none)도 빛무리는 호의 그 자리(진 자리·뜰 자리 = 지평선)에 남는다
  void _celestial(Canvas canvas, Size size, double k) {
    final arc = rules.skyArc;
    final c = look.celestial;
    final center = Offset(
      (arc.leftX + (arc.rightX - arc.leftX) * c.progress) * size.width,
      (rules.horizonY - (rules.horizonY - arc.peakY) * math.sin(math.pi * c.progress)) * k,
    );
    final radius = arc.glowRadiusPx * k;
    final glow = Color(look.sky.glow);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [
          glow.withValues(alpha: look.sky.glowStrength),
          glow.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    switch (c.body) {
      case SkyBody.sun:
        canvas.drawCircle(center, 70 * k, Paint()..color = sunDisc);
      case SkyBody.moon:
        canvas.drawCircle(center, 55 * k, Paint()..color = moonDisc);
      case SkyBody.none:
        break;
    }
  }

  /// 한 바퀴([period])마다 되풀이되는 물체의 화면 x들. [worldX]는 레이어 위 위치, [margin]은 물체 반폭
  Iterable<double> _repeats(
      double worldX, double offset, double period, double width, double margin) sync* {
    var x = (worldX - offset) % period - period;
    while (x < -margin) {
      x += period;
    }
    for (; x <= width + margin; x += period) {
      yield x;
    }
  }

  /// 윗선이 띠(bandTop~bandBottom) 안에서 오르내리는 실루엣을 [bottom]까지 채운다.
  /// 윗선은 가로 한 바퀴(widthPx)에 [waves] 개수만큼 물결치는 사인 합이라 끊김 없이 이어진다.
  /// [flatten]이 1보다 작으면 띠의 아래쪽에서만 오르내린다
  void _silhouette(Canvas canvas, Size size, double k, SceneLayer layer, double offset,
      Color color, double bottom,
      {List<int> waves = const [3, 7, 13], double phase = 0, double flatten = 1}) {
    const step = 12.0;
    final period = layer.widthPx! * k;
    final bandBottom = layer.bandBottom! * k;
    final span = (layer.bandBottom! - layer.bandTop!) * k * flatten;
    final path = Path()..moveTo(0, bottom);
    for (var x = 0.0; x <= size.width + step; x += step) {
      final t = 2 * math.pi * (x + offset) / period;
      final h = 0.5 * math.sin(waves[0] * t + phase) +
          0.35 * math.sin(waves[1] * t + 2 * phase) +
          0.15 * math.sin(waves[2] * t);
      path.lineTo(x, bandBottom - span * (0.5 + 0.5 * h));
    }
    path
      ..lineTo(size.width + step, bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// L1 후경(지역별 먼 산). 지평선 쪽으로 흐리게
  void _backdrop(Canvas canvas, Size size, double k) {
    final layer = _layer(SceneLayerId.backdrop);
    final tint = backdropTints[look.backdrop] ?? fallbackBackdropTint;
    final sea = look.backdrop == seaBackdrop;
    final bottom = math.max(layer.topY! + layer.heightPx!, rules.horizonY) * k;
    _silhouette(canvas, size, k, layer, _offset(SceneLayerId.backdrop, k),
        Color.lerp(tint, Color(look.sky.horizon), 0.45)!, bottom,
        flatten: sea ? _seaHillFlatten : 1);
  }

  /// L2 능선 (모든 지역 공통)
  void _ridge(Canvas canvas, Size size, double k) {
    final layer = _layer(SceneLayerId.ridge);
    _silhouette(canvas, size, k, layer, _offset(SceneLayerId.ridge, k),
        Color.lerp(ridgeColor, Color(look.sky.horizon), 0.25)!,
        (layer.topY! + layer.heightPx!) * k,
        waves: const [2, 5, 11], phase: 1.7);
  }

  /// L3 숲: 둥근 나무 덩이들. 덩이 꼭대기는 띠 안에, 아래는 레이어 바닥까지 채운다
  void _grove(Canvas canvas, Size size, double k) {
    final layer = _layer(SceneLayerId.grove);
    final offset = _offset(SceneLayerId.grove, k);
    final period = layer.widthPx! * k;
    final bandTop = layer.bandTop! * k;
    final bandBottom = layer.bandBottom! * k;
    final paint = Paint()..color = groveColors[look.season]!;
    canvas.drawRect(
        Rect.fromLTRB(0, bandBottom, size.width, (layer.topY! + layer.heightPx!) * k), paint);
    final spacing = period / _groveCount;
    for (var i = 0; i < _groveCount; i++) {
      // 덩이마다 크기·높이를 다르게 하는 고정된 값 (i로만 정해 항상 같다)
      final jitter = (i * 37 % 11) / 11;
      final r = (110 + 60 * ((i * 53 % 7) / 7)) * k;
      final top = bandTop + (bandBottom - bandTop) * ((i * 29 % 5) / 4);
      final worldX = (i + 0.2 + 0.6 * jitter) * spacing;
      for (final x in _repeats(worldX, offset, period, size.width, r * 2)) {
        canvas.drawCircle(Offset(x, top + r), r, paint);
        canvas.drawCircle(Offset(x - r * 0.9, top + r * 1.2), r * 0.7, paint);
        canvas.drawCircle(Offset(x + r * 0.9, top + r * 1.2), r * 0.7, paint);
      }
    }
  }

  /// L4 길 뒤 풀밭: 잔물결 치는 풀 띠
  void _meadow(Canvas canvas, Size size, double k) {
    final layer = _layer(SceneLayerId.meadow);
    _silhouette(canvas, size, k, layer, _offset(SceneLayerId.meadow, k),
        meadowColors[look.season]!, (layer.topY! + layer.heightPx!) * k,
        waves: const [6, 11, 23], phase: 0.6);
  }

  /// 땅: 길 띠(흙)와 그 아래 풀 언덕을 화면 맨 아래까지. 길 위쪽은 비워서 풀밭이 보인다.
  /// 줄무늬로 움직임이 보이게 한다
  void _ground(Canvas canvas, Size size, double k) {
    final layer = _layer(SceneLayerId.ground);
    final pathTop = (rules.pathY - _pathHalfWidth) * k;
    final pathBottom = (rules.pathY + _pathHalfWidth) * k;
    final bottom = (layer.topY! + layer.heightPx!) * k;
    canvas.drawRect(Rect.fromLTRB(0, pathBottom, size.width, bottom),
        Paint()..color = groundColors[look.season]!);
    canvas.drawRect(
        Rect.fromLTRB(0, pathTop, size.width, pathBottom), Paint()..color = pathColor);

    final period = layer.widthPx! * k;
    final stripeW = period / _groundStripes;
    final offset = _offset(SceneLayerId.ground, k);
    final dark = Paint()..color = Palette.ink.withValues(alpha: 0.10);
    for (var i = (offset / stripeW).floor(); i * stripeW < offset + size.width; i++) {
      if (i.isEven) continue;
      final x = i * stripeW - offset;
      canvas.drawRect(Rect.fromLTRB(x, pathTop, x + stripeW, bottom), dark);
    }
    final edge = Paint()
      ..color = Palette.ink
      ..strokeWidth = 5 * k;
    canvas.drawLine(Offset(0, pathTop), Offset(size.width, pathTop), edge);
    canvas.drawLine(Offset(0, pathBottom), Offset(size.width, pathBottom), edge);
  }

  /// 배 구간: 지평선 아래를 바다색으로 채우고, 땅 자리에 물결을 줄지어 땅과 같은 속도로 흘린다.
  /// 물결은 한 바퀴를 나눠 떨어져야 이어진다
  void _seaGround(Canvas canvas, Size size, double k) {
    final layer = _layer(SceneLayerId.ground);
    canvas.drawRect(Rect.fromLTRB(0, rules.horizonY * k, size.width, size.height),
        Paint()..color = seaColor);

    final period = layer.widthPx! * k;
    final waveLen = period / 16;
    final offset = _offset(SceneLayerId.ground, k);
    final wave = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * k
      ..strokeCap = StrokeCap.round;
    const rows = 6;
    final top = layer.topY! * k;
    final rowH = layer.heightPx! * k / rows;
    for (var r = 0; r < rows; r++) {
      final y = top + (r + 0.5) * rowH;
      final path = Path();
      for (var x = 0.0; x <= size.width + 8; x += 8) {
        final yy = y + 12 * k * math.sin(2 * math.pi * (x + offset) / waveLen + r * 1.7);
        x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
      }
      canvas.drawPath(path, wave);
    }
    _boat(canvas, size, k);
  }

  /// 화면 가운데에 고정된 배. 갑판이 길 높이(pathY)에 놓여 캐릭터가 그 위에 선다
  void _boat(Canvas canvas, Size size, double k) {
    final u = _unit(k);
    final cx = size.width / 2;
    final deckY = rules.pathY * k;
    final halfDeck = size.width * 0.30;
    final halfKeel = size.width * 0.22;
    final depth = size.height * 0.045;
    final stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * u
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 돛대와 깃발 (뒤쪽)
    final mastX = cx - halfDeck * 0.8;
    canvas.drawLine(Offset(mastX, deckY), Offset(mastX, deckY - 120 * u), stroke);
    final flag = Path()
      ..moveTo(mastX, deckY - 120 * u)
      ..lineTo(mastX + 34 * u, deckY - 108 * u)
      ..lineTo(mastX, deckY - 96 * u)
      ..close();
    canvas.drawPath(flag, Paint()..color = Palette.terracotta);
    canvas.drawPath(flag, stroke);

    final hull = Path()
      ..moveTo(cx - halfDeck, deckY)
      ..lineTo(cx + halfDeck, deckY)
      ..lineTo(cx + halfKeel, deckY + depth)
      ..lineTo(cx - halfKeel, deckY + depth)
      ..close();
    canvas.drawPath(hull, Paint()..color = boatHull);
    canvas.drawPath(hull, stroke);
    canvas.drawLine(Offset(cx - halfDeck, deckY), Offset(cx + halfDeck, deckY),
        Paint()
          ..color = boatDeck
          ..strokeWidth = 6 * u);
  }

  /// L5 전경 풀: 땅과 같은 속도. 풀 뿌리는 레이어 바닥 가까이, 끝은 띠 안까지 올라온다.
  /// 캐릭터가 가리지 않게 듬성듬성
  void _foreground(Canvas canvas, Size size, double k) {
    final layer = _layer(SceneLayerId.foreground);
    final period = layer.widthPx! * k;
    final offset = _offset(SceneLayerId.foreground, k);
    final base = (layer.topY! + layer.heightPx!) * k;
    final tipTop = layer.bandTop! * k;
    final tipBottom = layer.bandBottom! * k;
    final blade = Paint()
      ..color = tuftColors[look.season]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * k
      ..strokeCap = StrokeCap.round;
    final speck = Paint()..color = tuftSpecks[look.season]!;
    final spacing = period / _tuftCount;
    for (var i = 0; i < _tuftCount; i++) {
      // 풀마다 높이·간격을 다르게 하는 고정된 값 (i로만 정해 항상 같다)
      final jitter = (i * 37 % 11) / 11;
      final worldX = i * spacing + jitter * spacing * 0.6;
      final baseY = base - 12 * k * ((i * 53 % 7) / 7);
      final tipY = tipTop + (tipBottom - tipTop) * ((i * 53 % 7) / 7);
      for (final x in _repeats(worldX, offset, period, size.width, 60 * k)) {
        for (final dx in const [-18.0, 0.0, 18.0]) {
          canvas.drawLine(Offset(x + dx * k, baseY), Offset(x + dx * 1.8 * k, tipY), blade);
        }
        if (look.season != Season.summer) {
          canvas.drawCircle(Offset(x + 32 * k, tipY), 8 * k, speck);
        }
      }
    }
  }

  void _tent(Canvas canvas, Size size, double u, FootSpot spot) {
    final cx = spot.x * size.width;
    final fy = spot.footY * size.height;
    final w = 110 * u;
    final h = 100 * u;
    final stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * u
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(cx - w / 2, fy)
      ..lineTo(cx, fy - h)
      ..lineTo(cx + w / 2, fy)
      ..close();
    canvas.drawPath(body, Paint()..color = tentColor);
    canvas.drawPath(body, stroke);
    final door = Path()
      ..moveTo(cx - w * 0.12, fy)
      ..lineTo(cx, fy - h * 0.55)
      ..lineTo(cx + w * 0.12, fy)
      ..close();
    canvas.drawPath(door, Paint()..color = tentDoor);
    canvas.drawPath(door, stroke);
  }

  void _signpost(Canvas canvas, Size size, double u, FootSpot spot) {
    final x = spot.x * size.width;
    final fy = spot.footY * size.height;
    final wood = Paint()..color = woodColor;
    final stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u;
    final pole = Rect.fromLTWH(x - 3 * u, fy - 80 * u, 6 * u, 80 * u);
    canvas.drawRect(pole, wood);
    canvas.drawRect(pole, stroke);
    for (final (i, dir) in [(0, 1.0), (1, -1.0)]) {
      final y = fy - (76 - i * 22) * u;
      final plank = Rect.fromLTWH(dir > 0 ? x : x - 44 * u, y, 44 * u, 16 * u);
      canvas.drawRect(plank, wood);
      canvas.drawRect(plank, stroke);
    }
  }

  /// 모닥불: 캐릭터와 동료 자리 사이, 캐릭터 앞쪽. 밤일수록 불빛이 번진다
  void _fire(Canvas canvas, Size size, double u, CampTheme camp) {
    final x = (camp.character.x + camp.companion.x) / 2 * size.width;
    final fy = (camp.character.footY + 0.02) * size.height;
    final glow = switch (look.phase) {
      SkyPhase.night => 0.40,
      SkyPhase.sunset || SkyPhase.dawn => 0.25,
      _ => 0.10,
    };
    canvas.drawCircle(
      Offset(x, fy - 18 * u),
      70 * u,
      Paint()
        ..shader = RadialGradient(colors: [
          flameOuter.withValues(alpha: glow),
          flameOuter.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: Offset(x, fy - 18 * u), radius: 70 * u)),
    );
    final log = Paint()
      ..color = woodColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - 22 * u, fy), Offset(x + 18 * u, fy - 8 * u), log);
    canvas.drawLine(Offset(x + 22 * u, fy), Offset(x - 18 * u, fy - 8 * u), log);
    Path flame(double s) => Path()
      ..moveTo(x - 14 * s * u, fy - 8 * u)
      ..quadraticBezierTo(x - 16 * s * u, fy - 30 * s * u, x, fy - 52 * s * u)
      ..quadraticBezierTo(x + 16 * s * u, fy - 30 * s * u, x + 14 * s * u, fy - 8 * u)
      ..close();
    canvas.drawPath(flame(1), Paint()..color = flameOuter);
    canvas.drawPath(flame(0.55), Paint()..color = flameInner);
  }

  /// 캐릭터 자리표시자: 잉크 선의 작은 화가. 오른쪽을 보고 선다.
  /// 키(발~베레모 꼭대기)가 config characterHeightPx × k가 되게 그림 좌표(135)를 키운다.
  /// 걷기는 다리를 걸음 보폭에 맞춰 흔들고, 달리기는 앞으로 기울고 속도 선이 붙는다.
  /// 서 있을 때(쉼터·배 위)는 다리를 흔들지 않는다
  void _character(Canvas canvas, double k, double cx, double footY, {required bool standing}) {
    canvas.save();
    canvas.translate(cx, footY);
    canvas.scale(_unit(k));
    // 캐릭터에는 캐릭터 세기로 입힌다 (그려지는 범위만 레이어로)
    final factor = tintFactorAt(look.mix, rules, character: true);
    final tinted = factor != _white;
    if (tinted) {
      canvas.saveLayer(const Rect.fromLTRB(-100, -160, 70, 20), _tintPaint(factor));
    }

    final ink = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final limb = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // 그림자
    canvas.drawOval(const Rect.fromLTWH(-30, -5, 60, 10),
        Paint()..color = Palette.ink.withValues(alpha: 0.18));

    // 걸음 한 쌍(보폭 두 번)마다 다리가 한 바퀴
    final stride = running ? rules.runStrideM : rules.walkStrideM;
    final swing = standing ? 0.0 : math.sin(2 * math.pi * distanceM / (2 * stride));
    final legAngle = swing * (running ? 0.75 : 0.45);

    const hipY = -38.0;
    const legLen = 38.0;
    for (final s in const [1.0, -1.0]) {
      final a = legAngle * s;
      canvas.drawLine(Offset(s * 5, hipY),
          Offset(s * 5 + math.sin(a) * legLen, hipY + math.cos(a) * legLen), limb);
    }

    // 몸통부터는 엉덩이를 축으로 앞으로 기운다
    canvas.save();
    canvas.translate(0, hipY);
    canvas.rotate(running && !standing ? 0.22 : 0.04);
    canvas.translate(0, -hipY);

    // 배낭 (뒤)
    final pack = RRect.fromRectAndRadius(
        const Rect.fromLTRB(-30, -82, -10, -44), const Radius.circular(6));
    canvas.drawRRect(pack, Paint()..color = Palette.moss);
    canvas.drawRRect(pack, ink);

    // 팔
    final armA = -legAngle * 1.2;
    canvas.drawLine(const Offset(6, -78),
        Offset(6 + math.sin(armA) * 28, -78 + math.cos(armA) * 28), limb);

    // 몸통(코트)
    final torso = RRect.fromRectAndRadius(
        const Rect.fromLTRB(-16, -86, 16, -34), const Radius.circular(10));
    canvas.drawRRect(torso, Paint()..color = Palette.terracotta);
    canvas.drawRRect(torso, ink);

    // 머리: 2.5등신 느낌의 큰 머리
    const head = Offset(0, -106);
    canvas.drawCircle(head, 24, Paint()..color = Palette.card);
    canvas.drawCircle(head, 24, ink);
    canvas.drawCircle(const Offset(10, -106), 2.5, Paint()..color = Palette.ink);
    // 베레모
    final beret = Rect.fromCenter(center: const Offset(2, -126), width: 46, height: 18);
    canvas.drawOval(beret, Paint()..color = Palette.ink);
    canvas.restore();

    if (running && !standing) {
      for (final y in const [-90.0, -70.0, -50.0]) {
        canvas.drawLine(Offset(-44, y), Offset(-76, y),
            Paint()
              ..color = Palette.ink.withValues(alpha: 0.45)
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round);
      }
    }
    if (tinted) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.look != look ||
      old.mode != mode ||
      old.distanceM != distanceM ||
      old.onSea != onSea ||
      old.running != running ||
      old.camp != camp ||
      old.rules != rules;
}
