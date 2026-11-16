import 'dart:convert';
import 'dart:math' as math;

import 'color.dart';
import 'gait.dart';
import 'geo.dart';
import 'rules.dart';
import 'landmark.dart';
import 'scene.dart' show Season, nearestLandmark, seasonOf;
import 'sky.dart';
import 'sun.dart';
import 'time_kst.dart';

// 물감 색과 물감 모으기 (16장 11/14, M1 명세 v0.7, config paintColor).
// - 그 순간 물감 색 = 시간대 5 + 날씨 3(맑음이면 시간대 색) × 강도(뛰면 진하게) = 16색 ([colorOf]).
//   방울에 곱하는 색이고, 물감 통이 나오면 그 통의 색이다.
// - 물감 방울(paintDrop.spacingM마다)마다 보상 표([PaintColorRules.rewards])를 굴린다. MVP는 물감 통 하나뿐이고
//   (럭 +1은 방울마다 따로, M1 v0.5 ③), 무작위는 물감 길 번호·방울 번호로 정해서 다시 계산해도 같다 ([rollDrop]).
// - 물감 길은 쉼터 배낭에서 고른 색을 다 쓸 때까지 칠하고, 다 쓰면 그 자리에서 나머지는 기본 물감 ([paintSplit]).
//   걷는 중에도 배낭에서 바꿀 수 있어서(16장 11/16) 물감 길 하나에 색 구간이 여럿 생긴다 ([TrailPaint.segments]).
// - 계절 변주(16장 11/15): 16색이 주운 날(한국 날짜)의 계절마다 달라 따로 쌓인다 = 64색. 보관 키 `<계절>.<색>`
//   (예 autumn.sunset_run). 계절이 없는 키(1단계에서 모은 것)는 계절 없는 기준 hex로 읽는다.
// - 지역 색(16장 11/15): 물감 통이 나오면 그중 config region.chancePerTube가 지금 권역(가장 가까운 명소의
//   landmarks region)의 지역 색. 보관 키 `region.<id>`(예 region.kr.capital), 계절·뛰기 변주 없음

/// 날씨 (서버 getWeather의 kind, M2~M6 v0.20 Y). 맑음이면 시간대 색
enum PaintWeather { clear, cloudy, rain, snow }

/// 날씨 색의 차례 (16장 11/14 ‘비·눈·흐림’). 배낭 탭이 이 차례로 늘어놓는다
const paintWeatherOrder = [PaintWeather.rain, PaintWeather.snow, PaintWeather.cloudy];

/// 날씨 이름 → 값 (모르는 이름이면 null = 날씨를 모름 → 시간대 색)
PaintWeather? paintWeatherOf(String? name) {
  for (final w in PaintWeather.values) {
    if (w.name == name) return w;
  }
  return null;
}

/// 걷기·뛰기 두 색. [run]이 없으면 config paintColor.intensity.run 계산식으로 낸다
class PaintHexPair {
  const PaintHexPair(this.walk, this.run);

  final int walk;
  final int run;
}

/// 지역 색 하나 (config paintColor.region.colors): [region]은 landmarks region 값(권역 키), [id]는 나라.권역
class RegionPaint {
  const RegionPaint({required this.region, required this.id, required this.name, required this.hex});

  final String region;
  final String id;
  final String name;
  final int hex;

  /// 보관 키 (config region.stockKey `region.<id>`)
  String get stockId => '$regionPaintPrefix$id';
}

/// 지역 색 보관 키 앞말
const regionPaintPrefix = 'region.';

/// 배낭 물감 탭 묶음 (config paintColor.backpack.order)
enum PaintGroup { basic, recent, season, region }

/// 처음 펼쳐 둘 묶음 (config paintColor.backpack.openOnStart): 지금 계절만·모두·없음
enum PaintOpenOnStart { currentSeason, all, none }

