import 'format_int.dart';
import 'gait.dart';
import 'notification_policy.dart' show josa;
import 'rules.dart';

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

// 구매·사용 규칙 (M4.5). 화면과 동기화가 같은 판정을 쓴다

/// 구매·사용이 막힌 까닭. [message]는 화면에 그대로 보여 줄 수 있다
/// ('여정 중에만 쓸 수 있어요'만 명세 문구, 나머지는 가안)
enum ShopBlock {
  unknownItem('살 수 없는 상품이에요'),
  owned('이미 가지고 있어요'),
  holdFull('더 보관할 수 없어요'),
  notEnoughCoins('럭이 모자라요'),
  notOwned('가지고 있지 않아요'),
  noJourney('여정 중에만 쓸 수 있어요'),
  noWalk('걷는 중에만 쓸 수 있어요'),
  dailyLimit('오늘은 더 쓸 수 없어요'),
  dailyCap('오늘은 더 쓸 수 없어요');

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

/// 구매 질문: '지름길을 50 럭에 구매할까요?' (config coins.format.buyQuestion)
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

/// 살 수 없는 까닭. 살 수 있으면 null. 여행 효과는 [held]가 [maxHold]보다 적어야 하고,
/// 소품·배는 한 번만 산다
ShopBlock? buyBlock(
  ShopItem item, {
  required int balance,
  required int held,
  required int maxHold,
  required bool owned,
}) {
  if (item.effect == null && item.propId == null && item.boatId == null) {
    return ShopBlock.unknownItem;
  }
  if (item.effect != null) {
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
