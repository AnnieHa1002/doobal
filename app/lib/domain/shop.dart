// 럭 상점 상품 (shop.json v4, M4.5): 여행 효과(소모품)·소품·꾸밈 효과·배. 값은 베타 뒤 조정

/// 상점 탭. travel은 소모품, effect는 꾸미기 효과 칸의 영구 소품이다
enum ShopTab { travel, prop, effect, boat }

/// 여행 효과의 종류 (shop.json effect.kind)
enum ShopEffectKind { travelKmInstant, travelRatioUntilWalkEnd }

/// 여행 효과 하나. 결과는 하루 요약의 shopM으로만 들어간다 (액자·도장·방명록·걷기 기록에는 안 넣는다)
class ShopEffect {
  const ShopEffect({required this.kind, this.km, this.ratio});

  final ShopEffectKind kind;

  /// travelKmInstant: 바로 더하는 여행 거리(km)
  final double? km;

  /// travelRatioUntilWalkEnd: 이번 걷는 중의 실제 거리에 곱해서 더하는 비율
  final double? ratio;

  factory ShopEffect.fromJson(Map<String, dynamic> j) => ShopEffect(
        kind: switch (j['kind']) {
          'travelKmInstant' => ShopEffectKind.travelKmInstant,
          'travelRatioUntilWalkEnd' => ShopEffectKind.travelRatioUntilWalkEnd,
          final k => throw FormatException('모르는 여행 효과: $k'),
        },
        km: (j['km'] as num?)?.toDouble(),
        ratio: (j['ratio'] as num?)?.toDouble(),
      );
}

/// 상품 하나. [propId]는 소품·꾸밈 효과, [boatId]는 배, [effect]·[dailyLimit]·[maxHold]는 여행 효과에만 있다
class ShopItem {
  const ShopItem({
    required this.id,
    required this.tab,
    required this.name,
    required this.price,
    required this.order,
    this.propId,
    this.boatId,
    this.effect,
    this.dailyLimit,
    this.maxHold,
    this.requiresJourney = false,
  });

  final String id;
  final ShopTab tab;
  final String name;
  final int price;
  final int order;
  final String? propId;
  final String? boatId;
  final ShopEffect? effect;
  final int? dailyLimit;
  final int? maxHold;
  final bool requiresJourney;

  factory ShopItem.fromJson(Map<String, dynamic> j) {
    final effect = j['effect'] as Map<String, dynamic>?;
    return ShopItem(
      id: j['id'] as String,
      tab: _tabOf(j['tab'] as String),
      name: j['name'] as String,
      price: j['price'] as int,
      order: j['order'] as int,
      propId: j['propId'] as String?,
      boatId: j['boatId'] as String?,
      effect: effect == null ? null : ShopEffect.fromJson(effect),
      dailyLimit: j['dailyLimit'] as int?,
      maxHold: j['maxHold'] as int?,
      requiresJourney: j['requiresJourney'] as bool? ?? false,
    );
  }
}

/// shop.json 전체
class ShopCatalog {
  ShopCatalog({required this.tabLabels, required this.defaultBoat, required this.items});

  /// 탭 화면 이름
  final Map<ShopTab, String> tabLabels;

  /// 처음 타는 배 (boats.json id)
  final String defaultBoat;

  /// 파일에 적힌 순서 그대로
  final List<ShopItem> items;

  late final Map<String, ShopItem> _byId = {for (final i in items) i.id: i};

  ShopItem? byId(String id) => _byId[id];

  /// [tab]의 상품을 order 순서로
  List<ShopItem> inTab(ShopTab tab) =>
      [for (final i in items) if (i.tab == tab) i]..sort((a, b) => a.order.compareTo(b.order));
}

ShopCatalog parseShop(Map<String, dynamic> json) => ShopCatalog(
      tabLabels: {
        for (final e in (json['tabLabels'] as Map<String, dynamic>).entries)
          _tabOf(e.key): e.value as String,
      },
      defaultBoat: json['defaultBoat'] as String,
      items: [
        for (final i in json['items'] as List) ShopItem.fromJson(i as Map<String, dynamic>),
      ],
    );

ShopTab _tabOf(String name) => ShopTab.values.firstWhere(
      (t) => t.name == name,
      orElse: () => throw FormatException('모르는 상점 탭: $name'),
    );
