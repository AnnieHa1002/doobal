// 도장(배지, M4 명세, badges.json): 동기화 끝에 조건을 로컬 기록으로 판정해 한 번만 준다.
// 못 받은 도장의 진행도는 보여 주지 않는다 (showProgress false)

import 'geo.dart';
import 'sun.dart';
import 'time_kst.dart';

/// badges.json의 도장 하나
class Badge {
  const Badge({
    required this.id,
    required this.name,
    required this.desc,
    required this.group,
    required this.icon,
    required this.order,
    required this.cond,
  });

  final String id;
  final String name;

  /// 조건 설명 한 줄 (도장을 눌렀을 때 보인다)
  final String desc;
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
      desc: j['desc'] as String? ?? '',
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

/// 하늘 구간 (badges.json phases): 해 뜨고 지는 시각에서 잰 분. 시작 이상, 끝 미만
class BadgePhases {
  const BadgePhases({
    required this.dawn,
    required this.sunset,
    required this.nightFromSunsetMin,
    required this.nightToSunriseMin,
  });

  /// 새벽: 일출 기준 [from, to) 분
  final (double, double) dawn;

  /// 노을: 일몰 기준 [from, to) 분
  final (double, double) sunset;

  /// 밤: 일몰 + from분 이후, 또는 (그날) 일출 + to분 이전
  final double nightFromSunsetMin;
  final double nightToSunriseMin;

  factory BadgePhases.fromJson(Map<String, dynamic> j) {
    (double, double) range(String key, String field) {
      final r = ((j[key] as Map<String, dynamic>)[field] as List).cast<num>();
      return (r[0].toDouble(), r[1].toDouble());
    }

    final night = j['night'] as Map<String, dynamic>;
    return BadgePhases(
      dawn: range('dawn', 'fromSunriseMin'),
      sunset: range('sunset', 'fromSunsetMin'),
      nightFromSunsetMin: (night['fromSunsetMin'] as num).toDouble(),
      nightToSunriseMin: (night['toSunriseMin'] as num).toDouble(),
    );
  }

  /// [utc] 시각이 속한 하늘 구간 (dawn·sunset·night), 어디에도 안 속하면 null.
  /// [sun]은 그 한국 날짜의 일출·일몰이다 (새벽 전의 밤도 같은 날 일출 기준으로 본다)
  String? phaseAt(DateTime utc, SunTimes sun) {
    double minutes(DateTime from) =>
        utc.difference(from).inMicroseconds / Duration.microsecondsPerMinute;
    final fromRise = minutes(sun.sunrise);
    final fromSet = minutes(sun.sunset);
    if (fromRise >= dawn.$1 && fromRise < dawn.$2) return 'dawn';
    if (fromSet >= sunset.$1 && fromSet < sunset.$2) return 'sunset';
    if (fromSet >= nightFromSunsetMin || fromRise < nightToSunriseMin) return 'night';
    return null;
  }
}

/// badges.json 전체: 도장 목록과 하늘 구간
class BadgeCatalog {
  const BadgeCatalog({required this.badges, required this.phases});

  final List<Badge> badges;
  final BadgePhases phases;

  factory BadgeCatalog.fromJson(Map<String, dynamic> json) => BadgeCatalog(
        badges: parseBadges(json),
        phases: BadgePhases.fromJson(json['phases'] as Map<String, dynamic>),
      );
}

/// 걷기 1번 시작 시각 [startUtc]의 하늘 구간. 걷기가 있던 지점은 저장하지 않아서 출발 동네 좌표 [home]으로
/// 근사한다 (한국 안에서 일출·일몰은 수십 분만 달라서 구간 경계에서만 틀릴 수 있다)
String? walkPhase(DateTime startUtc, LatLng home, BadgePhases phases, double zenithDeg) =>
    phases.phaseAt(startUtc, sunTimes(home, kstDayKey(startUtc), zenithDeg));

/// 화집 도장 탭의 묶음 (캔버스 Gallery): 이름과 그 묶음의 도장 (order 순서)
class BadgeSection {
  const BadgeSection(this.name, this.badges);

  final String name;
  final List<Badge> badges;
}

/// 도장을 묶음별로 (걷기 습관·시간대·지형·계절·여정·동행). 지형과 계절은 한 묶음이다
List<BadgeSection> badgeSections(List<Badge> badges) {
  const names = {
    'habit': '걷기 습관',
    'time': '시간대',
    'terrain': '지형·계절',
    'season': '지형·계절',
    'journey': '여정',
    'companion': '동행',
  };
  final sections = <String, List<Badge>>{};
  for (final b in badges) {
    sections.putIfAbsent(names[b.group] ?? b.group, () => []).add(b);
  }
  return [for (final e in sections.entries) BadgeSection(e.key, e.value)];
}

/// 새 도장 토스트 한 줄 (가안): `새 도장을 받았어요 · 첫 걸음`, 여럿이면 `… · 첫 걸음 외 1개`
String newBadgeToast(List<Badge> badges) => '새 도장을 받았어요 · ${badges.first.name}'
    '${badges.length > 1 ? ' 외 ${badges.length - 1}개' : ''}';
