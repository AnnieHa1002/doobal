import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/rules.dart';

Future<Rules> loadRules() async {
  final text = await rootBundle.loadString('assets/data/config.json');
  return Rules.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
