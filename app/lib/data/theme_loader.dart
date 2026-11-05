import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/camp_theme.dart';

Future<CampTheme> loadCampTheme() async {
  final text = await rootBundle.loadString('assets/data/themes/camp_wide.json');
  return CampTheme.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
