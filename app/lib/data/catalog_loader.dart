import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/boat.dart';
import '../domain/companion.dart';
import '../domain/shop.dart';

Future<Map<String, dynamic>> _json(String file) async =>
    jsonDecode(await rootBundle.loadString('assets/data/$file')) as Map<String, dynamic>;

/// 럭 상점 상품 (shop.json)
Future<ShopCatalog> loadShopCatalog() async => parseShop(await _json('shop.json'));

/// 배 9척 (boats.json)
Future<BoatCatalog> loadBoatCatalog() async => parseBoats(await _json('boats.json'));

/// 동행과 이야기 (companions.json)
Future<CompanionCatalog> loadCompanionCatalog() async =>
    parseCompanions(await _json('companions.json'));
