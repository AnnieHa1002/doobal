import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../domain/paint_color.dart';
import '../domain/rules.dart';
import '../domain/trail_pattern.dart';

/// 배낭 물감 탭의 물감 하나 (가진 색만, 기본 물감 포함)
class PaintStockView {
  const PaintStockView({
    required this.colorId,
    required this.tubes,
    required this.remainM,
    this.firstGotAt,
    this.lastGotAt,
    this.seen = true,
  });

  final String colorId;

  /// 아직 다 안 쓴 통 수. 기본 물감은 0
  final int tubes;

  /// 남은 거리(m). 기본 물감은 무한
  final double remainM;
  final DateTime? firstGotAt;
  final DateTime? lastGotAt;

  /// 새 색 표시를 이미 봤는가
  final bool seen;

  bool get basic => remainM == double.infinity;
}

/// 배낭 물감 탭 맨 위 무늬 줄의 칸 하나 (T17b, 가진 것만: 기본 방울 + 가진 무늬)
class PatternCellView {
  const PatternCellView({required this.pattern, this.seen = true});

  final TrailPattern pattern;

  /// 새 무늬 표시를 이미 봤는가 (기본 방울은 늘 봤다)
  final bool seen;

  String get id => pattern.id;
  bool get isDefault => pattern.kind == TrailUnlockKind.initial;
}

/// 배낭 물감 탭 한 번 읽은 것: 가진 색(기본 물감이 맨 앞)과 지금 칠할 물감, 최근에 고른(쓴) 색 차례,
/// 맨 위 무늬 줄(기본 방울 + 가진 무늬, trails.json 차례)과 지금 칠할 무늬
class PaintShelfData {
  const PaintShelfData({
    required this.colors,
    required this.current,
    this.recent = const [],
    this.patterns = const [],
    this.currentPattern,
  });

  final List<PaintStockView> colors;

  /// 지금 칠할 물감 id (고른 색이 남았으면 그 색, 아니면 기본 물감)
  final String current;

  /// 최근에 고른(쓴) 색 id, 최근 것부터 (기본 물감 빼고, 다 쓴 색도 들 수 있다). [PaintService.shelf] 참고
  final List<String> recent;

  /// 무늬 줄 칸 (무늬 목록이 없으면 비어 있다). 무늬를 하나도 안 가졌으면 기본 방울 1칸 (config emptyRow defaultOnly)
  final List<PatternCellView> patterns;

  /// 지금 칠할 무늬 id (기본 방울이면 그 id). 무늬 목록이 없으면 null
  final String? currentPattern;
}

/// 물감 보관·고르기·칠하기·물감 통 받기 (16장 11/14·11/15·11/16, M1 v0.7·v0.8, 스키마 18·20).
/// - 물감 길을 열 때 그때 칠할 물감을 그 물감 길의 첫 색 구간으로 적는다 ([beginTrail]). 걷는 중에도 배낭에서
///   바꾸면 그 순간부터 새 구간이고([choose]), 고른 색을 다 쓰면 그 순간부터 기본 물감 구간 (DB PaintTrailColors).
/// - 물감 길 거리가 늘 때마다([addPaint]) 지금 구간 색의 남은 양을 그만큼 줄이고, 새로 넘은 방울마다 보상 표를 굴려
///   물감 통이면 그 순간 색(계절 키)으로, 지역 색으로 나온 통이면 지금 권역의 지역 색으로 보관에 더한다
///   (방울 번호는 이정표와 같은 센서 물감 길 거리 기준).
/// - 무늬(T17b, 16장 11/19·11/20 ②)도 색처럼 구간마다 적는다 (PaintTrailColors.pattern_id, null = 기본 방울):
///   물감 길을 열 때 그때 고른 무늬, 걷는 중에 배낭 무늬 줄에서 바꾸면 그 순간부터 새 구간 ([choosePattern]).
///   이미 칠한 구간은 그때 무늬 그대로. 색만 바꾸거나 고른 색을 다 써도 무늬는 그대로 이어진다.
/// 거리는 한 번 넘기면 다시 계산하지 않는다 (길 위 이벤트와 같다). 방울 보상은 물감 길·방울 번호로 정하는
/// 무작위라 같은 방울을 다시 넘겨도 (PaintTubes 키) 한 번만 받고, 백업 복원 뒤에도 같다
class PaintService {
  PaintService(this.db, this.rules, {this.random = seededPaintRandom, this.trails});

  final AppDb db;
  final Rules rules;

  /// 방울 보상 무작위 (시험은 고정한 것을 넣는다)
  final PaintRandom random;

