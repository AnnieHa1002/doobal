import 'format_int.dart';
import 'gait.dart';
import 'notification_policy.dart' show josa;
import 'rules.dart';

// 럭 상점 상품 (shop.json v9, M4.5): 여행 효과(소모품)·소품·꾸밈 효과·배, v7부터 쉼터 꾸밈 물품, v9 미니 친구·무늬·물감 통.
// 상점 화면은 탭 없이 여행 효과 고정 칸 + 오늘의 수레 칸 (shop_cart.dart, 16장 11/19)
// 값은 베타 뒤 조정

/// 상품 분류 (shop.json v7 category, 분류 아이콘). prop에는 꾸미기 소품·색 소품·꾸밈 효과·물감 길 무늬·물감 통이 든다
enum ShopCategory { travel, prop, decor, boat }

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

/// 상품 하나. [propId]는 소품·꾸밈 효과, [boatId]는 배, [decorId]는 쉼터 꾸밈 물품(decor.json), [trailId]는 물감 길 무늬
/// (trails.json), [effect]·[dailyLimit]·[maxHold]는 여행 효과에만 있다. [slot]은 소품 칸(무늬는 trail, 물감 통은 paintTube)
class ShopItem {
  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.price,
    required this.order,
    this.slot,
    this.propId,
    this.boatId,
    this.decorId,
    this.trailId,
    this.consumable = false,
    this.effect,
    this.dailyLimit,
    this.maxHold,
    this.requiresJourney = false,
    this.requires,
    this.desc,
    this.cartChancePerDay,
    this.cartMaxPerDay,
    this.paintTubes,
  });

  final String id;
  final ShopCategory category;
  final String name;
  final int price;
  final int order;

  /// 소품 칸 (shop v9 slot). 오늘의 수레가 종류를 나눌 때 쓴다(T16). 여행 효과·꾸밈 물품·배에는 없다
  final String? slot;
  final String? propId;
  final String? boatId;
  final String? decorId;
  final String? trailId;

  /// 사서 쓰는 것인가 (shop v9 물감 통). 여행 효과는 [effect]로 안다
  final bool consumable;
  final ShopEffect? effect;
  final int? dailyLimit;
  final int? maxHold;
  final bool requiresJourney;

  /// 먼저 가져야 살 수 있는 소품 id. 색 소품의 기본 소품 (props unlock.requires)
  final String? requires;

  /// 상점 칸 이름 아래 설명 한 줄. 여행 효과만 있다 (shop v6 desc, 16장 11/13 화면 글 ②)
  final String? desc;

  /// 소모품이 그날 수레에 나올 확률과 하루 최대 칸 수 (shop v9 cart.chancePerDay·maxPerDay, 물감 통)
  final double? cartChancePerDay;
  final int? cartMaxPerDay;

  /// 물감 통 상품: 사면 그날 색 통 몇 개 (shop v9 paint.tubes). 물감 통이 아니면 null
  final int? paintTubes;

  factory ShopItem.fromJson(Map<String, dynamic> j) {
    final effect = j['effect'] as Map<String, dynamic>?;
    final cart = j['cart'] as Map<String, dynamic>?;
    final paint = j['paint'] as Map<String, dynamic>?;
    if (paint != null) {
      // 물감 통 (16장 11/19 밤): 그날 계절 색 하나, 지역 색 없음. 다른 값은 모른다
      if (paint['color'] != 'todaySeasonRandom' || paint['excludeRegion'] != true) {
        throw FormatException('물감 통 paint 값을 모른다: ${j['id']}');
      }
    }
    return ShopItem(
      id: j['id'] as String,
      category: _categoryOf(j['category'] as String),
      name: j['name'] as String,
      price: j['price'] as int,
      order: j['order'] as int,
      slot: j['slot'] as String?,
      propId: j['propId'] as String?,
      boatId: j['boatId'] as String?,
      decorId: j['decorId'] as String?,
      trailId: j['trailId'] as String?,
      consumable: j['consumable'] as bool? ?? false,
      effect: effect == null ? null : ShopEffect.fromJson(effect),
      dailyLimit: j['dailyLimit'] as int?,
      maxHold: j['maxHold'] as int?,
      requiresJourney: j['requiresJourney'] as bool? ?? false,
      desc: j['desc'] as String?,
      cartChancePerDay: (cart?['chancePerDay'] as num?)?.toDouble(),
      cartMaxPerDay: cart?['maxPerDay'] as int?,
      paintTubes: paint?['tubes'] as int?,
    );
  }
}

