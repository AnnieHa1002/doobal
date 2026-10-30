import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/look.dart';

/// palette.json의 머리색 견본 (피부·잔디는 M4에서 읽는다)
Future<List<HairSwatch>> loadHairSwatches() async {
  final text = await rootBundle.loadString('assets/data/palette.json');
  return parseHairSwatches(jsonDecode(text) as Map<String, dynamic>);
}