/// 배낭 물감 탭 (config paintColor.backpack, 물감색_개발인계 4장·물감색_계절지역 3장)
class PaintBackpackRules {
  const PaintBackpackRules({
    this.order = PaintGroup.values,
    this.recentCount = 3,
    this.collapsible = true,
    this.openOnStart = PaintOpenOnStart.currentSeason,
    this.remainStepKm = 0.1,
  });

  /// 묶음 차례 (기본 → 최근 → 계절 → 지역)
  final List<PaintGroup> order;

  /// 최근 칸 수
  final int recentCount;

  /// 묶음을 접을 수 있는가
  final bool collapsible;
  final PaintOpenOnStart openOnStart;

  /// 남은 거리 꼬리표의 단위(km)와 내림 (config remainStep·remainRound floor)
  final double remainStepKm;

  factory PaintBackpackRules.fromJson(Map<String, dynamic> j) {
    final order = [for (final g in (j['order'] as List).cast<String>()) PaintGroup.values.byName(g)];
    if (order.toSet().length != order.length || order.first != PaintGroup.basic) {
      throw const FormatException('paintColor.backpack.order는 basic이 맨 앞이고 겹치지 않아야 한다');
    }
    if (j['remainUnit'] != 'km' || j['remainRound'] != 'floor') {
      throw FormatException('paintColor.backpack 남은 거리를 모른다: ${j['remainUnit']} ${j['remainRound']}');
    }
    final step = _d(j['remainStep']);
    if (step <= 0) throw const FormatException('paintColor.backpack.remainStep은 0보다 커야 한다');
    return PaintBackpackRules(
      order: order,
      recentCount: j['recentCount'] as int,
      collapsible: j['groupsCollapsible'] as bool,
      openOnStart: PaintOpenOnStart.values.byName(j['openOnStart'] as String),
      remainStepKm: step,
    );
  }

  /// 꼬리표의 남은 거리(km): remainStep 단위로 내림
  double remainKm(double remainM) {
    final steps = (remainM / 1000 / remainStepKm + 1e-9).floor();
    return steps * remainStepKm;
  }
}

/// 방울 하나에서 나올 수 있는 보상 한 줄 (config 보상 표). [chance]는 방울 하나에서 이 줄이 나올 확률
sealed class DropReward {
  const DropReward(this.chance);

  final double chance;

  /// 보상 표 이름 (config kind)
  String get kind;
}

/// 물감 통: 양은 [minM]~[maxM] m 사이 정수 m를 고르게 (config paintColor.tube.amountM)
class TubeReward extends DropReward {
  const TubeReward(super.chance, {required this.minM, required this.maxM});

  final int minM;
  final int maxM;

  @override
  String get kind => 'tube';
}

/// 방울 하나를 굴린 결과. 보상이 없으면 [reward]가 null (럭 +1은 늘 따로 있다)
class DropRoll {
  const DropRoll(this.reward, {this.amountM = 0, this.region = false});

  final DropReward? reward;

  /// 물감 통이면 그 양(m)
  final int amountM;

  /// 물감 통이 지역 색인가 (config paintColor.region.chancePerTube)
  final bool region;

  bool get tube => reward is TubeReward;
}

/// 물감 길 [trailId]의 [dropNo]번째 방울에서 [slot] 이름의 0 이상 1 미만 수. 시험은 고정한 것을 넣는다
typedef PaintRandom = double Function(int trailId, int dropNo, String slot);

/// 기본 무작위: 물감 길 번호·방울 번호·slot의 hash (FNV-1a 32비트 + 섞기). 기기·판·다시 계산·백업 복원에 상관없이 같다
double seededPaintRandom(int trailId, int dropNo, String slot) {
  var h = 0x811C9DC5;
  for (final b in utf8.encode('paint|$trailId|$dropNo|$slot')) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  // FNV는 끝 글자가 비슷하면 값도 붙어 나와서 섞는다 (murmur3 fmix32)
  h ^= h >> 16;
  h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
  h ^= h >> 13;
  h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
  h ^= h >> 16;
  return h / 4294967296.0;
}

