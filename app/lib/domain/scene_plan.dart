import 'dart:math' as math;

// 걷는 중 길가 조각 배치 (scene.json pieces·layout). 같은 여정·같은 자리면 언제나 같은 그림이다.
// 그리는 쪽은 scene_art_painter.dart

/// 같은 여정·구간에서는 항상 같은 조각을 고른다. Dart hashCode에 의존하지 않는다.
int sceneArtHash(String seed, int segment) {
  var h = 2166136261;
  for (final c in '$seed:$segment'.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7fffffff;
  }
  return h;
}

/// 조각이 서는 줄: 군락 L2, 길가 뒷줄·앞줄 L3
enum SceneRow { grove, back, front }

/// 조각 하나 (scene.json pieces)
class ScenePiece {
  const ScenePiece({
    required this.id,
    required this.file,
    required this.tags,
    required this.tall,
    this.big = false,
    this.seasons = const [],
    this.frontOnly = false,
    this.heightPx,
  });

  final String id;
  final String file;
  final List<String> tags;

  /// 세로로 길어 정령 뒤를 지날 때 흐려지는 조각
  final bool tall;
  final bool big;

  /// 있는 계절 (군락은 빈 목록 = 늘)
  final List<String> seasons;

  /// 앞줄에만 선다 (전봇대)
  final bool frontOnly;

  /// 군락의 화면 높이 (그림 px)
  final double? heightPx;

  factory ScenePiece.fromJson(Map<String, dynamic> j) => ScenePiece(
        id: j['id'] as String,
        file: j['file'] as String,
        tags: (j['tags'] as List).cast<String>(),
        tall: j['tall'] as bool? ?? false,
        big: j['size'] == 'big',
        seasons: (j['seasons'] as List?)?.cast<String>() ?? const [],
        frontOnly: j['row'] == 'front',
        heightPx: (j['heightPx'] as num?)?.toDouble(),
      );
}

/// 줄에 놓인 조각. [x]는 세상 x, [height]는 화면 높이 (모두 그림 px)
class PlacedPiece {
  const PlacedPiece(this.piece, this.x, this.height);

  final ScenePiece piece;
  final double x;
  final double height;
}

/// 줄 하나의 규칙 (scene.json layout)
class SceneRowSpec {
  const SceneRowSpec({
    required this.speed,
    required this.feetY,
    required this.slots,
    required this.jitterPx,
    this.haze = 0,
  });

  final double speed;
  final double feetY;

  /// 주기 하나에 놓는 칸 수
  final int slots;

  /// 칸 안에서 움직이는 폭
  final double jitterPx;

  /// 앱이 얹는 안개
  final double haze;
}

/// scene.json의 pieces·layout
class ScenePlan {
  ScenePlan({
    required this.cycle,
    required this.grovePieces,
    required this.roadsidePieces,
    required this.grove,
    required this.front,
    required this.back,
    required this.bigHeight,
    required this.smallHeight,
    required this.backScale,
    required this.tallClearX,
    required this.tallNearOpacity,
    required this.tallFadePx,
    required this.regionTags,
  });

  /// 줄이 되풀이되는 폭 (그림 px)
  final double cycle;
  final List<ScenePiece> grovePieces;
  final List<ScenePiece> roadsidePieces;
  final SceneRowSpec grove;
  final SceneRowSpec front;
  final SceneRowSpec back;

  /// 앞줄 큰 조각·작은 조각의 높이 범위
  final List<double> bigHeight;
  final List<double> smallHeight;

  /// 뒷줄은 앞줄 높이의 이 비율
  final List<double> backScale;

  /// 키 큰 조각이 흐려지는 정령 중심 ± 폭 (기준 화면 px)
  final double tallClearX;
  final double tallNearOpacity;

  /// 흐려지기 시작하는 곳까지의 폭 (기준 화면 px)
  final double tallFadePx;

  /// 지역 → 태그
  final Map<String, List<String>> regionTags;

  SceneRowSpec spec(SceneRow row) => switch (row) {
        SceneRow.grove => grove,
        SceneRow.back => back,
        SceneRow.front => front,
      };

  /// 이 지역·계절에 설 수 있는 조각. 태그가 하나라도 겹치거나 공용(태그 없음)이고, 그 계절에 있는 것만
  List<ScenePiece> eligible(SceneRow row, String region, String season) {
    final tags = regionTags[region] ?? const <String>[];
    bool tagged(ScenePiece p) => p.tags.isEmpty || p.tags.any(tags.contains);
    return switch (row) {
      SceneRow.grove => [
          for (final p in grovePieces)
            if (p.tags.any(tags.contains)) p,
        ],
      SceneRow.front => [
          for (final p in roadsidePieces)
            if (tagged(p) && p.seasons.contains(season)) p,
        ],
      SceneRow.back => [
          for (final p in roadsidePieces)
            if (p.big && !p.frontOnly && tagged(p) && p.seasons.contains(season)) p,
        ],
    };
  }

