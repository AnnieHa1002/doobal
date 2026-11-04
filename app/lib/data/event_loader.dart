import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/badge.dart';
import '../domain/road_event.dart';

/// events.json (길 위 이벤트 풍경·칭찬 문구)
Future<EventCatalog> loadEventCatalog() async {
  final text = await rootBundle.loadString('assets/data/events.json');
  return EventCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);
}

/// badges.json (도장 20개와 하늘 구간)
Future<BadgeCatalog> loadBadgeCatalog() async {
  final text = await rootBundle.loadString('assets/data/badges.json');
  return BadgeCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
