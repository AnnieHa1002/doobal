import 'package:flutter/material.dart';

import '../../domain/camp_theme.dart';
import '../../domain/geo.dart';
import '../../domain/landmark.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart';
import 'scene_painter.dart';

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

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: ScenePainter(
          look: sceneLook(nowUtc, position, onSea, landmarks, rules),
          mode: mode,
          distanceM: distanceM,
          rules: rules,
          onSea: onSea,
          running: running,
          camp: camp,
        ),
      ),
    );
  }
}
