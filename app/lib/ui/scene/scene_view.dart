import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../domain/boat.dart';
import '../../domain/camp_theme.dart';
import '../../domain/geo.dart';
import '../../domain/landmark.dart';
import '../../domain/rest_camera.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
import '../../domain/spirit_look.dart';
import '../../domain/time_tint.dart';
import 'doobal_character.dart';
import 'scene_painter.dart';
import 'scene_art.dart';
import 'scene_art_painter.dart';

export 'scene_painter.dart' show SceneMode;

/// 쉼터·걷는 중이 함께 쓰는 장면. 화면을 가득 채우고, 위 레이어(버튼·패널)는 밖에서 얹는다.
/// 하늘은 [nowUtc]와 [position]의 일출·일몰로, 후경은 위치로, 땅은 [distanceM]으로 정해진다
class SceneView extends StatelessWidget {
  const SceneView({
    super.key,
    required this.mode,
    required this.distanceM,
    required this.nowUtc,
    required this.position,
    required this.onSea,
    required this.rules,
    required this.landmarks,
    this.camp,
    this.running = false,
    this.moving = true,
    this.seated = true,
    this.sceneSeed = 'default',
    this.spirit = SpiritLook.base,
    this.boat,
    this.camera,
    this.sceneBehind = const [],
    this.sceneBeside = const [],
    this.sceneAbove = const [],
    this.walkCompanion,
  });

  final SceneMode mode;

  /// 땅이 스크롤되는 거리(m). 쉼터는 0
  final double distanceM;
  final DateTime nowUtc;
  final LatLng position;
  final bool onSea;
  final Rules rules;
  final List<Landmark> landmarks;

  /// 쉼터 테마 (쉼터에서만)
  final CampTheme? camp;

  /// 달리는 중이면 true (캐릭터 모습이 달라진다)
  final bool running;

  /// 현재 걸음 기록이 있을 때만 움직인다.
  final bool moving;

  /// 쉼터에서는 기본으로 앉는다. 서서 쉬는 장면에서는 false를 전달한다.
  final bool seated;

  /// 같은 여정·구간의 군락이 다시 방문해도 바뀌지 않는다.
  final String sceneSeed;

  /// 정령이 입은 얼굴·소품
  final SpiritLook spirit;

  /// 배 구간에 그릴 배. 없으면 옛 배 한 장
  final BoatArt? boat;

  /// 쉼터 밀기·확대. 없으면 처음 화면에 고정이다 (camp가 있을 때만 쓴다)
  final ValueListenable<RestCamera>? camera;

  /// 쉼터 장면에 얹는 것 (camp가 있을 때만, Positioned). 좌표는 확대·밀기 전 기기 pt이고 장면과 함께 움직인다.
  /// [sceneBehind]는 정령 뒤(물건), [sceneBeside]는 정령과 앞판 사이(동행), [sceneAbove]는 맨 위(누름 상자)
  final List<Widget> sceneBehind;
  final List<Widget> sceneBeside;
  final List<Widget> sceneAbove;

  /// 걷는 중 장면의 동행 층 (정령 뒤·앞풀 아래). 장면이 자리를 넘겨 부른다. 없으면 혼자다
  final Widget Function(SceneCompanionSpot spot)? walkCompanion;

