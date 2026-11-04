import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/moderation.dart';

/// 앱에 넣은 금칙어 규칙 (첫 실행·오프라인용, M5에서는 서버 문서를 먼저 쓴다)
Future<Moderation> loadModeration() async => Moderation.fromJson(
    jsonDecode(await rootBundle.loadString('assets/data/moderation.json')) as Map<String, dynamic>);
