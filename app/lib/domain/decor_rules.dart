// 쉼터 꾸미기 규칙 (config rest.decor·coins.firstSketchGift·companions.finaleRoam, 16장 11/18 ③④·11/19, M2~M6 AB).
// 모르는 값이면 FormatException (코드가 그 동작을 모르는 채로 지나가지 않게)

import 'sky.dart' show SkyPhase;

/// 화면 끝으로 끌면 장면이 따라 밀린다 (config rest.decor.edgeScroll, 가안)
class DecorEdgeScroll {
  const DecorEdgeScroll({required this.edgePt, required this.ptPerSec});

  /// 화면 왼쪽·오른쪽 끝에서 이 안(pt)으로 끌면
  final double edgePt;

  /// 초당 이만큼(pt) 민다
  final double ptPerSec;
}

/// 등불·석등 밤 빛 (config rest.decor.nightLight, 반딧불 빛 RadialGradient 더하기를 물품 자리에서, 새 그림 없음)
class DecorNightLight {
  const DecorNightLight({
    required this.items,
    required this.radiusPt,
    required this.centerAlpha,
    required this.phases,
    this.colors = const [0xFFFFFFFF],
    this.additive = true,
  });

  /// 빛이 켜지는 물품 id
  final Set<String> items;

  /// 납품 README 반지름이 없을 때 반지름 (pt)
  final double radiusPt;

  /// 빛 가운데 불투명도 (가장자리 0)
  final double centerAlpha;

  /// 빛이 켜지는 하늘 때 (밤·새벽·노을, 낮에는 꺼짐)
  final Set<SkyPhase> phases;

  /// 빛 색 (가운데 → 바깥, 불투명 ARGB). 재사용하는 반딧불 빛(reuse 경로의 glow.colors)
  final List<int> colors;

  /// 더하기로 합성 (glow.blend plus)
  final bool additive;

  bool onAt(SkyPhase phase) => phases.contains(phase);
}

/// 쉼터 꾸미기 놓는 규칙 (config rest.decor)
class DecorRules {
  const DecorRules({
    required this.maxPlaced,
    required this.blocked,
    required this.flipButton,
    required this.edgeScroll,
    required this.tintSeason,
    required this.tintTime,
    required this.hungTapOpensBigView,
    required this.nightLight,
  });

  /// config에 rest.decor가 없으면 쉼터 꾸미기를 열지 않는다
  static const none = DecorRules(
    maxPlaced: 0,
    blocked: {},
    flipButton: false,
    edgeScroll: DecorEdgeScroll(edgePt: 0, ptPerSec: 0),
    tintSeason: false,
    tintTime: false,
    hungTapOpensBigView: false,
    nightLight: DecorNightLight(items: {}, radiusPt: 0, centerAlpha: 0, phases: {}),
  );

  /// 쉼터에 한 번에 놓는 물품 수 (가안 20, 성능)
  final int maxPlaced;

  /// 못 놓는 자리 id (camp_wide decor.blocked 중 이것만)
  final Set<String> blocked;

  /// 집은(고른) 물품 옆 좌우 뒤집기 버튼
  final bool flipButton;

  final DecorEdgeScroll edgeScroll;

  /// 물품에도 계절·시간대 보정
  final bool tintSeason;
  final bool tintTime;

  /// 걸린 그림을 누르면 크게 보기 (넘기기는 그 물품에 걸린 그림 안에서만)
  final bool hungTapOpensBigView;

  final DecorNightLight nightLight;

  bool get enabled => maxPlaced > 0;