  /// 무늬 목록 (trails.json). 없으면 무늬를 고르지 못하고 모든 구간이 기본 방울이다
  final TrailCatalog? trails;

  PaintColorRules get _pc => rules.paintColor;

  /// 지금 칠할 물감 id: 고른 색이 있고 남았으면 그 색, 아니면 기본 물감
  Future<String> currentColor() async {
    final chosen = (await _profile())?.paintColorId;
    if (chosen == null || chosen == _pc.defaultId) return _pc.defaultId;
    final row = await _stock(chosen);
    return row != null && row.remainM > 0 ? chosen : _pc.defaultId;
  }

  /// 쓸 물감을 고른다 (배낭 물감 탭). 기본 물감 id면 기본으로. 가진 적 없거나 남은 게 없는 색이면 false.
  /// 물감 길 [openTrailId]가 열려 있으면 [now]부터 그 색으로 칠한다 (새 구간, 16장 11/16, 무늬는 그대로). 앞 구간에
  /// 칠한 만큼은 부르는 쪽(PaintTrailController)이 먼저 [addPaint]로 넘긴다
  Future<bool> choose(String colorId, {int? openTrailId, DateTime? now}) => db.transaction(() async {
        String? value;
        if (colorId != _pc.defaultId) {
          final row = await _stock(colorId);
          if (row == null || row.remainM <= 0) return false;
          value = colorId;
        }
        await db.into(db.profile).insertOnConflictUpdate(
            ProfileCompanion(id: const Value(1), paintColorId: Value(value)));
        if (openTrailId != null && now != null) {
          final trail = await _trail(openTrailId);
          if (trail != null && trail.endUtc == null) {
            final last = await _lastSegment(trail);
            await _segmentFrom(
                trail, now.toUtc().millisecondsSinceEpoch, value ?? _pc.defaultId, last.patternId);
          }
        }
        return true;
      });

  /// 지금 칠할 무늬 id (16장 11/19): 배낭에서 고른 무늬를 가졌으면 그 무늬, 아니면 null (기본 방울).
  /// 무늬 목록이 없거나 목록에 없는 id여도 null
  Future<String?> currentPattern() async {
    final chosen = (await _profile())?.paintPatternId;
    final catalog = trails;
    if (chosen == null || catalog == null || catalog.byId(chosen) == null) return null;
    if (chosen == catalog.defaultId) return null;
    return await _ownsPattern(chosen) ? chosen : null;
  }

  /// 칠할 무늬를 고른다 (배낭 물감 탭 맨 위 무늬 줄, 16장 11/19·11/20 ②: 누르면 그 순간부터 그대로, ‘선택 후 적용’
  /// 없음). 기본 방울 id면 기본으로(null). 안 가진 무늬·모르는 id면 false.
  /// 물감 길 [openTrailId]가 열려 있으면 [now]부터 그 무늬로 칠한다 (새 구간, 색은 그대로). 이미 칠한 구간은 그대로
  Future<bool> choosePattern(String patternId, {int? openTrailId, DateTime? now}) =>
      db.transaction(() async {
        final catalog = trails;
        if (catalog == null || catalog.byId(patternId) == null) return false;
        final value = patternId == catalog.defaultId ? null : patternId;
        if (value != null && !await _ownsPattern(value)) return false;
        await db.into(db.profile).insertOnConflictUpdate(
            ProfileCompanion(id: const Value(1), paintPatternId: Value(value)));
        if (openTrailId != null && now != null) {
          final trail = await _trail(openTrailId);
          if (trail != null && trail.endUtc == null) {
            final last = await _lastSegment(trail);
            await _segmentFrom(trail, now.toUtc().millisecondsSinceEpoch, last.colorId, value);
          }
        }
        return true;
      });

  /// 물감 길 [trailId]를 연 때: 그 물감 길의 첫 색 구간에 지금 칠할 물감과 무늬를 적는다 (이미 적혀 있으면 그대로)
  Future<void> beginTrail(int trailId) => db.transaction(() async {
        final trail = await _trail(trailId);
        if (trail == null || (await _segments(trailId)).isNotEmpty) return;
        await db.into(db.paintTrailColors).insert(PaintTrailColorRow(
            trailId: trailId,
            fromUtc: trail.startUtc,
            colorId: await currentColor(),
            patternId: await currentPattern()));
      });

  /// 물감 길 [trailId]가 지금 칠하는 무늬 (마지막 구간, 없으면 null = 기본 방울)
  Future<String?> trailPattern(int trailId) async => (await _segments(trailId)).lastOrNull?.patternId;

