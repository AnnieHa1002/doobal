import 'dart:convert';
import 'dart:math' as math;

import 'color.dart';
import 'gait.dart';
import 'geo.dart';
import 'rules.dart';
import 'sky.dart';
import 'sun.dart';
import 'time_kst.dart';

// 물감 색과 물감 모으기 (16장 11/14, M1 명세 v0.7, config paintColor).
// - 그 순간 물감 색 = 시간대 5 + 날씨 3(맑음이면 시간대 색) × 강도(뛰면 진하게) = 16색 ([colorOf]).
//   방울에 곱하는 색이고, 물감 통이 나오면 그 통의 색이다.
// - 물감 방울(paintDrop.spacingM마다)마다 보상 표([PaintColorRules.rewards])를 굴린다. MVP는 물감 통 하나뿐이고
//   (럭 +1은 방울마다 따로, M1 v0.5 ③), 무작위는 물감 길 번호·방울 번호로 정해서 다시 계산해도 같다 ([rollDrop]).
// - 물감 길은 쉼터 배낭에서 고른 색을 다 쓸 때까지 칠하고, 다 쓰면 그 자리에서 나머지는 기본 물감 ([paintSplit]).
// 계절 변주·지역 색(16장 11/15)은 개발 기획의 config가 오면 [PaintColorRules]에 끼운다: 색 id 앞에 `<계절>.`이
// 붙거나 `region.<id>`가 되고, 화면은 [paintBase]로 시간대·날씨·뛰기를 읽는다

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
  const DropRoll(this.reward, {this.amountM = 0});

  final DropReward? reward;

  /// 물감 통이면 그 양(m)
  final int amountM;

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

  /// 걷는 중(물감 길이 열린 동안)에 고를 수 있는가 (config paintColor.choose.whileWalking, false)
  final bool chooseWhileWalking;

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
    final choose = j['choose'] as Map<String, dynamic>;
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
    );
  }

  /// 16색 id 전부 (시간대 5 새벽~밤 → 날씨 3 비·눈·흐림, 각각 걷기 → 뛰기). 배낭 탭이 이 차례로 늘어놓는다
  List<String> get colorIds => [
        for (final base in [...timePhase.keys.map((p) => p.name), ...weather.keys.map((w) => w.name)])
          for (final run in const [false, true]) run ? '${base}_run' : base,
      ];

  /// 색 id의 색 (불투명 ARGB). 기본·모르는 id는 기본 물감 색
  int hexOf(String id) {
    final base = paintBase(id);
    if (base == null) return defaultHex;
    final pair = base.phase != null ? timePhase[base.phase] : weather[base.weather];
    if (pair == null) return defaultHex;
    return base.run ? pair.run : pair.walk;
  }

  /// 아는 색 id인가 (기본 포함)
  bool knows(String id) => id == defaultId || colorIds.contains(id);
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

/// [p](정령이 있는 지도 위 여정 지점)·[utc]의 그 순간 물감 색 id. 날씨 [weather]가 null이면 시간대 색
String momentColorAt(LatLng p, DateTime utc, PaintWeather? weather, Gait gait, Rules rules) =>
    colorOf(paintPhaseAt(p, utc, rules), weather, gait);

/// 물감 길 [trailId]의 [dropNo]번째 방울의 보상. 보상 표를 차례로 쌓아 한 수로 고르고(많아야 하나),
/// 물감 통이면 양을 따로 고른다
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
        return DropRoll(r, amountM: r.minM + math.min(span - 1, (a * span).floor()));
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

/// 물감 길 하나에 칠한 색 (DB PaintTrails의 colorId·colorEndUtc, 시각은 epoch ms). [endMs]가 null이면 열려 있다
class TrailPaint {
  const TrailPaint({required this.startMs, this.endMs, this.colorId, this.colorEndMs});

  final int startMs;
  final int? endMs;

  /// 연 때 고른 물감. null이면 기본 물감 (스키마 18 전 물감 길)
  final String? colorId;

  /// 고른 물감을 다 쓴 시각 (그 뒤는 기본 물감)
  final int? colorEndMs;
}

/// [ms](분 시작 시각)에 칠한 물감 색 id (M1 v0.7 구간 색). 그 시각이 든 물감 길의 고른 색, 그 색을 다 쓴 뒤거나
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
  final colorEnd = t.colorEndMs;
  if (colorEnd != null && ms >= colorEnd) return defaultId;
  return t.colorId ?? defaultId;
}
