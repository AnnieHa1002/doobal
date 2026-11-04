import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/badge.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/road_event.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/domain/sun.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

// 경복궁에서 동쪽으로 약 1km
const _nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

// 설치 KST 2026-11-18 09:00, 이벤트는 한 시간 뒤 (낮, 가을)
final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

final _byId = {for (final l in landmarks) l.id: l};

/// 여정 길이가 [minKm, maxKm]인 육지 명소 (_nearGyeongbok에서)
Landmark _farDest({double minKm = 40, double maxKm = 90}) => landmarks.firstWhere((l) {
      if (l.island != Island.mainland) return false;
      final km = buildRoute(_nearGyeongbok, l.latLng, rules).totalEffectiveKm;
      return km >= minKm && km <= maxKm;
    });

StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

class _Env {
  _Env({EventCatalog? events, BadgeCatalog? badges, bool withCatalogs = true})
      : db = AppDb(NativeDatabase.memory()),
        source = FakeStepSource() {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _byId,
      props: props,
      milestones: milestones,
      eventCatalog: withCatalogs ? (events ?? eventCatalog) : null,
      badgeCatalog: withCatalogs ? (badges ?? badgeCatalog) : null,
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  /// 설치(t0) + 출발 동네 + 경복궁 옆에서 [destId]로 출발한 진행 중 여정 (경비 없음)
  Future<String> startJourney(String destId) async {
    await svc.sync(_t0);
    await completeOnboarding(db);
    await placeAt(db, _nearGyeongbok, _t0);
    await svc.startJourney(destId, _t1, useFund: false);
    return 'j${_t1.millisecondsSinceEpoch}';
  }

  Future<List<JourneyEventRow>> events() => (db.select(db.journeyEvents)
        ..orderBy([(t) => OrderingTerm(expression: t.journeyId), (t) => OrderingTerm(expression: t.k)]))
      .get();

  Future<Map<String, int>> badges() async =>
      {for (final r in await db.select(db.badgesOwned).get()) r.badgeId: r.atUtc};

  Future<double> eventM(String id) async =>
      (await (db.select(db.journeys)..where((t) => t.id.equals(id))).getSingle()).eventM;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late _Env e;
  late String journeyId;

  group('addEventDistance: 길 위 이벤트', () {
    setUp(() async {
      e = _Env();
      journeyId = await e.startJourney(_farDest().id);
    });
    tearDown(() => e.db.close());

    test('2km 칸을 넘는 그 자리에서 한 줄을 만들고, 못 넘었으면 거리만 쌓인다', () async {
      expect(await e.svc.addEventDistance(1500, _t1), isEmpty);
      expect(await e.eventM(journeyId), 1500);
      expect(await e.events(), isEmpty);

      final made = await e.svc.addEventDistance(600, _t1);
      expect(made, hasLength(1));
      expect(await e.eventM(journeyId), 2100);

      final rows = await e.events();
      expect(rows, hasLength(1));
      final r = rows.single;
      expect((r.journeyId, r.k, r.season, r.night), (journeyId, 1, 'autumn', false));
      expect(['mountain', 'coast', 'field', 'city'], contains(r.terrain));
      // 풍경 문구는 그 장면의 묶음 안에 있고, 칭찬은 빈칸이 다 채워졌다
      final scene = eventCatalog.scene(r.terrain, 'autumn', false);
      expect(scene.texts.keys, contains(r.sceneTextId));
      expect(r.praiseText, isNotEmpty);
      expect(r.praiseText, isNot(contains('{')));
      expect(r.atUtc, _t1.millisecondsSinceEpoch);
      // 돌려준 줄은 저장한 것과 같다
      expect((made.single.k, made.single.praiseText, made.single.sceneText),
          (1, r.praiseText, scene.texts[r.sceneTextId]));
    });

    test('한 번 만든 칸은 다시 만들지 않고, 한꺼번에 여러 칸을 넘으면 칸마다 만든다', () async {
      await e.svc.addEventDistance(2100, _t1);
      final first = (await e.events()).single;

      // 같은 칸 안에서 더 걸어도 새 줄이 없고 기존 줄은 그대로다
      expect(await e.svc.addEventDistance(1000, _t1), isEmpty);
      expect((await e.events()).single.praiseText, first.praiseText);

      // 3100 + 3500 = 6600m: 2km 칸 둘(k=2, k=3)을 한 번에 넘는다
      final made = await e.svc.addEventDistance(3500, _t1);
      expect(made.map((v) => v.k), [2, 3]);
      expect((await e.events()).map((r) => r.k), [1, 2, 3]);
      // 거리가 0 이하면 아무것도 안 한다
      expect(await e.svc.addEventDistance(0, _t1), isEmpty);
      expect(await e.svc.addEventDistance(-5, _t1), isEmpty);
      expect(await e.eventM(journeyId), 6600);
    });

    test('같은 설치·여정·칸이면 문구가 늘 같다 (시드)', () async {
      await e.svc.addEventDistance(20000, _t1);
      final a = [for (final r in await e.events()) (r.k, r.sceneTextId, r.praiseId, r.praiseText)];

      final e2 = _Env();
      addTearDown(e2.db.close);
      await e2.startJourney(_farDest().id);
      await e2.svc.addEventDistance(20000, _t1);
      final b = [for (final r in await e2.events()) (r.k, r.sceneTextId, r.praiseId, r.praiseText)];
      expect(a, hasLength(10));
      expect(b, a);
    });

    test('직전 이벤트와 같은 풍경 문구·기본 칭찬 문구는 피한다', () async {
      await e.svc.addEventDistance(80000, _t1); // 40칸
      final rows = await e.events();
      expect(rows, hasLength(40));
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].sceneTextId, isNot(rows[i - 1].sceneTextId), reason: 'k=${rows[i].k}');
        final both = eventCatalog.defaults.keys;
        if (both.contains(rows[i].praiseId) && both.contains(rows[i - 1].praiseId)) {
          expect(rows[i].praiseId, isNot(rows[i - 1].praiseId), reason: 'k=${rows[i].k}');
        }
      }
    });

