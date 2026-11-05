import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _userVersion(AppDb db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');

/// 그 이름의 표가 DB에 있는가
Future<bool> _hasTable(AppDb db, String table) async => (await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable.withString(table)])
        .get())
    .isNotEmpty;

Future<List<String>> _columns(AppDb db, String table) async => [
      for (final r in await db.customSelect('PRAGMA table_info($table)').get())
        r.read<String>('name'),
    ];

/// 스키마 12의 여정 표 (행 없음). 13에서 event_m 열이 더해지니 여정 표가 있는 옛 DB를 흉내 낼 때 쓴다
void _createOldJourneys(dynamic raw) {
  raw.execute('''
    CREATE TABLE journeys (
      id TEXT NOT NULL, origin_lat REAL NOT NULL, origin_lng REAL NOT NULL,
      dest_id TEXT NOT NULL, start_utc INTEGER NOT NULL, fund_km REAL NOT NULL,
      total_effective_km REAL NOT NULL, status TEXT NOT NULL, arrived_utc INTEGER NULL,
      end_lat REAL NULL, end_lng REAL NULL, ended_utc INTEGER NULL,
      visit_no INTEGER NULL, prev_frame TEXT NULL, new_frame TEXT NULL,
      arrival_shown INTEGER NOT NULL DEFAULT 0 CHECK (arrival_shown IN (0, 1)),
      dest_lat REAL NULL, dest_lng REAL NULL, PRIMARY KEY (id))
  ''');
}

/// 스키마 6~11의 프로필 표(3에서 생겼고 6에서 시작 흐름 열이 늘었다, 12에서 표시 글꼴 열이 생긴다)
void _createOldProfile(dynamic raw) {
  raw.execute('''
    CREATE TABLE profile (
      id INTEGER NOT NULL, home_name TEXT NULL, home_lat REAL NULL, home_lng REAL NULL,
      home_id TEXT NULL, age_confirmed_at INTEGER NULL, install_id TEXT NULL, nickname TEXT NULL,
      look TEXT NULL, onboarded_at INTEGER NULL, link_consent_at INTEGER NULL,
      guestbook_consent_at INTEGER NULL, PRIMARY KEY (id))
  ''');
}

/// 옛 스키마의 동기화 상태 표(1부터 있었고 restore_floor_day 열은 10에서 생겼다)와 행 하나.
/// 하루 요약·걷기 구간 표도 1부터 있었고 11에서 열이 늘어서(그래서 11로 올라올 때 열을 더한다)
/// 행 없는 옛 표를 같이 만든다 ([dayTables]가 false면 테스트가 직접 만든다).
/// [raw]는 NativeDatabase의 setup이 주는 sqlite3 Database
void _createOldSyncState(dynamic raw, {bool dayTables = true}) {
  raw.execute('''
    CREATE TABLE sync_state (
      id INTEGER NOT NULL, last_fetched_utc INTEGER NULL, first_record_day TEXT NOT NULL,
      install_utc INTEGER NOT NULL, PRIMARY KEY (id))
  ''');
  raw.execute("INSERT INTO sync_state VALUES (1, 500, '2026-11-18', 100)");
  if (dayTables) _createOldDayTables(raw);
}

/// 스키마 10의 하루 요약·걷기 구간 표 (행 없음)
void _createOldDayTables(dynamic raw) {
  raw.execute('''
    CREATE TABLE day_summaries (
      day TEXT NOT NULL, steps INTEGER NOT NULL, distance_m REAL NOT NULL,
      counted_sessions INTEGER NOT NULL, PRIMARY KEY (day))
  ''');
  raw.execute('''
    CREATE TABLE walk_sessions (
      start_utc INTEGER NOT NULL, end_utc INTEGER NOT NULL, steps INTEGER NOT NULL,
      distance_m REAL NOT NULL, run_ratio REAL NOT NULL,
      qualified INTEGER NOT NULL CHECK (qualified IN (0, 1)),
      counted INTEGER NOT NULL CHECK (counted IN (0, 1)), PRIMARY KEY (start_utc))
  ''');
}

/// 그림 표의 열 (스키마 7의 정의. 첫 그림은 고정 그림이라 다시 그리는 값 열이 없다)
const _paintingColumns = [
  'landmark_id',
  'visits',
  'frame',
  'best_km',
  'first_arrived_utc',
  'last_arrived_utc',
  'seen',
];

/// 도착 기회 하나(쓴 것)와 그 글 하나
Future<void> _insertGuestbook(AppDb db) async {
  await db.into(db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
        id: 'a:j1',
        kind: TicketKind.arrival,
        scope: 'kr001',
        openedUtc: 10,
        usedUtc: const Value(20),
      ));
  await db.into(db.guestbookPosts).insert(GuestbookPostsCompanion.insert(
        ticketId: 'a:j1',
        scope: 'kr001',
        body: '좋았어요',
        createdUtc: 20,
        status: PostStatus.pending,
      ));
}

