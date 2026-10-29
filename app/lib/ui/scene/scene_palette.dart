import 'package:flutter/painting.dart';

import '../../domain/scene.dart';
import '../../domain/sky.dart';

// 그림이 나오기 전까지 쓰는 임시 색. 디자인 색이지 규칙 숫자가 아니다

/// 하늘 위·아래 색
class SkyColors {
  const SkyColors(this.top, this.bottom);

  final Color top;
  final Color bottom;
}

const skyColors = {
  SkyPhase.dawn: SkyColors(Color(0xFF8E9BB8), Color(0xFFF1C9A5)),
  SkyPhase.morning: SkyColors(Color(0xFFA9CBE0), Color(0xFFF6E3C0)),
  SkyPhase.day: SkyColors(Color(0xFF8EC1DD), Color(0xFFE3EEDC)),
  SkyPhase.sunset: SkyColors(Color(0xFF6F7FA6), Color(0xFFE9A06A)),
  SkyPhase.night: SkyColors(Color(0xFF1F2A44), Color(0xFF4A5478)),
};

/// 후경 지역(landmarks.json의 backdrop 7종 + sea)별 언덕 색
const backdropTints = {
  'capital': Color(0xFF8FA38A),
  'gangwon': Color(0xFF5F7F6A),
  'chungcheong': Color(0xFF93A06E),
  'jeolla': Color(0xFF7FA064),
  'gyeongsang': Color(0xFFA3925F),
  'jeju': Color(0xFF5C7A62),
  'sea': Color(0xFF9FB4C0),
};

const fallbackBackdropTint = Color(0xFF8FA38A);

const groundColors = {
  Season.spring: Color(0xFF9DB06A),
  Season.summer: Color(0xFF6F8F4A),
  Season.autumn: Color(0xFFB58A4A),
  Season.winter: Color(0xFFD9D6CC),
};

const seaColor = Color(0xFF5E86A0);
const waveColor = Color(0xFFD7E6EC);
const boatHull = Color(0xFF8A5A3C);
const boatDeck = Color(0xFFB98A5E);

/// 전경 풀 색 (계절별) 과 꽃·눈 점
const tuftColors = {
  Season.spring: Color(0xFF7FA05A),
  Season.summer: Color(0xFF4F7A3A),
  Season.autumn: Color(0xFFC0702E),
  Season.winter: Color(0xFFB9B4A8),
};
const tuftSpecks = {
  Season.spring: Color(0xFFE8A0B0),
  Season.summer: Color(0xFFF2D95C),
  Season.autumn: Color(0xFF8A4A22),
  Season.winter: Color(0xFFFFFFFF),
};

const tentColor = Color(0xFFD9B48A);
const tentDoor = Color(0xFF6B4A32);
const woodColor = Color(0xFF8A5A3C);
const flameOuter = Color(0xFFE07A2F);
const flameInner = Color(0xFFF6D56A);
