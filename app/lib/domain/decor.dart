// 쉼터 꾸밈 물품 (decor.json v1, 16장 11/18 쉼터 꾸미기·11/19 쉼터·상점 세부): 보상 4 + 상점 8.
// 읽기만 한다. 얻기·놓기·그림 걸기는 T15 (놓는 규칙은 config rest.decor, 땅 띠는 camp_wide decor)

/// 물품을 얻는 길 (decor.json unlock.kind)
enum DecorUnlockKind {
  /// 선물: [DecorItem.giftOn] 때 받는다 (이젤은 첫 그림 도착 firstSketchArrival)
  gift,

  /// 도착한 서로 다른 명소 수가 [DecorItem.landmarks] 이상 (내 동네 스케치 빼고, 재방문은 안 셈, 11/19 Annie)
  landmarksVisited,

  /// 상점에서 [DecorItem.price] 럭
  shop,
}

/// 꾸밈 물품 하나
class DecorItem {
  const DecorItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.order,
    required this.art,
    this.giftOn,
    this.landmarks,
    this.price,
    this.paintingSlots = 0,
    this.startPainting,
    this.nightLight = false,
  });

  final String id;
  final String name;
  final DecorUnlockKind kind;
  final int order;

  /// 그림 이름 (확장자 없이, Assets camp_deco_v01). 그림이 오기 전에는 앱이 자리표시 상자
  final String art;

  /// gift: 받는 때 (unlock.on)
  final String? giftOn;

  /// landmarksVisited: 도착한 서로 다른 명소 수 (unlock.n)
  final int? landmarks;

  /// shop: 값(럭), shop.json 상품 값과 같다 (check_data가 본다)
  final int? price;

  /// 화집 그림을 거는 칸 수. 0이면 그림을 걸지 않는 물품
  final int paintingSlots;

  /// 처음 놓일 때 걸린 그림 (이젤: sketch = 첫 그림)
  final String? startPainting;

  /// 밤에 불빛이 켜지는가 (등불·석등)
  final bool nightLight;

  factory DecorItem.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final u = j['unlock'] as Map<String, dynamic>;
    final kind = switch (u['kind']) {
      'gift' => DecorUnlockKind.gift,
      'landmarksVisited' => DecorUnlockKind.landmarksVisited,
      'shop' => DecorUnlockKind.shop,
      final k => throw FormatException('모르는 꾸밈 물품 얻는 길: $k ($id)'),
    };
    final item = DecorItem(
      id: id,
      name: j['name'] as String,
      kind: kind,
      order: j['order'] as int,
      art: j['art'] as String,
      giftOn: u['on'] as String?,
      landmarks: u['n'] as int?,
      price: u['price'] as int?,
      paintingSlots: j['paintingSlots'] as int? ?? 0,
      startPainting: j['startPainting'] as String?,
      nightLight: j['nightLight'] as bool? ?? false,
    );
    final missing = switch (kind) {
      DecorUnlockKind.gift => item.giftOn == null,
      DecorUnlockKind.landmarksVisited => item.landmarks == null,
      DecorUnlockKind.shop => item.price == null,
    };
    if (missing) throw FormatException('꾸밈 물품 얻는 길 값이 없다: ${kind.name} ($id)');
    return item;
  }
}

/// decor.json 전체
class DecorCatalog {
  DecorCatalog({required this.maxPlaced, required this.perItem, required this.items});

  /// 쉼터에 한 번에 놓을 수 있는 물품 수
  final int maxPlaced;

  /// 물품 하나를 몇 개까지 가지는가
  final int perItem;

  /// order 순서
  final List<DecorItem> items;

  late final Map<String, DecorItem> _byId = {for (final i in items) i.id: i};

  DecorItem? byId(String id) => _byId[id];
}

DecorCatalog parseDecor(Map<String, dynamic> json) {
  final items = [
    for (final i in json['items'] as List) DecorItem.fromJson(i as Map<String, dynamic>),
  ]..sort((a, b) => a.order.compareTo(b.order));
  final ids = <String>{};
  for (final i in items) {
    if (!ids.add(i.id)) throw FormatException('꾸밈 물품 id가 겹친다: ${i.id}');
  }
  return DecorCatalog(
    maxPlaced: json['maxPlaced'] as int,
    perItem: json['perItem'] as int,
    items: items,
  );
}
