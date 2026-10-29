import 'package:drift/drift.dart';

part 'app_db.g.dart';

// M1 범위 (M1 명세 5장). 시각은 모두 UTC 정수(epoch ms, 걸음은 epoch 분),
// 날짜 계산만 kstDayKey로 한다. 행 클래스는 domain 이름과 겹치지 않게 ~Row로 둔다

/// 분 단위 걸음. 모든 계산의 원본
@DataClassName('StepMinuteRow')
class StepMinutes extends Table {
  IntColumn get minuteUtc => integer()();
  IntColumn get steps => integer()();

  @override
  Set<Column> get primaryKey => {minuteUtc};
}

@DataClassName('DaySummaryRow')
class DaySummaries extends Table {
  TextColumn get day => text()();
  IntColumn get steps => integer()();
  RealColumn get distanceM => real()();
  IntColumn get countedSessions => integer()();

  @override
  Set<Column> get primaryKey => {day};
}

@DataClassName('WalkSessionRow')
class WalkSessions extends Table {
  IntColumn get startUtc => integer()();
  IntColumn get endUtc => integer()();
  IntColumn get steps => integer()();
  RealColumn get distanceM => real()();
  RealColumn get runRatio => real()();
  BoolColumn get qualified => boolean()();
  BoolColumn get counted => boolean()();

  @override
  Set<Column> get primaryKey => {startUtc};
}

enum JourneyStatus { active, arrived, stopped }

@DataClassName('JourneyRow')
class Journeys extends Table {
  TextColumn get id => text()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  TextColumn get destId => text()();
  IntColumn get startUtc => integer()();
  RealColumn get fundKm => real()();
  RealColumn get totalEffectiveKm => real()();
  TextColumn get status => textEnum<JourneyStatus>()();
  IntColumn get arrivedUtc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 1행. fundedUntilUtc = 어디까지 경비에 넣었는지 (다시 동기화해도 두 번 넣지 않게)
@DataClassName('TravelFundRow')
class TravelFund extends Table {
  IntColumn get id => integer()();
  RealColumn get km => real()();
  IntColumn get fundedUntilUtc => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 1행
@DataClassName('SyncStateRow')
class SyncState extends Table {
  IntColumn get id => integer()();
  IntColumn get lastFetchedUtc => integer().nullable()();
  TextColumn get firstRecordDay => text()();
  IntColumn get installUtc => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [StepMinutes, DaySummaries, WalkSessions, Journeys, TravelFund, SyncState],
)
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 1;
}