  /// 물감 길 [trail]의 마지막 구간 색·무늬. 아직 구간이 없으면 지금 칠할 물감·무늬 (열 때 적기 전)
  Future<({String colorId, String? patternId})> _lastSegment(PaintTrailRow trail) async {
    final last = (await _segments(trail.id)).lastOrNull;
    if (last != null) return (colorId: last.colorId, patternId: last.patternId);
    return (colorId: await currentColor(), patternId: await currentPattern());
  }

  /// 기본 방울은 늘 가졌고, 그 밖은 PatternsOwned 줄이 있으면 가졌다
  Future<bool> _ownsPattern(String id) async =>
      id == trails?.defaultId ||
      await (db.select(db.patternsOwned)..where((t) => t.patternId.equals(id))).getSingleOrNull() != null;

  /// 물감 길 [trailId]가 지금 칠하는 색 (마지막 구간, 없으면 기본 물감)
  Future<String> trailColor(int trailId) async {
    final segs = await _segments(trailId);
    return segs.isEmpty ? _pc.defaultId : segs.last.colorId;
  }

  /// 물감 길 [trailId]의 거리가 [fromM]에서 [toM]으로 늘었다 (이정표에 넘기는 것과 같은 센서 물감 길 거리, m).
  /// 1) 지금 구간 색의 남은 양을 늘어난 만큼 줄인다. 다 쓰면 [now]부터 기본 물감 구간 (프로필의 고른 물감은 비운다,
  ///    걷는 중 알림 없음, 같은 색 통을 다시 주워도 저절로 다시 고르지 않음 — config choose.reselectOnRefill false).
  /// 2) 새로 넘은 방울 (내림(fromM ÷ 간격) + 1 ~ 내림(toM ÷ 간격))마다 보상 표를 굴린다. 물감 통이면 그 순간 색
  ///    [momentColor]로, 지역 색으로 나온 통이면 [regionColor](지금 권역의 지역 색 키, 없으면 그 순간 색)로 보관에
  ///    더한다. 그 색 통이 config 상한이면 나오지 않는다.
  /// 새로 받은 통 줄을 돌려준다
  Future<List<PaintTubeRow>> addPaint({
    required int trailId,
    required double fromM,
    required double toM,
    required DateTime now,
    required String momentColor,
    String? regionColor,
  }) {
    if (!(toM > fromM)) return Future.value(const []);
    return db.transaction(() async {
      final trail = await _trail(trailId);
      if (trail == null) return const <PaintTubeRow>[];
      final at = now.toUtc().millisecondsSinceEpoch;
      await _use(trail, toM - fromM, at);

      final spacing = rules.paintDropSpacingM;
      final first = (fromM / spacing + 1e-9).floor() + 1;
      final last = (toM / spacing + 1e-9).floor();
      final got = <PaintTubeRow>[];
      for (var k = first; k <= last; k++) {
        final roll = rollDrop(trailId, k, _pc, random: random);
        if (!roll.tube) continue;
        final color = roll.region ? regionColor ?? momentColor : momentColor;
        final tube = await _addTube(trailId, k, color, roll.amountM.toDouble(), at);
        if (tube != null) got.add(tube);
      }
      return got;
    });
  }

  /// 물감 길 [trail]을 [deltaM] 칠한다. 지금 구간이 고른 색이면 남은 양을 줄이고 다 쓰면 [at]부터 기본 물감 구간
  Future<void> _use(PaintTrailRow trail, double deltaM, int at) async {
    final color = await trailColor(trail.id);
    if (color == _pc.defaultId) return;
    final row = await _stock(color);
    final split = paintSplit(row?.remainM ?? 0, deltaM);
    if (row != null && split.usedM > 0) {
      await (db.update(db.paintStock)..where((t) => t.colorId.equals(color))).write(
          PaintStockCompanion(
              remainM: Value(split.leftM),
              tubes: Value(await _tubesLeft(color, split.leftM))));
    }
    if (split.leftM > 0) return;
    await _segmentFrom(trail, at, _pc.defaultId, await trailPattern(trail.id));
    if ((await _profile())?.paintColorId == color) {
      await (db.update(db.profile)..where((t) => t.id.equals(1)))
          .write(const ProfileCompanion(paintColorId: Value(null)));
    }
  }

