import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/spirit_palette.dart';

/// palette.json의 정령 부분: 몸 색 견본·얼굴 파츠 이름·소품 색 규칙 (꾸미기·시작 화면·정령 그리기).
/// 잔디는 쉼터가 따로 읽는다
Future<SpiritPalette> loadSpiritPalette() async {
  final text = await rootBundle.loadString('assets/data/palette.json');
  return SpiritPalette.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
