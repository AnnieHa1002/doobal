import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/journey.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _userVersion(AppDb db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('새 DB는 스키마 2로 열리고 새 표를 바로 쓸 수 있다', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.select(db.paintingsOwned).get(), isEmpty);
    expect(await db.select(db.propsOwned).get(), isEmpty);
    expect(await _userVersion(db), 2);

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
  });

  test('스키마 1(여정 표만 있던 때)에서 열면 2로 올라가고 옛 행이 남는다', () async {
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
    expect(await _userVersion(db), 2);
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
  });
}