/// shop.json 전체
class ShopCatalog {
  ShopCatalog({
    required this.defaultBoat,
    required this.items,
    this.categories = const [],
    this.categoryIcons = const {},
  });

  /// 분류 순서 (shop v7 categories)
  final List<ShopCategory> categories;

  /// 분류 아이콘 그림 이름 (shop v7 categoryIcons, 회색조 — 앱이 색을 입힘). 그림이 오기 전(pending)에도 이름은 있다
  final Map<ShopCategory, String> categoryIcons;

  /// 처음 타는 배 (boats.json id)
  final String defaultBoat;

  /// 파일에 적힌 순서 그대로
  final List<ShopItem> items;

  late final Map<String, ShopItem> _byId = {for (final i in items) i.id: i};

  ShopItem? byId(String id) => _byId[id];
}

ShopCatalog parseShop(Map<String, dynamic> json) {
  final icons = json['categoryIcons'] as Map<String, dynamic>? ?? const {};
  return ShopCatalog(
    categories: [
      for (final c in (json['categories'] as List?) ?? const []) _categoryOf(c as String),
    ],
    // pending·note 같은 적어 둔 값은 건너뛴다
    categoryIcons: {
      for (final c in ShopCategory.values)
        if (icons[c.name] case final String name) c: name,
    },
    defaultBoat: json['defaultBoat'] as String,
    items: [
      for (final i in json['items'] as List) ShopItem.fromJson(i as Map<String, dynamic>),
    ],
  );
}

ShopCategory _categoryOf(String name) => ShopCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => throw FormatException('모르는 상품 분류: $name'),
    );

// 구매·사용 규칙 (M4.5). 화면과 동기화가 같은 판정을 쓴다

/// 구매·사용이 막힌 까닭. [message]는 화면에 그대로 보여 줄 수 있다
/// ('여정 중에만 쓸 수 있어요'만 명세 문구, 나머지는 가안)
enum ShopBlock {
  unknownItem('살 수 없는 상품이에요'),
  needsBase('아직 살 수 없어요'),
  owned('이미 가지고 있어요'),
  holdFull('더 보관할 수 없어요'),
  notEnoughCoins('럭이 모자라요'),
  notOwned('가지고 있지 않아요'),
  noJourney('여정 중에만 쓸 수 있어요'),
  noWalk('걷는 중에만 쓸 수 있어요'),
  dailyLimit('오늘은 더 쓸 수 없어요'),
  dailyCap('오늘은 더 쓸 수 없어요'),

  /// 오늘의 수레 칸이 이미 팔렸거나 새벽에 수레가 바뀌었다 (가안, 시트를 연 사이에만 나온다)
  soldOut('이제 살 수 없어요');

  const ShopBlock(this.message);

  final String message;
}

/// 구매·사용을 막았을 때 던진다. 아무것도 바뀌지 않은 상태다
class ShopBlocked extends StateError {
  ShopBlocked(this.block) : super(block.message);

  final ShopBlock block;
}

/// 럭 값 글자: '5,000 럭' (config coins.format.amount)
String coinAmountText(int n, Rules rules) =>
    rules.coinAmountFormat.replaceAll('{n}', formatInt(n));

/// 구매 질문 (config coins.format.buyQuestion v16 '구매하시겠습니까?', 16장 11/13). 옛 꼴 '{item}을(를) {n} 럭에'도 채운다
String buyQuestionText(String item, int price, Rules rules) => rules.coinBuyQuestion
    .replaceAll('{item}을(를)', '$item${josa(item, '을/를')}')
    .replaceAll('{n}', formatInt(price));

