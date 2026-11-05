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
          builder: (context, art, elapsed) {
            if (stage != null) {
              return _restStage(stage, art, elapsed, look, pose, speed, tint, painter);
            }
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
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: layer(ScenePass.background)),
                ),
                _character(foot, figureHeight, speed, pose, tint),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: layer(ScenePass.foreground)),
                  ),
                ),
              ],
            );
          },
        );
      },
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
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(Color(tint), BlendMode.modulate),
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
  /// 밀거나 확대할 때 다시 그리지 않는다
  Widget _restStage(
    RestGeometry stage,
    SceneArt? art,
    double elapsed,
    SceneLook look,
    DoobalPose pose,
    double speed,
    int tint,
    ScenePainter Function(ScenePass) fallback,
  ) {
    final near = Size(stage.sceneWidth, stage.height);
    final far = Size(stage.farWidth, stage.height);
    final screen = Size(stage.width, stage.height);
    CustomPainter layer(ScenePass pass) => SceneArtPainter(
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
            RepaintBoundary(
              child: CustomPaint(
                size: far,
                painter: art == null ? fallback(ScenePass.background) : layer(ScenePass.restFar),
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
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: layer(ScenePass.restFire)),
                        ),
                      ),
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

/// 배율 [zoom]으로 키운 뒤 ([x], [y])만큼 옮기는 행렬
Matrix4 _matrix(double x, double y, double zoom) =>
    Matrix4.diagonal3Values(zoom, zoom, 1)..setTranslationRaw(x, y, 0);
