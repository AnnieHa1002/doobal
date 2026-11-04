// 도장(배지, M4 명세, badges.json): 동기화 끝에 조건을 로컬 기록으로 판정해 한 번만 준다.
// 못 받은 도장의 진행도는 보여 주지 않는다 (showProgress false)

/// badges.json의 도장 하나
class Badge {
  const Badge({
    required this.id,
    required this.name,
    required this.group,
    required this.icon,
    required this.order,
    required this.cond,
  });

  final String id;
  final String name;
  final String group;
  final String icon;
  final int order;
  final Map<String, dynamic> cond;

  factory Badge.fromJson(Map<String, dynamic> j) {
    final cond = j['cond'] as Map<String, dynamic>;
    if (!_kinds.contains(cond['kind'])) {
      throw FormatException('모르는 도장 조건: ${cond['kind']} (${j['id']})');
    }
    return Badge(
      id: j['id'] as String,
      name: j['name'] as String,
      group: j['group'] as String,
      icon: j['icon'] as String,
      order: j['order'] as int,
      cond: cond,
    );
  }
}

const _kinds = {
  'sessionsCount',
  'sessionKmGte',
  'dayStepsGte',
  'walkInPhase',
  'terrainEvents',
  'seasonsWalked',
  'arrivalCount',
  'seaCrossed',
  'frameGet',
  'journeyKmGte',
  'companionsMet',
  'finaleCount',
};

/// badges.json의 도장 전부 (order 순서)
List<Badge> parseBadges(Map<String, dynamic> json) => [
      for (final b in json['badges'] as List) Badge.fromJson(b as Map<String, dynamic>),
    ]..sort((a, b) => a.order.compareTo(b.order));

/// 로컬 DB에서 모은 기록. 거리 조건은 실제 + 본격 걷기 보너스 (상점 효과는 빠진다, M1 4.7)
class BadgeFacts {
  const BadgeFacts({
    this.sessionsCount = 0,
    this.bestSessionKm = 0,
    this.dayStepsBest = 0,
    this.dayStepsCounts = const {},
    this.walksInPhase = const {},
    this.terrainEvents = const {},
    this.seasonsWalked = const {},
    this.arrivalCount = 0,
    this.seaCrossed = false,
    this.frames = const {},
    this.bestJourneyKm = 0,
    this.companionsMet = 0,
    this.finaleCount = 0,
  });

  /// 인정된 걷기 1번 횟수
  final int sessionsCount;
  final double bestSessionKm;
  final int dayStepsBest;

  /// 걸음 기준 → 그 기준을 넘긴 날 수. 조건에 count가 있을 때 본다
  final Map<int, int> dayStepsCounts;

  /// 하늘 구간(dawn·sunset·night) → 그때 시작한 걷기 1번 횟수
  final Map<String, int> walksInPhase;

  /// 지형 → 이벤트 개수
  final Map<String, int> terrainEvents;
  final Set<String> seasonsWalked;

  /// 명소 도착 횟수 (내 동네 스케치 제외)
  final int arrivalCount;
  final bool seaCrossed;

  /// 받은 액자 등급 이름
  final Set<String> frames;
  final double bestJourneyKm;
  final int companionsMet;
  final int finaleCount;
}

/// 조건을 채웠는가. 같은 기록이면 늘 같은 답이다
bool badgeMet(Map<String, dynamic> cond, BadgeFacts f) {
  num n(String key, [num fallback = 1]) => cond[key] as num? ?? fallback;
  return switch (cond['kind']) {
    'sessionsCount' => f.sessionsCount >= n('n'),
    'sessionKmGte' => f.bestSessionKm >= n('km'),
    'dayStepsGte' => cond['count'] == null
        ? f.dayStepsBest >= n('steps')
        : (f.dayStepsCounts[n('steps').toInt()] ?? 0) >= n('count'),
    'walkInPhase' => (f.walksInPhase[cond['phase']] ?? 0) >= n('n'),
    'terrainEvents' => (f.terrainEvents[cond['terrain']] ?? 0) >= n('n'),
    'seasonsWalked' => f.seasonsWalked.length >= n('n'),
    'arrivalCount' => f.arrivalCount >= n('n'),
    'seaCrossed' => f.seaCrossed,
    'frameGet' => f.frames.contains(cond['frame']),
    'journeyKmGte' => f.bestJourneyKm >= n('km'),
    'companionsMet' => f.companionsMet >= n('n'),
    'finaleCount' => f.finaleCount >= n('n'),
    _ => false,
  };
}

/// 새로 받은 도장: 조건을 채웠고 아직 안 받은 것
List<Badge> newBadges(List<Badge> badges, BadgeFacts facts, Set<String> owned) => [
      for (final b in badges)
        if (!owned.contains(b.id) && badgeMet(b.cond, facts)) b,
    ];
