// 쉼터 꾸밈 물품 자리 계산 (16장 11/18 ③·11/19, M2~M6 AB, config rest.decor·camp_wide decor·decor.json v2).
// 좌표는 쉼터 장면 pt (왼쪽 위 기준, 기준 화면 390×844, 장면 폭 585). 그리는 쪽·저장·시험이 함께 쓴다.
// - 발 자리 = 물품 그림의 바닥 기준점(groundAt)이 오는 곳. 땅 띠(groundBand) 안에만 둔다
// - 저장은 장면 비율: x ÷ 장면 폭, 발 y는 띠 안 비율 (테마·화면 크기가 바뀌어도 그대로)
// - 앞뒤는 발 y가 큰 것이 앞 (같으면 놓은 순서)
// - 못 놓는 자리(정령·모닥불·수레 상자)에 물품 상자가 겹치면 놓을 수 없다 (튕겨 원래 자리로)
// - 좌우 뒤집기: 캔버스 x → W − x, 칸 x → W − x − w (README)

import 'dart:math' as math;

import 'camp_theme.dart';
import 'decor.dart';
import 'decor_rules.dart';
import 'rules.dart';
import 'scene.dart';
import 'scene_color.dart';
import 'time_tint.dart';

/// 장면 위의 점 (pt)
class ScenePoint {
  const ScenePoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is ScenePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ScenePoint($x, $y)';
}

/// 장면 위의 상자 (pt)
class SceneRect {
  const SceneRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;

  bool contains(ScenePoint p) => p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  /// 넓이가 있게 겹치는가 (모서리만 닿으면 아니다)
  bool overlaps(CampBox b) =>
      left < b.x + b.w && right > b.x && top < b.y + b.h && bottom > b.y;

  @override
  String toString() => 'SceneRect($left, $top, $width, $height)';
}

/// 놓인 물품 하나 (장면 pt)
class DecorSpot {
  const DecorSpot({required this.decorId, required this.foot, this.flipped = false, this.placedUtc = 0});

  final String decorId;
  final ScenePoint foot;
  final bool flipped;

  /// 놓은 시각 (epoch ms). 발 y가 같으면 나중에 놓은 것이 앞
  final int placedUtc;

  DecorSpot copyWith({ScenePoint? foot, bool? flipped, int? placedUtc}) => DecorSpot(
        decorId: decorId,
        foot: foot ?? this.foot,
        flipped: flipped ?? this.flipped,
        placedUtc: placedUtc ?? this.placedUtc,
      );
}

/// 저장하는 비율 (DB decor_placed xRatio·yRatio)
typedef DecorRatio = ({double x, double y});

/// 물품 하나를 장면에 그릴 자리: 보이는 상자(누름 상자·자리표시), 캔버스 전체 그림 상자, 그림 칸, 빛
class DecorLayout {
  const DecorLayout({
    required this.box,
    required this.art,
    required this.slots,
    required this.hangs,
    this.lightAt,
    this.lightRadius,
  });

  /// 보이는 그림 상자 (투명 여백 뺀 크기, 발이 아래 가운데). 누름 상자·자리표시
  final SceneRect box;

  /// 캔버스 전체 그림 상자 (그림 파일을 이 상자에 그린다, 뒤집혔으면 그림만 좌우로 뒤집어 그린다)
  final SceneRect art;

  /// 그림 거는 칸 (decor.json 순서, 뒤집기 반영)
  final List<SceneRect> slots;

  /// 칸마다 그림 위 끝 가운데 (hangAt, 뒤집기 반영)
  final List<ScenePoint> hangs;

  /// 밤 불빛 가운데·반지름 (pt). 빛 없는 물품은 null
  final ScenePoint? lightAt;
  final double? lightRadius;
}

/// 쉼터 꾸미기 자리 계산. [ptPerPx]는 장면 pt ÷ 기준 화면 px (decor.json showPx·lightRadiusPx는 1170×2532 화면 px,
/// 기준 화면 높이 844pt ÷ config scene.screenHeightPx 2532 = 1/3)
class DecorStage {
  DecorStage({
    required this.decor,
    required this.rules,
    required this.sceneWidth,
    required this.spiritFootY,
    required this.ptPerPx,
  }) : blocked = [
          for (final b in decor.blocked)
            if (rules.blocked.contains(b.id)) b,
        ];

  /// 테마에서 만든다. 테마에 꾸미기 자리가 없으면 null
  static DecorStage? of(CampTheme theme, DecorRules rules, {required double screenHeightPx}) {
    final decor = theme.decor;
    if (decor == null || !rules.enabled || screenHeightPx <= 0) return null;
    return DecorStage(
      decor: decor,
      rules: rules,
      sceneWidth: theme.widthPt,
      spiritFootY: theme.character.footY,
      ptPerPx: theme.refH / screenHeightPx,
    );
  }

