import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/sigungu.dart';

/// sigungu.json의 시·군·구 (출발 동네 후보). 앱 안 데이터라 오프라인으로 쓴다
Future<List<Sigungu>> loadSigungu() async {
  final text = await rootBundle.loadString('assets/data/sigungu.json');
  return parseSigungu(jsonDecode(text) as Map<String, dynamic>);
}