  /// 주기 [cycleIndex]에 놓이는 조각. 시드·지역·계절·줄·주기가 같으면 늘 같다
  List<PlacedPiece> place(
    SceneRow row, {
    required String seed,
    required String region,
    required String season,
    required int cycleIndex,
  }) {
    final pool = eligible(row, region, season);
    if (pool.isEmpty) return const [];
    final rowSpec = spec(row);
    final slotWidth = cycle / rowSpec.slots;
    final placed = <PlacedPiece>[];
    ScenePiece? previous;
    for (var slot = 0; slot < rowSpec.slots; slot++) {
      final h = sceneArtHash('$seed:$region:$season:${row.name}:$cycleIndex', slot);
      var piece = pool[(h >> 3) % pool.length];
      // 같은 조각이 잇달아 서지 않게
      if (identical(piece, previous) && pool.length > 1) {
        piece = pool[((h >> 3) + 1) % pool.length];
      }
      previous = piece;
      final jitter = rowSpec.jitterPx <= 0 ? 0 : (h >> 7) % rowSpec.jitterPx.round();
      placed.add(PlacedPiece(
        piece,
        (cycleIndex * cycle) + slot * slotWidth + jitter,
        _height(row, piece, h),
      ));
    }
    return placed;
  }

  double _height(SceneRow row, ScenePiece piece, int hash) {
    double between(List<double> range, int salt) =>
        range[0] + (range[1] - range[0]) * (((hash >> salt) & 0xff) / 255);
    return switch (row) {
      SceneRow.grove => piece.heightPx ?? smallHeight[0],
      SceneRow.front => between(piece.big ? bigHeight : smallHeight, 11),
      SceneRow.back => between(bigHeight, 11) * between(backScale, 19),
    };
  }

  /// 키 큰 조각의 불투명도. 왼쪽·오른쪽 끝이 [left]·[right]인 조각이 중심 [center] ± [clear] 안이면
  /// [near], [fade]만큼 떨어진 곳에서 1로 부드럽게 올라간다
  static double tallOpacity({
    required double left,
    required double right,
    required double center,
    required double clear,
    required double near,
    required double fade,
  }) {
    final gap = math.max(left - (center + clear), (center - clear) - right);
    if (gap <= 0) return near;
    if (fade <= 0 || gap >= fade) return 1;
    return near + (1 - near) * (gap / fade);
  }

  factory ScenePlan.fromJson(Map<String, dynamic> scene) {
    final pieces = scene['pieces'] as Map<String, dynamic>;
    final layout = scene['layout'] as Map<String, dynamic>;
    final grove = layout['grove'] as Map<String, dynamic>;
    final roadside = layout['roadside'] as Map<String, dynamic>;
    final front = roadside['front'] as Map<String, dynamic>;
    final back = roadside['back'] as Map<String, dynamic>;
    final cycle = _d(layout['cycleWidthPx']);
    final slots = grove['slotsPerCycle'] as int;
    final backdrops = scene['backdrops'] as Map<String, dynamic>;
    return ScenePlan(
      cycle: cycle,
      grovePieces: [
        for (final p in pieces['grove'] as List) ScenePiece.fromJson(p as Map<String, dynamic>),
      ],
      roadsidePieces: [
        for (final p in pieces['roadside'] as List) ScenePiece.fromJson(p as Map<String, dynamic>),
      ],
      grove: SceneRowSpec(
        speed: _d(grove['speed']),
        feetY: _d(grove['feetY']),
        slots: slots,
        // 칸 폭에서 뺀 만큼만 움직이면 이웃과 gapMinPx 이상 떨어진다
        jitterPx: math.max(0, cycle / slots - _d(grove['gapMinPx'])),
      ),
      front: SceneRowSpec(
        speed: _d(front['speed']),
        feetY: _d(front['feetY']),
        slots: front['slotsPerCycle'] as int,
        jitterPx: _d(front['jitterPx']),
      ),
      back: SceneRowSpec(
        speed: _d(back['speed']),
        feetY: _d(back['feetY']),
        slots: back['slotsPerCycle'] as int,
        jitterPx: _d(back['jitterPx']),
        haze: _d(back['haze']),
      ),
      bigHeight: _pair(front['bigHeightPx']),
      smallHeight: _pair(front['smallHeightPx']),
      backScale: _pair(back['scaleOfFront']),
      tallClearX: _d(roadside['tallObjectClearX']),
      tallNearOpacity: _d(roadside['tallNearCharacterOpacity']),
      tallFadePx: _d(roadside['tallFadePx']),
      regionTags: {
        for (final e in backdrops.entries)
          e.key: ((e.value as Map)['tags'] as List).cast<String>(),
      },
    );
  }
}

double _d(dynamic v) => (v as num).toDouble();

List<double> _pair(dynamic v) => [for (final n in v as List) _d(n)];
