// 물감 길 무늬 (trails.json v2, 16장 11/19 상점 무늬): 기본 방울 + 무늬 3종. 소품이 아니라 물감처럼 칠하는 재료.
// 거리 보상 판정([planPatternRewards])과 토스트 글. 고르기·구간마다 저장은 PaintService, 보상 저장은 동기화
// (sync_pattern.dart), 그리기는 ui (규칙 값은 config paintPattern, T17b)

import 'format_int.dart';

/// 무늬를 얻는 길 (trails.json unlock.kind, default는 예약어라 initial)
enum TrailUnlockKind {
  /// 처음부터, 무제한
  initial,

  /// 물감 길 누적 실제 거리가 [TrailPattern.km] 이상. 상점에서도 [TrailPattern.shopPrice] 럭에 산다
  trailKm,
}

/// 무늬 하나. 그림은 회색조 타일(512×64)·끝(64×64)에 구간 색을 곱한다
class TrailPattern {
  const TrailPattern({
    required this.id,
    required this.name,
    required this.kind,
    required this.tile,
    required this.cap,
    this.km,
    this.shopPrice,
    this.icon,
    this.pending = false,
  });

  final String id;
  final String name;
  final TrailUnlockKind kind;

  /// 타일·끝 그림 이름 (확장자 없이)
  final String tile;
  final String cap;

  /// trailKm: 물감 길 누적 실제 거리(km)
  final double? km;

  /// 상점 값(럭). shop.json 무늬 상품 값과 같다
  final int? shopPrice;

  /// 칸 아이콘 그림 이름. 기본 방울은 없다 (앱이 방울 타일로 만든다)
  final String? icon;

  /// 그림 납품 전. 그림이 없으면 그 구간도 방울 타일로 그린다
  final bool pending;

  factory TrailPattern.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final u = j['unlock'] as Map<String, dynamic>;
    final kind = switch (u['kind']) {
      'default' => TrailUnlockKind.initial,
      'trailKm' => TrailUnlockKind.trailKm,
      final k => throw FormatException('모르는 무늬 얻는 길: $k ($id)'),
    };
    final km = (u['km'] as num?)?.toDouble();
    if (kind == TrailUnlockKind.trailKm && km == null) {
      throw FormatException('무늬 거리 값이 없다: $id');
    }
    return TrailPattern(
      id: id,
      name: j['name'] as String,
      kind: kind,
      tile: j['tile'] as String,
      cap: j['cap'] as String,
      km: km,
      shopPrice: u['shopPrice'] as int?,
      icon: j['icon'] as String?,
      pending: j['pending'] as bool? ?? false,
    );
  }
}

/// trails.json 전체
class TrailCatalog {
  TrailCatalog({required this.defaultId, required this.patterns});

  /// 기본 무늬 id (방울)
  final String defaultId;

  /// 파일에 적힌 순서 그대로
  final List<TrailPattern> patterns;

  late final Map<String, TrailPattern> _byId = {for (final p in patterns) p.id: p};

  TrailPattern? byId(String id) => _byId[id];

  TrailPattern get defaultPattern => _byId[defaultId]!;

  /// 거리 보상으로 얻는 무늬 (trailKm), 파일 차례 = 보상으로 주는 차례
  List<TrailPattern> get rewardPatterns => [
        for (final p in patterns)
          if (p.kind == TrailUnlockKind.trailKm) p,
      ];

  /// 거리 보상 문턱(km, 오름차순, 겹치면 하나): 무늬마다 unlock.km (config paintPattern.reward.kmFrom)
  List<int> get rewardKms => ({for (final p in rewardPatterns) p.km!.round()}.toList()..sort());
}

/// 거리 보상 하나: 물감 길 누적 실제 거리가 [km]에 닿아 [patternId] 무늬를 얻었거나, 무늬를 이미 다 가져서
/// 그 대신 [coins] 럭을 받았다 (둘 중 하나)
class PatternReward {
  const PatternReward.pattern(this.km, String this.patternId) : coins = 0;
  const PatternReward.coins(this.km, this.coins) : patternId = null;

  final int km;
  final String? patternId;
  final int coins;