  /// 물감 길 [trail]을 [atMs]부터 [colorId]·[patternId](null = 기본 방울)로 칠한다: 지금 구간과 색·무늬가 같으면
  /// 그대로, 아니면 새 구간 (같은 시각이면 그 구간을 바꾼다). 물감 길 시작·지금 구간 시작보다 앞이면 그 시각에 둔다
  Future<void> _segmentFrom(PaintTrailRow trail, int atMs, String colorId, String? patternId) async {
    final segs = await _segments(trail.id);
    if (segs.isNotEmpty && segs.last.colorId == colorId && segs.last.patternId == patternId) return;
    var from = atMs < trail.startUtc ? trail.startUtc : atMs;
    if (segs.isNotEmpty && from < segs.last.fromUtc) from = segs.last.fromUtc;
    await db.into(db.paintTrailColors).insertOnConflictUpdate(PaintTrailColorRow(
        trailId: trail.id, fromUtc: from, colorId: colorId, patternId: patternId));
  }

  Future<List<PaintTrailColorRow>> _segments(int trailId) => (db.select(db.paintTrailColors)
        ..where((t) => t.trailId.equals(trailId))
        ..orderBy([(t) => OrderingTerm(expression: t.fromUtc)]))
      .get();

  /// 방울 하나의 물감 통을 보관에 더한다. 이미 받은 방울이거나 그 색 통이 상한이면 null
  Future<PaintTubeRow?> _addTube(int trailId, int dropNo, String colorId, double amountM, int at) async {
    final done = await (db.select(db.paintTubes)
          ..where((t) => t.trailId.equals(trailId) & t.dropNo.equals(dropNo)))
        .getSingleOrNull();
    if (done != null) return null;
    final row = await _stock(colorId);
    if (row != null && row.tubes >= _pc.maxTubesPerColor) return null;
    final tube = PaintTubeRow(
        trailId: trailId, dropNo: dropNo, colorId: colorId, amountM: amountM, atUtc: at);
    await db.into(db.paintTubes).insert(tube);
    if (row == null) {
      await db.into(db.paintStock).insert(PaintStockCompanion.insert(
          colorId: colorId, tubes: 1, remainM: amountM, firstGotAt: at, lastGotAt: at));
    } else {
      final remain = row.remainM + amountM;
      await (db.update(db.paintStock)..where((t) => t.colorId.equals(colorId))).write(
          PaintStockCompanion(
              remainM: Value(remain),
              tubes: Value(await _tubesLeft(colorId, remain)),
              lastGotAt: Value(at)));
    }
    return tube;
  }

  /// [colorId] 통을 주운 차례로 써서 [remainM]이 남았을 때 아직 다 안 쓴 통 수
  Future<int> _tubesLeft(String colorId, double remainM) async {
    final rows = await (db.select(db.paintTubes)
          ..where((t) => t.colorId.equals(colorId))
          ..orderBy([(t) => OrderingTerm(expression: t.atUtc), (t) => OrderingTerm(expression: t.dropNo)]))
        .get();
    final amounts = [for (final r in rows) r.amountM];
    final total = amounts.fold(0.0, (a, b) => a + b);
    return tubesLeft(amounts, total - remainM);
  }

  /// 배낭 물감 탭: 기본 물감이 맨 앞, 그 뒤 남은 게 있는 색 (config 16색 차례, 모르는 id는 뒤에 이름순)
  Future<PaintShelfData> shelf() async {
    final rows = await (db.select(db.paintStock)..where((t) => t.remainM.isBiggerThanValue(0))).get();
    final order = {for (final (i, id) in _pc.colorIds.indexed) id: i};
    // 계절이 붙은 id(autumn.sunset)도 계절을 뗀 16색 차례로. 지역 색·모르는 id는 뒤
    int rank(String id) =>
        id.startsWith('region.') ? order.length : order[id.substring(id.lastIndexOf('.') + 1)] ?? order.length;

    rows.sort((a, b) {
      final r = rank(a.colorId).compareTo(rank(b.colorId));
      return r != 0 ? r : a.colorId.compareTo(b.colorId);
    });
    final current = await currentColor();
    final catalog = trails;
    return PaintShelfData(
      patterns: catalog == null ? const [] : await _patternCells(catalog),
      currentPattern: catalog == null ? null : await currentPattern() ?? catalog.defaultId,
      colors: [
        PaintStockView(colorId: _pc.defaultId, tubes: 0, remainM: double.infinity),
        for (final r in rows)
          PaintStockView(
            colorId: r.colorId,
            tubes: r.tubes,
            remainM: r.remainM,
            firstGotAt: DateTime.fromMillisecondsSinceEpoch(r.firstGotAt, isUtc: true),
            lastGotAt: DateTime.fromMillisecondsSinceEpoch(r.lastGotAt, isUtc: true),
            seen: r.seen,
          ),
      ],
      current: current,
      recent: await _recentIds(current),
    );
  }