  @override
  Widget build(BuildContext context) {
    final look = sceneLook(nowUtc, position, onSea, landmarks, rules);
    final rest = mode == SceneMode.rest;
    final speed = rest || onSea || !moving ? 0.0 : (running ? 2.0 : 1.0);
    final pose = onSea
        ? DoobalPose.boat
        : rest && seated
        ? DoobalPose.sitting
        : DoobalPose.standing;
    final tint = tintFactorAt(look.mix, rules, character: true);
    ScenePainter painter(ScenePass pass) => ScenePainter(
      look: look,
      mode: mode,
      distanceM: distanceM,
      rules: rules,
      onSea: onSea,
      running: running,
      camp: camp,
      pass: pass,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final stage = rest && camp != null
            ? RestGeometry(camp!, rules.rest, size.width, size.height)
            : null;
        return SceneArtHost(
          look: look,
          mode: mode,
          size: size,
          onSea: onSea,
          boat: boat,
          camp: camp,
          restFarWidth: stage?.farWidth,
          builder: (context, art, clock) {
            if (stage != null) {
              return _restStage(stage, art, clock, look, pose, speed, tint, painter);
            }
            return ValueListenableBuilder<double>(
              valueListenable: clock,
              builder: (context, elapsed, _) =>
                  _walkStage(size, art, elapsed, look, pose, speed, tint, painter),
            );
          },
        );
      },
    );
  }

  /// 걷는 중 장면: 땅·배 판 → 정령 → 앞풀. 거리와 시계에 따라 다시 그린다
  Widget _walkStage(
    Size size,
    SceneArt? art,
    double elapsed,
    SceneLook look,
    DoobalPose pose,
    double speed,
    int tint,
    ScenePainter Function(ScenePass) painter,
  ) {
    final artLayout = art == null
        ? null
        : SceneArtLayout(art, size, mode, onSea, camp);
    CustomPainter layer(ScenePass pass) => art == null
        ? painter(pass)
        : SceneArtPainter(
            art: art,
            look: look,
            mode: mode,
            distanceM: distanceM,
            rules: rules,
            onSea: onSea,
            pass: pass,
            elapsed: elapsed,
            camp: camp,
            seed: sceneSeed,
          );
    final k = size.height / rules.screenHeightPx;
    final baseFoot = artLayout?.foot ?? Offset(size.width / 2, rules.pathY * k);
    final foot = baseFoot + Offset(0, artLayout?.boatSwayY(elapsed) ?? 0);
    // 정령의 머리 위 y150~발바닥 y440을 실제 캐릭터 키로 맞춘다.
    // 키는 config다: 가로 화면은 기준 1170px, 세로는 기준 화면 높이에 대한 값.
    final figureHeight =
        artLayout?.figureHeight ??
        (size.width > size.height
            ? rules.characterHeightLandscapePx * size.height / 1170
            : rules.characterHeightPx * k);
    final companion = walkCompanion;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: layer(ScenePass.background)),
        ),
        // 동행이 없어도 자리는 둔다 (정령이 다시 만들어지지 않게)
        Positioned.fill(
          child: IgnorePointer(
            child: companion == null
                ? const SizedBox.shrink()
                : companion(_companionSpot(size, art, artLayout, foot, figureHeight, tint)),
          ),
        ),
        _character(foot, figureHeight, speed, pose, tint),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: layer(ScenePass.foreground)),
          ),
        ),
      ],
    );
  }

  /// 동행 층에 넘길 자리. 배 위면 배 그림의 동행 발(boat_layers companionFoot)을 정령 발과 같이 흔든다
  SceneCompanionSpot _companionSpot(
    Size size,
    SceneArt? art,
    SceneArtLayout? layout,
    Offset foot,
    double figureHeight,
    int tint,
  ) {
    final boat = onSea ? art?.boat : null;
    final at = boat == null || layout == null
        ? null
        : placeBoat(
            boat.art,
            footX: foot.dx,
            footY: foot.dy,
            scale: layout.figureHeight / rules.characterCanvasHeightPx,
          ).companionFoot;
    return SceneCompanionSpot(
      size: size,
      spiritFoot: foot,
      figureHeight: figureHeight,
      groundPtPerM: rules.groundPxPerM *
          (layout == null ? figureHeight / rules.characterHeightPx : layout.scale * layout.groundScale),
      tint: tint,
      boatFoot: at == null ? null : Offset(at.x, at.y),
    );
  }

  /// 정령 (발 [foot], 키 [figureHeight]). 정령의 머리 위 y150~발바닥 y440을 키로 본다
  Widget _character(Offset foot, double figureHeight, double speed, DoobalPose pose, int tint) {
    final scale = figureHeight / (440 - 150);
    return Positioned(
      left: foot.dx - 300 * scale,
      top: foot.dy - 440 * scale,
      width: 600 * scale,
      height: 600 * scale,
      child: SceneTinted(
        tint: tint,
        child: RepaintBoundary(
          child: DoobalCharacter(
            speed: speed,
            pose: pose,
            spirit: spirit,
            // 쉼터에서만 정령을 연타하면 화낸다
            tapRules: mode == SceneMode.rest ? rules : null,
          ),
        ),
      ),
    );
  }

  /// 쉼터 장면: 하늘·후경 한 층(천천히)과 캠프·물건·정령 한 층. 두 층을 옮기고 키우기만 하므로
  /// 밀거나 확대할 때 다시 그리지 않는다. 시간에 따라 다시 그리는 것은 구름과 불꽃뿐이다
  Widget _restStage(
    RestGeometry stage,
    SceneArt? art,
    ValueListenable<double> clock,
    SceneLook look,
    DoobalPose pose,
    double speed,
    int tint,
    ScenePainter Function(ScenePass) fallback,
  ) {
    final near = Size(stage.sceneWidth, stage.height);
    final far = Size(stage.farWidth, stage.height);
    final screen = Size(stage.width, stage.height);
    CustomPainter layer(ScenePass pass, [double elapsed = 0]) => SceneArtPainter(
      art: art!,
      look: look,
      mode: mode,
      distanceM: distanceM,
      rules: rules,
      onSea: onSea,
      pass: pass,
      elapsed: elapsed,
      camp: camp,
      seed: sceneSeed,
      layoutSize: screen,
    );
    final layout = art == null ? null : SceneArtLayout(art, screen, mode, onSea, camp);
    final foot = layout?.foot ??
        Offset(stage.sx(camp!.character.footX), stage.sy(camp!.character.footY));
    final figureHeight = camp!.character.heightPt * stage.k;
    // 시계를 들으며 움직이는 층 하나
    Widget ticking(ScenePass pass, Size size) => RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: clock,
        builder: (_, elapsed, _) => CustomPaint(size: size, painter: layer(pass, elapsed)),
      ),
    );
    Widget placed(Size size, Matrix4 Function(RestCamera) matrix, Widget child) => Positioned(
      left: 0,
      top: 0,
      width: size.width,
      height: size.height,
      child: camera == null
          ? child
          : AnimatedBuilder(
              animation: camera!,
              child: child,
              builder: (_, child) =>
                  Transform(transform: matrix(stage.clamp(camera!.value)), child: child),
            ),
    );
    return ClipRect(
      child: Stack(
        children: [
          placed(
            far,
            (c) => _matrix(stage.farX(c), stage.liftY(c), c.zoom),
            art == null
                ? RepaintBoundary(
                    child: CustomPaint(size: far, painter: fallback(ScenePass.background)),
                  )
                : SizedBox.fromSize(
                    size: far,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(size: far, painter: layer(ScenePass.restSky)),
                        ),
                        ticking(ScenePass.restClouds, far),
                        RepaintBoundary(
                          child: CustomPaint(size: far, painter: layer(ScenePass.restFar)),
                        ),
                      ],
                    ),
                  ),
          ),
          placed(
            near,
            (c) => _matrix(c.x, stage.liftY(c), c.zoom),
            SizedBox.fromSize(
              size: near,
              child: Stack(
                children: [
                  if (art != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: layer(ScenePass.restBack)),
                      ),
                    ),
                  ...sceneBehind,
                  _character(foot, figureHeight, speed, pose, tint),
                  ...sceneBeside,
                  if (art != null) ...[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: layer(ScenePass.restFront)),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(child: ticking(ScenePass.restFire, near)),
                    ),
                  ] else
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: fallback(ScenePass.foreground)),
                      ),
                    ),
                  ...sceneAbove,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 걷는 중 장면이 동행 층에 주는 자리. 좌표는 장면(화면) pt
