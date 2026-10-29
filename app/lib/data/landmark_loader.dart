import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/landmark.dart';

Future<List<Landmark>> loadLandmarks() async {
  final text = await rootBundle.loadString('assets/data/landmarks.json');
  final json = jsonDecode(text) as Map<String, dynamic>;
  return (json['landmarks'] as List)
      .map((e) => Landmark.fromJson(e as Map<String, dynamic>))
      .toList();
}