  /// 최근에 고른(쓴) 색 id, 최근 것부터 (16장 11/17 ②, 캔버스 6-1 ‘최근 쓴’): 지금 고른 색이 맨 앞, 그 뒤는 물감 길
  /// 색 구간(PaintTrailColors)을 마지막으로 시작한 시각 차례. 기본 물감은 뺀다. 새 칸 없이 프로필 고른 물감과 색 구간만
  /// 읽어서, 걷지 않는 사이 골랐다가 칠하기 전에 바꾼 색은 남지 않는다
  Future<List<String>> _recentIds(String current) async {
    final t = db.paintTrailColors;
    final last = t.fromUtc.max();
    final rows = await (db.selectOnly(t)
          ..addColumns([t.colorId, last])
          ..groupBy([t.colorId])
          ..orderBy([OrderingTerm.desc(last), OrderingTerm.asc(t.colorId)]))
        .get();
    return {
      if (current != _pc.defaultId) current,
      for (final r in rows)
        if (r.read(t.colorId) case final id? when id != _pc.defaultId) id,
    }.toList();
  }

  /// 무늬 줄 (config paintPattern.choose ownedOnly·emptyRow defaultOnly, 16장 11/20): 기본 방울이 맨 앞, 그 뒤 가진
  /// 무늬만 trails.json 차례. 안 가진 칸·예시·잠긴 칸은 없다. 목록에 없는 줄(옛 id)은 뺀다
  Future<List<PatternCellView>> _patternCells(TrailCatalog catalog) async {
    final owned = {for (final r in await db.select(db.patternsOwned).get()) r.patternId: r};
    return [
      for (final p in catalog.patterns)
        if (p.id == catalog.defaultId)
          PatternCellView(pattern: p)
        else if (owned[p.id] case final row?)
          PatternCellView(pattern: p, seen: row.seen),
    ];
  }

  /// 처음 모은 뒤 아직 배낭에서 안 본 색 수 (배낭 새 소식 점)
  Future<int> unseenColors() async =>
      (await (db.select(db.paintStock)..where((t) => t.seen.equals(false))).get()).length;

  /// 얻은 뒤 아직 배낭에서 안 본 무늬 수 (거리 보상·상점, 배낭 새 소식 점과 무늬 칸 새 표시)
  Future<int> unseenPatterns() async =>
      (await (db.select(db.patternsOwned)..where((t) => t.seen.equals(false))).get()).length;

  /// 배낭 물감 탭을 열면 새 색·새 무늬 표시를 지운다
  Future<void> markSeen() => db.transaction(() async {
        await (db.update(db.paintStock)..where((t) => t.seen.equals(false)))
            .write(const PaintStockCompanion(seen: Value(true)));
        await (db.update(db.patternsOwned)..where((t) => t.seen.equals(false)))
            .write(const PatternsOwnedCompanion(seen: Value(true)));
      });

  /// [colorId] 통 한 번 더 주울 수 있는가 (가진 통이 상한 아래). 걷는 중 화면이 통을 보일지 본다
  Future<bool> canGetTube(String colorId) async {
    final row = await _stock(colorId);
    return row == null || row.tubes < _pc.maxTubesPerColor;
  }

  /// 그날 받아 둔 날씨 (스키마 20 sync_state.weather_day·weather_kind). 없으면 null
  Future<({String day, String kind})?> savedWeather() async {
    final row = await (db.select(db.syncState)..where((t) => t.id.equals(1))).getSingleOrNull();
    final day = row?.weatherDay;
    final kind = row?.weatherKind;
    return day == null || kind == null ? null : (day: day, kind: kind);
  }

  /// 그날 날씨를 적는다 (동기화 상태 행이 아직 없으면 적지 않는다: 메모리에만)
  Future<void> saveWeather(String day, String kind) =>
      (db.update(db.syncState)..where((t) => t.id.equals(1))).write(
          SyncStateCompanion(weatherDay: Value(day), weatherKind: Value(kind)));

  Future<ProfileRow?> _profile() =>
      (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<PaintStockRow?> _stock(String colorId) =>
      (db.select(db.paintStock)..where((t) => t.colorId.equals(colorId))).getSingleOrNull();

  Future<PaintTrailRow?> _trail(int id) =>
      (db.select(db.paintTrails)..where((t) => t.id.equals(id))).getSingleOrNull();
}
