import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sketch.dart';
import '../scene/scene_view.dart';
import 'palette.dart';

/// 장면을 그리는 기준 화면 (폰 비율). 이 크기로 그린 뒤 부모 상자에 맞춰 자른다
const _sceneSize = Size(390, 844);

/// 캐릭터(화면 아래쪽)가 보이게 위를 잘라 내는 정렬. 가로 상자에서도 땅과 캐릭터가 남는다
const _characterAlignment = Alignment(0, 0.6);

/// 내 동네 스케치: 도착한 순간의 장면에 내 캐릭터를 얹은 그림. 걷는 중과 같은 장면 그리기를
/// 거리 0·도착 시각·적어 둔 후경으로 다시 그린다 (하늘·계절·시간대 보정은 도착 시각에서).
/// 부모가 정한 크기를 꽉 채우고 넘치는 곳은 자른다. 종이 질감과 액자는 디자인이 정하면
/// 맨 위 레이어로 더한다. 캐릭터는 아직 자리표시 그림이라 [Sketch.look]은 그리는 데 쓰지 않는다 (M4)
class SketchPainting extends ConsumerWidget {
  const SketchPainting({super.key, required this.sketch});

  final Sketch sketch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider).value;
    final landmarks = ref.watch(landmarksProvider).value;
    if (rules == null || landmarks == null) return const SizedBox.shrink();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: _characterAlignment,
        child: SizedBox.fromSize(
          size: _sceneSize,
          child: SceneView(
            mode: SceneMode.walking,
            distanceM: 0,
            nowUtc: sketch.arrivedAt,
            position: sketch.point,
            onSea: false,
            rules: rules,
            landmarks: landmarks,
            backdrop: sketch.backdrop,
          ),
        ),
      ),
    );
  }
}

/// [SketchPainting]에 잉크색 얇은 테두리를 두른 것 (화집 칸·벽·도착·상세).
/// 액자 등급이 없는 자리라 색 액자 대신 선만 긋는다. 부모를 꽉 채운다
class SketchThumb extends StatelessWidget {
  const SketchThumb({super.key, required this.sketch});

  final Sketch sketch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Palette.ink, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SketchPainting(sketch: sketch),
      ),
    );
  }
}