/// 알림 기록 두 줄: 보낸 N2와 예약한 N5
Future<void> _insertNotice(AppDb db) async {
  await db.into(db.notificationLog).insert(NotificationLogCompanion.insert(
        kind: NoticeKind.n2,
        refKey: 'j1',
        atUtc: 10,
        status: NoticeStatus.sent,
      ));
  await db.into(db.notificationLog).insert(NotificationLogCompanion.insert(
        kind: NoticeKind.n5,
        refKey: '',
        atUtc: 20,
        status: NoticeStatus.scheduled,
      ));
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('새 DB는 스키마 15로 열리고 새 표를 바로 쓸 수 있다', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.select(db.paintingsOwned).get(), isEmpty);
    expect(await db.select(db.propsOwned).get(), isEmpty);
    expect(await db.select(db.profile).get(), isEmpty);
    expect(await _hasTable(db, 'wall_slots'), isFalse);
    expect(await _userVersion(db), 15);

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
    // 그림의 seen 기본값은 true (새 그림 표시는 도착할 때 false로 넣는다), 소품은 false
    expect((await db.select(db.paintingsOwned).getSingle()).seen, isTrue);
    // 첫 그림(landmarkId 'sketch')은 visits 1과 도착 시각만 넣는다 (다시 그리는 값 열은 없다)
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
    await db.into(db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
          landmarkId: 'sketch',
          visits: 1,
          frame: Frame.wood,
          bestKm: 2.5,
          firstArrivedUtc: 1,
          lastArrivedUtc: 1,
          seen: const Value(false),
        ));
    final firstPack = await (db.select(db.paintingsOwned)
          ..where((t) => t.landmarkId.equals('sketch')))
        .getSingle();
    expect((firstPack.visits, firstPack.frame, firstPack.seen), (1, Frame.wood, false));
    // 여정의 가상 목적지 좌표는 비워 둘 수 있다
    await db.into(db.journeys).insert(JourneysCompanion.insert(
          id: 'j1',
          originLat: 37.5,
          originLng: 127,
          destId: 'kr001',
          startUtc: 1,
          fundKm: 0,
          totalEffectiveKm: 5,
          status: JourneyStatus.active,
        ));
    expect(await db.select(db.journeys).getSingle().then((r) => (r.destLat, r.destLng)),
        (null, null));
    expect((await db.select(db.propsOwned).getSingle()).seen, isFalse);

    // 프로필은 1행: 출발 동네 열은 비워 둘 수 있고, 같은 id로 다시 넣으면 바뀐다
    await db.into(db.profile).insert(ProfileCompanion.insert(id: const Value(1)));
    var profile = await db.select(db.profile).getSingle();
    expect(profile.homeName, isNull);
    expect(profile.homeLat, isNull);
    expect(profile.homeLng, isNull);
    // 시작 흐름·동의 열도 모두 비어 있다
    expect([
      profile.homeId,
      profile.ageConfirmedAt,
      profile.installId,
      profile.nickname,
      profile.look,
      profile.onboardedAt,
      profile.linkConsentAt,
      profile.guestbookConsentAt,
    ], everyElement(isNull));
    await db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
        id: const Value(1),
        homeName: const Value('중구'),
        homeLat: const Value(37.5665),
        homeLng: const Value(126.978)));
    profile = await db.select(db.profile).getSingle();
    expect((profile.homeName, profile.homeLat, profile.homeLng), ('중구', 37.5665, 126.978));

    // 방명록 표: 처음엔 비어 있고, 기회는 id가 키, 글은 기회 하나에 하나(ticketId가 키)
    expect(await db.select(db.guestbookTickets).get(), isEmpty);
    expect(await db.select(db.guestbookPosts).get(), isEmpty);
    await _insertGuestbook(db);
    final ticket = await db.select(db.guestbookTickets).getSingle();
    expect((ticket.id, ticket.kind, ticket.scope), ('a:j1', TicketKind.arrival, 'kr001'));
    expect((ticket.openedUtc, ticket.usedUtc, ticket.closedUtc), (10, 20, null));
    final post = await db.select(db.guestbookPosts).getSingle();
    expect((post.ticketId, post.scope, post.body, post.createdUtc, post.status),
        ('a:j1', 'kr001', '좋았어요', 20, PostStatus.pending));
    await expectLater(
        db.into(db.guestbookPosts).insert(GuestbookPostsCompanion.insert(
            ticketId: 'a:j1',
            scope: 'kr001',
            body: '또 쓰기',
            createdUtc: 30,
            status: PostStatus.pending)),
        throwsA(anything));
    expect(await _columns(db, 'guestbook_tickets'),
        ['id', 'kind', 'scope', 'opened_utc', 'used_utc', 'closed_utc']);
    expect(await _columns(db, 'guestbook_posts'),
        ['ticket_id', 'scope', 'body', 'created_utc', 'status']);

    // 알림 기록은 쌓기만 하고(id가 저절로 붙는다), 켜고 끄기는 1행이다 (열 기본값은 모두 켬)
    expect(await db.select(db.notificationLog).get(), isEmpty);
    expect(await db.select(db.notificationSettings).get(), isEmpty);
    await _insertNotice(db);
    final notices = await db.select(db.notificationLog).get();
    expect(notices.map((r) => (r.kind, r.refKey, r.atUtc, r.status)), [
      (NoticeKind.n2, 'j1', 10, NoticeStatus.sent),
      (NoticeKind.n5, '', 20, NoticeStatus.scheduled),
    ]);
    expect(notices[0].id, isNot(notices[1].id));
    await db
        .into(db.notificationSettings)
        .insert(NotificationSettingsCompanion.insert(id: const Value(1)));
    final settings = await db.select(db.notificationSettings).getSingle();
    expect(
        [settings.allOn, settings.n1On, settings.n2On, settings.n3On, settings.n4On, settings.n5On],
        everyElement(isTrue));
    // 동기화 상태: 복원한 마지막 날 열은 비워 둘 수 있다
    expect(await _columns(db, 'sync_state'), [
      'id',
      'last_fetched_utc',
      'first_record_day',
      'install_utc',
      'restore_floor_day',
      'last_alive_utc',
    ]);
    await db.into(db.syncState).insert(SyncStateCompanion.insert(
        id: const Value(1), firstRecordDay: '2026-11-18', installUtc: 100));
    expect((await db.select(db.syncState).getSingle()).restoreFloorDay, isNull);
    expect(await _columns(db, 'notification_log'), ['id', 'kind', 'ref_key', 'at_utc', 'status']);
    expect(await _columns(db, 'notification_settings'),
        ['id', 'all_on', 'n1_on', 'n2_on', 'n3_on', 'n4_on', 'n5_on']);
  });

  test('insertOnConflictUpdate는 companion에 없는 열(seen)을 갱신하지 않는다', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);

    PaintingsOwnedCompanion painting(int visits, {Value<bool> seen = const Value.absent()}) =>
        PaintingsOwnedCompanion.insert(
          landmarkId: 'kr001',
          visits: visits,
          frame: Frame.wood,
          bestKm: 5,
          firstArrivedUtc: 1,
          lastArrivedUtc: visits,
          seen: seen,
        );
    Future<(int, bool)> row() async {
      final r = await db.select(db.paintingsOwned).getSingle();
      return (r.visits, r.seen);
    }

    // seen을 빼고 충돌 갱신하면 다른 열만 바뀌고, 안 본 그림은 안 본 채, 본 그림은 본 채
    await db.into(db.paintingsOwned).insert(painting(1, seen: const Value(false)));
    await db.into(db.paintingsOwned).insertOnConflictUpdate(painting(2));
    expect(await row(), (2, false));

    await db.into(db.paintingsOwned).insertOnConflictUpdate(painting(3, seen: const Value(true)));
    expect(await row(), (3, true));
    await db.into(db.paintingsOwned).insertOnConflictUpdate(painting(4));
    expect(await row(), (4, true));
  });

  test('스키마 1(여정 표만 있던 때)에서 열면 15로 올라가고 옛 행이 남는다', () async {
    // 스키마 1의 journeys 표와 행 둘(도착, 멈춤)을 직접 만들어 두고 user_version = 1로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
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
    expect(await _userVersion(db), 15);
    expect(rows.keys, {'j1', 'j2'});
    // 동기화 상태는 그대로이고 새 열은 비어 있다
    final sync = await db.select(db.syncState).getSingle();
    expect((sync.lastFetchedUtc, sync.firstRecordDay, sync.installUtc, sync.restoreFloorDay),
        (500, '2026-11-18', 100, null));
    // 새 열은 비어 있고, 옛 도착 여정은 도착 화면을 이미 본 것으로 둔다
    expect(rows['j1']!.endLat, isNull);
    expect(rows['j1']!.visitNo, isNull);
    expect(rows['j1']!.arrivalShown, isTrue);
    expect(rows['j2']!.arrivalShown, isFalse);
    expect(rows['j2']!.status, JourneyStatus.stopped);
    expect(rows['j2']!.fundKm, 1);
    // 가상 목적지 열도 생겼고 비어 있다
    expect((rows['j1']!.destLat, rows['j1']!.destLng), (null, null));

    // 새 열·새 표를 쓸 수 있다
    await (db.update(db.journeys)..where((t) => t.id.equals('j2'))).write(
        const JourneysCompanion(endLat: Value(37.5), prevFrame: Value(Frame.wood)));
    expect((await (db.select(db.journeys)..where((t) => t.id.equals('j2'))).getSingle()).prevFrame,
        Frame.wood);
    expect(await db.select(db.paintingsOwned).get(), isEmpty);
    expect(await db.select(db.propsOwned).get(), isEmpty);
    expect(await db.select(db.profile).get(), isEmpty);
    expect(await _hasTable(db, 'wall_slots'), isFalse);
    // 방명록 표도 새로 생겼고 비어 있다. 쓸 수 있다
    expect(await db.select(db.guestbookTickets).get(), isEmpty);
    expect(await db.select(db.guestbookPosts).get(), isEmpty);
    await _insertGuestbook(db);
    expect((await db.select(db.guestbookPosts).getSingle()).body, '좋았어요');
    // 1에서 올라오면 프로필 표도 처음부터 시작 흐름 열이 있다 (열을 또 더하다 실패하지 않는다)
    await db.into(db.profile).insert(ProfileCompanion.insert(
        id: const Value(1), nickname: const Value('화가'), onboardedAt: const Value(7)));
    expect((await db.select(db.profile).getSingle()).nickname, '화가');
    // 1에서 올라오면 그림 표는 처음부터 seen 열이 있다 (열을 또 더하다 실패하지 않는다)
    await db.into(db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
          landmarkId: 'kr001',
          visits: 1,
          frame: Frame.wood,
          bestKm: 5,
          firstArrivedUtc: 1,
          lastArrivedUtc: 1,
          seen: const Value(false),
        ));
    expect((await db.select(db.paintingsOwned).getSingle()).seen, isFalse);
    // 그림 표는 지금 정의 그대로다 (다시 그리는 값 열은 어디서 올라와도 없다)
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
  });

  test('스키마 2(프로필 표가 없던 때)에서 열면 15로 올라가고 옛 행이 그대로 남는다', () async {
    // 스키마 2의 journeys 표(새 열 포함)·그림·소품 표와 행을 직접 만들어 두고 user_version = 2로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
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
    expect(await _userVersion(db), 15);
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
    // 2에서 올라오면 프로필 표는 처음부터 시작 흐름 열이 있다 (열을 또 더하다 실패하지 않는다)
    await db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
        id: const Value(1), installId: Value('a' * 32), ageConfirmedAt: const Value(9)));
    final profile = await db.select(db.profile).getSingle();
    expect((profile.homeName, profile.installId, profile.ageConfirmedAt), ('종로구', 'a' * 32, 9));
    // 스키마 2의 그림·소품도 그대로
    final painting = await db.select(db.paintingsOwned).getSingle();
    expect((painting.landmarkId, painting.visits, painting.frame), ('kr001', 2, Frame.silver));
    expect(painting.seen, isTrue);
    // 그림 표에는 열이 더해지지 않았다. 여정 표에는 가상 목적지 열이 생겼다
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
    expect(rows['j1']!.destLat, isNull);
    expect((await db.select(db.propsOwned).getSingle()).seen, isTrue);
    // 화집 벽 표는 13에서 없어졌다
    expect(await _hasTable(db, 'wall_slots'), isFalse);
  });

  test('스키마 3(화집 벽 표가 없던 때)에서 열면 15로 올라가고 옛 행이 그대로 남는다', () async {
    // 스키마 3의 journeys·그림·소품·프로필 표와 행을 직접 만들어 두고 user_version = 3으로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
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
      // 도착했고 도착 화면을 아직 안 본 여정 (3 → 4에서 건드리면 안 된다)
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'kr001', 10, 0, 5, 'arrived', "
          "20, 37.5, 127.0, NULL, 1, NULL, 'wood', 0)");
      raw.execute('''
        CREATE TABLE paintings_owned (
          landmark_id TEXT NOT NULL, visits INTEGER NOT NULL, frame TEXT NOT NULL,
          best_km REAL NOT NULL, first_arrived_utc INTEGER NOT NULL,
          last_arrived_utc INTEGER NOT NULL, PRIMARY KEY (landmark_id))
      ''');
      raw.execute("INSERT INTO paintings_owned VALUES ('kr001', 1, 'wood', 5, 20, 20)");
      raw.execute('''
        CREATE TABLE props_owned (
          prop_id TEXT NOT NULL, unlocked_utc INTEGER NOT NULL,
          seen INTEGER NOT NULL DEFAULT 0 CHECK (seen IN (0, 1)), PRIMARY KEY (prop_id))
      ''');
      raw.execute("INSERT INTO props_owned VALUES ('hat_01', 5, 1)");
      raw.execute('''
        CREATE TABLE profile (
          id INTEGER NOT NULL, home_name TEXT NULL, home_lat REAL NULL, home_lng REAL NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO profile VALUES (1, '종로구', 37.57, 126.98)");
      raw.execute('PRAGMA user_version = 3');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    final j = await db.select(db.journeys).getSingle();
    expect((j.id, j.status, j.visitNo, j.newFrame, j.arrivalShown),
        ('j1', JourneyStatus.arrived, 1, Frame.wood, false));
    final painting = await db.select(db.paintingsOwned).getSingle();
    expect((painting.landmarkId, painting.visits, painting.frame), ('kr001', 1, Frame.wood));
    expect(painting.seen, isTrue);
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
    expect(j.destLng, isNull);
    expect((await db.select(db.propsOwned).getSingle()).propId, 'hat_01');
    // 프로필의 옛 열은 그대로고 시작 흐름 열이 새로 생겨 비어 있다
    final profile = await db.select(db.profile).getSingle();
    expect((profile.homeName, profile.homeLat, profile.homeLng), ('종로구', 37.57, 126.98));
    expect([profile.homeId, profile.ageConfirmedAt, profile.nickname, profile.onboardedAt],
        everyElement(isNull));

    // 화집 벽 표는 13에서 없앴다 (3에서 만들었다가 지운다)
    expect(await _hasTable(db, 'wall_slots'), isFalse);
  });

  test('스키마 4(그림 표에 seen 열이 없던 때)에서 열면 15로 올라가고 옛 그림은 본 것이다', () async {
    // 스키마 4의 journeys·그림·소품·프로필·벽 표와 행을 직접 만들어 두고 user_version = 4로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
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
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'kr001', 10, 0, 5, 'arrived', "
          "20, 37.5, 127.0, NULL, 1, NULL, 'wood', 0)");
      raw.execute('''
        CREATE TABLE paintings_owned (
          landmark_id TEXT NOT NULL, visits INTEGER NOT NULL, frame TEXT NOT NULL,
          best_km REAL NOT NULL, first_arrived_utc INTEGER NOT NULL,
          last_arrived_utc INTEGER NOT NULL, PRIMARY KEY (landmark_id))
      ''');
      raw.execute("INSERT INTO paintings_owned VALUES ('kr001', 1, 'wood', 5, 20, 20)");
      raw.execute("INSERT INTO paintings_owned VALUES ('kr002', 3, 'gold', 60, 30, 90)");
      raw.execute('''
        CREATE TABLE props_owned (
          prop_id TEXT NOT NULL, unlocked_utc INTEGER NOT NULL,
          seen INTEGER NOT NULL DEFAULT 0 CHECK (seen IN (0, 1)), PRIMARY KEY (prop_id))
      ''');
      raw.execute("INSERT INTO props_owned VALUES ('hat_01', 5, 0)");
      raw.execute('''
        CREATE TABLE profile (
          id INTEGER NOT NULL, home_name TEXT NULL, home_lat REAL NULL, home_lng REAL NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO profile VALUES (1, '종로구', 37.57, 126.98)");
      raw.execute('''
        CREATE TABLE wall_slots (
          slot INTEGER NOT NULL, landmark_id TEXT NOT NULL, PRIMARY KEY (slot))
      ''');
      raw.execute("INSERT INTO wall_slots VALUES (0, 'kr002')");
      raw.execute('PRAGMA user_version = 4');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    // 옛 그림은 모두 본 것으로 두고, 다른 열은 그대로
    final paintings = {for (final r in await db.select(db.paintingsOwned).get()) r.landmarkId: r};
    expect(paintings.keys, {'kr001', 'kr002'});
    expect(paintings.values.every((r) => r.seen), isTrue);
    expect((paintings['kr002']!.visits, paintings['kr002']!.frame, paintings['kr002']!.bestKm),
        (3, Frame.gold, 60));
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
    // 다른 표의 옛 행도 그대로 (소품은 안 본 채)
    expect((await db.select(db.journeys).getSingle()).newFrame, Frame.wood);
    expect((await db.select(db.propsOwned).getSingle()).seen, isFalse);
    expect((await db.select(db.profile).getSingle()).homeName, '종로구');
    // 옛 벽 표는 13에서 지워진다
    expect(await _hasTable(db, 'wall_slots'), isFalse);

    // 새 열을 쓸 수 있다: 새로 넣는 그림은 seen을 false로 둘 수 있고, 안 넣으면 true
    await db.into(db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
          landmarkId: 'kr003',
          visits: 1,
          frame: Frame.silver,
          bestKm: 22,
          firstArrivedUtc: 100,
          lastArrivedUtc: 100,
          seen: const Value(false),
        ));
    await db.into(db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
          landmarkId: 'kr004',
          visits: 1,
          frame: Frame.wood,
          bestKm: 3,
          firstArrivedUtc: 100,
          lastArrivedUtc: 100,
        ));
    final all = {for (final r in await db.select(db.paintingsOwned).get()) r.landmarkId: r.seen};
    expect(all, {'kr001': true, 'kr002': true, 'kr003': false, 'kr004': true});
  });

  test('스키마 5(프로필에 시작 흐름 열이 없던 때)에서 열면 15로 올라가고 옛 행이 그대로 남는다', () async {
    // 스키마 5의 여정·그림·프로필·벽 표와 행을 직접 만들어 두고 user_version = 5로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
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
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'kr001', 10, 0, 5, 'arrived', "
          "20, 37.5, 127.0, NULL, 1, NULL, 'wood', 1)");
      raw.execute('''
        CREATE TABLE paintings_owned (
          landmark_id TEXT NOT NULL, visits INTEGER NOT NULL, frame TEXT NOT NULL,
          best_km REAL NOT NULL, first_arrived_utc INTEGER NOT NULL,
          last_arrived_utc INTEGER NOT NULL,
          seen INTEGER NOT NULL DEFAULT 1 CHECK (seen IN (0, 1)), PRIMARY KEY (landmark_id))
      ''');
      raw.execute("INSERT INTO paintings_owned VALUES ('kr001', 1, 'wood', 5, 20, 20, 0)");
      raw.execute('''
        CREATE TABLE profile (
          id INTEGER NOT NULL, home_name TEXT NULL, home_lat REAL NULL, home_lng REAL NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO profile VALUES (1, '종로구', 37.57, 126.98)");
      raw.execute('''
        CREATE TABLE wall_slots (
          slot INTEGER NOT NULL, landmark_id TEXT NOT NULL, PRIMARY KEY (slot))
      ''');
      raw.execute("INSERT INTO wall_slots VALUES (0, 'kr001')");
      raw.execute('PRAGMA user_version = 5');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    // 옛 프로필 행은 그대로고 새 열 여덟 개는 비어 있다
    var profile = await db.select(db.profile).getSingle();
    expect((profile.id, profile.homeName, profile.homeLat, profile.homeLng),
        (1, '종로구', 37.57, 126.98));
    expect([
      profile.homeId,
      profile.ageConfirmedAt,
      profile.installId,
      profile.nickname,
      profile.look,
      profile.onboardedAt,
      profile.linkConsentAt,
      profile.guestbookConsentAt,
    ], everyElement(isNull));
    // 다른 표의 옛 행도 그대로 (여정 표에는 가상 목적지 열이 생겨 비어 있다)
    expect((await db.select(db.journeys).getSingle()).destLat, isNull);
    expect((await db.select(db.paintingsOwned).getSingle()).seen, isFalse);
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
    // 옛 벽 표는 13에서 지워진다
    expect(await _hasTable(db, 'wall_slots'), isFalse);

    // 새 열을 쓸 수 있고, 일부 열만 넣어도 다른 열은 그대로다
    await db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
      id: const Value(1),
      ageConfirmedAt: const Value(100),
      installId: Value('b' * 32),
      nickname: const Value('화가'),
      look: const Value('{"hair":1}'),
      homeId: const Value('11140'),
      onboardedAt: const Value(200),
      linkConsentAt: const Value(300),
      guestbookConsentAt: const Value(400),
    ));
    await db.into(db.profile).insertOnConflictUpdate(
        const ProfileCompanion(id: Value(1), nickname: Value('나그네')));
    profile = await db.select(db.profile).getSingle();
    expect((profile.homeName, profile.nickname, profile.installId), ('종로구', '나그네', 'b' * 32));
    expect((profile.ageConfirmedAt, profile.onboardedAt, profile.homeId), (100, 200, '11140'));
    expect((profile.linkConsentAt, profile.guestbookConsentAt), (300, 400));
    expect(profile.look, '{"hair":1}');
  });

  test('스키마 6(가상 목적지·스케치 열이 없던 때)에서 열면 15로 올라가고 옛 행이 그대로 남는다', () async {
    // 스키마 6의 여정·그림·프로필 표와 행을 직접 만들어 두고 user_version = 6으로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
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
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'kr001', 10, 0, 5, 'arrived', "
          "20, 37.5, 127.0, NULL, 1, NULL, 'wood', 1)");
      raw.execute('''
        CREATE TABLE paintings_owned (
          landmark_id TEXT NOT NULL, visits INTEGER NOT NULL, frame TEXT NOT NULL,
          best_km REAL NOT NULL, first_arrived_utc INTEGER NOT NULL,
          last_arrived_utc INTEGER NOT NULL,
          seen INTEGER NOT NULL DEFAULT 1 CHECK (seen IN (0, 1)), PRIMARY KEY (landmark_id))
      ''');
      raw.execute("INSERT INTO paintings_owned VALUES ('kr001', 2, 'silver', 22.5, 20, 50, 0)");
      raw.execute('''
        CREATE TABLE profile (
          id INTEGER NOT NULL, home_name TEXT NULL, home_lat REAL NULL, home_lng REAL NULL,
          home_id TEXT NULL, age_confirmed_at INTEGER NULL, install_id TEXT NULL,
          nickname TEXT NULL, look TEXT NULL, onboarded_at INTEGER NULL,
          link_consent_at INTEGER NULL, guestbook_consent_at INTEGER NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO profile VALUES (1, '종로구', 37.57, 126.98, '11110', 1, '"
          "${'c' * 32}', '화가', NULL, 2, NULL, NULL)");
      raw.execute('PRAGMA user_version = 6');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    // 옛 행은 그대로고 새 열은 비어 있다
    var journey = await db.select(db.journeys).getSingle();
    expect((journey.id, journey.destId, journey.status, journey.visitNo, journey.arrivalShown),
        ('j1', 'kr001', JourneyStatus.arrived, 1, true));
    expect((journey.destLat, journey.destLng), (null, null));
    var painting = await db.select(db.paintingsOwned).getSingle();
    expect((painting.landmarkId, painting.visits, painting.frame, painting.seen),
        ('kr001', 2, Frame.silver, false));
    // 그림 표는 v6 그대로 (v7은 여정 표에만 열을 더한다)
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
    final profile = await db.select(db.profile).getSingle();
    expect((profile.homeName, profile.installId, profile.nickname), ('종로구', 'c' * 32, '화가'));

    // 새 열을 쓸 수 있다: 가상 목적지 좌표. 첫 그림 행은 다시 그리는 값 없이 들어간다
    await (db.update(db.journeys)..where((t) => t.id.equals('j1')))
        .write(const JourneysCompanion(destLat: Value(37.6), destLng: Value(127.01)));
    await db.into(db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
          landmarkId: 'sketch',
          visits: 1,
          frame: Frame.wood,
          bestKm: 2.5,
          firstArrivedUtc: 30,
          lastArrivedUtc: 30,
          seen: const Value(false),
        ));
    journey = await db.select(db.journeys).getSingle();
    expect((journey.destLat, journey.destLng), (37.6, 127.01));
    painting = await (db.select(db.paintingsOwned)..where((t) => t.landmarkId.equals('sketch')))
        .getSingle();
    expect((painting.visits, painting.frame, painting.seen), (1, Frame.wood, false));
  });

  test('스키마 7(방명록 표가 없던 때)에서 열면 15로 올라가고 옛 행이 그대로 남는다', () async {
    // 스키마 7의 여정·그림·프로필 표와 행을 직접 만들어 두고 user_version = 7로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
      raw.execute('''
        CREATE TABLE journeys (
          id TEXT NOT NULL, origin_lat REAL NOT NULL, origin_lng REAL NOT NULL,
          dest_id TEXT NOT NULL, start_utc INTEGER NOT NULL, fund_km REAL NOT NULL,
          total_effective_km REAL NOT NULL, status TEXT NOT NULL, arrived_utc INTEGER NULL,
          end_lat REAL NULL, end_lng REAL NULL, ended_utc INTEGER NULL,
          visit_no INTEGER NULL, prev_frame TEXT NULL, new_frame TEXT NULL,
          arrival_shown INTEGER NOT NULL DEFAULT 0 CHECK (arrival_shown IN (0, 1)),
          dest_lat REAL NULL, dest_lng REAL NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'sketch', 10, 0, 2.5, "
          "'arrived', 20, 38.01, 128.01, NULL, 1, NULL, 'wood', 1, 38.01, 128.01)");
      raw.execute('''
        CREATE TABLE paintings_owned (
          landmark_id TEXT NOT NULL, visits INTEGER NOT NULL, frame TEXT NOT NULL,
          best_km REAL NOT NULL, first_arrived_utc INTEGER NOT NULL,
          last_arrived_utc INTEGER NOT NULL,
          seen INTEGER NOT NULL DEFAULT 1 CHECK (seen IN (0, 1)), PRIMARY KEY (landmark_id))
      ''');
      raw.execute("INSERT INTO paintings_owned VALUES ('sketch', 1, 'wood', 2.5, 20, 20, 0)");
      raw.execute('''
        CREATE TABLE profile (
          id INTEGER NOT NULL, home_name TEXT NULL, home_lat REAL NULL, home_lng REAL NULL,
          home_id TEXT NULL, age_confirmed_at INTEGER NULL, install_id TEXT NULL,
          nickname TEXT NULL, look TEXT NULL, onboarded_at INTEGER NULL,
          link_consent_at INTEGER NULL, guestbook_consent_at INTEGER NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO profile VALUES (1, '종로구', 37.57, 126.98, '11110', 1, '"
          "${'d' * 32}', '화가', NULL, 2, NULL, NULL)");
      raw.execute('PRAGMA user_version = 7');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    // 옛 행은 그대로 (v8은 새 표만 더한다)
    final journey = await db.select(db.journeys).getSingle();
    expect((journey.id, journey.destId, journey.status, journey.destLat),
        ('j1', 'sketch', JourneyStatus.arrived, 38.01));
    final painting = await db.select(db.paintingsOwned).getSingle();
    expect((painting.landmarkId, painting.seen), ('sketch', false));
    expect(await _columns(db, 'paintings_owned'), _paintingColumns);
    final profile = await db.select(db.profile).getSingle();
    expect((profile.homeName, profile.installId, profile.guestbookConsentAt),
        ('종로구', 'd' * 32, null));

    // 방명록 표 둘이 새로 생겼고 비어 있다. 쓸 수 있다
    expect(await db.select(db.guestbookTickets).get(), isEmpty);
    expect(await db.select(db.guestbookPosts).get(), isEmpty);
    await db.into(db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
          id: 'm:100',
          kind: TicketKind.milestone,
          scope: 'steps:100',
          openedUtc: 5,
        ));
    await _insertGuestbook(db);
    final tickets = {for (final r in await db.select(db.guestbookTickets).get()) r.id: r};
    expect(tickets.keys, {'m:100', 'a:j1'});
    expect((tickets['m:100']!.usedUtc, tickets['m:100']!.closedUtc), (null, null));
    expect(tickets['m:100']!.kind, TicketKind.milestone);
    expect((await db.select(db.guestbookPosts).getSingle()).status, PostStatus.pending);
  });

  test('스키마 8(알림 표가 없던 때)에서 열면 15로 올라가고 옛 행이 그대로 남는다', () async {
    // 스키마 8의 방명록 표와 행을 직접 만들어 두고 user_version = 8로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldJourneys(raw);
      _createOldSyncState(raw);
      raw.execute('''
        CREATE TABLE guestbook_tickets (
          id TEXT NOT NULL, kind TEXT NOT NULL, scope TEXT NOT NULL,
          opened_utc INTEGER NOT NULL, used_utc INTEGER NULL, closed_utc INTEGER NULL,
          PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO guestbook_tickets VALUES ('m:100', 'milestone', 'steps:100', 5, "
          'NULL, NULL)');
      raw.execute('''
        CREATE TABLE guestbook_posts (
          ticket_id TEXT NOT NULL, scope TEXT NOT NULL, body TEXT NOT NULL,
          created_utc INTEGER NOT NULL, status TEXT NOT NULL, PRIMARY KEY (ticket_id))
      ''');
      raw.execute("INSERT INTO guestbook_posts VALUES ('m:100', 'steps:100', '좋아요', 6, 'pending')");
      _createOldProfile(raw);
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    // 옛 행은 그대로 (v9는 새 표만 더한다)
    final ticket = await db.select(db.guestbookTickets).getSingle();
    expect((ticket.id, ticket.kind, ticket.openedUtc), ('m:100', TicketKind.milestone, 5));
    expect((await db.select(db.guestbookPosts).getSingle()).body, '좋아요');

    // 알림 표 둘이 새로 생겼고 비어 있다. 쓸 수 있다
    expect(await db.select(db.notificationLog).get(), isEmpty);
    expect(await db.select(db.notificationSettings).get(), isEmpty);
    await _insertNotice(db);
    expect((await db.select(db.notificationLog).get()).map((r) => r.status),
        [NoticeStatus.sent, NoticeStatus.scheduled]);
    await db.into(db.notificationSettings).insert(NotificationSettingsCompanion.insert(
          id: const Value(1),
          allOn: const Value(false),
          n3On: const Value(false),
        ));
    final settings = await db.select(db.notificationSettings).getSingle();
    expect((settings.allOn, settings.n1On, settings.n3On), (false, true, false));
  });

  test('스키마 9(동기화 상태에 복원한 마지막 날 열이 없던 때)에서 열면 15로 올라가고 옛 행이 그대로 남는다',
      () async {
    // 스키마 9의 동기화 상태·하루 요약·걷기 구간 표와 행을 직접 만들어 두고 user_version = 9로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldJourneys(raw);
      _createOldSyncState(raw);
      raw.execute("INSERT INTO day_summaries VALUES ('2026-11-18', 8123, 5686.1, 2)");
      raw.execute("INSERT INTO walk_sessions VALUES (1000, 2000, 3000, 2100.0, 0.25, 1, 1)");
      _createOldProfile(raw);
      raw.execute('PRAGMA user_version = 9');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    expect(await _columns(db, 'sync_state'), [
      'id',
      'last_fetched_utc',
      'first_record_day',
      'install_utc',
      'restore_floor_day',
      'last_alive_utc',
    ]);
    // 옛 행은 그대로고 새 열은 비어 있다 (복원한 적이 없다)
    var sync = await db.select(db.syncState).getSingle();
    expect((sync.lastFetchedUtc, sync.firstRecordDay, sync.installUtc, sync.restoreFloorDay),
        (500, '2026-11-18', 100, null));
    final day = await db.select(db.daySummaries).getSingle();
    expect((day.day, day.steps, day.distanceM, day.countedSessions),
        ('2026-11-18', 8123, 5686.1, 2));
    expect((await db.select(db.walkSessions).getSingle()).steps, 3000);

    // 새 열을 쓸 수 있고, 일부 열만 넣어도 다른 열은 그대로다
    await (db.update(db.syncState)..where((t) => t.id.equals(1)))
        .write(const SyncStateCompanion(restoreFloorDay: Value('2026-11-18')));
    await (db.update(db.syncState)..where((t) => t.id.equals(1)))
        .write(const SyncStateCompanion(lastFetchedUtc: Value(900)));
    sync = await db.select(db.syncState).getSingle();
    expect((sync.lastFetchedUtc, sync.restoreFloorDay), (900, '2026-11-18'));
  });

  test('스키마 10(본격 걷기 열·표가 없던 때)에서 열면 15로 올라가고 옛 하루의 이동 거리는 실제 거리가 된다',
      () async {
    // 스키마 10의 동기화 상태(복원한 마지막 날 열 있음)·하루 요약·걷기 구간 표와 행을 직접 만들고
    // user_version = 10으로 연다
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldJourneys(raw);
      raw.execute('''
        CREATE TABLE sync_state (
          id INTEGER NOT NULL, last_fetched_utc INTEGER NULL, first_record_day TEXT NOT NULL,
          install_utc INTEGER NOT NULL, restore_floor_day TEXT NULL, PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO sync_state VALUES (1, 500, '2026-11-18', 100, '2026-11-17')");
      _createOldDayTables(raw);
      raw.execute("INSERT INTO day_summaries VALUES ('2026-11-18', 8123, 5686.1, 2)");
      raw.execute("INSERT INTO day_summaries VALUES ('2026-11-19', 0, 0.0, 0)");
      raw.execute("INSERT INTO walk_sessions VALUES (1000, 2000, 3000, 2100.0, 0.25, 1, 1)");
      _createOldProfile(raw);
      raw.execute('PRAGMA user_version = 10');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    expect(await _columns(db, 'day_summaries'), [
      'day',
      'steps',
      'distance_m',
      'counted_sessions',
      'bonus_m',
      'shop_m',
      'travel_m',
      'walk_travel_m',
      'coins',
    ]);
    expect(await _columns(db, 'walk_sessions'), [
      'start_utc',
      'end_utc',
      'steps',
      'distance_m',
      'run_ratio',
      'qualified',
      'counted',
      'bonus_m',
    ]);
    expect(await _columns(db, 'app_walks'), ['id', 'start_utc', 'end_utc', 'end_reason']);
    expect(await _columns(db, 'coin_ledger'), ['id', 'day', 'kind', 'amount', 'ref_id']);
    expect(await _columns(db, 'sync_state'), [
      'id',
      'last_fetched_utc',
      'first_record_day',
      'install_utc',
      'restore_floor_day',
      'last_alive_utc',
    ]);

    // 옛 하루: 앱 걷기가 없던 때라 이동 거리 = 실제 거리, 보너스·앱 걷기 이동 거리·럭은 0
    final days = {for (final d in await db.select(db.daySummaries).get()) d.day: d};
    expect((days['2026-11-18']!.steps, days['2026-11-18']!.distanceM), (8123, 5686.1));
    expect(days['2026-11-18']!.travelM, 5686.1);
    expect((days['2026-11-18']!.bonusM, days['2026-11-18']!.shopM), (0, 0));
    expect((days['2026-11-18']!.walkTravelM, days['2026-11-18']!.coins), (0, 0));
    expect(days['2026-11-19']!.travelM, 0);
    final session = await db.select(db.walkSessions).getSingle();
    expect((session.steps, session.distanceM, session.bonusM), (3000, 2100.0, 0));
    final sync = await db.select(db.syncState).getSingle();
    expect((sync.lastFetchedUtc, sync.restoreFloorDay, sync.lastAliveUtc), (500, '2026-11-17', null));

    // 새 표를 쓸 수 있다
    final id = await db.into(db.appWalks).insert(AppWalksCompanion.insert(startUtc: 100));
    var walk = await db.select(db.appWalks).getSingle();
    expect((walk.id, walk.startUtc, walk.endUtc, walk.endReason), (id, 100, null, null));
    await (db.update(db.appWalks)..where((t) => t.id.equals(id))).write(
        const AppWalksCompanion(endUtc: Value(200), endReason: Value(AppWalkEnd.appEnded)));
    walk = await db.select(db.appWalks).getSingle();
    expect((walk.endUtc, walk.endReason), (200, AppWalkEnd.appEnded));
    await db.into(db.coinLedger).insert(CoinLedgerCompanion.insert(
        day: '2026-11-18', kind: CoinKind.earn, amount: 40));
    await db.into(db.coinLedger).insert(CoinLedgerCompanion.insert(
        day: '2026-11-18', kind: CoinKind.ad, amount: 5, refId: const Value('ad-1')));
    final ledger = await db.select(db.coinLedger).get();
    expect(ledger.map((r) => (r.id, r.kind, r.amount, r.refId)),
        [(1, CoinKind.earn, 40, null), (2, CoinKind.ad, 5, 'ad-1')]);
  });

  test('스키마 11(표시 글꼴 열이 없던 때)에서 열면 15로 올라가고 프로필은 그대로, 글꼴은 비어 있다', () async {
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldJourneys(raw);
      _createOldProfile(raw);
      raw.execute("INSERT INTO profile (id, nickname, home_name) VALUES (1, '화가', '서울 종로구')");
      raw.execute('PRAGMA user_version = 11');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    expect(await _columns(db, 'profile'), isNot(contains('display_font')));
    final row = await db.select(db.profile).getSingle();
    expect((row.nickname, row.homeName), ('화가', '서울 종로구'));
  });

  test('스키마 13(표시 글꼴 열이 있던 때)에서 열면 15로 올라가고 그 열만 지운다', () async {
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldJourneys(raw);
      _createOldProfile(raw);
      raw.execute('ALTER TABLE profile ADD COLUMN display_font TEXT NULL');
      raw.execute(
          "INSERT INTO profile (id, nickname, home_name, display_font) VALUES (1, '화가', '서울 종로구', 'dongle')");
      raw.execute('PRAGMA user_version = 13');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    expect(await _columns(db, 'profile'), isNot(contains('display_font')));
    final row = await db.select(db.profile).getSingle();
    expect((row.nickname, row.homeName), ('화가', '서울 종로구'));
  });

  test('스키마 12(길 위 이벤트·도장이 없던 때)에서 열면 15로 올라가고 기존 데이터가 그대로 남는다', () async {
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldSyncState(raw);
      _createOldProfile(raw);
      raw.execute('''
        CREATE TABLE journeys (
          id TEXT NOT NULL, origin_lat REAL NOT NULL, origin_lng REAL NOT NULL,
          dest_id TEXT NOT NULL, start_utc INTEGER NOT NULL, fund_km REAL NOT NULL,
          total_effective_km REAL NOT NULL, status TEXT NOT NULL, arrived_utc INTEGER NULL,
          end_lat REAL NULL, end_lng REAL NULL, ended_utc INTEGER NULL,
          visit_no INTEGER NULL, prev_frame TEXT NULL, new_frame TEXT NULL,
          arrival_shown INTEGER NOT NULL DEFAULT 0 CHECK (arrival_shown IN (0, 1)),
          dest_lat REAL NULL, dest_lng REAL NULL, PRIMARY KEY (id))
      ''');
      raw.execute("INSERT INTO journeys VALUES ('j1', 38.0, 128.0, 'kr001', 10, 3, 40, 'active', "
          'NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL)');
      raw.execute("INSERT INTO journeys VALUES ('j0', 38.0, 128.0, 'kr002', 5, 0, 7, 'arrived', "
          "20, 37.5, 127.0, NULL, 1, NULL, 'wood', 1, NULL, NULL)");
      raw.execute('''
        CREATE TABLE props_owned (
          prop_id TEXT NOT NULL, unlocked_utc INTEGER NOT NULL,
          seen INTEGER NOT NULL DEFAULT 0 CHECK (seen IN (0, 1)), PRIMARY KEY (prop_id))
      ''');
      raw.execute("INSERT INTO props_owned VALUES ('hat_01', 5, 1)");
      raw.execute('''
        CREATE TABLE wall_slots (
          slot INTEGER NOT NULL, landmark_id TEXT NOT NULL, PRIMARY KEY (slot))
      ''');
      raw.execute("INSERT INTO wall_slots VALUES (0, 'kr002')");
      raw.execute('PRAGMA user_version = 12');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    // 기존 여정은 그대로고 새 열 eventM은 0이다
    final rows = {for (final r in await db.select(db.journeys).get()) r.id: r};
    expect(rows.keys, {'j0', 'j1'});
    expect((rows['j1']!.fundKm, rows['j1']!.totalEffectiveKm, rows['j1']!.status),
        (3, 40, JourneyStatus.active));
    expect((rows['j0']!.visitNo, rows['j0']!.arrivalShown), (1, true));
    expect([rows['j0']!.eventM, rows['j1']!.eventM], [0, 0]);
    expect((await db.select(db.propsOwned).getSingle()).propId, 'hat_01');
    expect((await db.select(db.syncState).getSingle()).lastFetchedUtc, 500);
    // 새 표는 비어 있고, 안 쓰는 화집 벽 표는 지워졌다 (그 안의 행도 함께)
    expect(await db.select(db.journeyEvents).get(), isEmpty);
    expect(await db.select(db.badgesOwned).get(), isEmpty);
    expect(await _hasTable(db, 'wall_slots'), isFalse);
    expect(await _columns(db, 'journey_events'), [
      'journey_id', 'k', 'terrain', 'season', 'night', 'scene_text_id', 'praise_id',
      'praise_text', 'progress_pct', 'at_utc',
    ]);
    expect(await _columns(db, 'badges_owned'), ['badge_id', 'at_utc', 'seen']);

    // 새 열·표를 쓸 수 있다. 이벤트는 (여정, 칸)이 키, 도장은 id가 키, 도장의 seen은 기본 false
    await (db.update(db.journeys)..where((t) => t.id.equals('j1')))
        .write(const JourneysCompanion(eventM: Value(2500.5)));
    expect(
        (await (db.select(db.journeys)..where((t) => t.id.equals('j1'))).getSingle()).eventM, 2500.5);
    await db.into(db.journeyEvents).insert(JourneyEventsCompanion.insert(
          journeyId: 'j1',
          k: 1,
          terrain: 'field',
          season: 'autumn',
          night: false,
          sceneTextId: 'S1',
          praiseId: 'R10',
          praiseText: '발이 길을 기억하기 시작했어.',
          atUtc: 100,
        ));
    expect(
        () => db.into(db.journeyEvents).insert(JourneyEventsCompanion.insert(
              journeyId: 'j1',
              k: 1,
              terrain: 'field',
              season: 'autumn',
              night: false,
              sceneTextId: 'S1',
              praiseId: 'R10',
              praiseText: '또',
              atUtc: 200,
            )),
        throwsA(anything));
    expect((await db.select(db.journeyEvents).getSingle()).progressPct, 0);
    await db.into(db.badgesOwned).insert(BadgesOwnedCompanion.insert(badgeId: 'b_first_walk', atUtc: 9));
    expect((await db.select(db.badgesOwned).getSingle()).seen, isFalse);
  });

  test('스키마 14에서 열면 15로 올라가고 프로필에 고른 배 열, 새 표 다섯이 생긴다', () async {
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      _createOldProfile(raw);
      raw.execute("INSERT INTO profile (id, nickname) VALUES (1, '화가')");
      raw.execute('PRAGMA user_version = 14');
    }));
    addTearDown(db.close);

    expect(await _userVersion(db), 15);
    final row = await db.select(db.profile).getSingle();
    expect((row.nickname, row.boatId), ('화가', null));
    expect(await db.select(db.companions).get(), isEmpty);
    expect(await db.select(db.companionStints).get(), isEmpty);
    expect(await db.select(db.shopInventory).get(), isEmpty);
    expect(await db.select(db.shopUses).get(), isEmpty);
    expect(await db.select(db.boatsOwned).get(), isEmpty);
  });

  test('동행·상점·배 표: 기본값과 키', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.companions).insert(
        CompanionsCompanion.insert(companionId: 'bright', metUtc: 10));
    final met = await db.select(db.companions).getSingle();
    expect((met.walksTogether, met.chapter, met.readChapter, met.metJourneyId, met.metK),
        (0, 0, 0, null, null));
    expect(
        () => db.into(db.companions).insert(
            CompanionsCompanion.insert(companionId: 'bright', metUtc: 20)),
        throwsA(anything));

    // 혼자 걷기는 동행 id가 없는 줄이다
    await db.into(db.companionStints).insert(
        CompanionStintsCompanion.insert(startUtc: const Value(10), companionId: const Value('bright')));
    await db.into(db.companionStints).insert(CompanionStintsCompanion.insert(startUtc: const Value(20)));
    expect((await db.select(db.companionStints).get()).map((r) => r.companionId), ['bright', null]);

    await db.into(db.shopInventory).insert(
        ShopInventoryCompanion.insert(itemId: 'fx_shortcut', count: 2));
    expect((await db.select(db.shopInventory).getSingle()).count, 2);

    await db.into(db.shopUses).insert(
        ShopUsesCompanion.insert(itemId: 'fx_shortcut', day: '2026-11-18', journeyId: 'j1'));
    final used = await db.select(db.shopUses).getSingle();
    expect((used.km, used.appWalkId), (0, null));

    await db.into(db.boatsOwned).insert(BoatsOwnedCompanion.insert(boatId: 'boat_skiff', atUtc: 30));
    expect((await db.select(db.boatsOwned).getSingle()).colors, isNull);
  });
}