  final CampDecor decor;
  final DecorRules rules;

  /// 장면 폭 (pt, 585)
  final double sceneWidth;

  /// 정령 발 y. 발이 이보다 아래(크면)인 물품은 정령 앞에 그린다
  final double spiritFootY;

  final double ptPerPx;

  /// 지금 규칙이 막는 자리만
  final List<CampBlocked> blocked;

  CampGroundBand get band => decor.band;

  /// 첫 그림 이젤 첫 발 자리 (없으면 땅 띠 가운데)
  ScenePoint get easelStart => clampToBand(ScenePoint(
        decor.easelFootX ?? (band.xMin + band.xMax) / 2,
        decor.easelFootY ?? (band.footYMin + band.footYMax) / 2,
      ));

  // 비율 ↔ pt

  DecorRatio toRatio(ScenePoint foot) {
    final h = band.footYMax - band.footYMin;
    return (x: foot.x / sceneWidth, y: h <= 0 ? 0 : (foot.y - band.footYMin) / h);
  }

  /// 저장한 비율 → 발 자리. 띠가 바뀌었어도 띠 안으로
  ScenePoint fromRatio(double xRatio, double yRatio) => clampToBand(ScenePoint(
        xRatio * sceneWidth,
        band.footYMin + yRatio.clamp(0.0, 1.0) * (band.footYMax - band.footYMin),
      ));

  ScenePoint clampToBand(ScenePoint p) => ScenePoint(
        p.x.clamp(band.xMin, band.xMax).toDouble(),
        p.y.clamp(band.footYMin, band.footYMax).toDouble(),
      );

  bool inBand(ScenePoint p) =>
      p.x >= band.xMin && p.x <= band.xMax && p.y >= band.footYMin && p.y <= band.footYMax;

  // 크기·자리

  /// 보이는 크기 (pt). decor.json에 크기가 없으면 null (그 물품은 놓지 않는다)
  ({double w, double h})? shownSize(DecorItem item) {
    final show = item.showPx;
    if (show == null || item.groundAt == null) return null;
    return (w: show.w * ptPerPx, h: show.h * ptPerPx);
  }

  bool canPlace(DecorItem item) => shownSize(item) != null;

  /// 보이는 상자: 발이 아래 가운데 (README 그림 상자는 바닥점 x를 가운데로 둔다)
  SceneRect boxAt(DecorItem item, ScenePoint foot) {
    final s = shownSize(item)!;
    return SceneRect(foot.x - s.w / 2, foot.y - s.h, s.w, s.h);
  }

  /// [foot]에 [flipped]로 둔 물품의 그릴 자리
  DecorLayout layout(DecorItem item, ScenePoint foot, {bool flipped = false}) {
    final box = boxAt(item, foot);
    final canvas = item.canvasPx;
    final ground = item.groundAt!;
    final perPx = item.pxPerCanvasPx;
    if (canvas == null || perPx == null) {
      return DecorLayout(box: box, art: box, slots: const [], hangs: const []);
    }
    // 캔버스 px → 장면 pt
    final k = perPx * ptPerPx;
    double fx(double x) => flipped ? canvas.w - x : x;
    final left = foot.x - fx(ground.x) * k;
    final top = foot.y - ground.y * k;
    final art = SceneRect(left, top, canvas.w * k, canvas.h * k);
    final slots = [
      for (final s in item.slotsAt)
        SceneRect(left + (flipped ? canvas.w - s.x - s.w : s.x) * k, top + s.y * k, s.w * k, s.h * k),
    ];
    final hangs = [
      for (final s in item.slotsAt) ScenePoint(left + fx(s.hangAt.x) * k, top + s.hangAt.y * k),
    ];
    final light = item.light;
    final lit = light != null || rules.nightLight.items.contains(item.id);
    return DecorLayout(
      box: box,
      art: art,
      slots: slots,
      hangs: hangs,
      lightAt: !lit
          ? null
          : light == null
              ? ScenePoint(box.centerX, box.top + box.height / 2)
              : ScenePoint(left + fx(light.at.x) * k, top + light.at.y * k),
      lightRadius: !lit ? null : (light == null ? rules.nightLight.radiusPt : light.radiusPx * ptPerPx),
    );
  }

  // 못 놓는 자리

  /// [item]을 [foot]에 두면 못 놓는 자리에 걸리는가 (그 자리 id, 아니면 null). 띠 밖도 못 놓는다 ('band')
  String? blockedAt(DecorItem item, ScenePoint foot) {
    if (!inBand(foot)) return 'band';
    return blockedBy(boxAt(item, foot));
  }

