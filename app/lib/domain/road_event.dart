import 'dart:convert';

import 'format_int.dart';

// 길 위 이벤트 (M4 명세, events.json v3): 앱이 켜진 동안 걸은 2km마다 이정표 카드 2줄.
// ① 기록 칭찬 ② 풍경 한 줄. 버튼·판정은 없고, 한 번 만든 줄은 다시 계산하지 않는다

/// 장면(지형 × 계절 × 낮밤) 하나의 풍경 문구 묶음
class EventScene {
  const EventScene({
    required this.id,
    required this.terrain,
    required this.season,
    required this.night,
    required this.texts,
  });

  final String id;
  final String terrain;
  final String season;
  final bool night;

  /// 문구 id → 문구 (파일 순서)
  final Map<String, String> texts;

  factory EventScene.fromJson(Map<String, dynamic> j) => EventScene(
        id: j['id'] as String,
        terrain: j['terrain'] as String,
        season: j['season'] as String,
        night: switch (j['dayNight']) {
          'day' => false,
          'night' => true,
          final v => throw FormatException('모르는 낮밤: $v (${j['id']})'),
        },
        texts: {
          for (final t in j['texts'] as List)
            (t as Map<String, dynamic>)['id'] as String: t['text'] as String,
        },
      );
}

/// 조건이 붙은 칭찬 한 줄. [value]는 조건의 기준값이고 없는 조건도 있다
class PraiseRule {
  const PraiseRule({required this.id, required this.cond, required this.text, this.value});

  final String id;
  final String cond;
  final String text;
  final Object? value;
}

/// events.json 전체
class EventCatalog {
  const EventCatalog({required this.scenes, required this.rules, required this.defaults});

  final List<EventScene> scenes;

  /// priority 순서
  final List<PraiseRule> rules;

  /// 맞는 조건이 없을 때 쓰는 칭찬: 문구 id → 문구
  final Map<String, String> defaults;

  factory EventCatalog.fromJson(Map<String, dynamic> j) {
    final praise = j['praise'] as Map<String, dynamic>;
    final raw = (praise['conditional'] as List).cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
    final rules = [
      for (final r in raw)
        PraiseRule(
          id: r['id'] as String,
          cond: r['cond'] as String,
          text: r['text'] as String,
          value: r['value'],
        ),
    ];
    for (final r in rules) {
      if (!_conds.contains(r.cond)) throw FormatException('모르는 칭찬 조건: ${r.cond} (${r.id})');
    }
    return EventCatalog(
      scenes: [
        for (final s in j['scenes'] as List) EventScene.fromJson(s as Map<String, dynamic>),
      ],
      rules: rules,
      defaults: {
        for (final d in praise['default'] as List)
          (d as Map<String, dynamic>)['id'] as String: d['text'] as String,
      },
    );
  }

  /// 그 지형·계절·낮밤의 장면. 없으면 StateError (32개가 모두 있다, 테스트가 본다)
  EventScene scene(String terrain, String season, bool night) => scenes.firstWhere(
      (s) => s.terrain == terrain && s.season == season && s.night == night);
}

const _conds = {
  'remainingKmLte',
  'progressPctCross',
  'etaGainDaysGte',
  'todayOverAvg',
  'runKmGte',
  'todayStepsGte',
  'sessionKmGte',
  'isNight',
  'totalKmGte',
};

/// 이벤트가 생긴 순간의 기록. 칭찬 조건과 문구 빈칸이 읽는다.
/// '이번'은 걷는 중 화면에 들어온 뒤부터, '오늘'·평균·누적은 동기화 값 + 아직 안 들어온 센서 값
class PraiseFacts {
  const PraiseFacts({
    required this.dest,
    required this.remainingKm,
    required this.progressPct,
    required this.lastProgressPct,
    required this.etaGainDays,
    required this.todayOverAvgKm,
    required this.runKm,
    required this.todaySteps,
    required this.sessionKm,
    required this.totalKm,
    required this.night,
  });

  final String dest;
  final double remainingKm;

  /// 지금 진행률과 지난 이벤트 때의 진행률(%). 그 사이에 기준을 넘었는지 본다
  final double progressPct;
  final double lastProgressPct;

  /// 이 걸음으로 도착 예정일이 며칠 당겨졌는지 (없으면 0)
  final int etaGainDays;

  /// 최근 하루 평균보다 오늘 더 걸은 km (적게 걸었으면 0 이하)
  final double todayOverAvgKm;
  final double runKm;
  final int todaySteps;
  final double sessionKm;
  final double totalKm;
  final bool night;
}