/// config paintColor (+ 보상 표)
class PaintColorRules {
  const PaintColorRules({
    required this.defaultId,
    required this.defaultHex,
    required this.timePhase,
    required this.weather,
    required this.rewards,
    required this.maxTubesPerColor,
    required this.weatherAskMin,
    required this.weatherCacheMin,
    required this.chooseWhileWalking,
    this.weatherPerDay = false,
    this.names = const {},
    this.seasonNames = const {},
    this.seasonHex = const {},
    this.regions = const {},
    this.regionChancePerTube = 0,
    this.backpack = const PaintBackpackRules(),
    this.tubeRoadSprite = 'ui_paint_tube_road_v01',
    this.tubeIconSprite = 'ui_paint_tube_icon_v01',
  });

  /// 기본 물감 id(basic)와 색. 무제한
  final String defaultId;
  final int defaultHex;

  /// 시간대 색 (config paintColor.timePhase, 키는 scene.sky 키 구간)
  final Map<SkyPhase, PaintHexPair> timePhase;

  /// 날씨 색 (config paintColor.weather: 비·눈·흐림). 맑음은 시간대 색이라 없다
  final Map<PaintWeather, PaintHexPair> weather;

  /// 방울 하나의 보상 표 (확률이 겹치지 않게 차례로 쌓는다: 한 방울에서 많아야 하나)
  final List<DropReward> rewards;

  /// 색마다 통 수 상한 (config paintColor.stock.maxTubesPerColor). 가진 통이 이만큼이면 그 색 통은 안 나온다
  final int maxTubesPerColor;

  /// 앱이 날씨를 다시 묻는 간격(분). config paintColor.weatherSource.askMin이 없으면 서버 캐시 간격(cacheMin)
  final int weatherAskMin;
  final int weatherCacheMin;

  /// 걷는 중(물감 길이 열린 동안)에 고를 수 있는가 (config paintColor.choose.whileWalking, 16장 11/16 true:
  /// 그 순간부터 그 색으로 칠한다)
  final bool chooseWhileWalking;

  /// 날씨를 한국 날짜마다 한 번만 묻는가 (config weatherSource.per kstDay, 16장 11/16: 그날 처음 물감 길이 열릴 때)
  final bool weatherPerDay;

  /// 화면 이름 (config paintColor.names): 시간대·날씨 id → 이름, runPrefix(‘진한’), basic(‘기본’)
  final Map<String, String> names;

  /// 계절 이름과 계절마다 16색 (config paintColor.season). 비어 있으면 계절 변주 없음
  final Map<Season, String> seasonNames;
  final Map<Season, Map<String, PaintHexPair>> seasonHex;

  /// 지역 색: 권역 키(landmarks region) → 지역 색 (config paintColor.region.colors)
  final Map<String, RegionPaint> regions;

  /// 물감 통 중 지역 색이 되는 비율 (config paintColor.region.chancePerTube)
  final double regionChancePerTube;

  /// 배낭 물감 탭 (config paintColor.backpack)
  final PaintBackpackRules backpack;

  /// 물감 통 그림 이름 (config paintColor.tube.sprites, 확장자 없이)
  final String tubeRoadSprite;
  final String tubeIconSprite;