class SceneCompanionSpot {
  const SceneCompanionSpot({
    required this.size,
    required this.spiritFoot,
    required this.figureHeight,
    required this.groundPtPerM,
    required this.tint,
    this.boatFoot,
  });

  final Size size;

  /// 정령 발 (배 흔들림 포함)
  final Offset spiritFoot;

  /// 정령 키. 동행 키는 이것의 비율이다
  final double figureHeight;

  /// 땅 1m가 화면에서 몇 pt인가 (뒤처진 거리를 화면 거리로)
  final double groundPtPerM;

  /// 시간대 보정 색 (흰색이면 없음). 동행에도 입힌다 (M2)
  final int tint;

  /// 배 위 동행 발 (흔들림 포함). 땅 위거나 배 그림이 없으면 null
  final Offset? boatFoot;
}

/// 시간대 색을 곱한다. 낮(흰색)에는 층을 만들지 않는다 (정령·동행)
class SceneTinted extends StatelessWidget {
  const SceneTinted({super.key, required this.tint, required this.child});

  final int tint;
  final Widget child;

  @override
  Widget build(BuildContext context) => tint == 0xFFFFFFFF
      ? child
      : ColorFiltered(
          colorFilter: ColorFilter.mode(Color(tint), BlendMode.modulate),
          child: child,
        );
}

/// 배율 [zoom]으로 키운 뒤 ([x], [y])만큼 옮기는 행렬
Matrix4 _matrix(double x, double y, double zoom) =>
    Matrix4.diagonal3Values(zoom, zoom, 1)..setTranslationRaw(x, y, 0);