  /// config 전체 [j]에서 rest.decor를 읽는다
  factory DecorRules.fromJson(Map<String, dynamic> j) {
    final d = (j['rest'] as Map<String, dynamic>?)?['decor'] as Map<String, dynamic>?;
    if (d == null) return none;
    String check(String key, Set<String> known) {
      final v = d[key];
      if (v is! String || !known.contains(v)) throw FormatException('모르는 rest.decor.$key: $v');
      return v;
    }

    // 지금 코드가 아는 동작만 (다른 값이면 그 동작을 새로 만들어야 한다)
    if (d['editMode'] != false) throw FormatException('rest.decor.editMode는 false만 안다: ${d['editMode']}');
    check('pick', {'longPress'});
    check('save', {'onDrop'});
    check('area', {'camp_wide.decor.groundBand'});
    check('order', {'lowerIsFront'});
    check('blockedFeedback', {'bounceBack'});
    check('remove', {'dragToDrawer'});
    check('coords', {'sceneRatio'});
    final tint = (d['tint'] as List? ?? const []).cast<String>();
    for (final t in tint) {
      if (t != 'season' && t != 'timePhase') throw FormatException('모르는 rest.decor.tint: $t');
    }
    final edge = d['edgeScroll'] as Map<String, dynamic>;
    final tap = d['hungPaintingTap'] as Map<String, dynamic>?;
    if (tap != null) {
      if (tap['opens'] != 'bigView') throw FormatException('모르는 hungPaintingTap.opens: ${tap['opens']}');
      if (tap['page'] != 'withinItem') throw FormatException('모르는 hungPaintingTap.page: ${tap['page']}');
    }
    final light = d['nightLight'] as Map<String, dynamic>;
    final glow = _path(j, light['reuse'] as String?);
    final phases = <SkyPhase>{
      for (final p in (light['phases'] as List).cast<String>())
        SkyPhase.values.firstWhere((s) => s.name == p,
            orElse: () => throw FormatException('모르는 nightLight.phases: $p')),
    };
    final maxPlaced = d['maxPlaced'] as int;
    if (maxPlaced < 1) throw FormatException('rest.decor.maxPlaced는 1 이상: $maxPlaced');
    return DecorRules(
      maxPlaced: maxPlaced,
      blocked: (d['blocked'] as List).cast<String>().toSet(),
      flipButton: d['flipButton'] as bool? ?? false,
      edgeScroll: DecorEdgeScroll(
        edgePt: (edge['edgePt'] as num).toDouble(),
        ptPerSec: (edge['ptPerSec'] as num).toDouble(),
      ),
      tintSeason: tint.contains('season'),
      tintTime: tint.contains('timePhase'),
      hungTapOpensBigView: tap != null,
      nightLight: DecorNightLight(
        items: (light['items'] as List).cast<String>().toSet(),
        radiusPt: (light['radiusPt'] as num).toDouble(),
        centerAlpha: (light['centerAlpha'] as num).toDouble(),
        phases: phases,
        colors: [
          for (final c in (glow?['colors'] as List?)?.cast<String>() ?? const ['#FFFFFF']) _argb(c),
        ],
        additive: (glow?['blend'] ?? 'plus') == 'plus',
      ),
    );
  }
}

/// config [j]에서 점으로 이은 경로 (effects.items.effect_05.glow). 없으면 null, 경로가 틀리면 FormatException
Map<String, dynamic>? _path(Map<String, dynamic> j, String? path) {
  if (path == null) return null;
  dynamic at = j;
  for (final key in path.split('.')) {
    if (at is! Map<String, dynamic> || !at.containsKey(key)) {
      throw FormatException('rest.decor.nightLight.reuse 경로가 없다: $path');
    }
    at = at[key];
  }
  return at as Map<String, dynamic>;
}

int _argb(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) throw FormatException('색은 #RRGGBB: $hex');
  return 0xFF000000 | int.parse(h, radix: 16);
}

/// 첫 그림 선물 (config coins.firstSketchGift): 첫 그림 도착 때 럭과 함께 [decorId]를 주고 [hangs] 그림을 건 채
/// 테마의 첫 자리(camp_wide decor.easelStart)에 놓는다. 없으면 null
class FirstSketchGift {
  const FirstSketchGift({required this.decorId, required this.hangs});

  final String decorId;

  /// 걸어 둘 그림 (sketch = 첫 그림)
  final String hangs;