/// 구매 뒤 토스트: '지름길을 구매했어요' (캔버스 8-1)
String boughtText(String item) => '$item${josa(item, '을/를')} 구매했어요';

/// 구매 시트의 둘째 줄: '남는 럭 1,190' (캔버스 8-1)
String coinsLeftText(int left) => '남는 럭 ${formatInt(left)}';

/// 잔액 = 들어온 럭(earn·gift·ad) − 쓴 럭(spend). 다시 계산한 earn이 줄어도 음수로 보이지 않는다
int coinBalanceOf({required int credited, required int spent}) =>
    credited > spent ? credited - spent : 0;

/// 사면 무엇이 생기는지 아는 상품인가: 여행 효과·소품(꾸밈 효과·색 소품·미니 친구)·배·쉼터 물품·무늬·물감 통
bool isSellable(ShopItem item) =>
    item.effect != null ||
    item.propId != null ||
    item.boatId != null ||
    item.decorId != null ||
    item.trailId != null ||
    (item.consumable && item.paintTubes != null);

/// 살 수 없는 까닭. 살 수 있으면 null. 여행 효과·물감 통(소모품)은 [held]가 [maxHold]보다 적어야 하고,
/// 소품·배·쉼터 물품·무늬는 한 번만 산다. 색 소품은 기본 소품([ShopItem.requires])을 가져야 산다([hasRequired])
ShopBlock? buyBlock(
  ShopItem item, {
  required int balance,
  required int held,
  required int maxHold,
  required bool owned,
  bool hasRequired = true,
}) {
  if (!isSellable(item)) return ShopBlock.unknownItem;
  if (item.requires != null && !hasRequired) return ShopBlock.needsBase;
  if (item.effect != null || item.consumable) {
    if (held >= maxHold) return ShopBlock.holdFull;
  } else if (owned) {
    return ShopBlock.owned;
  }
  return balance < item.price ? ShopBlock.notEnoughCoins : null;
}

/// 여행 효과를 쓸 수 없는 까닭. 쓸 수 있으면 null. [usedToday]는 오늘 그 효과를 쓴 횟수,
/// [usedKmToday]는 오늘 모든 효과로 더한 거리다. 상한이 다 찼으면 쓰지 않게 막는다 (효과만 버려진다)
ShopBlock? useBlock(
  ShopItem item, {
  required int held,
  required bool hasJourney,
  required bool inWalk,
  required int usedToday,
  required double usedKmToday,
  required double capKm,
}) {
  final effect = item.effect;
  if (effect == null) return ShopBlock.unknownItem;
  if (held <= 0) return ShopBlock.notOwned;
  // 효과는 여정 진행에만 들어가서 여정이 없으면 쓸 곳이 없다 (경비에는 안 더한다)
  if (!hasJourney) return ShopBlock.noJourney;
  if (effect.kind == ShopEffectKind.travelRatioUntilWalkEnd && !inWalk) return ShopBlock.noWalk;
  if (item.dailyLimit case final limit? when usedToday >= limit) return ShopBlock.dailyLimit;
  return usedKmToday >= capKm ? ShopBlock.dailyCap : null;
}

/// 오늘 이미 더한 [usedKm] 위에 더할 수 있는 만큼 [wantKm]을 자른다 (넘는 만큼 버림)
double clipEffectKm(double wantKm, {required double usedKm, required double capKm}) {
  final room = capKm - usedKm;
  if (room <= 0 || wantKm <= 0) return 0;
  return wantKm < room ? wantKm : room;
}

/// 순풍이 보는 실제 거리(m): 분 시작이 [fromMs, toMs) 안인 분의 걸음 × 보폭
double walkedMBetween(List<GaitMinute> minutes, int fromMs, int toMs, Rules rules) {
  var sum = 0.0;
  for (final m in minutes) {
    final ms = m.minute * Duration.millisecondsPerMinute;
    if (ms >= fromMs && ms < toMs) sum += m.steps * strideM(m.gait, rules);
  }
  return sum;
}