  /// [box]가 겹치는 못 놓는 자리 id. 없으면 null
  String? blockedBy(SceneRect box) {
    for (final b in blocked) {
      if (box.overlaps(b.box)) return b.id;
    }
    return null;
  }

  /// [want] 둘레에서 놓을 수 있는 가장 가까운 발 자리 (서랍에서 누르면 화면 가운데에, 캔버스 2-2).
  /// 같은 높이에서 오른쪽 → 왼쪽으로 조금씩 넓혀 보고, 안 되면 띠의 다른 높이. 모두 막히면 null
  ScenePoint? freeSpotNear(DecorItem item, ScenePoint want) {
    if (!canPlace(item)) return null;
    final start = clampToBand(want);
    final step = math.max(4.0, shownSize(item)!.w / 4);
    final ys = <double>{
      start.y,
      (band.footYMin + band.footYMax) / 2,
      band.footYMax,
      band.footYMin,
    };
    final reach = band.xMax - band.xMin;
    for (final y in ys) {
      for (var d = 0.0; d <= reach; d += step) {
        for (final x in d == 0 ? [start.x] : [start.x + d, start.x - d]) {
          if (x < band.xMin || x > band.xMax) continue;
          final p = ScenePoint(x, y);
          if (blockedAt(item, p) == null) return p;
        }
      }
    }
    return null;
  }

  /// 그리는 순서 (뒤 → 앞): 발 y가 작은 것부터, 같으면 먼저 놓은 것부터, 그다음 id
  List<DecorSpot> drawOrder(Iterable<DecorSpot> spots) => spots.toList()
    ..sort((a, b) {
      final y = a.foot.y.compareTo(b.foot.y);
      if (y != 0) return y;
      final t = a.placedUtc.compareTo(b.placedUtc);
      return t != 0 ? t : a.decorId.compareTo(b.decorId);
    });

  /// 정령 앞에 그리는가 (발 y가 정령 발보다 아래)
  bool frontOfSpirit(ScenePoint foot) => foot.y > spiritFootY;

  /// 끄는 손가락이 화면 끝 [edgePt] 안이면 장면을 밀 속도 (화면 pt/초, 장면 왼쪽 끝 x의 변화).
  /// 오른쪽 끝이면 음수(장면을 왼쪽으로 = 오른쪽을 보러), 왼쪽 끝이면 양수
  double edgeScrollSpeed(double fingerX, double screenWidth) {
    final e = rules.edgeScroll;
    if (e.edgePt <= 0 || e.ptPerSec <= 0) return 0;
    if (fingerX >= screenWidth - e.edgePt) return -e.ptPerSec;
    if (fingerX <= e.edgePt) return e.ptPerSec;
    return 0;
  }
}

/// 이번에 새로 얻는 보상·선물 물품 (동기화 끝 소품 해금 자리, 16장 11/19).
/// - landmarksVisited: 도착한 서로 다른 명소 수 [visitedLandmarks] ≥ n (내 동네 스케치 빼고, 재방문은 안 셈)
/// - gift firstSketchArrival: 첫 그림을 가졌으면 (이미 받았으면 다시 안 줌)
/// 상점 물품은 사야 얻는다. [owned]는 이미 가진 것. decor.json 순서
List<DecorItem> decorToUnlock(
  DecorCatalog catalog, {
  required Set<String> owned,
  required int visitedLandmarks,
  required bool sketchArrived,
}) => [
      for (final i in catalog.items)
        if (!owned.contains(i.id))
          if (switch (i.kind) {
            DecorUnlockKind.landmarksVisited => visitedLandmarks >= (i.landmarks ?? 1 << 30),
            DecorUnlockKind.gift => i.giftOn == 'firstSketchArrival' && sketchArrived,
            DecorUnlockKind.shop => false,
          })
            i,
    ];

/// 꾸밈 물품에 입힐 색 행렬 (config rest.decor.tint: 계절 → 시간대). 계절 보정은 scene.seasonTint 값을 레이어와
/// 상관없이 입힌다 (물품은 그 표의 레이어가 아니라서 rest.decor.tint가 정한다). 입힐 것이 없으면 null
List<double>? decorTintMatrix(SceneLook look, Rules rules) {
  final decor = rules.decor.place;
  final season = decor.tintSeason ? rules.seasonTint[look.season.name] : null;
  final time = decor.tintTime ? tintFactorAt(look.mix, rules, character: false) : 0xFFFFFFFF;
  return chainAll([
    if (season != null) ...[
      if (season.saturation != 0) saturationMatrix(season.saturation),
      if (season.brightness != 0) brightnessMatrix(season.brightness),
      multiplyMatrix(season.multiply, season.strength),
    ],
    if (time != 0xFFFFFFFF) factorMatrix(time),
  ]);
}
