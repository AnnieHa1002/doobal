import 'dart:convert';

import 'time_kst.dart';
import 'shop.dart';

// 오늘의 수레 (16장 11/19·11/20, M2~M6 명세 AC, config shop.cart). 상점 = 여행 효과 고정 칸 + 그날 정한 수레 칸.
// 그날 줄은 새벽 새로 고침(한국 시간) 뒤 첫 실행에 한 번 정해 저장하고 그날은 바꾸지 않는다 (DB 21 shop_cart_slots).
// 이 파일은 순수 규칙만 둔다. 저장·사기는 app/sync_shop.dart

/// 누적 거리 [km]부터 칸 [slots]개 (config shop.cart.slotsByKm 한 줄)
class CartSlotStep {
  const CartSlotStep(this.km, this.slots);

  final double km;
  final int slots;
}

/// 누적 거리 [km]부터 열리는 수레 종류 (config shop.cart.kindsByKm 한 줄). 종류는 [cartKindOf]
class CartKindStep {
  const CartKindStep(this.km, this.kinds);

  final double km;
  final Set<String> kinds;
}

/// 산 칸 도장 (config shop.cart.soldMark, 16장 11/20 Q016, 디자인 기획 가안). 코드로 그린다
class SoldMark {
  const SoldMark({
    required this.diameterPt,
    required this.argb,
    required this.outerPt,
    required this.innerInsetPt,
    required this.innerPt,
    required this.text,
    required this.textPt,
    required this.letterSpacingPt,
    required this.textWeight,
    required this.rotateDeg,
    required this.opacity,
    required this.tappable,
  });

  factory SoldMark.fromJson(Map<String, dynamic> j) {
    if (j['draw'] != 'code') throw FormatException('shop.cart.soldMark.draw는 code만 안다: ${j['draw']}');
    if (j['until'] != 'nextRefresh') {
      throw FormatException('shop.cart.soldMark.until은 nextRefresh만 안다: ${j['until']}');
    }
    final opacity = _d(j['opacity']);
    if (opacity < 0 || opacity > 1) throw const FormatException('shop.cart.soldMark.opacity는 0~1');
    return SoldMark(
      diameterPt: _d(j['diameterPt']),
      argb: _hex(j['color'] as String),
      outerPt: _d(j['outerPt']),
      innerInsetPt: _d(j['innerInsetPt']),
      innerPt: _d(j['innerPt']),
      text: j['text'] as String,
      textPt: _d(j['textPt']),
      letterSpacingPt: _d(j['letterSpacingPt'] ?? 0),
      textWeight: j['textWeight'] as int,
      rotateDeg: _d(j['rotateDeg']),
      opacity: opacity,
      tappable: j['tappable'] as bool? ?? false,
    );
  }

  final double diameterPt;
  final int argb;

  /// 바깥 테두리 굵기, 안쪽 선이 들어간 거리, 안쪽 선 굵기 (pt)
  final double outerPt;
  final double innerInsetPt;
  final double innerPt;

  /// 가운데 글자 (문구 키, v33 'SOLD')와 크기·자간·굵기(100~900)
  final String text;
  final double textPt;
  final double letterSpacingPt;
  final int textWeight;

  /// 기울기(도, 음수는 반시계)와 투명도(0~1)
  final double rotateDeg;
  final double opacity;

  /// 도장 칸을 누를 수 있는가 (v33 false)
  final bool tappable;
}

/// config shop.cart
class CartRules {
  const CartRules({
    required this.refreshHour,
    required this.slotsByKm,
    required this.kindsByKm,
    required this.fixedKinds,
    required this.excludeOwned,
    required this.neverShownFirst,
    required this.showFewer,
    required this.colorsFollowBase,
    required this.removeOnBuy,
    required this.newDotOnNeverShown,
    required this.consumableKinds,
    required this.ownedStillSold,
    required this.soldMark,
  });

