import 'package:flutter/painting.dart';

import '../../domain/journey.dart' show Frame;
import '../../domain/landmark.dart';
import '../scene/scene_palette.dart';

// 액자 색은 그림이 나오기 전까지의 자리 표시용. 디자인 색이지 규칙 숫자가 아니다
const frameColors = {
  Frame.wood: Color(0xFFA67B4F),
  Frame.silver: Color(0xFFB9BDC4),
  Frame.gold: Color(0xFFD8AC3C),
};

/// 그림이 나오기 전까지 그림 자리에 칠하는 색: 그 명소의 후경 지역 색
Color paintingTint(Landmark l) => backdropTints[l.backdrop] ?? fallbackBackdropTint;
