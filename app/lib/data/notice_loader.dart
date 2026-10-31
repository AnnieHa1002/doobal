import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/notification_policy.dart';

/// notifications.json의 알림 종류별 우선순위와 문구
Future<NoticeCatalog> loadNoticeCatalog() async {
  final text = await rootBundle.loadString('assets/data/notifications.json');
  return NoticeCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