  /// 수레가 없는 규칙 (config에 shop.cart가 없을 때): 고정 칸(여행 효과)만
  static const none = CartRules(
    refreshHour: 0,
    slotsByKm: [],
    kindsByKm: [],
    fixedKinds: {travelKind},
    excludeOwned: true,
    neverShownFirst: true,
    showFewer: true,
    colorsFollowBase: true,
    removeOnBuy: true,
    newDotOnNeverShown: false,
    consumableKinds: {},
    ownedStillSold: {travelKind},
    soldMark: null,
  );

  factory CartRules.fromJson(Map<String, dynamic>? j) {
    if (j == null) return none;
    if (j['refreshTz'] != 'Asia/Seoul') {
      throw FormatException('shop.cart.refreshTz는 Asia/Seoul만 안다: ${j['refreshTz']}');
    }
    if (j['distanceBasis'] != 'actualAll') {
      throw FormatException('shop.cart.distanceBasis는 actualAll만 안다: ${j['distanceBasis']}');
    }
    final hour = j['refreshHour'] as int;
    if (hour < 0 || hour > 23) throw const FormatException('shop.cart.refreshHour는 0~23');
    final slots = [
      for (final s in (j['slotsByKm'] as List).cast<Map<String, dynamic>>())
        CartSlotStep(_d(s['km']), s['slots'] as int),
    ]..sort((a, b) => a.km.compareTo(b.km));
    if (slots.isEmpty || slots.first.km != 0) {
      throw const FormatException('shop.cart.slotsByKm은 0km 줄부터 있어야 한다');
    }
    final kinds = [
      for (final s in (j['kindsByKm'] as List).cast<Map<String, dynamic>>())
        CartKindStep(_d(s['km']), {...(s['kinds'] as List).cast<String>()}),
    ]..sort((a, b) => a.km.compareTo(b.km));
    final exclude = {...((j['exclude'] as List?) ?? const []).cast<String>()};
    final unknownExclude = exclude.difference({'owned'});
    if (unknownExclude.isNotEmpty) throw FormatException('shop.cart.exclude를 모른다: $unknownExclude');
    String known(String key, Set<String> allowed) {
      final v = j[key] as String;
      if (!allowed.contains(v)) throw FormatException('shop.cart.$key를 모른다: $v');
      return v;
    }

    final boughtToday = known('boughtToday', {'removeOnBuy', 'keepWithOwnedTag'});
    final mark = j['soldMark'] as Map<String, dynamic>?;
    return CartRules(
      refreshHour: hour,
      slotsByKm: slots,
      kindsByKm: kinds,
      fixedKinds: {...((j['fixed'] as List?) ?? const []).cast<String>()},
      excludeOwned: exclude.contains('owned'),
      neverShownFirst: known('prefer', {'neverShownFirst'}) == 'neverShownFirst',
      showFewer: known('fewerThanSlots', {'showFewer'}) == 'showFewer',
      colorsFollowBase: known('colorVariants', {'followBase'}) == 'followBase',
      removeOnBuy: boughtToday == 'removeOnBuy',
      newDotOnNeverShown: (j['newDot'] as String?) == 'cartHasNeverShown',
      consumableKinds: {...((j['consumableKinds'] as List?) ?? const []).cast<String>()},
      ownedStillSold: {...((j['ownedStillSold'] as List?) ?? const []).cast<String>()},
      soldMark: mark == null ? null : SoldMark.fromJson(mark),
    );
  }

  /// 새로 고침 시각 (한국 시간 시, v33 5)
  final int refreshHour;
  final List<CartSlotStep> slotsByKm;
  final List<CartKindStep> kindsByKm;

  /// 무작위 밖 고정 칸 종류 (v33 travel = 여행 효과)
  final Set<String> fixedKinds;

  /// 가진 물품은 수레에 안 나온다 (exclude owned, [ownedStillSold]는 예외)
  final bool excludeOwned;

  /// 한 번도 안 나온 것 먼저, 그다음 덜 나온 것 (prefer neverShownFirst)
  final bool neverShownFirst;