  factory PaintColorRules.fromJson(Map<String, dynamic> j, {Map<String, dynamic>? paintDrop}) {
    final def = j['default'] as Map<String, dynamic>;
    if (def['infinite'] != true) throw const FormatException('paintColor.default는 무제한이어야 한다');
    // 뛰기 색을 모두 hex 쌍으로 주면(11/15 디자인 기획) intensity는 없어도 된다
    final run = (j['intensity'] as Map<String, dynamic>?)?['run'] as Map<String, dynamic>?;
    PaintHexPair pair(Object? v, String where) {
      if (v is String) {
        final walk = _hex(v, where);
        if (run == null) throw FormatException('$where에 뛰기 색이 없고 intensity.run도 없다');
        return PaintHexPair(walk, _runOf(walk, _d(run['darken']), _d(run['saturate'])));
      }
      if (v is Map) return PaintHexPair(_hex(v['walk'], '$where.walk'), _hex(v['run'], '$where.run'));
      throw FormatException('$where는 "#RRGGBB"나 {walk, run}이어야 한다');
    }

    final phases = j['timePhase'] as Map<String, dynamic>;
    final timePhase = {
      for (final p in SkyPhase.values) p: pair(phases[p.name], 'paintColor.timePhase.${p.name}'),
    };
    final weatherJson = j['weather'] as Map<String, dynamic>;
    final weather = {
      for (final w in paintWeatherOrder) w: pair(weatherJson[w.name], 'paintColor.weather.${w.name}'),
    };
    final count = (timePhase.length + weather.length) * 2;
    if (j['colorCount'] != null && j['colorCount'] != count) {
      throw FormatException('paintColor.colorCount ${j['colorCount']} ≠ $count');
    }

    final tube = j['tube'] as Map<String, dynamic>;
    final amount = (tube['amountM'] as List).cast<num>();
    if (amount.length != 2 || amount[0] <= 0 || amount[1] < amount[0]) {
      throw const FormatException('paintColor.tube.amountM은 [최소, 최대] m여야 한다');
    }
    TubeReward tubeReward(double chance) =>
        TubeReward(chance, minM: amount[0].round(), maxM: amount[1].round());
    // 보상 표: config paintDrop.rewards 목록이 있으면 그것 (새 아이템은 한 줄씩 더한다), 없으면
    // paintColor.tube.chancePerDrop 한 줄
    final listed = paintDrop?['rewards'] as List?;
    final rewards = listed == null
        ? [tubeReward(_d(tube['chancePerDrop']))]
        : [
            for (final r in listed.cast<Map<String, dynamic>>())
              switch (r['kind']) {
                'tube' => tubeReward(_d(r['chance'])),
                _ => throw FormatException('paintDrop.rewards kind를 모른다: ${r['kind']}'),
              },
          ];
    final total = rewards.fold(0.0, (a, r) => a + r.chance);
    if (rewards.any((r) => r.chance < 0) || total > 1 + 1e-9) {
      throw const FormatException('방울 보상 확률은 0 이상이고 합이 1 이하여야 한다');
    }

    final stock = j['stock'] as Map<String, dynamic>;
    final source = j['weatherSource'] as Map<String, dynamic>;
    if (source['offline'] != 'timePhase') {
      throw FormatException('paintColor.weatherSource.offline을 모른다: ${source['offline']}');
    }
    final cacheMin = source['cacheMin'] as int;
    final per = source['per'];
    if (per != null && per != 'kstDay') {
      throw FormatException('paintColor.weatherSource.per를 모른다: $per');
    }
    final choose = j['choose'] as Map<String, dynamic>;
    // 다 쓴 색을 같은 색 통으로 저절로 다시 고르기는 없다 (16장 11/16)
    if ((choose['reselectOnRefill'] ?? false) != false) {
      throw const FormatException('paintColor.choose.reselectOnRefill true는 모른다');
    }

    // 계절 변주 (config season: 달은 config seasons, 계절마다 16색 {walk, run})
    final seasonJson = j['season'] as Map<String, dynamic>?;
    final seasonNames = <Season, String>{};
    final seasonHex = <Season, Map<String, PaintHexPair>>{};
    if (seasonJson != null) {
      if (seasonJson['monthsFrom'] != 'seasons') {
        throw FormatException('paintColor.season.monthsFrom을 모른다: ${seasonJson['monthsFrom']}');
      }
      if (seasonJson['stockKey'] != '<season>.<colorId>') {
        throw FormatException('paintColor.season.stockKey를 모른다: ${seasonJson['stockKey']}');
      }
      final names = seasonJson['names'] as Map<String, dynamic>;
      final hex = seasonJson['hex'] as Map<String, dynamic>;
      final bases = [...SkyPhase.values.map((p) => p.name), ...paintWeatherOrder.map((w) => w.name)];
      for (final season in Season.values) {
        final table = hex[season.name] as Map<String, dynamic>?;
        if (table == null) throw FormatException('paintColor.season.hex에 ${season.name}가 없다');
        if (table.keys.toSet().difference({'note'}).length != bases.length) {
          throw FormatException('paintColor.season.hex.${season.name}는 16색 id여야 한다');
        }
        seasonNames[season] = names[season.name] as String;
        seasonHex[season] = {
          for (final b in bases) b: pair(table[b], 'paintColor.season.hex.${season.name}.$b'),
        };
      }
    }

    // 지역 색 (config region: 권역 키 → id·이름·hex, 통의 chancePerTube)
    final regionJson = j['region'] as Map<String, dynamic>?;
    final regions = <String, RegionPaint>{};
    var regionChance = 0.0;
    if (regionJson != null) {
      if (regionJson['by'] != 'nearestLandmarkRegion' || regionJson['stockKey'] != 'region.<id>') {
        throw FormatException('paintColor.region을 모른다: ${regionJson['by']} ${regionJson['stockKey']}');
      }
      regionChance = _d(regionJson['chancePerTube']);
      if (regionChance < 0 || regionChance > 1) {
        throw const FormatException('paintColor.region.chancePerTube는 0~1이어야 한다');
      }
      for (final e in (regionJson['colors'] as Map<String, dynamic>).entries) {
        final c = e.value as Map<String, dynamic>;
        regions[e.key] = RegionPaint(
          region: e.key,
          id: c['id'] as String,
          name: c['name'] as String,
          hex: _hex(c['hex'], 'paintColor.region.colors.${e.key}.hex'),
        );
      }
      if ({for (final r in regions.values) r.id}.length != regions.length) {
        throw const FormatException('paintColor.region.colors id가 겹친다');
      }
    }

    final namesJson = j['names'] as Map<String, dynamic>?;
    final sprites = tube['sprites'] as Map<String, dynamic>?;
    if (sprites != null && sprites['tint'] != 'multiplyRgb') {
      throw FormatException('paintColor.tube.sprites.tint를 모른다: ${sprites['tint']}');
    }
    final backpack = j['backpack'] as Map<String, dynamic>?;
    return PaintColorRules(
      defaultId: def['id'] as String,
      defaultHex: _hex(def['hex'], 'paintColor.default.hex'),
      timePhase: timePhase,
      weather: weather,
      rewards: rewards,
      maxTubesPerColor: stock['maxTubesPerColor'] as int,
      weatherAskMin: (source['askMin'] as int?) ?? cacheMin,
      weatherCacheMin: cacheMin,
      chooseWhileWalking: choose['whileWalking'] as bool,
      weatherPerDay: per == 'kstDay',
      names: {
        if (namesJson != null)
          for (final e in namesJson.entries)
            if (e.key != 'note') e.key: e.value as String,
      },
      seasonNames: seasonNames,
      seasonHex: seasonHex,
      regions: regions,
      regionChancePerTube: regionChance,
      backpack: backpack == null ? const PaintBackpackRules() : PaintBackpackRules.fromJson(backpack),
      tubeRoadSprite: (sprites?['road'] as String?) ?? 'ui_paint_tube_road_v01',
      tubeIconSprite: (sprites?['icon'] as String?) ?? 'ui_paint_tube_icon_v01',
    );
  }

