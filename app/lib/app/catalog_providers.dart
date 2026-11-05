import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_loader.dart';
import '../domain/boat.dart';
import '../domain/companion.dart';
import '../domain/shop.dart';

/// 럭 상점 상품 (shop.json)
final shopCatalogProvider = FutureProvider<ShopCatalog>((ref) => loadShopCatalog());

/// 배 9척 (boats.json)
final boatCatalogProvider = FutureProvider<BoatCatalog>((ref) => loadBoatCatalog());

/// 동행과 이야기 (companions.json)
final companionCatalogProvider = FutureProvider<CompanionCatalog>((ref) => loadCompanionCatalog());
