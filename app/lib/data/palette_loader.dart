import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/look.dart';
import '../domain/look_palette.dart';

Future<Map<String, dynamic>> _loadPalette() async {
  final text = await rootBundle.loadString('assets/data/palette.json');
  return jsonDecode(text) as Map<String, dynamic>;
}

/// palette.json의 머리색 견본 (시작 ②가 읽는다)
Future<List<HairSwatch>> loadHairSwatches() async => parseHairSwatches(await _loadPalette());

/// palette.json의 머리·피부 규칙 전부 (꾸미기와 나의 정보 초상). 잔디는 쉼터가 따로 읽는다
Future<LookPalette> loadLookPalette() async => LookPalette.fromJson(await _loadPalette());