  /// 16색 id 전부 (시간대 5 새벽~밤 → 날씨 3 비·눈·흐림, 각각 걷기 → 뛰기, 계절 없음). 배낭 탭이 이 차례로 늘어놓는다
  List<String> get colorIds => [
        for (final base in [...timePhase.keys.map((p) => p.name), ...weather.keys.map((w) => w.name)])
          for (final run in const [false, true]) run ? '${base}_run' : base,
      ];

  /// 계절 [s]의 16색 보관 키 (예 autumn.sunset_run), [colorIds] 차례
  List<String> seasonIds(Season s) => [for (final id in colorIds) seasonalId(s, id)];

  /// 계절 변주를 하는가 (config paintColor.season이 있다)
  bool get seasonal => seasonHex.isNotEmpty;

  /// 보관 키 [id]의 지역 색 (지역 색 키가 아니거나 모르는 지역이면 null)
  RegionPaint? regionOf(String id) {
    if (!id.startsWith(regionPaintPrefix)) return null;
    for (final r in regions.values) {
      if (r.stockId == id) return r;
    }
    return null;
  }

  /// 색 id의 색 (불투명 ARGB). 계절이 붙으면 그 계절 hex, 계절이 없는 키(1단계)는 기준 hex.
  /// 기본·모르는 id는 기본 물감 색
  int hexOf(String id) {
    if (id.startsWith(regionPaintPrefix)) return regionOf(id)?.hex ?? defaultHex;
    final base = paintBase(id);
    if (base == null) return defaultHex;
    final key = base.phase?.name ?? base.weather!.name;
    final season = paintSeason(id);
    final pair = (season == null ? null : seasonHex[season]?[key]) ??
        (base.phase != null ? timePhase[base.phase] : weather[base.weather]);
    if (pair == null) return defaultHex;
    return base.run ? pair.run : pair.walk;
  }

