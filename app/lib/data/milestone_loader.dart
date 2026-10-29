import 'dart:convert';

import 'package:flutter/services.dart';

/// milestones.json의 방명록 걸음 숫자(오름차순)
Future<List<int>> loadMilestones() async {
  final text = await rootBundle.loadString('assets/data/milestones.json');
  final json = jsonDecode(text) as Map<String, dynamic>;
  return (json['stepMilestones'] as List).cast<int>();
}
