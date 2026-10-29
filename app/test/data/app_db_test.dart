import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/journey.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _userVersion(AppDb db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('새 DB는 스키마 3으로 열리고 새 표를 바로 쓸 수 있다', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.select(db.paintingsOwned).get(), isEmpty);
    expect(await db.select(db.propsOwned).get(), isEmpty);
    expect(await db.select(db.profile).get(), isEmpty);
    expect(await _userVersion(db), 3);

    await db.into(db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
          landmarkId: 'kr001',
          visits: 1,
          frame: Frame.silver,
          bestKm: 22.5,
          firstArrivedUtc: 1,
          lastArrivedUtc: 2,
        ));
    await db.into(db.propsOwned).insert(PropsOwnedCompanion.insert(propId: 'hat_01', unlockedUtc: 1));
    expect((await db.select(db.paintingsOwned).getSingle()).frame, Frame.silver);
    expect((await db.select(db.propsOwned).getSingle()).seen, isFalse);

    // 프로필은 1행: 출발 동네 열은 비워 둘 수 있고, 같은 id로 다시 넣으면 바뀐다
    await db.into(db.profile).insert(ProfileCompanion.insert(id: const Value(1)));
    var profile = await db.select(db.profile).getSingle();
    expect(profile.homeName, isNull);
    expect(profile.homeLat, isNull);
    expect(profile.homeLng, isNull);
    await db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
        id: const Value(1),
        homeName: const Value('중구'),
        homeLat: const Value(37.5665),
        homeLng: const Value(126.978)));
    profile = await db.select(db.profile).getSingle();
    expect((profile.homeName, profile.homeLat, profile.homeLng), ('중구', 37.5665, 126.978));
  });

  test('스키마 1(여정 표만 있던 때)에서 열면 3으로 올라가고 옛 행이 남는다', () async {
    // 스키마 1의 journeys 표와 행 둘(도착, 멈춤)을 직접 만들어 두고 user_version = 1로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE journeys (
          id TEXT NOT NULL, origin_lat REAL NOT NULL, origin_lng REAL NOT NULL,
          dest_id TEXT NOT NULL, start_utc INTEGER NOT NULL, fund_km REAL NOT NULL,
          total_effective_km REAL NOT NULL, status TEXT NOT NULL, arrived_utc INTEGER NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'kr001', 10, 0, 5, 'arrived', 20)");
      raw.execute("INSERT INTO journeys VALUES ('j2', 38.0, 128.0, 'kr002', 30, 1, 6, 'stopped', NULL)");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);

    final rows = {for (final r in await db.select(db.journeys).get()) r.id: r};
    expect(await _userVersion(db), 3);
    expect(rows.keys, {'j1', 'j2'});
    // 새 열은 비어 있고, 옛 도착 여정은 도착 화면을 이미 본 것으로 둔다
    expect(rows['j1']!.endLat, isNull);
    expect(rows['j1']!.visitNo, isNull);
    expect(rows['j1']!.arrivalShown, isTrue);
    expect(rows['j2']!.arrivalShown, isFalse);
    expect(rows['j2']!.status, JourneyStatus.stopped);
    expect(rows['j2']!.fundKm, 1);

    // 새 열·새 표를 쓸 수 있다
    await (db.update(db.journeys)..where((t) => t.id.equals('j2'))).write(
        const JourneysCompanion(endLat: Value(37.5), prevFrame: Value(Frame.wood)));
    expect((await (db.select(db.journeys)..where((t) => t.id.equals('j2'))).getSingle()).prevFrame,
        Frame.wood);
    expect(await db.select(db.paintingsOwned).get(), isEmpty);
    expect(await db.select(db.propsOwned).get(), isEmpty);
    expect(await db.select(db.profile).get(), isEmpty);
  });

  test('스키마 2(프로필 표가 없던 때)에서 열면 3으로 올라가고 옛 행이 그대로 남는다', () async {
    // 스키마 2의 journeys 표(새 열 포함)·그림·소품 표와 행을 직접 만들어 두고 user_version = 2로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE journeys (
          id TEXT NOT NULL, origin_lat REAL NOT NULL, origin_lng REAL NOT NULL,
          dest_id TEXT NOT NULL, start_utc INTEGER NOT NULL, fund_km REAL NOT NULL,
          total_effective_km REAL NOT NULL, status TEXT NOT NULL, arrived_utc INTEGER NULL,
          end_lat REAL NULL, end_lng REAL NULL, ended_utc INTEGER NULL,
          visit_no INTEGER NULL, prev_frame TEXT NULL, new_frame TEXT NULL,
          arrival_shown INTEGER NOT NULL DEFAULT 0 CHECK (arrival_shown IN (0, 1)),
          PRIMARY KEY (id))
      ''');
      // 도착했지만 도착 화면은 아직 안 본 여정 (2 → 3에서 건드리면 안 된다)과 멈춘 여정
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'kr001', 10, 0, 5, 'arrived', "
          "20, 37.5, 127.0, NULL, 1, NULL, 'wood', 0)");
      raw.execute("INSERT INTO journeys VALUES ('j2', 38.0, 128.0, 'kr002', 30, 1, 6, 'stopped', "
          "NULL, 37.6, 127.1, 40, NULL, NULL, NULL, 0)");
      raw.execute('''
        CREATE TABLE paintings_owned (
          landmark_id TEXT NOT NULL, visits INTEGER NOT NULL, frame TEXT NOT NULL,
          best_km REAL NOT NULL, first_arrived_utc INTEGER NOT NULL,
          last_arrived_utc INTEGER NOT NULL, PRIMARY KEY (landmark_id))
      ''');
      raw.execute("INSERT INTO paintings_owned VALUES ('kr001', 2, 'silver', 22.5, 20, 50)");
      raw.execute('''
        CREATE TABLE props_owned (
          prop_id TEXT NOT NULL, unlocked_utc INTEGER NOT NULL,
          seen INTEGER NOT NULL DEFAULT 0 CHECK (seen IN (0, 1)), PRIMARY KEY (prop_id))
      ''');
      raw.execute("INSERT INTO props_owned VALUES ('hat_01', 5, 1)");
      raw.execute('PRAGMA user_version = 2');
    }));
    addTearDown(db.close);

    final rows = {for (final r in await db.select(db.journeys).get()) r.id: r};
    expect(await _userVersion(db), 3);
    expect(rows.keys, {'j1', 'j2'});
    expect(rows['j1']!.status, JourneyStatus.arrived);
    expect(rows['j1']!.newFrame, Frame.wood);
    expect(rows['j1']!.arrivalShown, isFalse);
    expect(rows['j2']!.endLat, 37.6);
    expect(rows['j2']!.endedUtc, 40);

    // 프로필 표가 새로 생겼고 비어 있다. 쓸 수 있다
    expect(await db.select(db.profile).get(), isEmpty);
    await db.into(db.profile).insert(ProfileCompanion.insert(
        id: const Value(1),
        homeName: const Value('종로구'),
        homeLat: const Value(37.57),
        homeLng: const Value(126.98)));
    expect((await db.select(db.profile).getSingle()).homeName, '종로구');
    // 스키마 2의 그림·소품도 그대로
    final painting = await db.select(db.paintingsOwned).getSingle();
    expect((painting.landmarkId, painting.visits, painting.frame), ('kr001', 2, Frame.silver));
    expect((await db.select(db.propsOwned).getSingle()).seen, isTrue);
  });
}