  @override
  bool operator ==(Object other) =>
      other is PatternReward && other.km == km && other.patternId == patternId && other.coins == coins;

  @override
  int get hashCode => Object.hash(km, patternId, coins);

  @override
  String toString() => 'PatternReward($km km → ${patternId ?? '$coins 럭'})';
}

/// 럭 장부에 남기는 ‘무늬를 다 가져서 받은 럭’ 줄의 refId (같은 문턱을 두 번 주지 않게, 백업 복원 뒤에도 같다)
String patternCoinsRef(int km) => 'trailPattern:$km';

/// 물감 길 무늬 거리 보상 (16장 11/19 밤 Annie 창구 Q005, config paintPattern.reward): 물감 길 누적 실제 거리
/// [trailKm](상점 효과 제외)가 문턱(10·50·100km)에 닿을 때마다, 아직 없는 무늬 중 표 차례로 첫 번째를 준다.
/// 이미 다 가졌으면(상점에서 사서) 그 대신 [allOwnedCoins] 럭.
/// [owned]는 가진 무늬 id(기본 방울은 넣지 않아도 된다), [givenKms]는 이미 보상을 준 문턱
/// (patterns_owned.reward_km과 럭 장부 [patternCoinsRef]). 한 번에 여러 문턱을 넘었으면 낮은 문턱부터 차례로 준다.
/// 같은 값으로 다시 부르면 빈 목록이 아니라 같은 목록이 나오므로, 부르는 쪽이 준 것을 [givenKms]·[owned]에 넣는다
List<PatternReward> planPatternRewards({
  required TrailCatalog catalog,
  required double trailKm,
  required Set<String> owned,
  required Set<int> givenKms,
  required int allOwnedCoins,
}) {
  final have = {...owned};
  final out = <PatternReward>[];
  for (final km in catalog.rewardKms) {
    // 부동소수 오차로 9.9999km에서 못 받지 않게 아주 조금 여유를 둔다
    if (trailKm + 1e-9 < km || givenKms.contains(km)) continue;
    final next = catalog.rewardPatterns.where((p) => !have.contains(p.id)).firstOrNull;
    if (next == null) {
      // 럭이 0이면 줄 것이 없다 (장부에 남길 것도, 알릴 것도 없음)
      if (allOwnedCoins > 0) out.add(PatternReward.coins(km, allOwnedCoins));
    } else {
      have.add(next.id);
      out.add(PatternReward.pattern(km, next.id));
    }
  }
  return out;
}

/// 거리 보상 한 줄 토스트 (가안: 소품·배와 같은 꼴 ‘새 무늬를 얻었어요 · 발자국’, 럭은 ‘물감 길 100km · +100 럭’).
/// [rewards]의 첫 무늬 보상이 이름, 나머지는 ‘외 n개’. 무늬 없이 럭만이면 럭 줄. [coinAmount]는 config
/// coins.format.amount (‘{n} 럭’)
String patternRewardToast(TrailCatalog catalog, List<PatternReward> rewards, String coinAmount) {
  final patterns = [
    for (final r in rewards)
      if (r.patternId case final id?) catalog.byId(id)?.name ?? id,
  ];
  if (patterns.isNotEmpty) {
    return '새 무늬를 얻었어요 · ${patterns.first}${patterns.length > 1 ? ' 외 ${patterns.length - 1}개' : ''}';
  }
  final coins = rewards.fold(0, (s, r) => s + r.coins);
  return '물감 길 ${rewards.last.km}km · +${coinAmount.replaceAll('{n}', formatInt(coins))}';
}

TrailCatalog parseTrails(Map<String, dynamic> json) {
  final patterns = [
    for (final p in json['patterns'] as List) TrailPattern.fromJson(p as Map<String, dynamic>),
  ];
  final ids = <String>{};
  for (final p in patterns) {
    if (!ids.add(p.id)) throw FormatException('무늬 id가 겹친다: ${p.id}');
  }
  final defaultId = json['default'] as String;
  if (!ids.contains(defaultId)) throw FormatException('기본 무늬가 목록에 없다: $defaultId');
  return TrailCatalog(defaultId: defaultId, patterns: patterns);
}
