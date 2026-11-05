part of 'sync_service.dart';

// 동행 (M4). 동행 일의 동기화는 이 파일에 둔다 (병렬 개발 때 sync_service.dart 본문이 부딪히지 않게)

/// 프롤로그를 아직 안 본 동행의 readChapter. 칸에서 만났지만 길 위 만남 흐름을 안 끝낸 상태다
/// (앱이 꺼져도 다음 걷는 중 화면에서 이어서 보여 준다). 흐름을 끝내면 0
const _unreadPrologue = -1;

/// 만난 동행 한 명을 화면에서 보는 값
class MetCompanion {
  const MetCompanion({
    required this.companion,
    required this.chapter,
    required this.readChapter,
    required this.walksTogether,
  });

  final Companion companion;

  /// 열린 장 (0 = 프롤로그뿐)
  final int chapter;

  /// 읽은 장
  final int readChapter;

  /// 함께 인정된 걷기 1번 수
  final int walksTogether;
}

/// 동행 화면의 값
class CompanionsView {
  const CompanionsView({required this.met, required this.walkingWith, required this.lastWith});

  /// 만난 순서. 길 위 만남 흐름을 아직 안 끝낸 동행은 빠진다
  final List<MetCompanion> met;

  /// 지금 함께 걷는 동행 id. 혼자 걷는 중이면 null
  final String? walkingWith;

  /// 마지막으로 함께 걸은 동행 id (없으면 먼저 만난 동행). 혼자 걷는 중에 이 동행의 이야기를 보여 준다.
  /// 만난 동행이 없으면 null
  final String? lastWith;

  MetCompanion? metById(String? id) {
    if (id == null) return null;
    for (final m in met) {
      if (m.companion.id == id) return m;
    }
    return null;
  }
}

extension CompanionSync on SyncService {
  /// 동기화 끝에 동행 일을 처리한다: 인정된 걷기 1번의 시작 시각에 함께 걷던 동행에게 +1,
  /// 걷기 4번마다 새 장. 저장된 기록에서 늘 처음부터 세므로 같은 기록으로 다시 돌려도 안 바뀐다.
  /// 늦게 들어온 기록으로 걷기 수가 줄어도 한 번 열린 장은 닫지 않는다.
  /// 돌려주는 것은 이번에 새로 생긴 알림 후보(N3).
  /// TODO(T2b): 새 장이 열리면 N3 후보를 돌려주고, 8장이 열리면 완결 소품을 준다
  Future<List<NoticeCandidate>> _syncCompanions(DateTime now) async {
    final rows = await db.select(db.companions).get();
    if (rows.isEmpty) return const [];
    final stints = await _companionStints();
    final sessions =
        await (db.select(db.walkSessions)..where((t) => t.counted.equals(true))).get();
    final walks = walksTogether([for (final s in sessions) s.startUtc], stints);
    for (final r in rows) {
      final n = walks[r.companionId] ?? 0;
      final chapter = math.max(r.chapter, openedChapter(n, rules));
      if (n == r.walksTogether && chapter == r.chapter) continue;
      await (db.update(db.companions)..where((t) => t.companionId.equals(r.companionId)))
          .write(CompanionsCompanion(walksTogether: Value(n), chapter: Value(chapter)));
    }
    return const [];
  }

  /// 도장 조건이 읽는 값: 만난 동행 수, 이야기를 끝까지 연 동행 수
  Future<({int met, int finales})> _companionBadgeFacts() async {
    final rows = await db.select(db.companions).get();
    return (
      met: rows.length,
      finales: rows.where((r) => r.chapter >= rules.companionChapters).length,
    );
  }

