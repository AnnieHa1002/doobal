// 쉼터 꾸밈 물품 (decor.json v2, 16장 11/18 쉼터 꾸미기·11/19 쉼터·상점 세부): 보상 4 + 상점 8.
// v2(11/20, 검수 A29 README): 물품마다 그림 캔버스(canvasPx)·화면 크기(showPx, 세로 1170×2532 화면 px 가안)·
// 바닥 기준점(groundAt)·그림 걸 자리(paintingSlotsAt)·빛 자리(light). 놓는 규칙은 config rest.decor
// (decor_rules.dart), 땅 띠·못 놓는 자리는 camp_wide decor (camp_theme.dart), 자리 계산은 decor_place.dart

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
    this.canvasPx,
    this.showPx,
    this.groundAt,
    this.bboxPx,
    this.slotsAt = const [],
    this.light,
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

  /// 그림 파일 캔버스 (w, h px). v1에는 없다
  final DecorSize? canvasPx;

  /// 화면에 보일 크기 (투명 여백을 뺀 그림, 세로 1170×2532 화면 px, 가안). 없으면 자리표시 크기도 없다
  final DecorSize? showPx;

  /// 바닥 기준점 (캔버스 px): 이 점이 쉼터의 발 자리에 온다
  final DecorPoint? groundAt;

  /// 투명 여백을 뺀 그림 상자 [x0, y0, x1, y1] (캔버스 px, 납품 props/manifest bbox). decor v2에는 없다.
  /// 있으면 캔버스 → 화면 배율을 이것으로 정한다 ([pxPerCanvasPx])
  final List<double>? bboxPx;

  /// 그림 거는 칸 자리 (paintingSlotsAt, 캔버스 px). 칸 수는 [paintingSlots]
  final List<DecorSlotSpot> slotsAt;

  /// 밤 불빛 자리 (등불·석등). 없으면 null
  final DecorLight? light;

  /// 그림 캔버스 px 하나가 화면 px 몇인가. 그림은 늘이지 않고 같은 배율로 줄였다 (README ‘폭·높이를 동시에 맞추려고
  /// 늘이지 않음’). 그림 상자([bboxPx])가 있으면 화면 높이 ÷ 상자 높이, 없으면 걸 칸의 보이는 높이 ÷ 칸 높이
  /// (README frame_visible_height_px = 칸 높이 × 배율), 둘 다 없으면 화면 높이 ÷ 바닥점 y (그림 위 끝이 캔버스 위 끝이라
  /// 보고 셈, 투명 여백만큼 조금 작게 나온다 — 추정). 크기 값이 없으면 null
  double? get pxPerCanvasPx {
    final show = showPx;
    final ground = groundAt;
    if (show == null || ground == null) return null;
    final box = bboxPx;
    if (box != null && box[3] > box[1]) return show.h / (box[3] - box[1]);
    for (final s in slotsAt) {
      if (s.frameVisiblePx case final v? when s.h > 0) return v / s.h;
    }
    return ground.y > 0 ? show.h / ground.y : null;
  }

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
      canvasPx: DecorSize.parse(j['canvasPx'], 'canvasPx', id),
      showPx: DecorSize.parse(j['showPx'], 'showPx', id),
      groundAt: DecorPoint.parse(j['groundAt'], 'groundAt', id),
      bboxPx: _numbers(j['bboxPx'], 4, 'bboxPx', id),
      slotsAt: [
        for (final s in (j['paintingSlotsAt'] as List?) ?? const [])
          DecorSlotSpot.fromJson(s as Map<String, dynamic>, id),
      ],
      light: j['light'] == null ? null : DecorLight.fromJson(j['light'] as Map<String, dynamic>, id),
    );
    if (item.slotsAt.isNotEmpty && item.slotsAt.length != item.paintingSlots) {
      throw FormatException('꾸밈 물품 걸 자리 수가 paintingSlots와 다르다 ($id)');
    }
    final missing = switch (kind) {
      DecorUnlockKind.gift => item.giftOn == null,
      DecorUnlockKind.landmarksVisited => item.landmarks == null,
      DecorUnlockKind.shop => item.price == null,
    };
    if (missing) throw FormatException('꾸밈 물품 얻는 길 값이 없다: ${kind.name} ($id)');
    return item;
  }
}

/// 크기 (w, h)
class DecorSize {
  const DecorSize(this.w, this.h);

  final double w;
  final double h;

  static DecorSize? parse(dynamic v, String key, String id) {
    final n = _numbers(v, 2, key, id);
    return n == null ? null : DecorSize(n[0], n[1]);
  }
}

/// 점 (x, y)
class DecorPoint {
  const DecorPoint(this.x, this.y);

  final double x;
  final double y;

  static DecorPoint? parse(dynamic v, String key, String id) {
    final n = _numbers(v, 2, key, id);
    return n == null ? null : DecorPoint(n[0], n[1]);
  }
}

/// 그림 거는 칸 하나 (paintingSlotsAt, 캔버스 px): 칸 상자 [x, y, w, h], 그림 위 끝 가운데 [hangAt],
/// 보이는 액자 높이(화면 px)와 붙는 모양 (bottom_on_ledge·top_at_brass_ring·top_at_peg_tip)
class DecorSlotSpot {
  const DecorSlotSpot({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.hangAt,
    this.frameVisiblePx,
    this.attach,
  });

  final double x;
  final double y;
  final double w;
  final double h;
  final DecorPoint hangAt;
  final double? frameVisiblePx;
  final String? attach;

  factory DecorSlotSpot.fromJson(Map<String, dynamic> j, String id) {
    final slot = _numbers(j['slot'], 4, 'slot', id)!;
    return DecorSlotSpot(
      x: slot[0],
      y: slot[1],
      w: slot[2],
      h: slot[3],
      hangAt: DecorPoint.parse(j['hangAt'], 'hangAt', id) ??
          DecorPoint(slot[0] + slot[2] / 2, slot[1]),
      frameVisiblePx: (j['frameVisiblePx'] as num?)?.toDouble(),
      attach: j['attach'] as String?,
    );
  }
}

/// 밤 불빛 (light): 빛 가운데 [at](캔버스 px), 반지름(화면 px), 낮에는 꺼지는가
class DecorLight {
  const DecorLight({required this.at, required this.radiusPx, required this.dayOff});

  final DecorPoint at;
  final double radiusPx;
  final bool dayOff;

  factory DecorLight.fromJson(Map<String, dynamic> j, String id) => DecorLight(
        at: DecorPoint.parse(j['lightAt'], 'lightAt', id) ??
            (throw FormatException('꾸밈 물품 빛 자리가 없다 ($id)')),
        radiusPx: ((j['lightRadiusPx'] as num?) ??
                (throw FormatException('꾸밈 물품 빛 반지름이 없다 ($id)')))
            .toDouble(),
        dayOff: j['dayOff'] as bool? ?? true,
      );
}

/// 숫자 [n]개 목록. 없으면 null, 개수가 다르면 FormatException
List<double>? _numbers(dynamic v, int n, String key, String id) {
  if (v == null) return null;
  final list = v as List;
  if (list.length != n) throw FormatException('꾸밈 물품 $key는 숫자 $n개다 ($id)');
  return [for (final x in list) (x as num).toDouble()];
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