  static FirstSketchGift? fromJson(Map<String, dynamic> j) {
    final g = (j['coins'] as Map<String, dynamic>?)?['firstSketchGift'] as Map<String, dynamic>?;
    if (g == null) return null;
    final place = g['placeAt'];
    if (place != 'camp_wide.decor.easelStart') throw FormatException('모르는 firstSketchGift.placeAt: $place');
    return FirstSketchGift(decorId: g['decor'] as String, hangs: g['hangs'] as String);
  }
}

/// 완결 동행 쉼터 돌아다니기 (config companions.finaleRoam, 16장 11/18 ④·11/19 ②, 가안)
class FinaleRoamRules {
  const FinaleRoamRules({
    required this.walkPtPerSec,
    required this.stopMinSec,
    required this.stopMaxSec,
    required this.sitChance,
    required this.bubbleSec,
    required this.noRepeat,
    required this.secondTapOpensCompanion,
  });

  /// 걷는 빠르기 (장면 pt/초)
  final double walkPtPerSec;

  /// 멈추는 시간 범위 (초)
  final double stopMinSec;
  final double stopMaxSec;

  /// 멈출 때 앉을 확률
  final double sitChance;

  /// 누르면 말풍선이 떠 있는 시간 (초)
  final double bubbleSec;

  /// 바로 앞 줄을 다시 고르지 않는다
  final bool noRepeat;

  /// 말풍선이 떠 있을 때 한 번 더 누르면 동행 화면
  final bool secondTapOpensCompanion;

  /// config 전체 [j]에서 companions.finaleRoam. 없으면 null (완결 동행이 쉼터에 오지 않는다)
  static FinaleRoamRules? fromJson(Map<String, dynamic> j) {
    final r = (j['companions'] as Map<String, dynamic>?)?['finaleRoam'] as Map<String, dynamic>?;
    if (r == null) return null;
    if (r['where'] != 'rest') throw FormatException('모르는 finaleRoam.where: ${r['where']}');
    if (r['when'] != 'chapter8Read') throw FormatException('모르는 finaleRoam.when: ${r['when']}');
    if (r['band'] != 'camp_wide.decor.groundBand') throw FormatException('모르는 finaleRoam.band: ${r['band']}');
    if (r['orderWithDecor'] != 'lowerIsFront') {
      throw FormatException('모르는 finaleRoam.orderWithDecor: ${r['orderWithDecor']}');
    }
    final stop = (r['stopSec'] as List).cast<num>();
    final tap = r['tap'] as Map<String, dynamic>;
    if (tap['first'] != 'bubble') throw FormatException('모르는 finaleRoam.tap.first: ${tap['first']}');
    if (tap['pick'] != 'random') throw FormatException('모르는 finaleRoam.tap.pick: ${tap['pick']}');
    final second = tap['secondTapWhileBubble'];
    if (second != null && second != 'companionScreen') {
      throw FormatException('모르는 finaleRoam.tap.secondTapWhileBubble: $second');
    }
    return FinaleRoamRules(
      walkPtPerSec: (r['walkPtPerSec'] as num).toDouble(),
      stopMinSec: stop[0].toDouble(),
      stopMaxSec: stop[1].toDouble(),
      sitChance: (r['sitChance'] as num).toDouble(),
      bubbleSec: (tap['bubbleSec'] as num).toDouble(),
      noRepeat: tap['noRepeat'] as bool? ?? false,
      secondTapOpensCompanion: second == 'companionScreen',
    );
  }
}

/// 쉼터 꾸미기 규칙 묶음 (Rules.decor)
class CampDecorRules {
  const CampDecorRules({this.place = DecorRules.none, this.firstSketchGift, this.finaleRoam});

  static const none = CampDecorRules();

  final DecorRules place;
  final FirstSketchGift? firstSketchGift;
  final FinaleRoamRules? finaleRoam;

  factory CampDecorRules.fromJson(Map<String, dynamic> j) => CampDecorRules(
        place: DecorRules.fromJson(j),
        firstSketchGift: FirstSketchGift.fromJson(j),
        finaleRoam: FinaleRoamRules.fromJson(j),
      );
}
