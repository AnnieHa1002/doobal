import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

final _t0 = DateTime.utc(2026, 11, 18, 0);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDb db;
  late SyncService svc;

  String badgeOf(String kind) =>
      badgeCatalog.badges.firstWhere((b) => b.cond['kind'] == kind).id;

  Future<Set<String>> owned() async =>
      {for (final r in await db.select(db.badgesOwned).get()) r.badgeId};

  Future<void> meet(String id, {int chapter = 0}) => db
      .into(db.companions)
      .insert(CompanionsCompanion.insert(companionId: id, metUtc: 1, chapter: Value(chapter)));

  setUp(() {
    db = AppDb(NativeDatabase.memory());
    svc = SyncService(
      db: db,
      source: FakeStepSource(),
      rules: rules,
      allowedSources: const [],
      landmarks: {for (final l in landmarks) l.id: l},
      props: props,
      badgeCatalog: badgeCatalog,
    );
  });
  tearDown(() => db.close());

  test('동행이 없으면 동행 도장을 주지 않고, 새 배도 없다', () async {
    final report = await svc.sync(_t0);
    expect(await owned(), isNot(contains(badgeOf('companionsMet'))));
    expect(await owned(), isNot(contains(badgeOf('finaleCount'))));
    expect(report.newBoats, isEmpty);
  });

  test('세 동행을 모두 만나면 만남 도장, 한 명이 마지막 장까지 열면 완결 도장', () async {
    await meet('bright');
    await meet('rest');
    await svc.sync(_t0);
    expect(await owned(), isNot(contains(badgeOf('companionsMet'))));

    await meet('doctor', chapter: rules.companionChapters - 1);
    await svc.sync(_t0.add(const Duration(minutes: 1)));
    expect(await owned(), contains(badgeOf('companionsMet')));
    expect(await owned(), isNot(contains(badgeOf('finaleCount'))));

    await (db.update(db.companions)..where((t) => t.companionId.equals('doctor')))
        .write(CompanionsCompanion(chapter: Value(rules.companionChapters)));
    final report = await svc.sync(_t0.add(const Duration(minutes: 2)));
    expect(await owned(), contains(badgeOf('finaleCount')));
    expect(report.newBadges.map((b) => b.id), contains(badgeOf('finaleCount')));

    // 같은 기록으로 또 돌려도 늘지 않는다
    final again = await svc.sync(_t0.add(const Duration(minutes: 3)));
    expect(again.newBadges, isEmpty);
  });
}
