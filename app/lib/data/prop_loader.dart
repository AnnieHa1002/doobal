import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/prop.dart';

Future<List<Prop>> loadProps() async {
  final text = await rootBundle.loadString('assets/data/props.json');
  return parseProps(jsonDecode(text) as Map<String, dynamic>);
}
