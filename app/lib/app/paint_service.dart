import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../domain/paint_color.dart';
import '../domain/rules.dart';

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

/// 배낭 물감 탭 한 번 읽은 것: 가진 색(기본 물감이 맨 앞)과 지금 칠할 물감
class PaintShelfData {
  const PaintShelfData({required this.colors, required this.current});

  final List<PaintStockView> colors;

  /// 지금 칠할 물감 id (고른 색이 남았으면 그 색, 아니면 기본 물감)
  final String current;
}

/// 물감 보관·고르기·칠하기·물감 통 받기 (16장 11/14, M1 v0.7, 스키마 18).
/// - 물감 길을 열 때 그때 칠할 물감을 물감 길에 적는다 ([beginTrail]). 걷는 중에는 고르지 않으니 물감 길 하나는
///   고른 색 → (다 쓰면) 기본 물감, 많아야 두 구간이다.
/// - 물감 길 거리가 늘 때마다([addPaint]) 고른 색 남은 양을 그만큼 줄이고, 새로 넘은 방울마다 보상 표를 굴려
///   물감 통이면 그 순간 색으로 보관에 더한다 (방울 번호는 이정표와 같은 센서 물감 길 거리 기준).
/// 거리는 한 번 넘기면 다시 계산하지 않는다 (길 위 이벤트와 같다). 방울 보상은 물감 길·방울 번호로 정하는
/// 무작위라 같은 방울을 다시 넘겨도 (PaintTubes 키) 한 번만 받고, 백업 복원 뒤에도 같다
class PaintService {
  PaintService(this.db, this.rules, {this.random = seededPaintRandom});

  final AppDb db;
  final Rules rules;

  /// 방울 보상 무작위 (시험은 고정한 것을 넣는다)
  final PaintRandom random;

  PaintColorRules get _pc => rules.paintColor;

  /// 지금 칠할 물감 id: 고른 색이 있고 남았으면 그 색, 아니면 기본 물감
  Future<String> currentColor() async {
    final chosen = (await _profile())?.paintColorId;
    if (chosen == null || chosen == _pc.defaultId) return _pc.defaultId;
    final row = await _stock(chosen);
    return row != null && row.remainM > 0 ? chosen : _pc.defaultId;
  }

  /// 쓸 물감을 고른다 (배낭 물감 탭). 기본 물감 id면 기본으로. 가진 적 없거나 남은 게 없는 색이면 false
  Future<bool> choose(String colorId) => db.transaction(() async {
        String? value;
        if (colorId != _pc.defaultId) {
          final row = await _stock(colorId);
          if (row == null || row.remainM <= 0) return false;
          value = colorId;
        }
        await db.into(db.profile).insertOnConflictUpdate(
            ProfileCompanion(id: const Value(1), paintColorId: Value(value)));
        return true;
      });

  /// 물감 길 [trailId]를 연 때: 그 물감 길에 지금 칠할 물감을 적는다 (이미 적혀 있으면 그대로)
  Future<void> beginTrail(int trailId) => db.transaction(() async {
        final trail = await _trail(trailId);
        if (trail == null || trail.colorId != null) return;
        await (db.update(db.paintTrails)..where((t) => t.id.equals(trailId)))
            .write(PaintTrailsCompanion(colorId: Value(await currentColor())));
      });

  /// 물감 길 [trailId]의 거리가 [fromM]에서 [toM]으로 늘었다 (이정표에 넘기는 것과 같은 센서 물감 길 거리, m).
  /// 1) 그 물감 길의 고른 색 남은 양을 늘어난 만큼 줄인다. 다 쓰면 [now]부터 기본 물감 (물감 길 colorEndUtc,
  ///    프로필의 고른 물감은 비운다, 걷는 중 알림 없음).
  /// 2) 새로 넘은 방울 (내림(fromM ÷ 간격) + 1 ~ 내림(toM ÷ 간격))마다 보상 표를 굴린다. 물감 통이면 그 순간 색
  ///    [momentColor]로 보관에 더한다. 그 색 통이 config 상한이면 나오지 않는다.
  /// 새로 받은 통 줄을 돌려준다
  Future<List<PaintTubeRow>> addPaint({
    required int trailId,
    required double fromM,
    required double toM,
    required DateTime now,
    required String momentColor,
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
        final tube = await _addTube(trailId, k, momentColor, roll.amountM.toDouble(), at);
        if (tube != null) got.add(tube);
      }
      return got;
    });
  }

  /// 물감 길 [trail]을 [deltaM] 칠한다. 고른 색이면 남은 양을 줄이고 다 쓰면 [at]에 기본 물감으로 넘긴다
  Future<void> _use(PaintTrailRow trail, double deltaM, int at) async {
    final color = trail.colorId;
    if (color == null || color == _pc.defaultId || trail.colorEndUtc != null) return;
    final row = await _stock(color);
    final split = paintSplit(row?.remainM ?? 0, deltaM);
    if (row != null && split.usedM > 0) {
      await (db.update(db.paintStock)..where((t) => t.colorId.equals(color))).write(
          PaintStockCompanion(
              remainM: Value(split.leftM),
              tubes: Value(await _tubesLeft(color, split.leftM))));
    }
    if (split.leftM > 0) return;
    await (db.update(db.paintTrails)..where((t) => t.id.equals(trail.id)))
        .write(PaintTrailsCompanion(colorEndUtc: Value(at)));
    if ((await _profile())?.paintColorId == color) {
      await (db.update(db.profile)..where((t) => t.id.equals(1)))
          .write(const ProfileCompanion(paintColorId: Value(null)));
    }
  }

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
    return PaintShelfData(
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
      current: await currentColor(),
    );
  }

  /// 처음 모은 뒤 아직 배낭에서 안 본 색 수 (배낭 새 소식 점)
  Future<int> unseenColors() async =>
      (await (db.select(db.paintStock)..where((t) => t.seen.equals(false))).get()).length;

  /// 배낭 물감 탭을 열면 새 색 표시를 지운다
  Future<void> markSeen() => (db.update(db.paintStock)..where((t) => t.seen.equals(false)))
      .write(const PaintStockCompanion(seen: Value(true)));

  /// [colorId] 통 한 번 더 주울 수 있는가 (가진 통이 상한 아래). 걷는 중 화면이 통을 보일지 본다
  Future<bool> canGetTube(String colorId) async {
    final row = await _stock(colorId);
    return row == null || row.tubes < _pc.maxTubesPerColor;
  }

  Future<ProfileRow?> _profile() =>
      (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<PaintStockRow?> _stock(String colorId) =>
      (db.select(db.paintStock)..where((t) => t.colorId.equals(colorId))).getSingleOrNull();

  Future<PaintTrailRow?> _trail(int id) =>
      (db.select(db.paintTrails)..where((t) => t.id.equals(id))).getSingleOrNull();
}