  /// 고를 상품이 칸보다 적으면 칸을 줄인다 (fewerThanSlots showFewer, 빈 칸 없음)
  final bool showFewer;

  /// 색 소품은 기본 소품을 가진 뒤 그 종류로 섞인다 (colorVariants followBase)
  final bool colorsFollowBase;

  /// 산 칸은 다시 채우지 않고 도장만 (boughtToday removeOnBuy)
  final bool removeOnBuy;

  /// 그날 수레에 처음 나온 상품이 있으면 새 상품 점 (newDot cartHasNeverShown)
  final bool newDotOnNeverShown;

  /// 소모품 종류 (v33 paintTube): 가진 것 빼기·안 나온 것 먼저에서 빠지고, 나올지는 상품의 하루 확률로 뽑는다
  final Set<String> consumableKinds;

  /// 가져도 다시 파는 종류 (v33 paintTube·travel)
  final Set<String> ownedStillSold;

  /// 산 칸 도장. 없으면 도장 없이 빈 칸
  final SoldMark? soldMark;

  /// 누적 실제 거리 [totalKm]의 칸 수
  int slotsAt(double totalKm) {
    var n = 0;
    for (final s in slotsByKm) {
      if (totalKm + 1e-9 >= s.km) n = s.slots;
    }
    return n;
  }

  /// 누적 실제 거리 [totalKm]에 열린 수레 종류
  Set<String> kindsAt(double totalKm) => {
        for (final s in kindsByKm)
          if (totalKm + 1e-9 >= s.km) ...s.kinds,
      };

  /// [nowUtc]의 수레 날 키 'YYYY-MM-DD': 한국 시각에서 [refreshHour]시간을 뺀 날 (하루 카드와 같은 경계)
  String dayOf(DateTime nowUtc) => kstDayKey(nowUtc.toUtc().subtract(Duration(hours: refreshHour)));

  /// 수레 날 [day]가 시작하는 시각 (UTC, 그날 한국 시간 [refreshHour]시)
  DateTime dayStartUtc(String day) => kstDayStartUtc(day).add(Duration(hours: refreshHour));
}

/// 여행 효과의 수레 종류 (고정 칸)
const travelKind = 'travel';

/// 그날 수레 칸 하나
class CartSlot {
  const CartSlot({required this.slot, required this.item, this.soldUtc, this.fresh = false, this.tubeColor});

  /// 칸 순서 (0부터, 저장한 줄 그대로)
  final int slot;
  final ShopItem item;

  /// 사거나 걸어서 얻어 팔린 시각 (epoch ms). null이면 살 수 있는 칸
  final int? soldUtc;

  /// 그날 수레에 처음 나온 상품 (새 상품 점, shop_shown.firstShownDay가 그날)
  final bool fresh;

  /// 물감 통 칸이면 그날 색 (물감 보관 키, 예 autumn.sunset)
  final String? tubeColor;

  bool get sold => soldUtc != null;
}

/// 상점 화면 한 번 읽은 것: 여행 효과 고정 칸 + 그날 수레 칸
class TodayCart {
  const TodayCart({
    required this.day,
    required this.fixed,
    required this.slots,
    required this.cartKm,
    required this.totalKm,
    this.news = false,
    this.seenUtc,
    this.seenSlots = 0,
  });

  static const empty = TodayCart(day: '', fixed: [], slots: [], cartKm: 0, totalKm: 0);

  /// 수레 날 키 ([CartRules.dayOf])
  final String day;

  /// 여행 효과 고정 칸 (shop.json order 순)
  final List<ShopItem> fixed;
  final List<CartSlot> slots;

  /// 그날 수레를 정한 누적 실제 거리(km): 수레 날 전날까지의 하루 요약 합 (낮에 넘은 단계는 다음 날부터)
  final double cartKm;

  /// 지금까지 누적 실제 거리(km, 오늘 포함). 다음 종류 한 줄이 쓴다
  final double totalKm;

