import 'package:flutter/widgets.dart';

import '../../domain/motion_rules.dart';

// 연출 공통 (T19, config ui.motion). 움직임 줄이기면 끝 상태만 보이고(reducedMotion endStateOnly), 연출이 끝나기 전에
// 다시 시작되면 끝 상태로 건너뛴 뒤 처음부터 한다(repeat skipToEndThenRestart: controller.forward(from: 0))

/// 기기 설정 ‘움직임 줄이기’가 켜졌는가. 켜졌으면 연출 없이 끝 상태만 그린다
bool motionReduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [sec]초짜리 연출 시계. 처음 값은 끝(1)이라 시작하기 전에는 끝 상태를 그린다
AnimationController motionController(TickerProvider vsync, double sec) =>
    AnimationController(vsync: vsync, duration: motionDuration(sec), value: 1);

/// 연출 시계 [c]의 지금 시각(초, 시작한 뒤). 끝났거나 시작 전이면 [sec] 이상
double motionTime(AnimationController c, double sec) => c.value * sec;