    test('칭찬은 부른 쪽이 넘긴 값(달린 거리 등)으로 채우고 적어 둔다', () async {
      final made = await e.svc.addEventDistance(
          2100, _t1, const EventLive(runKm: 0.6, sessionKm: 0, pendingSteps: 50, pendingM: 35));
      expect(made.single.praiseText, '이번엔 0.6km를 달렸네. 숨이 좋다.');
      expect((await e.events()).single.praiseText, '이번엔 0.6km를 달렸네. 숨이 좋다.');
    });

    test('밤에는 밤 풍경이다 (그 시각과 그 지점의 일출·일몰)', () async {
      final night = DateTime.utc(2026, 11, 18, 14); // KST 23:00
      final made = await e.svc.addEventDistance(2100, night);
      expect(made.single.night, isTrue);
      expect((await e.events()).single.night, isTrue);
    });

    test('같은 기록으로 동기화를 두 번 해도 이벤트는 늘거나 바뀌지 않는다', () async {
      e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 30, 100));
      await e.svc.addEventDistance(4300, _t1);
      final before = [for (final r in await e.events()) r.toJson()];
      expect(before, hasLength(2));
      final eventM = await e.eventM(journeyId);

      final now = _t1.add(const Duration(hours: 1));
      await e.svc.sync(now);
      await e.svc.sync(now.add(const Duration(minutes: 1)));
      expect([for (final r in await e.events()) r.toJson()], before);
      expect(await e.eventM(journeyId), eventM);
    });

    test('앱 밖에서 걸은 거리는 여정 진행에만 들어가고 이벤트는 없다', () async {
      // 6km 걷기 기록 (동기화로만 들어온다: addEventDistance를 부르지 않았다)
      e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 90, 100));
      await e.svc.sync(_t1.add(const Duration(hours: 3)));
      expect(await e.events(), isEmpty);
      expect(await e.eventM(journeyId), 0);
      expect((await e.svc.snapshot(_t1.add(const Duration(hours: 3)))).journey!.progress.progressKm,
          greaterThan(5));
    });
  });

  group('addEventDistance: 만들지 않는 경우', () {
    test('내 동네 스케치 여정에는 만들지 않고 거리도 쌓지 않는다', () async {
      e = _Env();
      addTearDown(e.db.close);
      await e.svc.sync(_t0);
      await completeOnboarding(e.db);
      expect(await e.svc.startSketch(_t1), isTrue);
      expect(await e.svc.addEventDistance(5000, _t1), isEmpty);
      expect(await e.events(), isEmpty);
      final sketch = await e.db.select(e.db.journeys).getSingle();
      expect(sketch.eventM, 0);
    });

    test('진행 중인 여정이 없으면 아무것도 안 한다', () async {
      e = _Env();
      addTearDown(e.db.close);
      await e.svc.sync(_t0);
      await completeOnboarding(e.db);
      expect(await e.svc.addEventDistance(5000, _t1), isEmpty);
      expect(await e.events(), isEmpty);
    });

    test('문구 파일이 없으면 만들지 않는다', () async {
      e = _Env(withCatalogs: false);
      addTearDown(e.db.close);
      final id = await e.startJourney(_farDest().id);
      expect(await e.svc.addEventDistance(5000, _t1), isEmpty);
      expect(await e.eventM(id), 0);
    });

    test('도착한 여정에는 더 만들지 않는다 (진행 중인 여정이 아니다)', () async {
      e = _Env();
      addTearDown(e.db.close);
      await e.svc.sync(_t0);
      await completeOnboarding(e.db);
      await placeAt(e.db, _nearGyeongbok, _t0);
      await e.svc.startJourney('kr001', _t1, useFund: false);
      e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 30, 100));
      final arrivedAt = _t1.add(const Duration(hours: 2));
      await e.svc.sync(arrivedAt);
      expect((await e.svc.snapshot(arrivedAt)).journey, isNull);
      expect(await e.svc.addEventDistance(5000, arrivedAt), isEmpty);
      expect(await e.events(), isEmpty);
    });
  });

  group('도장 판정', () {
    late List<List<Badge>> toasts;
    late List<List<Badge>> streamed;

    setUp(() async {
      e = _Env();
      toasts = [];
      streamed = toasts;
      e.svc.newBadges.listen(streamed.add);
      await e.svc.sync(_t0);
      await completeOnboarding(e.db);
    });
    tearDown(() => e.db.close());

    test('걷기 1번을 채우면 첫 걸음 도장을 한 번만 받는다 (같은 기록으로 두 번 동기화해도 같다)', () async {
      e.source.records.add(_walk(_t1, 20, 100));
      final r1 = await e.svc.sync(_t1.add(const Duration(hours: 1)));
      expect(r1.newBadges.map((b) => b.id), ['b_first_walk']);
      final owned = await e.badges();
      expect(owned.keys, ['b_first_walk']);

      final r2 = await e.svc.sync(_t1.add(const Duration(hours: 2)));
      expect(r2.newBadges, isEmpty);
      expect(await e.badges(), owned); // 받은 시각도 그대로
      await Future<void>.delayed(Duration.zero);
      expect(toasts.map((l) => l.map((b) => b.id).toList()), [
        ['b_first_walk']
      ]);
      // 새 도장은 안 본 것으로 시작한다 (배낭 알림 점)
      expect((await e.svc.snapshot(_t1.add(const Duration(hours: 2)))).unseenBadges, 1);
      await e.svc.markBadgesSeen();
      expect((await e.svc.snapshot(_t1.add(const Duration(hours: 2)))).unseenBadges, 0);
      expect(await e.svc.ownedBadges(), {
        'b_first_walk': _t1.add(const Duration(hours: 1)),
      });
    });

    test('걷기 한 번의 거리·하루 걸음 도장', () async {
      // 75분 × 분당 100보 = 7,500보 = 5.25km. 하루 합계는 10,000보가 되도록 한 번 더 걷는다
      e.source.records
        ..add(_walk(_t1, 75, 100))
        ..add(_walk(_t1.add(const Duration(minutes: 90)), 25, 100));
      final r = await e.svc.sync(_t1.add(const Duration(hours: 4)));
      final ids = r.newBadges.map((b) => b.id).toSet();
      expect(ids, containsAll(['b_first_walk', 'b_walk_5km', 'b_day_10k']));
      expect(ids, isNot(contains('b_walk_10km')));
      expect(ids, isNot(contains('b_day_20k')));
      expect(ids, isNot(contains('b_walks_100')));
    });

    test('걷기 1번 수 100번 도장은 인정된 걷기 1번만 센다', () async {
      await e.db.batch((b) => b.insertAll(e.db.walkSessions, [
            for (var i = 0; i < 100; i++)
              WalkSessionsCompanion.insert(
                startUtc: Value(1000000 + i * 100000),
                endUtc: 1000000 + i * 100000 + 50000,
                steps: 1500,
                distanceM: 1000,
                runRatio: 0,
                qualified: true,
                counted: i != 0, // 하나는 인정 안 됨
              ),
          ]));
      await e.svc.sync(_t1);
      expect(await e.badges(), isNot(contains('b_walks_100')));
      await (e.db.update(e.db.walkSessions)..where((t) => t.startUtc.equals(1000000)))
          .write(const WalkSessionsCompanion(counted: Value(true)));
      await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      expect(await e.badges(), contains('b_walks_100'));
    });

    test('시간대 도장: 걷기 1번을 시작한 때가 노을·밤·새벽이면 (출발 동네 좌표로 근사)', () async {
      SunTimes sun(String day) => sunTimes(testHome, day, rules.sunZenithDeg);
      final day1 = sun('2026-11-18');
      final day2 = sun('2026-11-19');
      e.source.records
        // 노을: 일몰 10분 전에 시작
        ..add(_walk(day1.sunset.subtract(const Duration(minutes: 10)), 20, 100))
        // 밤: 일몰 2시간 뒤
        ..add(_walk(day1.sunset.add(const Duration(hours: 2)), 20, 100))
        // 새벽: 다음 날 일출 때
        ..add(_walk(day2.sunrise, 20, 100));
      final r = await e.svc.sync(day2.sunrise.add(const Duration(hours: 3)));
      expect(r.newBadges.map((b) => b.id).toSet(),
          containsAll(['b_first_walk', 'b_sunset', 'b_night', 'b_dawn']));
    });

    test('한낮에 시작한 걷기는 시간대 도장이 없다', () async {
      e.source.records.add(_walk(_t1, 20, 100)); // KST 10:00
      final r = await e.svc.sync(_t1.add(const Duration(hours: 1)));
      expect(r.newBadges.map((b) => b.id), ['b_first_walk']);
    });

    test('네 계절 도장: 걷기 1번이 있는 계절 수', () async {
      Future<void> session(DateTime kstDay) => e.db.into(e.db.walkSessions).insert(
            WalkSessionsCompanion.insert(
              startUtc: Value(kstDay.millisecondsSinceEpoch),
              endUtc: kstDay.millisecondsSinceEpoch + 1200000,
              steps: 1500,
              distanceM: 1000,
              runRatio: 0,
              qualified: true,
              counted: true,
            ),
          );
      await session(DateTime.utc(2026, 4, 5, 3)); // 봄
      await session(DateTime.utc(2026, 7, 5, 3)); // 여름
      await session(DateTime.utc(2026, 10, 5, 3)); // 가을
      await e.svc.sync(_t1);
      expect(await e.badges(), isNot(contains('b_seasons')));
      await session(DateTime.utc(2027, 1, 5, 3)); // 겨울
      await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      expect(await e.badges(), contains('b_seasons'));
    });

    test('여정 도장: 도착·배·금 액자·한 여정 100km (내 동네 스케치 도착은 첫 명소 도착이 아니다)', () async {
      // 스케치에 도착한 첫 여정과 그 그림
      await e.db.into(e.db.journeys).insert(JourneysCompanion.insert(
            id: 'j1',
            originLat: testHome.lat,
            originLng: testHome.lng,
            destId: 'sketch',
            startUtc: 1000,
            fundKm: 0,
            totalEffectiveKm: 0.7,
            status: JourneyStatus.arrived,
            arrivedUtc: const Value(2000),
            visitNo: const Value(1),
            newFrame: const Value(Frame.wood),
            destLat: Value(testHome.lat + 0.005),
            destLng: Value(testHome.lng),
          ));
      await e.svc.sync(_t1);
      expect(await e.badges(), isNot(contains('b_first_arrival')));

      // 서울 → 제주 명소 도착 (배 구간 + 환산 120km), 금 액자 그림
      final jeju = landmarks.firstWhere((l) => l.island == Island.jeju);
      await e.db.into(e.db.journeys).insert(JourneysCompanion.insert(
            id: 'j2',
            originLat: testHome.lat,
            originLng: testHome.lng,
            destId: jeju.id,
            startUtc: 3000,
            fundKm: 0,
            totalEffectiveKm: 120,
            status: JourneyStatus.arrived,
            arrivedUtc: const Value(4000),
            visitNo: const Value(1),
            newFrame: const Value(Frame.gold),
          ));
      await e.db.into(e.db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
            landmarkId: jeju.id,
            visits: 1,
            frame: Frame.gold,
            bestKm: 120,
            firstArrivedUtc: 4000,
            lastArrivedUtc: 4000,
          ));
      final r = await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      expect(r.newBadges.map((b) => b.id).toSet(),
          {'b_first_arrival', 'b_first_boat', 'b_first_gold', 'b_journey_100'});
    });

    test('지형 이정표 도장: 그 지형 이벤트 10번 (동기화에서도, 이벤트를 만드는 자리에서도 받는다)', () async {
      await placeAt(e.db, _nearGyeongbok, _t0);
      await e.svc.startJourney(_farDest().id, _t1, useFund: false);
      // 다른 여정의 옛 이벤트로 채운다 (이 여정의 칸 번호를 건드리지 않게)
      Future<void> insert(int k, String terrain) =>
          e.db.into(e.db.journeyEvents).insert(JourneyEventsCompanion.insert(
                journeyId: 'jold',
                k: k,
                terrain: terrain,
                season: 'autumn',
                night: false,
                sceneTextId: 'x',
                praiseId: 'R10',
                praiseText: '글',
                atUtc: 1,
              ));

      // 동기화 쪽: 산길 9번은 못 받고 10번째에 받는다
      for (var k = 101; k <= 109; k++) {
        await insert(k, 'mountain');
      }
      await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      expect(await e.badges(), isNot(contains('b_mountain')));
      await insert(110, 'mountain');
      await e.svc.sync(_t1.add(const Duration(minutes: 2)));
      expect(await e.badges(), contains('b_mountain'));

      // 이벤트를 만드는 쪽: 지금 지점의 지형으로 9번을 채워 두고 10번째를 거리로 만든다
      final first = (await e.svc.addEventDistance(2100, _t1)).single;
      for (var k = 201; k <= 208; k++) {
        await insert(k, first.terrain);
      }
      toasts.clear();
      final made = await e.svc.addEventDistance(2000, _t1);
      expect(made.single.terrain, first.terrain);
      expect(await e.badges(), contains('b_${first.terrain}'));
      await Future<void>.delayed(Duration.zero);
      expect([for (final l in toasts) ...l.map((b) => b.id)], contains('b_${first.terrain}'));
    });

    test('도장 문구와 조건 이름은 badges.json 그대로다 (20개, 누적)', () async {
      expect(badgeCatalog.badges, hasLength(20));
      // 아무 기록이 없으면 하나도 못 받는다
      final r = await e.svc.sync(_t1);
      expect(r.newBadges, isEmpty);
      expect(await e.badges(), isEmpty);
      expect(newBadgeToast(badgeCatalog.badges.take(2).toList()), '새 도장을 받았어요 · 첫 걸음 외 1개');
    });
  });
}