  /// 새 상품 점: 그날 처음 나온 상품이 있고 그날 수레가 바뀐 뒤 아직 상점을 안 봤다
  final bool news;

  /// 마지막으로 상점을 본 시각 (epoch ms, 본 적 없으면 설치 시각, 모르면 null). 연출 ③이 그 뒤에 팔린 칸만
  /// 빠짐 + 도장을 돌린다 (상점 화면이 연 순간 값을 쥐고, 열면 지금 시각으로 다시 적는다)
  final int? seenUtc;

  /// [seenUtc]의 수레 날 칸 수 (그날 수레를 정한 거리로, [CartRules.slotsAt]). 연출 ③이 이 번호부터의 칸을
  /// 그 뒤 새로 열린 칸으로 본다 (열린 칸마다 한 번, oncePerUnlock)
  final int seenSlots;

  /// 살 수 있는 칸 (팔리지 않은 칸)
  Iterable<CartSlot> get open => slots.where((s) => !s.sold);
}

/// 아직 안 열린 칸 자리 (캔버스 8-1 자물쇠 칸): 칸이 늘어나는 단계마다 늘어나는 칸 수만큼 그 단계 km.
/// [km]는 그날 수레를 정한 거리 ([TodayCart.cartKm])
List<double> lockedSlotKms(CartRules rules, double km) {
  final now = rules.slotsAt(km);
  final out = <double>[];
  var prev = now;
  for (final s in rules.slotsByKm) {
    if (s.km <= km + 1e-9 || s.slots <= prev) continue;
    for (var i = prev; i < s.slots; i++) {
      out.add(s.km);
    }
    prev = s.slots;
  }
  return out;
}

/// 다음에 열리는 종류 단계 (캔버스 8-1 ‘누적 n km를 걸으면 ○○도 수레에 실려요’). 다 열렸으면 null.
/// [km]는 지금 누적 거리 ([TodayCart.totalKm])
CartKindStep? nextKindStep(CartRules rules, double km) {
  for (final s in rules.kindsByKm) {
    if (s.km > km + 1e-9 && s.kinds.difference(rules.fixedKinds).isNotEmpty) return s;
  }
  return null;
}

/// 상품의 수레 종류: 소품 칸(shop v9 slot: hat·cloth·shoe·face·hand·float·pet·effect, 무늬 trail, 물감 통 paintTube),
/// 없으면 분류 이름(여행 효과 travel, 쉼터 물품 decor, 배 boat). shop.json categoryNote 그대로
String cartKindOf(ShopItem item) => item.slot ?? item.category.name;

/// [seed]·[day]·[slot]으로 정하는 0 이상 1 미만 수 (FNV-1a 32비트 + murmur3 fmix32). 기기·다시 열기·오프라인에
/// 상관없이 같은 날은 같다 (config shop.cart.seed hash(installId, kstDate))
double cartRandom(String seed, String day, String slot) {
  var h = 0x811C9DC5;
  for (final b in utf8.encode('cart|$seed|$day|$slot')) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  h ^= h >> 16;
  h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
  h ^= h >> 13;
  h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
  h ^= h >> 16;
  return h / 4294967296.0;
}