  /// 아는 색 id인가 (기본·16색·계절 64색·지역 색)
  bool knows(String id) {
    if (id == defaultId) return true;
    if (id.startsWith(regionPaintPrefix)) return regionOf(id) != null;
    final dot = id.indexOf('.');
    if (dot < 0) return colorIds.contains(id);
    final season = paintSeason(id);
    return season != null && seasonHex.containsKey(season) && colorIds.contains(id.substring(dot + 1));
  }

  /// 화면 이름 (config paintColor.names): 기본 ‘기본’, 지역 색은 config 이름(‘수도권 단청 주홍’),
  /// 그 밖은 [계절] [진한] 이름 (‘가을 진한 노을’, 16장 11/15). 모르는 id는 그대로
  String nameOf(String id) {
    if (id == defaultId) return names['basic'] ?? id;
    if (id.startsWith(regionPaintPrefix)) return regionOf(id)?.name ?? id;
    final base = paintBase(id);
    if (base == null) return id;
    final name = names[base.phase?.name ?? base.weather!.name] ?? id;
    final season = paintSeason(id);
    return [
      if (season != null) ?seasonNames[season],
      if (base.run) ?names['runPrefix'],
      name,
    ].join(' ');
  }
}

/// 계절 [s]의 보관 키 (config season.stockKey `<season>.<colorId>`)
String seasonalId(Season s, String colorId) => '${s.name}.$colorId';

