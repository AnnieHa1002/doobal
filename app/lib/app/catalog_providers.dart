import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_loader.dart';
import '../domain/asset_index.dart';
import '../domain/boat.dart';
import '../domain/companion.dart';
import '../domain/shop.dart';

/// 앱에 든 파일 목록 (칸 그림·수레·럭 보석을 파일이 있는지 보고 찾는다).
/// 읽기 전에는 값이 없어서 그림 없는 칸으로 그린다
final assetIndexProvider = FutureProvider<AssetIndex>((ref) => loadAssetIndex());

/// 럭 상점 상품 (shop.json)
final shopCatalogProvider = FutureProvider<ShopCatalog>((ref) => loadShopCatalog());

/// 배 9척 (boats.json)
final boatCatalogProvider = FutureProvider<BoatCatalog>((ref) => loadBoatCatalog());

/// 동행과 이야기 (companions.json)
final companionCatalogProvider = FutureProvider<CompanionCatalog>((ref) => loadCompanionCatalog());
