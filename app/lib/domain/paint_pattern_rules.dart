// 물감 길 무늬 규칙 (T17b, 16장 11/19 꾸밈 제안 세부·상점 무늬, 11/20 Codex 납품 뒤 결정 ②·오전 납품 디자인 결정 ①):
// config paintPattern(고르기·거리 보상·가진 것만·그림 없을 때)과 mapTrail.patterns(밤 윤곽·짧은 구간·굽이·바뀜 여백).
// 모양은 문자열 값이라 아는 값만 받고, 모르는 값이면 FormatException

class PaintPatternRules {
  const PaintPatternRules({
    required this.defaultId,
    required this.whileWalking,
    required this.autoSelectOnGain,
    required this.ownedOnly,
    required this.emptyRowDefaultOnly,
    required this.states,
    required this.allOwnedCoins,
    required this.walkingScreen,
    required this.nightOutlineColor,
    required this.nightOutlinePt,
    required this.shortUnderPt,
    required this.shortCaps,
    required this.shortGapPt,
    required this.curveChunkPx,
    required this.switchCaps,
    required this.switchGapPt,
  });

  /// [j]는 config.json 전체
  factory PaintPatternRules.fromJson(Map<String, dynamic> j) {
    final p = j['paintPattern'] as Map<String, dynamic>;
    final choose = p['choose'] as Map<String, dynamic>;
    final reward = p['reward'] as Map<String, dynamic>;
    final map = (j['mapTrail'] as Map<String, dynamic>)['patterns'] as Map<String, dynamic>;
    final night = map['night'] as Map<String, dynamic>;
    final short = map['shortSegment'] as Map<String, dynamic>;
    final curve = map['curve'] as Map<String, dynamic>;
    final change = map['switch'] as Map<String, dynamic>;

    void expect(Object? value, Object want, String key) {
      if (value != want) throw FormatException('$key: $want만 안다 ($value)');
    }

    expect(p['segmentKey'], 'patternId', 'paintPattern.segmentKey');
    expect(choose['where'], 'album.paints.topRow', 'paintPattern.choose.where');
    expect(choose['appliesFrom'], 'now', 'paintPattern.choose.appliesFrom');
    expect(reward['distanceBasis'], 'paintTrailActual', 'paintPattern.reward.distanceBasis');
    expect(reward['give'], 'firstMissingInOrder', 'paintPattern.reward.give');
    expect(p['missingArt'], 'drawAsDefault', 'paintPattern.missingArt');
    expect(night['when'], 'mapNight', 'mapTrail.patterns.night.when');
    expect(curve['rotate'], 'perChunk', 'mapTrail.patterns.curve.rotate');
    expect(map['from'], 'trails.json', 'mapTrail.patterns.from');
    // 셋 다 가졌을 때의 럭은 첫 선물처럼 하루 상한 밖(gift)만 안다
    expect(reward['allOwnedCoinsCountsTowardDailyCap'], false, 'paintPattern.reward.allOwnedCoinsCountsTowardDailyCap');
    final emptyRow = choose['emptyRow'];
    if (emptyRow != 'defaultOnly') throw FormatException('paintPattern.choose.emptyRow: 모르는 값 $emptyRow');
    final states = [for (final s in choose['states'] as List) s as String];
    for (final s in states) {
      if (s != 'pressed' && s != 'inUse') throw FormatException('paintPattern.choose.states: 모르는 상태 $s');
    }
    final shortCaps = short['caps'] as int;
    final switchCaps = change['caps'] as int;
    // 짧은 구간·바뀌는 곳 모두 끝 1개만 안다 (Q010 ③④)
    if (shortCaps != 1 || switchCaps != 1) {
      throw const FormatException('mapTrail.patterns: 짧은 구간·바뀌는 곳 끝은 1개만 안다');
    }
    return PaintPatternRules(
      defaultId: p['default'] as String,
      whileWalking: choose['whileWalking'] as bool,
      autoSelectOnGain: choose['autoSelectOnGain'] as bool,
      ownedOnly: choose['ownedOnly'] as bool,
      emptyRowDefaultOnly: true,
      states: List.unmodifiable(states),
      allOwnedCoins: reward['allOwnedCoins'] as int,
      walkingScreen: p['walkingScreen'] as bool,
      nightOutlineColor: _hex(night['outlineColor'] as String),
      nightOutlinePt: _d(night['outlinePt']),
      shortUnderPt: _d(short['underPt']),
      shortCaps: shortCaps,
      shortGapPt: _d(short['gapPt']),
      curveChunkPx: _d(curve['chunkPx']),
      switchCaps: switchCaps,
      switchGapPt: _d(change['gapPt']),
    );
  }

  /// 기본 무늬 id (trails.json default 방울). DB에는 null로 둔다
  final String defaultId;

  /// 걷는 중(물감 길이 열린 동안)에도 배낭에서 고르는가. 고르면 그 순간부터 새 구간
  final bool whileWalking;

  /// 새로 얻으면 저절로 고르는가 (false: 안 고름)
  final bool autoSelectOnGain;

  /// 배낭 무늬 줄은 가진 것만 (안 가진 칸·예시·잠긴 칸 없음)
  final bool ownedOnly;

  /// 무늬를 하나도 안 가졌으면 기본 방울 1칸만
  final bool emptyRowDefaultOnly;

  /// 칸 상태: pressed(누름)·inUse(쓰는 중)
  final List<String> states;

  /// 거리 보상 때 무늬를 셋 다 가졌으면 그 대신 주는 럭 (럭 장부 gift, 하루 상한 밖)
  final int allOwnedCoins;

  /// 걷는 중 화면에 무늬를 그리는가 (false: 지도·하루 카드만)
  final bool walkingScreen;

  /// 밤 지도: 무늬 아래에 같은 모양을 이 색으로 outlinePt 크게 먼저 깐다 (낮은 mapTrail.paint.border)
  final int nightOutlineColor;
  final double nightOutlinePt;

  /// 화면 길이 shortUnderPt 미만인 무늬 구간은 끝 1개만, 그 이상은 양끝 + 반복 무늬 앞뒤 여백 shortGapPt
  final double shortUnderPt;
  final int shortCaps;
  final double shortGapPt;

  /// 타일을 그림의 이 가로 px 묶음마다 그 자리 방향으로 돌린다
  final double curveChunkPx;

  /// 무늬가 바뀌는 곳: 앞 무늬 끝 1개 + 여백 switchGapPt 뒤 새 무늬 첫 도형
  final int switchCaps;
  final double switchGapPt;
}

int _hex(String s) {
  final v = int.parse(s.replaceFirst('#', ''), radix: 16);
  return s.length == 7 ? 0xFF000000 | v : v;
}

double _d(dynamic v) => (v as num).toDouble();
