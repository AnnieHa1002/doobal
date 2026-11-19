import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/asset_index.dart';
import '../domain/boat.dart';
import '../domain/companion.dart';
import '../domain/decor.dart';
import '../domain/shop.dart';
import '../domain/trail_pattern.dart';

Future<Map<String, dynamic>> _json(String file) async =>
    jsonDecode(await rootBundle.loadString('assets/data/$file')) as Map<String, dynamic>;

/// 앱에 든 파일 목록
Future<AssetIndex> loadAssetIndex() async =>
    AssetIndex((await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets());

/// 럭 상점 상품 (shop.json)
Future<ShopCatalog> loadShopCatalog() async => parseShop(await _json('shop.json'));

/// 배 9척 (boats.json)
Future<BoatCatalog> loadBoatCatalog() async => parseBoats(await _json('boats.json'));

/// 동행과 이야기 (companions.json)
Future<CompanionCatalog> loadCompanionCatalog() async =>
    parseCompanions(await _json('companions.json'));

/// 쉼터 꾸밈 물품 (decor.json). 화면 연결은 T15
Future<DecorCatalog> loadDecorCatalog() async => parseDecor(await _json('decor.json'));

/// 물감 길 무늬 (trails.json). 화면 연결은 T17
Future<TrailCatalog> loadTrailCatalog() async => parseTrails(await _json('trails.json'));
