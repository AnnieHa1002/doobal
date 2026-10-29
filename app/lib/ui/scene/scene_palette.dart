import 'package:flutter/painting.dart';

import '../../domain/scene.dart';

// 그림이 나오기 전까지 쓰는 임시 색. 디자인 색이지 규칙 숫자가 아니다
// (하늘 색·빛무리는 규칙이라 config scene.sky에 있다)

/// 해·달·별 (하늘에 그리는 임시 도형)
const sunDisc = Color(0xFFFFE6A0);
const moonDisc = Color(0xFFF1EEDD);
const starColor = Color(0xFFF8F4E2);

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

/// 능선(ridge)은 지역과 상관없이 같은 색
const ridgeColor = Color(0xFF7F9A8C);

/// 숲(grove)·풀밭(meadow) 색 (계절별)
const groveColors = {
  Season.spring: Color(0xFF6E9A58),
  Season.summer: Color(0xFF3F6B33),
  Season.autumn: Color(0xFFB5602A),
  Season.winter: Color(0xFF8E8A80),
};
const meadowColors = {
  Season.spring: Color(0xFFA8BC72),
  Season.summer: Color(0xFF7FA050),
  Season.autumn: Color(0xFFC49A56),
  Season.winter: Color(0xFFE2DFD6),
};

/// 길(흙)과, 길 아래 풀 언덕 (계절별)
const pathColor = Color(0xFFB8976A);
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