  /// 시작 시각 순서
  Future<List<CompanionStint>> _companionStints() async {
    final rows = await (db.select(db.companionStints)
          ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
        .get();
    return [for (final r in rows) CompanionStint(r.startUtc, r.companionId)];
  }

  /// 이 여정에서 만남이 차지한 마지막 칸 (없으면 0). 만남 칸에는 이벤트 줄이 없어서 따로 본다
  Future<int> _lastMeetK(String journeyId) async {
    final rows =
        await (db.select(db.companions)..where((t) => t.metJourneyId.equals(journeyId))).get();
    return rows.fold<int>(0, (m, r) => math.max(m, r.metK ?? 0));
  }

  /// 칸 [k]에서 동행을 만나면 줄을 넣고 그 동행을 돌려준다 (이 칸은 이벤트 대신 만남이다).
  /// 앞선 만남의 흐름을 아직 안 끝냈으면 새로 만나지 않는다
  Future<Companion?> _meetAtSlot(
    JourneyRow active,
    int k,
    String terrain,
    SyncStateRow state,
    String installId,
    DateTime now,
  ) async {
    final catalog = companionCatalog;
    if (catalog == null) return null;
    final rows = await db.select(db.companions).get();
    if (rows.any((r) => r.readChapter < 0)) return null;
    final today = dayFromKey(kstDayKey(now));
    final installed = dayFromKey(kstDayKey(_utc(state.installUtc)));
    final met = pickMeeting(
      companions: catalog.companions,
      metIds: {for (final r in rows) r.companionId},
      terrain: terrain,
      installAgeDays: today.difference(installed).inDays,
      installId: installId,
      journeyId: active.id,
      k: k,
      rules: rules,
    );
    if (met == null) return null;
    await db.into(db.companions).insert(CompanionsCompanion.insert(
          companionId: met.id,
          metUtc: now.toUtc().millisecondsSinceEpoch,
          metJourneyId: Value(active.id),
          metK: Value(k),
          readChapter: const Value(_unreadPrologue),
        ));
    return met;
  }

  /// 길 위 만남 흐름을 아직 안 끝낸 동행 (먼저 만난 순서로 하나). 없으면 null
  Future<Companion?> pendingMeeting() async {
    final catalog = companionCatalog;
    if (catalog == null) return null;
    final rows = await (db.select(db.companions)
          ..where((t) => t.readChapter.isSmallerThanValue(0))
          ..orderBy([(t) => OrderingTerm(expression: t.metUtc)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : catalog.byId(rows.single.companionId);
  }

  /// 길 위 만남 흐름을 끝낸다 (프롤로그를 읽은 것으로 둔다). [together]면 지금부터 이 동행과 걷고,
  /// 아니면 지금까지 걷던 대로다 (혼자였으면 혼자, 다른 동행과 걷고 있었으면 그 동행과)
  Future<void> finishMeeting(String id, DateTime now, {required bool together}) =>
      db.transaction(() async {
        final row = await _companionRow(id);
        if (row == null) throw StateError('아직 안 만난 동행: $id');
        if (row.readChapter < 0) {
          await (db.update(db.companions)..where((t) => t.companionId.equals(id)))
              .write(const CompanionsCompanion(readChapter: Value(0)));
        }
        if (together) await _addStint(id, now);
      });

  /// 함께 걷는 동행을 바꾼다 ([id]가 null이면 혼자 걷기). 다음에 시작하는 걷기부터 그 동행에게 쌓인다.
  /// 만나지 않았거나 만남 흐름을 안 끝낸 동행이면 StateError
  Future<void> walkWith(String? id, DateTime now) => db.transaction(() async {
        if (id != null) {
          final row = await _companionRow(id);
          if (row == null || row.readChapter < 0) throw StateError('아직 안 만난 동행: $id');
        }
        await _addStint(id, now);
      });

  /// 지금과 같으면 줄을 늘리지 않는다
  Future<void> _addStint(String? id, DateTime now) async {
    final stints = await _companionStints();
    if ((stints.isEmpty ? null : stints.last.companionId) == id) return;
    await db.into(db.companionStints).insertOnConflictUpdate(CompanionStintsCompanion.insert(
          startUtc: Value(now.toUtc().millisecondsSinceEpoch),
          companionId: Value(id),
        ));
  }

  /// 동행 화면의 값
  Future<CompanionsView> companionsView() async {
    final catalog = companionCatalog;
    if (catalog == null) {
      return const CompanionsView(met: [], walkingWith: null, lastWith: null);
    }
    final rows = await (db.select(db.companions)
          ..where((t) => t.readChapter.isBiggerOrEqualValue(0))
          ..orderBy([(t) => OrderingTerm(expression: t.metUtc)]))
        .get();
    final met = [
      for (final r in rows)
        if (catalog.byId(r.companionId) case final c?)
          MetCompanion(
            companion: c,
            chapter: r.chapter,
            readChapter: r.readChapter,
            walksTogether: r.walksTogether,
          ),
    ];
    final stints = await _companionStints();
    final last = stints.reversed.map((s) => s.companionId).whereType<String>().firstOrNull;
    return CompanionsView(
      met: met,
      walkingWith: stints.isEmpty ? null : stints.last.companionId,
      lastWith: last ?? (met.isEmpty ? null : met.first.companion.id),
    );
  }

  /// 이야기 [no]장을 읽은 것으로 둔다 (읽은 장은 줄지 않는다)
  Future<void> markStoryRead(String id, int no) async {
    final row = await _companionRow(id);
    if (row == null || no <= row.readChapter) return;
    await (db.update(db.companions)..where((t) => t.companionId.equals(id)))
        .write(CompanionsCompanion(readChapter: Value(no)));
  }

  Future<CompanionRow?> _companionRow(String id) =>
      (db.select(db.companions)..where((t) => t.companionId.equals(id))).getSingleOrNull();

  // 개발 화면 전용 (폰에서 2km를 걷거나 걷기 4번을 채우지 않고 화면을 보려고)

  /// 다음에 만날 동행을 바로 만난다 (칸 없이, 만남 흐름 대기 상태로). 이미 대기 중이면 그 동행.
  /// 다 만났으면 null
  Future<Companion?> debugMeetNext(DateTime now) async {
    final catalog = companionCatalog;
    if (catalog == null) return null;
    final pending = await pendingMeeting();
    if (pending != null) return pending;
    final metIds = {for (final r in await db.select(db.companions).get()) r.companionId};
    final next = catalog.companions.where((c) => !metIds.contains(c.id)).firstOrNull;
    if (next == null) return null;
    await db.into(db.companions).insert(CompanionsCompanion.insert(
          companionId: next.id,
          metUtc: now.toUtc().millisecondsSinceEpoch,
          readChapter: const Value(_unreadPrologue),
        ));
    return next;
  }

  /// 이 동행의 이야기를 한 장 더 연다 (걷기 수는 그대로. 열린 장은 동기화로 줄지 않는다)
  Future<void> debugOpenNextChapter(String id) async {
    final row = await _companionRow(id);
    if (row == null) return;
    final next = math.min(row.chapter + 1, rules.companionChapters);
    await (db.update(db.companions)..where((t) => t.companionId.equals(id)))
        .write(CompanionsCompanion(chapter: Value(next)));
  }
}
