import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../domain/boat.dart';
import '../../domain/camp_theme.dart';
import '../../domain/geo.dart';
import '../../domain/landmark.dart';
import '../../domain/rest_camera.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
import '../../domain/screen_rules.dart';
import '../../domain/sky.dart';
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
    this.playback = 1,
    this.seated = true,
    this.sceneSeed = 'default',
    this.spirit = SpiritLook.base,
    this.boat,
    this.camera,
    this.sceneBehind = const [],
    this.sceneBeside = const [],
    this.sceneAbove = const [],
    this.walkCompanion,
    this.walkGround,
    this.walkRoadside,
    this.restPose,
    this.spiritCue,
    this.spiritCues,
    this.onSpiritLongPress,
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

  /// 정령 걷기·뛰기 동작의 재생 빠르기 (걷는 중이 분당 걸음으로 낸다, config character.rive.walkPlayback)
  final double playback;

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

  /// 걷는 중 장면의 땅 위 층 (땅과 같이 흐르는 물감 방울, 정령·동행 뒤). 장면이 자리를 넘겨 부른다
  final Widget Function(SceneCompanionSpot spot)? walkGround;

  /// 걷는 중 장면의 길가 층 (화면에 고정된 방명록 표지판, 물감 방울 위·동행 뒤). 눌린다
  final Widget Function(SceneCompanionSpot spot)? walkRoadside;

  /// 쉼터 정령의 지금 자세 (쉼터가 config restSwap으로 20~40초마다 바꾼다). null이면 쉼터 첫 자세.
  /// 밤에는 이것 대신 잠들기 (config restSwap.night)
  final int? restPose;

  /// 잠깐 보일 정령 표정 (만남·새 소품 …). 다른 객체로 바뀔 때 한 번 울린다
  final SpiritCue? spiritCue;

  /// 정령 표정 호출 표 (밤 쉼터 졸림·누르기 행복·연타 화남). 없으면 표정 없이 동작만
  final SpiritCues? spiritCues;

  /// 정령을 길게 누르면 (쉼터 → 정령 꾸미기, config character.tapReaction.longPress). 없으면 길게 눌러도 그대로
  final VoidCallback? onSpiritLongPress;

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
    final stand = _stand(look, rest, speed);
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
              return _restStage(stage, art, clock, look, pose, speed, tint, stand, painter);
            }
            return ValueListenableBuilder<double>(
              valueListenable: clock,
              builder: (context, elapsed, _) =>
                  _walkStage(size, art, elapsed, look, pose, speed, tint, stand, painter),
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
    _SpiritStand stand,
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
    final ground = walkGround;
    final roadside = walkRoadside;
    final spot = companion == null && ground == null && roadside == null
        ? null
        : _companionSpot(size, art, artLayout, foot, figureHeight, tint);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: layer(ScenePass.background)),
        ),
        if (ground != null) Positioned.fill(child: IgnorePointer(child: ground(spot!))),
        if (roadside != null) Positioned.fill(child: roadside(spot!)),
        // 동행이 없어도 자리는 둔다 (정령이 다시 만들어지지 않게). 동행은 눌린다 (걷기 탭 → 동행 화면)
        Positioned.fill(
          child: companion == null ? const SizedBox.shrink() : companion(spot!),
        ),
        _character(foot, figureHeight, speed, pose, tint, stand),
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

  /// 화면별 정령 자세·방향·표정 (config character.rive.screens·restSwap·flipSideOn, 정령 계약 3·4장):
  /// 쉼터는 [restPose](밤에는 잠들기 + 졸림), 걷는 중은 옆 이동·멈추면 둥둥 옆이고 좌우로 뒤집는다.
  /// 배 위는 지금처럼 장면이 정한다 (config에 배 자세가 없다)
  _SpiritStand _stand(SceneLook look, bool rest, double speed) {
    final stage = rules.screen.spirit;
    if (rest) {
      final night = look.phase == SkyPhase.night;
      return (
        pose: night ? stage.restSwap.night : restPose ?? stage.poseOf('rest'),
        mirrored: false,
        expression: night ? spiritCues?.of('nightRest')?.expr ?? 0 : 0,
      );
    }
    if (onSea) return (pose: null, mirrored: false, expression: 0);
    final screen = speed > 0 ? 'walking' : 'walkingIdle';
    return (pose: stage.poseOf(screen), mirrored: stage.flips(screen), expression: 0);
  }

  /// 정령 (발 [foot], 키 [figureHeight]). 정령의 머리 위 y150~발바닥 y440을 키로 본다
  Widget _character(
    Offset foot,
    double figureHeight,
    double speed,
    DoobalPose pose,
    int tint,
    _SpiritStand stand,
  ) {
    final scale = figureHeight / (440 - 150);
    return Positioned(
      left: foot.dx - 300 * scale,
      top: foot.dy - 440 * scale,
      width: 600 * scale,
      height: 600 * scale,
      child: SceneTinted(
        tint: tint,
        child: _longPress(RepaintBoundary(
          child: DoobalCharacter(
            speed: speed,
            playback: playback,
            pose: pose,
            spirit: spirit,
            // 쉼터에서만 정령을 연타하면 화낸다
            tapRules: mode == SceneMode.rest ? rules : null,
            posePick: stand.pose,
            mirrored: stand.mirrored,
            expression: stand.expression,
            cue: spiritCue,
            cues: spiritCues,
          ),
        )),
      ),
    );
  }

  /// 정령 길게 누르기. 누르기 반응(정령 안의 탭)과 겨루다 0.5초가 지나면 이쪽이 이긴다.
  /// 걷는 중 장면의 정령은 누르기를 받지 않는다 (config character.tapReaction.screens는 쉼터·꾸미기):
  /// 정령의 600 캔버스 상자가 넓어서 그 뒤의 동행·길가 표지판을 가리지 않게
  Widget _longPress(Widget spirit) {
    if (mode != SceneMode.rest) return IgnorePointer(child: spirit);
    final onLong = onSpiritLongPress;
    if (onLong == null) return spirit;
    return GestureDetector(key: const ValueKey('spirit-long-press'), onLongPress: onLong, child: spirit);
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
    _SpiritStand stand,
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
                  _character(foot, figureHeight, speed, pose, tint, stand),
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

/// 장면 정령의 자세 번호(null이면 장면 속도·앉기로)·좌우 뒤집기·늘 두는 표정
typedef _SpiritStand = ({int? pose, bool mirrored, int expression});