/// 그날 수레 줄을 정한다 (칸 순서대로 상품 id). 순수 함수라 같은 값이면 같은 줄이다.
/// - [items]: 고를 수 있는 모든 상품(shop.json + 색 소품). 고정 칸 종류([CartRules.fixedKinds])는 빼고 본다.
/// - 칸 수·열린 종류는 [totalKm](그날 수레를 정할 때의 누적 실제 거리)로 정한다.
/// - [owned]가 true인 상품은 안 나온다 ([CartRules.ownedStillSold] 종류는 예외).
/// - 색 소품은 [haveBase]가 기본 소품([ShopItem.requires])을 가졌다고 할 때만, 그 종류로 (config colorVariants
///   followBase 하나만 안다).
/// - 소모품 종류([CartRules.consumableKinds])는 상품의 하루 확률([ShopItem.cartChancePerDay])로 뽑아 나오면
///   하루 [ShopItem.cartMaxPerDay]칸(기본 1)까지 차지하고, 그 자리는 그날 무작위 칸 하나다.
/// - 나머지는 [timesShown](수레에 나온 날 수, 없으면 0)이 적은 것 먼저, 같으면 [cartRandom] 순서.
/// - 고를 상품이 칸보다 적으면 칸을 줄인다 (빈 칸 없음)
List<String> planCart({
  required CartRules rules,
  required List<ShopItem> items,
  required bool Function(ShopItem item) owned,
  required bool Function(String propId) haveBase,
  required double totalKm,
  required Map<String, int> timesShown,
  required String seed,
  required String day,
}) {
  final slots = rules.slotsAt(totalKm);
  if (slots <= 0) return const [];
  final open = rules.kindsAt(totalKm);
  final regular = <ShopItem>[];
  final consumables = <ShopItem>[];
  for (final item in items) {
    final kind = cartKindOf(item);
    if (rules.fixedKinds.contains(kind) || !open.contains(kind)) continue;
    // 색 소품은 기본 소품을 가진 뒤에만 (기본 소품 없이는 살 수도 없다)
    if (item.requires case final base? when !haveBase(base)) continue;
    if (rules.consumableKinds.contains(kind)) {
      consumables.add(item);
      continue;
    }
    if (rules.excludeOwned && !rules.ownedStillSold.contains(kind) && owned(item)) continue;
    regular.add(item);
  }

  final picked = <String>[];
  // 소모품: 상품마다 그날 한 번 굴린다
  for (final item in consumables) {
    final chance = item.cartChancePerDay ?? 0;
    if (cartRandom(seed, day, 'consumable|${item.id}') >= chance) continue;
    final n = item.cartMaxPerDay ?? 1;
    for (var i = 0; i < n && picked.length < slots; i++) {
      picked.add(item.id);
    }
  }

  double tie(ShopItem i) => cartRandom(seed, day, 'pick|${i.id}');
  regular.sort((a, b) {
    if (rules.neverShownFirst) {
      final shown = (timesShown[a.id] ?? 0).compareTo(timesShown[b.id] ?? 0);
      if (shown != 0) return shown;
    }
    final t = tie(a).compareTo(tie(b));
    return t != 0 ? t : a.id.compareTo(b.id);
  });
  final room = slots - picked.length;
  final chosen = [for (final i in regular.take(room)) i.id];
  if (picked.isEmpty) return chosen;
  // 소모품 칸은 그날 무작위 자리에 끼운다
  final line = [...chosen];
  for (final (n, id) in picked.indexed) {
    final at = (cartRandom(seed, day, 'consumableAt|$n') * (line.length + 1)).floor();
    line.insert(at.clamp(0, line.length), id);
  }
  return line;
}

/// 그날 물감 통 칸의 색 (shop.json paint_tube.paint color todaySeasonRandom): [colors](그날 계절의 16색 보관 키)
/// 중 [seed]·[day]로 하나. 지역 색은 [colors]에 없다
String cartTubeColor(List<String> colors, String seed, String day) {
  if (colors.isEmpty) throw StateError('물감 통 색이 없다');
  final i = (cartRandom(seed, day, 'tubeColor') * colors.length).floor();
  return colors[i.clamp(0, colors.length - 1)];
}

/// 산 물감 통 [n]번째(0부터)의 양(m): [minM]~[maxM] 정수 m (길에서 줍는 통과 같은 양, config paintColor.tube.amountM)
int cartTubeAmountM(int minM, int maxM, String seed, String day, int n) =>
    minM + (cartRandom(seed, day, 'tubeAmount|$n') * (maxM - minM + 1)).floor().clamp(0, maxM - minM);

double _d(dynamic v) => (v as num).toDouble();

int _hex(String s) => 0xFF000000 | int.parse(s.substring(1), radix: 16);
