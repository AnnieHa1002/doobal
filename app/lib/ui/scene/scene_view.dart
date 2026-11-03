import 'package:flutter/material.dart';

import '../../domain/camp_theme.dart';
import '../../domain/geo.dart';
import '../../domain/landmark.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
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
        return SceneArtHost(
          look: look,
          mode: mode,
          size: size,
          onSea: onSea,
          builder: (context, art, elapsed) {
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
            final baseFoot =
                artLayout?.foot ??
                (rest && camp != null
                    ? Offset(
                        camp!.character.x * size.width,
                        camp!.character.footY * size.height,
                      )
                    : Offset(size.width / 2, rules.pathY * k));
            // 앞으로 뻗은 앉은 발이 모닥불에 겹치지 않도록 뒤·왼쪽에 앉힌다.
            final foot = rest && seated && !onSea
                ? baseFoot + Offset(-size.width * .10, -size.height * .075)
                : baseFoot;
            // 정령의 머리 위 y150~발바닥 y440을 실제 캐릭터 키로 맞춘다.
            // 가로 화면은 기준 1170px에서 키616px, 세로는 config의 키를 쓴다.
            final figureHeight =
                artLayout?.figureHeight ??
                (size.width > size.height
                    ? 616 * size.height / 1170
                    : rules.characterHeightPx * k);
            final scale = figureHeight / (440 - 150);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: layer(ScenePass.background)),
                ),
                Positioned(
                  left: foot.dx - 300 * scale,
                  top: foot.dy - 440 * scale,
                  width: 600 * scale,
                  height: 600 * scale,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Color(tint),
                      BlendMode.modulate,
                    ),
                    child: RepaintBoundary(
                      child: DoobalCharacter(speed: speed, pose: pose),
                    ),
                  ),
                ),
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
}