bool _met(PraiseRule r, PraiseFacts f) => switch (r.cond) {
      'remainingKmLte' => f.remainingKm <= (r.value as num),
      'progressPctCross' => (r.value as List)
          .cast<num>()
          .any((p) => f.lastProgressPct < p && f.progressPct >= p),
      'etaGainDaysGte' => f.etaGainDays >= (r.value as num),
      'todayOverAvg' => f.todayOverAvgKm > 0,
      'runKmGte' => f.runKm >= (r.value as num),
      'todayStepsGte' => f.todaySteps >= (r.value as num),
      'sessionKmGte' => f.sessionKm >= (r.value as num),
      'isNight' => f.night,
      'totalKmGte' => f.totalKm >= (r.value as num),
      _ => false,
    };

/// 문구 빈칸 채우기: km는 소수 1자리, 걸음은 천 단위 쉼표
String fillPraise(String template, PraiseFacts f, {num? crossedPct}) => template
    .replaceAll('{dest}', f.dest)
    .replaceAll('{remainingKm}', f.remainingKm.toStringAsFixed(1))
    .replaceAll('{progressPct}', '${crossedPct ?? f.progressPct.floor()}')
    .replaceAll('{etaGainDays}', '${f.etaGainDays}')
    .replaceAll('{todayOverAvgKm}', f.todayOverAvgKm.toStringAsFixed(1))
    .replaceAll('{runKm}', f.runKm.toStringAsFixed(1))
    .replaceAll('{todaySteps}', formatInt(f.todaySteps))
    .replaceAll('{sessionKm}', f.sessionKm.toStringAsFixed(1))
    .replaceAll('{totalKm}', f.totalKm.toStringAsFixed(1));

/// 이벤트 한 칸의 내용. 한 번 만들면 그대로 저장한다 (같은 기록이면 같은 결과)
class RoadEventPick {
  const RoadEventPick({
    required this.sceneTextId,
    required this.sceneText,
    required this.praiseId,
    required this.praiseText,
  });

  final String sceneTextId;
  final String sceneText;
  final String praiseId;
  final String praiseText;
}

/// 시드 hash(installId, journeyId, k)로 고른다. 같은 묶음에서 직전 문구([lastSceneTextId]·
/// [lastPraiseId])는 뺀다. 칭찬은 맞는 조건 중 우선순위가 가장 높은 것, 없으면 기본 묶음
RoadEventPick pickRoadEvent({
  required EventCatalog catalog,
  required String installId,
  required int journeyId,
  required int k,
  required String terrain,
  required String season,
  required bool night,
  required PraiseFacts facts,
  String? lastSceneTextId,
  String? lastPraiseId,
}) {
  final scene = catalog.scene(terrain, season, night);
  final sceneId = _pick(scene.texts.keys.toList(), lastSceneTextId, installId, journeyId, k, 's');
  for (final r in catalog.rules) {
    if (!_met(r, facts)) continue;
    num? crossed;
    if (r.cond == 'progressPctCross') {
      crossed = (r.value as List).cast<num>().lastWhere((p) => facts.progressPct >= p);
    }
    return RoadEventPick(
      sceneTextId: sceneId,
      sceneText: scene.texts[sceneId]!,
      praiseId: r.id,
      praiseText: fillPraise(r.text, facts, crossedPct: crossed),
    );
  }
  final praiseId = _pick(catalog.defaults.keys.toList(), lastPraiseId, installId, journeyId, k, 'p');
  return RoadEventPick(
    sceneTextId: sceneId,
    sceneText: scene.texts[sceneId]!,
    praiseId: praiseId,
    praiseText: fillPraise(catalog.defaults[praiseId]!, facts),
  );
}

String _pick(List<String> ids, String? last, String install, int journey, int k, String salt) {
  final pool = ids.length > 1 ? [for (final id in ids) if (id != last) id] : ids;
  return pool[eventSeed('$install|$journey|$k|$salt') % pool.length];
}

/// FNV-1a 32비트. 기기·판이 달라도 같은 값이 나온다 (String.hashCode는 보장이 없다)
int eventSeed(String key) {
  var h = 0x811C9DC5;
  for (final b in utf8.encode(key)) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// [eventM]을 지나며 새로 열린 칸 번호 (1부터). 이미 만든 칸([doneK]까지)은 다시 만들지 않는다
List<int> newEventSlots({required double eventM, required double everyKm, required int doneK}) {
  if (everyKm <= 0) return const [];
  final reached = (eventM / (everyKm * 1000) + 1e-9).floor();
  return [for (var k = doneK + 1; k <= reached; k++) k];
}