/// 보관 키의 계절 (`autumn.sunset` → autumn). 계절이 없거나 지역 색이면 null
Season? paintSeason(String id) {
  if (id.startsWith(regionPaintPrefix)) return null;
  final dot = id.indexOf('.');
  if (dot < 0) return null;
  final name = id.substring(0, dot);
  for (final s in Season.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// 색 id를 읽은 것: 시간대 색이면 [phase], 날씨 색이면 [weather], 뛰기 색이면 [run]
class PaintBase {
  const PaintBase({this.phase, this.weather, required this.run});

  final SkyPhase? phase;
  final PaintWeather? weather;
  final bool run;
}

/// 색 id(예 sunset·rain_run, 계절이 붙으면 autumn.sunset)를 읽는다. 기본·지역 색·모르는 id면 null
PaintBase? paintBase(String id) {
  final dot = id.lastIndexOf('.');
  if (id.startsWith('region.')) return null;
  var name = dot < 0 ? id : id.substring(dot + 1);
  final run = name.endsWith('_run');
  if (run) name = name.substring(0, name.length - 4);
  for (final p in SkyPhase.values) {
    if (p.name == name) return PaintBase(phase: p, run: run);
  }
  for (final w in PaintWeather.values) {
    if (w != PaintWeather.clear && w.name == name) return PaintBase(weather: w, run: run);
  }
  return null;
}

/// 그 순간 물감 색 id (M1 v0.7 colorOf): 날씨가 비·눈·흐림이면 날씨 색, 아니면(맑음·모름 = 오프라인) 시간대 색,
/// 뛰기면 뒤에 `_run`
String colorOf(SkyPhase phase, PaintWeather? weather, Gait gait) {
  final base = weather == null || weather == PaintWeather.clear ? phase.name : weather.name;
  return gait == Gait.run ? '${base}_run' : base;
}

/// [p] 지점·[utc] 시각의 시간대 (config paintColor.timePhase = scene.sky 키 구간): 하늘 섞임에서 더 가까운 단계
SkyPhase paintPhaseAt(LatLng p, DateTime utc, Rules rules) =>
    skyMixAt(utc, sunTimes(p, kstDayKey(utc), rules.sunZenithDeg), rules).dominant;

/// [p](정령이 있는 지도 위 여정 지점)·[utc]의 그 순간 물감 색 id. 날씨 [weather]가 null이면 시간대 색.
/// 계절 변주를 하면 앞에 그날(한국 날짜)의 계절이 붙는다 (예 autumn.sunset_run, 16장 11/15)
String momentColorAt(LatLng p, DateTime utc, PaintWeather? weather, Gait gait, Rules rules) {
  final id = colorOf(paintPhaseAt(p, utc, rules), weather, gait);
  return rules.paintColor.seasonal ? seasonalId(seasonOf(kstDayKey(utc), rules), id) : id;
}

/// [p] 둘레의 지역 색 (가장 가까운 명소의 권역, config region.by nearestLandmarkRegion). 권역 색이 없으면 null
RegionPaint? regionPaintAt(LatLng p, List<Landmark> landmarks, Rules rules) {
  if (landmarks.isEmpty || rules.paintColor.regions.isEmpty) return null;
  return rules.paintColor.regions[nearestLandmark(p, landmarks, rules.earthRadiusKm).region];
}

/// 물감 길 [trailId]의 [dropNo]번째 방울의 보상. 보상 표를 차례로 쌓아 한 수로 고르고(많아야 하나),
/// 물감 통이면 양과 지역 색인가(config region.chancePerTube)를 따로 고른다
DropRoll rollDrop(int trailId, int dropNo, PaintColorRules rules,
    {PaintRandom random = seededPaintRandom}) {
  final u = random(trailId, dropNo, 'reward');
  var acc = 0.0;
  for (final r in rules.rewards) {
    acc += r.chance;
    if (u >= acc) continue;
    switch (r) {
      case TubeReward():
        final a = random(trailId, dropNo, 'amount');
        final span = r.maxM - r.minM + 1;
        final region = rules.regionChancePerTube > 0 &&
            random(trailId, dropNo, 'region') < rules.regionChancePerTube;
        return DropRoll(r, amountM: r.minM + math.min(span - 1, (a * span).floor()), region: region);
    }
  }
  return const DropRoll(null);
}

/// 고른 물감으로 [deltaM]을 칠한 결과 ([paintSplit])
class PaintSplit {
  const PaintSplit({required this.usedM, required this.basicM, required this.leftM});

  /// 고른 색으로 칠한 거리(m) = 줄어든 양
  final double usedM;

  /// 고른 색이 떨어진 뒤 기본 물감으로 칠한 거리(m)
  final double basicM;

  /// 칠한 뒤 고른 색의 남은 양(m)
  final double leftM;

  /// 이번에 고른 색을 다 썼는가 (여기서 구간이 나뉜다)
  bool get ranOut => leftM <= 0 && usedM > 0;
}

/// 남은 [remainM] m인 고른 색으로 물감 길 [deltaM] m를 칠한다 (M1 v0.7 칠하기). 0이 되는 지점에서 나뉘고
/// 나머지는 기본 물감이다. 기본 물감(무제한)이면 [remainM]에 double.infinity를 넣는다
PaintSplit paintSplit(double remainM, double deltaM) {
  final d = deltaM > 0 ? deltaM : 0.0;
  final have = remainM > 0 ? remainM : 0.0;
  final used = math.min(have, d);
  return PaintSplit(usedM: used, basicM: d - used, leftM: have - used);
}

/// 가진 통 [amounts](주운 차례)를 처음부터 [usedM]만큼 썼을 때 아직 남은(다 안 쓴) 통 수
int tubesLeft(List<double> amounts, double usedM) {
  var acc = 0.0;
  var left = 0;
  for (final a in amounts) {
    acc += a;
    if (acc > usedM + 1e-6) left++;
  }
  return left;
}

/// 뛰기 색 계산식 (config paintColor.intensity.run: 밝기를 darken 비율만큼 줄이고 채도를 saturate만큼 더함).
/// 디자인 기획 11/15 hex(뛰기 따로)가 config에 오면 쓰지 않는다
int _runOf(int walk, double darken, double saturate) {
  final c = hslOfArgb(walk);
  return argbOfHsl(c.h, (c.s + saturate).clamp(0.0, 1.0), (c.l * (1 - darken)).clamp(0.0, 1.0));
}

int _hex(Object? v, String where) {
  if (v is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v)) {
    throw FormatException('$where는 "#RRGGBB"여야 한다: $v');
  }
  return argbFromHex(v);
}

double _d(dynamic v) => (v as num).toDouble();

/// 물감 길 하나의 색 구간 하나: [fromMs](epoch ms)부터 [colorId]로 칠했다 (DB PaintTrailColors, 스키마 20)
class PaintSegment {
  const PaintSegment(this.fromMs, this.colorId);

  final int fromMs;
  final String colorId;
}

/// 물감 길 하나에 칠한 색 (시각은 epoch ms). [endMs]가 null이면 열려 있다. [segments]는 fromMs 순 색 구간이고
/// 비어 있으면 기본 물감 (스키마 18 전 물감 길). 걷는 중에도 배낭에서 바꿀 수 있어 구간이 여럿이다 (16장 11/16)
class TrailPaint {
  const TrailPaint({required this.startMs, this.endMs, this.segments = const []});

  final int startMs;
  final int? endMs;
  final List<PaintSegment> segments;

  /// [ms]에 칠한 색. 첫 구간 앞이거나 구간이 없으면 null (기본 물감)
  String? colorAt(int ms) {
    String? color;
    for (final seg in segments) {
      if (seg.fromMs > ms) break;
      color = seg.colorId;
    }
    return color;
  }
}

/// [ms](분 시작 시각)에 칠한 물감 색 id (M1 v0.7 구간 색). 그 시각이 든 물감 길의 그 시각 구간 색,
/// 물감 길 밖이면 기본 물감 [defaultId]. [trails]는 시작 순이고 겹치지 않는다 (물감 길은 하나씩 열린다):
/// [ms] 이하에서 시작한 마지막 물감 길을 이분 탐색으로 본다
String paintedColorAt(List<TrailPaint> trails, int ms, String defaultId) {
  var lo = 0;
  var hi = trails.length - 1;
  var at = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (trails[mid].startMs <= ms) {
      at = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (at < 0) return defaultId;
  final t = trails[at];
  final end = t.endMs;
  if (end != null && ms >= end) return defaultId;
  // 열 때 첫 구간을 적기 전(첫 분이 시작 시각보다 앞인 때)은 첫 구간 색
  return t.colorAt(ms) ?? (t.segments.isEmpty ? defaultId : t.segments.first.colorId);
}
