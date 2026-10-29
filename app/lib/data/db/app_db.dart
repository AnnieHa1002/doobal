import 'package:drift/drift.dart';

import '../../domain/journey.dart' show Frame;

part 'app_db.g.dart';

// M1 범위 (M1 명세 5장) + 스키마 2 (M3: 그림·소품, 여정의 끝). 시각은 모두 UTC 정수
// (epoch ms, 걸음은 epoch 분), 날짜 계산만 kstDayKey로 한다.
// 행 클래스는 domain 이름과 겹치지 않게 ~Row로 둔다

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

  /// 여정이 끝난 곳: 도착이면 목적지, 멈춤이면 멈춘 지점. 진행 중이면 null
  RealColumn get endLat => real().nullable()();
  RealColumn get endLng => real().nullable()();

  /// 멈춘 시각 (도착은 arrivedUtc)
  IntColumn get endedUtc => integer().nullable()();

  /// 도착 화면에 쓸 값 (도착한 여정만): 몇 번째 방문, 도착 전·후 액자
  IntColumn get visitNo => integer().nullable()();
  TextColumn get prevFrame => textEnum<Frame>().nullable()();
  TextColumn get newFrame => textEnum<Frame>().nullable()();

  /// 도착 화면을 보여 줬는지. 앱 밖에서 도착하면 다음 실행 때 먼저 보여 준다
  BoolColumn get arrivalShown => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 얻은 그림. 명소마다 한 점 (MVP는 첫 방문). 다시 도착하면 방문 수와 액자만 바뀐다
@DataClassName('PaintingOwnedRow')
class PaintingsOwned extends Table {
  TextColumn get landmarkId => text()();
  IntColumn get visits => integer()();
  TextColumn get frame => textEnum<Frame>()();

  /// 가장 멀리서 걸어 온 환산 거리(km)
  RealColumn get bestKm => real()();
  IntColumn get firstArrivedUtc => integer()();
  IntColumn get lastArrivedUtc => integer()();

  @override
  Set<Column> get primaryKey => {landmarkId};
}

/// 얻은 소품. seen이 false면 배낭에 새 소품 표시
@DataClassName('PropOwnedRow')
class PropsOwned extends Table {
  TextColumn get propId => text()();
  IntColumn get unlockedUtc => integer()();
  BoolColumn get seen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {propId};
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
  tables: [
    StepMinutes,
    DaySummaries,
    WalkSessions,
    Journeys,
    TravelFund,
    SyncState,
    PaintingsOwned,
    PropsOwned,
  ],
)
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(journeys, journeys.endLat);
            await m.addColumn(journeys, journeys.endLng);
            await m.addColumn(journeys, journeys.endedUtc);
            await m.addColumn(journeys, journeys.visitNo);
            await m.addColumn(journeys, journeys.prevFrame);
            await m.addColumn(journeys, journeys.newFrame);
            await m.addColumn(journeys, journeys.arrivalShown);
            await m.createTable(paintingsOwned);
            await m.createTable(propsOwned);
            // 1에서 도착한 여정은 그림 기록이 없다. 도착 화면을 띄우지 않는다
            await customStatement("UPDATE journeys SET arrival_shown = 1 WHERE status = 'arrived'");
          }
        },
      );
}
