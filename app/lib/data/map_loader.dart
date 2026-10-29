import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/map_projection.dart';
import '../domain/map_regions.dart';

Future<MapProjection> loadMapProjection() async {
  final text = await rootBundle.loadString('assets/map/ui_map_projection_v01.json');
  return MapProjection.fromJson(jsonDecode(text) as Map<String, dynamic>);
}

Future<List<MapRegion>> loadMapRegions() async {
  final text = await rootBundle.loadString('assets/map/ui_map_regions_v01.svg');
  return parseMapRegions(text);
}
