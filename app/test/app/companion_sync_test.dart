import 'package:doobal/app/notification_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/notifier.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/route.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

// 경복궁에서 동쪽으로 약 1km
const _near = LatLng(37.57761, 126.9769 + 0.0113);

// 설치 KST 2026-11-18 09:00
final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

final _byId = {for (final l in landmarks) l.id: l};

Landmark _farDest() => landmarks.firstWhere((l) {
      if (l.island != Island.mainland) return false;
      final km = buildRoute(_near, l.latLng, rules).totalEffectiveKm;
      return km >= 200;
    });

StepRecord _walk(DateTime start, {int minutes = 12, int spm = 100}) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

class _Env {
  _Env() : db = AppDb(NativeDatabase.memory()), source = FakeStepSource() {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _byId,
      props: props,
      milestones: milestones,
      eventCatalog: eventCatalog,
      badgeCatalog: badgeCatalog,
      companionCatalog: companionCatalog,
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  Future<String> start({String? dest, DateTime? at}) async {
    final when = at ?? _t1;
    await svc.sync(_t0);
    await completeOnboarding(db);
    await placeAt(db, _near, _t0);
    await svc.startJourney(dest ?? _farDest().id, when, useFund: false);
    return 'j${when.millisecondsSinceEpoch}';
  }

  Future<List<CompanionRow>> rows() => db.select(db.companions).get();

  Future<CompanionRow> row(String id) =>
      (db.select(db.companions)..where((t) => t.companionId.equals(id))).getSingle();

  Future<List<JourneyEventRow>> events() => db.select(db.journeyEvents).get();

  Future<List<CompanionStintRow>> stints() => db.select(db.companionStints).get();

  /// 이미 만나고 흐름까지 끝낸 동행으로 넣는다
  Future<void> met(String id, {int at = 1}) => db
      .into(db.companions)
      .insert(CompanionsCompanion.insert(companionId: id, metUtc: at));

  /// [day]일째(설치일 0)에 인정된 걷기 한 번을 걷고 동기화한다. 같은 날은 [hour]로 시각을 나눈다
  Future<void> walkOn(int day, {int hour = 1}) async {
    final start = _t0.add(Duration(days: day, hours: hour));
    source.records.add(_walk(start));
    await svc.sync(start.add(const Duration(hours: 1)));
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late _Env e;
  setUp(() async {
    e = _Env();
    // 설치 시각은 첫 동기화다 (그 앞의 걸음은 안 센다)
    await e.svc.sync(_t0);
  });
  tearDown(() => e.db.close());

  group('만남은 이벤트 대신 나온다', () {
    test('첫 실제 여정의 k=1은 이벤트 줄 없이 첫 만남이고, 다음 칸부터 이벤트다', () async {
      final id = await e.start();
      expect(await e.svc.addEventDistance(1900, _t1), isEmpty);
      expect(await e.rows(), isEmpty);

      expect(await e.svc.addEventDistance(200, _t1), isEmpty, reason: '만남 칸은 카드가 없다');
      expect(await e.events(), isEmpty);
      final row = (await e.rows()).single;
      expect(row.metJourneyId, id);
      expect(row.metK, 1);
      expect(row.chapter, 0);
      expect(row.walksTogether, 0);
      expect((await e.svc.pendingMeeting())!.id, row.companionId);

      final made = await e.svc.addEventDistance(2000, _t1);
      expect(made.single.k, 2);
      expect((await e.events()).single.k, 2);
      expect(await e.rows(), hasLength(1));
    });

    test('같은 칸을 다시 지나도 또 만나지 않고, 한 번에 여러 칸을 넘어도 첫 칸만 만남이다', () async {
      await e.start();
      final made = await e.svc.addEventDistance(6500, _t1);
      expect(made.map((v) => v.k), [2, 3]);
      expect((await e.rows()).single.metK, 1);
      expect(await e.svc.addEventDistance(100, _t1), isEmpty);
      expect(await e.rows(), hasLength(1));
    });

    test('스케치 여정에서는 만나지 않는다', () async {
      await e.svc.sync(_t0);
      await completeOnboarding(e.db);
      expect(await e.svc.startSketch(_t1), isTrue);
      expect(await e.svc.addEventDistance(5000, _t1), isEmpty);
      expect(await e.rows(), isEmpty);
    });

    test('첫 실제 여정을 칸 전에 멈췄으면 다음 여정의 첫 칸에서 만난다', () async {
      await e.start();
      await e.svc.addEventDistance(1000, _t1);
      final later = _t1.add(const Duration(hours: 1));
      await e.svc.stopJourney(later);
      await e.svc.startJourney(_farDest().id, later, useFund: false);
      expect(await e.rows(), isEmpty);
      await e.svc.addEventDistance(2100, later);
      expect((await e.rows()).single.metJourneyId, 'j${later.millisecondsSinceEpoch}');
    });

    test('같은 설치·여정이면 같은 동행을 만난다', () async {
      Future<String> run() async {
        final env = _Env();
        await env.start();
        await env.svc.addEventDistance(2100, _t1);
        final id = (await env.rows()).single.companionId;
        await env.db.close();
        return id;
      }

      expect(await run(), await run());
    });

    test('다시 동기화해도 만남이 늘거나 바뀌지 않는다', () async {
      await e.start();
      await e.svc.addEventDistance(2100, _t1);
      final before = (await e.rows()).single;
      await e.svc.sync(_t1.add(const Duration(minutes: 5)));
      await e.svc.sync(_t1.add(const Duration(minutes: 6)));
      final after = (await e.rows()).single;
      expect(after.toJson(), before.toJson());
    });

    test('만남 흐름을 안 끝냈으면 보장 기한이 지나도 새로 만나지 않고 이벤트가 나온다', () async {
      final at = _t0.add(const Duration(days: 40));
      await e.start(at: at);
      await e.svc.addEventDistance(2100, at);
      expect(await e.rows(), hasLength(1));
      final made = await e.svc.addEventDistance(2000, at);
      expect(made.single.k, 2);
      expect(await e.rows(), hasLength(1));
    });

    test('catalog가 없으면 만남 없이 k=1도 이벤트다', () async {
      final env = _Env();
      final plain = SyncService(
        db: env.db,
        source: env.source,
        rules: rules,
        allowedSources: const [],
        landmarks: _byId,
        props: props,
        eventCatalog: eventCatalog,
      );
      await plain.sync(_t0);
      await completeOnboarding(env.db);
      await placeAt(env.db, _near, _t0);
      await plain.startJourney(_farDest().id, _t1, useFund: false);
      expect((await plain.addEventDistance(2100, _t1)).single.k, 1);
      expect(await plain.pendingMeeting(), isNull);
      await env.db.close();
    });
  });

  group('설치 후 보장', () {
    test('14일이 지나면 그 뒤 첫 칸에서 둘째를 만난다 (앱 밖에서 지났어도)', () async {
      await e.met('bright');
      await e.start();
      // 앱을 안 켠 채 기한이 지났고, 다음 실행 중 첫 칸이다
      final day14 = _t0.add(Duration(days: rules.companionGuaranteeDays.first));
      await e.svc.sync(day14);
      final made = await e.svc.addEventDistance(2100, day14);
      expect(made, isEmpty, reason: '이벤트 대신 만남');
      final rows = await e.rows();
      expect(rows, hasLength(2));
      expect(rows.last.companionId, isNot('bright'));
      expect(rows.last.metK, 1);
    });

    test('14일 전에는 칸이 많아도 시드 확률에 달렸다 (반드시 만나지는 않는다)', () async {
      await e.met('bright');
      await e.start();
      final day13 = _t0.add(Duration(days: rules.companionGuaranteeDays.first - 1));
      final made = await e.svc.addEventDistance(2100, day13);
      // 이 설치·여정의 첫 칸은 시드상 이벤트다 (시드가 바뀌면 이 값을 다시 본다)
      expect(made.single.k, 1);
      expect(await e.rows(), hasLength(1));
    });

    test('28일이 지나면 셋째를 만난다 (도장 companionsMet도 그 자리에서)', () async {
      final at = _t0.add(const Duration(days: 28));
      await e.met('bright');
      await e.met('rest');
      await e.start(at: at);
      await e.svc.addEventDistance(2100, at);
      expect((await e.rows()).map((r) => r.companionId), containsAll(['bright', 'rest', 'doctor']));
      final badge = badgeCatalog.badges.firstWhere((b) => b.cond['kind'] == 'companionsMet');
      final owned = await e.db.select(e.db.badgesOwned).get();
      expect(owned.map((r) => r.badgeId), contains(badge.id));
    });

    test('셋 다 만났으면 칸은 늘 이벤트다', () async {
      final at = _t0.add(const Duration(days: 60));
      await e.met('bright');
      await e.met('rest');
      await e.met('doctor');
      await e.start(at: at);
      final made = await e.svc.addEventDistance(10500, at);
      expect(made, hasLength(5));
    });
  });

  group('걷기 4번 → 1장', () {
    test('함께 걷는 동행에게 걷기마다 +1, 4번이면 1장, 다시 동기화해도 그대로', () async {
      await e.met('bright');
      await e.svc.walkWith('bright', _t0);
      for (var d = 1; d <= 3; d++) {
        await e.walkOn(d);
      }
      var r = await e.row('bright');
      expect((r.walksTogether, r.chapter), (3, 0));

      await e.walkOn(4);
      r = await e.row('bright');
      expect((r.walksTogether, r.chapter), (4, 1));

      final later = _t0.add(const Duration(days: 4, hours: 3));
      await e.svc.sync(later);
      await e.svc.sync(later.add(const Duration(minutes: 1)));
      r = await e.row('bright');
      expect((r.walksTogether, r.chapter), (4, 1));
    });

    test('혼자 걷기는 안 쌓이고, 다시 함께 걸으면 이어서 쌓인다', () async {
      await e.met('bright');
      await e.svc.walkWith('bright', _t0);
      await e.walkOn(1);
      await e.svc.walkWith(null, _t0.add(const Duration(days: 2)));
      await e.walkOn(2);
      await e.walkOn(3);
      expect((await e.row('bright')).walksTogether, 1);
      await e.svc.walkWith('bright', _t0.add(const Duration(days: 4)));
      await e.walkOn(4);
      expect((await e.row('bright')).walksTogether, 2);
    });

    test('줄이 없으면 혼자다: 만나기만 하고 고르지 않으면 안 쌓인다', () async {
      await e.met('bright');
      await e.walkOn(1);
      expect((await e.row('bright')).walksTogether, 0);
    });

    test('동행을 바꾸면 각자에게 쌓인다', () async {
      await e.met('bright');
      await e.met('rest');
      await e.svc.walkWith('bright', _t0);
      await e.walkOn(1);
      await e.svc.walkWith('rest', _t0.add(const Duration(days: 2)));
      await e.walkOn(2);
      await e.walkOn(3);
      expect((await e.row('bright')).walksTogether, 1);
      expect((await e.row('rest')).walksTogether, 2);
    });

    test('기록이 늦게 들어와도 그 걷기를 시작할 때의 동행에게 간다', () async {
      await e.met('bright');
      await e.met('rest');
      await e.svc.walkWith('bright', _t0);
      await e.svc.sync(_t0.add(const Duration(days: 1)));
      final start = _t0.add(const Duration(days: 1, hours: 1));
      // 걸은 뒤 동행을 바꿨고, 그 뒤에야 기록이 들어왔다
      await e.svc.walkWith('rest', start.add(const Duration(minutes: 30)));
      e.source.records.add(_walk(start));
      await e.svc.sync(start.add(const Duration(hours: 1)));
      expect((await e.row('bright')).walksTogether, 1);
      expect((await e.row('rest')).walksTogether, 0);
    });

    test('만남 칸을 지나는 그 걷기는 시작 때의 동행(없으면 혼자)에게 간다', () async {
      final journey = await e.start();
      expect(journey, isNotEmpty);
      e.source.records.add(_walk(_t1.add(const Duration(minutes: 1))));
      await e.svc.addEventDistance(2100, _t1.add(const Duration(minutes: 5)));
      final id = (await e.rows()).single.companionId;
      await e.svc.finishMeeting(id, _t1.add(const Duration(minutes: 6)), together: true);
      await e.svc.sync(_t1.add(const Duration(minutes: 30)));
      expect((await e.row(id)).walksTogether, 0);
    });

    test('인정 안 된 걷기는 안 쌓인다', () async {
      await e.met('bright');
      await e.svc.walkWith('bright', _t0);
      final start = _t0.add(const Duration(days: 1));
      e.source.records.add(_walk(start, minutes: 3));
      await e.svc.sync(start.add(const Duration(hours: 1)));
      expect((await e.row('bright')).walksTogether, 0);
    });

    test('36번 걸어도 8장에서 멈춘다', () async {
      await e.met('rest');
      await e.svc.sync(_t0);
      final past = _t0.subtract(const Duration(days: 60));
      await e.svc.walkWith('rest', past);
      await e.db.batch((b) => b.insertAll(e.db.walkSessions, [
            for (var i = 1; i <= 36; i++)
              WalkSessionsCompanion.insert(
                startUtc: Value(past.add(Duration(days: i)).millisecondsSinceEpoch),
                endUtc: past.add(Duration(days: i, minutes: 12)).millisecondsSinceEpoch,
                steps: 1200,
                distanceM: 800,
                runRatio: 0,
                qualified: true,
                counted: true,
              ),
          ]));
      await e.svc.sync(_t1);
      final r = await e.row('rest');
      expect((r.walksTogether, r.chapter), (36, rules.companionChapters));
    });

    test('걷기 수가 줄어도 열린 장은 닫히지 않는다', () async {
      await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
            companionId: 'doctor',
            metUtc: 1,
            walksTogether: const Value(9),
            chapter: const Value(2),
          ));
      await e.svc.sync(_t0);
      final r = await e.row('doctor');
      expect((r.walksTogether, r.chapter), (0, 2));
    });
  });

  group('새 장 알림 N3', () {
    test('4번째 걷기에 N3 후보가 하나 나오고, 다시 돌려도 없다', () async {
      await e.met('bright');
      await e.svc.walkWith('bright', _t0);
      for (var d = 1; d <= 3; d++) {
        await e.walkOn(d);
      }
      final walk = _t0.add(const Duration(days: 4, hours: 1));
      e.source.records.add(_walk(walk));
      final at = walk.add(const Duration(hours: 1));
      final report = await e.svc.sync(at);
      final n3 = report.notices.where((c) => c.kind == NoticeKind.n3).toList();
      expect(n3, hasLength(1));
      expect(n3.single.key, 'bright:1');
      expect(n3.single.vars['companion'], '퐁이');

      final again = await e.svc.sync(at.add(const Duration(minutes: 1)));
      expect(again.notices.where((c) => c.kind == NoticeKind.n3), isEmpty);
    });

    test('앱 밖이면 시스템 알림으로 한 번만 나가고, payload로 그 장을 찾을 수 있다', () async {
      final notifier = PlaceholderNotifier();
      final notices = NotificationService(
        db: e.db,
        rules: rules,
        catalog: noticeCatalog,
        notifier: notifier,
        inForeground: () => false,
      );
      final svc = SyncService(
        db: e.db,
        source: e.source,
        rules: rules,
        allowedSources: const [],
        landmarks: _byId,
        props: props,
        companionCatalog: companionCatalog,
        notificationService: notices,
      );
      await e.met('rest');
      await e.svc.walkWith('rest', _t0);
      for (var d = 1; d <= 4; d++) {
        e.source.records.add(_walk(_t0.add(Duration(days: d, hours: 1))));
      }
      // 낮에 동기화한다 (조용한 시간이면 예약이 된다)
      final at = _t0.add(const Duration(days: 4, hours: 3));
      await svc.sync(at);
      await svc.sync(at.add(const Duration(minutes: 1)));
      final shown = notifier.calls.where((c) => c.kind == NoticeKind.n3).toList();
      expect(shown, hasLength(1));
      expect(shown.single.payload, 'N3:rest:1');
      expect('${shown.single.title} ${shown.single.body}', contains('휴'));
      final logged = await (e.db.select(e.db.notificationLog)
            ..where((t) => t.kind.equalsValue(NoticeKind.n3)))
          .get();
      expect(logged.single.refKey, 'rest:1');
    });

    test('한 번에 여러 장이 열리면 마지막 장으로 하나, 혼자 걸으면 없다', () async {
      await e.met('doctor');
      await e.svc.walkWith('doctor', _t0);
      for (var d = 1; d <= 8; d++) {
        e.source.records.add(_walk(_t0.add(Duration(days: d, hours: 1))));
      }
      final report = await e.svc.sync(_t0.add(const Duration(days: 8, hours: 3)));
      final n3 = report.notices.where((c) => c.kind == NoticeKind.n3).toList();
      expect(n3.single.key, 'doctor:2');

      await e.svc.walkWith(null, _t0.add(const Duration(days: 9)));
      for (var d = 10; d <= 13; d++) {
        e.source.records.add(_walk(_t0.add(Duration(days: d, hours: 1))));
      }
      final solo = await e.svc.sync(_t0.add(const Duration(days: 13, hours: 3)));
      expect(solo.notices.where((c) => c.kind == NoticeKind.n3), isEmpty);
    });

    test('만남 프롤로그(0장)는 알리지 않는다', () async {
      await e.met('bright');
      final report = await e.svc.sync(_t1);
      expect(report.notices.where((c) => c.kind == NoticeKind.n3), isEmpty);
    });
  });

  group('완결 소품', () {
    /// [id]에게 인정된 걷기 [count]번을 한꺼번에 넣는다 (함께 걸은 뒤로)
    Future<void> walked(String id, int count) async {
      await e.met(id);
      final past = _t0.subtract(const Duration(days: 60));
      await e.svc.walkWith(id, past);
      await e.db.batch((b) => b.insertAll(e.db.walkSessions, [
            for (var i = 1; i <= count; i++)
              WalkSessionsCompanion.insert(
                startUtc: Value(past.add(Duration(days: i)).millisecondsSinceEpoch),
                endUtc: past.add(Duration(days: i, minutes: 12)).millisecondsSinceEpoch,
                steps: 1200,
                distanceM: 800,
                runRatio: 0,
                qualified: true,
                counted: true,
              ),
          ]));
    }

    Future<List<String>> ownedCompanionProps() async {
      final ids = {
        for (final p in props)
          if (p.kind == PropUnlockKind.companion) p.id,
      };
      return [
        for (final r in await e.db.select(e.db.propsOwned).get())
          if (ids.contains(r.propId)) r.propId,
      ];
    }

    int walksFor(int chapters) => rules.companionWalksPerChapter * chapters;

    test('7장까지는 없고, 8장이 열리면 그 동행의 소품이 한 번 들어온다', () async {
      await walked('bright', walksFor(rules.companionChapters - 1));
      await e.svc.sync(_t1);
      expect(await ownedCompanionProps(), isEmpty);

      final past = _t0.subtract(const Duration(days: 60));
      await e.db.batch((b) => b.insertAll(e.db.walkSessions, [
            for (var i = 40; i < 40 + rules.companionWalksPerChapter; i++)
              WalkSessionsCompanion.insert(
                startUtc: Value(past.add(Duration(days: i)).millisecondsSinceEpoch),
                endUtc: past.add(Duration(days: i, minutes: 12)).millisecondsSinceEpoch,
                steps: 1200,
                distanceM: 800,
                runRatio: 0,
                qualified: true,
                counted: true,
              ),
          ]));
      final report = await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      final finale = companionCatalog.byId('bright')!.finaleProp;
      expect(await ownedCompanionProps(), [finale]);
      expect(report.newProps.map((p) => p.id), [finale], reason: '토스트로 알린다');
      expect(
        (await (e.db.select(e.db.propsOwned)..where((t) => t.propId.equals(finale))).getSingle())
            .seen,
        isFalse,
        reason: '배낭 점이 켜진다',
      );
      expect(report.notices.where((c) => c.kind == NoticeKind.n3).single.key,
          'bright:${rules.companionChapters}');
    });

    test('다시 돌려도 한 번: 줄이 안 늘고 토스트도 없다', () async {
      await walked('rest', walksFor(rules.companionChapters));
      final first = await e.svc.sync(_t1);
      expect(first.newProps, hasLength(1));
      final second = await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      expect(second.newProps, isEmpty);
      expect(await ownedCompanionProps(), hasLength(1));
    });

    test('같은 기록으로 두 번 동기화해도 장·걷기 수·소품이 그대로다', () async {
      await walked('doctor', walksFor(rules.companionChapters) + 3);
      await e.svc.sync(_t1);
      final before = await e.row('doctor');
      final ownedBefore = await ownedCompanionProps();
      await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      final after = await e.row('doctor');
      expect((after.walksTogether, after.chapter), (before.walksTogether, before.chapter));
      expect(await ownedCompanionProps(), ownedBefore);
    });

    test('소품이 이미 있으면 다시 안 준다 (백업에서 돌아온 경우)', () async {
      final finale = companionCatalog.byId('rest')!.finaleProp;
      await e.db.into(e.db.propsOwned).insert(
          PropsOwnedCompanion.insert(propId: finale, unlockedUtc: 1, seen: const Value(true)));
      await walked('rest', walksFor(rules.companionChapters));
      final report = await e.svc.sync(_t1);
      expect(report.newProps, isEmpty);
      final row =
          await (e.db.select(e.db.propsOwned)..where((t) => t.propId.equals(finale))).getSingle();
      expect((row.unlockedUtc, row.seen), (1, true));
    });

    test('심 박사만 8장을 읽은 뒤 안경 층을 숨긴다 (열리기만 해서는 그대로, 11/6 Annie)', () async {
      final last = rules.companionChapters;
      await walked('doctor', walksFor(last));
      await e.svc.sync(_t1);
      Future<String?> hidden(String id) async =>
          (await e.svc.companionsView()).metById(id)!.hiddenLayer;
      expect((await e.row('doctor')).chapter, last);
      expect(await hidden('doctor'), isNull, reason: '열렸지만 아직 안 읽었다');

      await e.svc.markStoryRead('doctor', last - 1);
      expect(await hidden('doctor'), isNull);

      await e.svc.markStoryRead('doctor', last);
      expect(await hidden('doctor'), 'glasses');

      await e.svc.sync(_t1.add(const Duration(minutes: 1)));
      expect(await hidden('doctor'), 'glasses', reason: '다시 동기화해도 그대로');

      // 안경 층이 없는 동행은 8장을 읽어도 숨길 것이 없다
      await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
          companionId: 'rest', metUtc: 2, chapter: Value(last), readChapter: Value(last)));
      expect(await hidden('rest'), isNull);
    });

    test('개발 화면으로 8장을 열어도 다음 동기화에 소품이 들어온다', () async {
      await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
          companionId: 'bright', metUtc: 1, chapter: Value(rules.companionChapters - 1)));
      await e.svc.debugOpenNextChapter('bright');
      final report = await e.svc.sync(_t1);
      expect(report.newProps.map((p) => p.id), [companionCatalog.byId('bright')!.finaleProp]);
    });
  });

  group('안 읽은 장', () {
    Future<CompanionsView> view() => e.svc.companionsView();

    test('장이 열리면 생기고 읽으면 없어진다. 프롤로그뿐이면 없다', () async {
      await e.met('bright');
      expect((await view()).hasUnread, isFalse);
      await e.svc.walkWith('bright', _t0);
      for (var d = 1; d <= 4; d++) {
        await e.walkOn(d);
      }
      var v = await view();
      expect(v.hasUnread, isTrue);
      expect(v.metById('bright')!.isUnread(1), isTrue);
      expect(v.metById('bright')!.isUnread(0), isFalse);
      expect(v.metById('bright')!.isUnread(2), isFalse, reason: '안 열린 장은 아니다');

      await e.svc.markStoryRead('bright', 1);
      v = await view();
      expect(v.hasUnread, isFalse);

      await e.svc.sync(_t0.add(const Duration(days: 4, hours: 4)));
      expect((await view()).hasUnread, isFalse, reason: '다시 동기화해도 다시 안 켜진다');
    });

    test('뒤 장을 읽으면 앞 장도 읽은 것으로 본다', () async {
      await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
          companionId: 'rest', metUtc: 1, chapter: const Value(3)));
      expect((await view()).metById('rest')!.isUnread(2), isTrue);
      await e.svc.markStoryRead('rest', 3);
      final m = (await view()).metById('rest')!;
      expect((m.hasUnread, m.isUnread(2)), (false, false));
    });

    test('만남 흐름을 안 끝낸 동행은 세지 않는다', () async {
      await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
          companionId: 'doctor', metUtc: 1, readChapter: const Value(-1)));
      expect((await view()).hasUnread, isFalse);
    });

    group('먼저 볼 동행', () {
      Future<void> withChapter(String id, int chapter, {int read = 0, int at = 1}) => e.db
          .into(e.db.companions)
          .insert(CompanionsCompanion.insert(
              companionId: id, metUtc: at, chapter: Value(chapter), readChapter: Value(read)));

      test('지금 걷는 동행에 있으면 그대로 둔다', () async {
        await withChapter('bright', 1);
        await withChapter('rest', 1, at: 2);
        await e.svc.walkWith('rest', _t0);
        expect((await view()).unreadFocus, isNull);
      });

      test('지금 걷는 동행에 없고 다른 동행에 있으면 그 동행', () async {
        await withChapter('bright', 1, read: 1);
        await withChapter('rest', 1, at: 2);
        await e.svc.walkWith('bright', _t0);
        expect((await view()).unreadFocus, 'rest');
      });

      test('혼자 걷는 중이면 마지막 동행 기준', () async {
        await withChapter('bright', 1, read: 1);
        await withChapter('rest', 2, at: 2);
        await e.svc.walkWith('rest', _t0);
        await e.svc.walkWith(null, _t1);
        expect((await view()).unreadFocus, isNull);
        await e.svc.markStoryRead('rest', 2);
        expect((await view()).unreadFocus, isNull, reason: '안 읽은 장이 없다');
      });
    });
  });

  group('걷기 기록의 이야기 값', () {
    /// [day]일째 걷기를 마친 뒤의 값
    Future<WalkStoryView?> afterWalk(int day) async {
      await e.walkOn(day);
      final start = _t0.add(Duration(days: day, hours: 1));
      return e.svc.walkStory(start, start.add(const Duration(minutes: 13)));
    }

    test('혼자 걸었으면 없다', () async {
      await e.met('bright');
      expect(await afterWalk(1), isNull);
    });

    test('함께 걸으면 다음 장까지 진행, 4번째 걷기면 열린 장', () async {
      await e.met('bright');
      await e.svc.walkWith('bright', _t0);
      for (var d = 1; d <= 3; d++) {
        final v = await afterWalk(d);
        expect(v!.companion.id, 'bright');
        expect((v.story.opened, v.story.next, v.story.walks), (null, 1, d));
      }
      final v = await afterWalk(4);
      expect((v!.story.opened, v.story.next, v.story.walks), (1, 2, 0));
    });

    test('지난 걷기를 다시 보면 그때의 값이다', () async {
      await e.met('bright');
      await e.svc.walkWith('bright', _t0);
      for (var d = 1; d <= 5; d++) {
        await e.walkOn(d);
      }
      final start = _t0.add(const Duration(days: 4, hours: 1));
      final v = await e.svc.walkStory(start, start.add(const Duration(minutes: 13)));
      expect((v!.story.opened, v.story.walks), (1, 0));
      final earlier = _t0.add(const Duration(days: 2, hours: 1));
      final w = await e.svc.walkStory(earlier, earlier.add(const Duration(minutes: 13)));
      expect((w!.story.opened, w.story.next, w.story.walks), (null, 1, 2));
    });

    test('인정이 안 된 걷기는 지금까지의 진행만 보여 준다', () async {
      await e.met('rest');
      await e.svc.walkWith('rest', _t0);
      await e.walkOn(1);
      final short = _t0.add(const Duration(days: 2, hours: 1));
      e.source.records.add(_walk(short, minutes: 3));
      await e.svc.sync(short.add(const Duration(hours: 1)));
      final v = await e.svc.walkStory(short, short.add(const Duration(minutes: 3)));
      expect((v!.story.opened, v.story.next, v.story.walks), (null, 1, 1));
    });
  });

  group('동행 바꾸기·혼자 걷기', () {
    test('안 만난 동행이나 흐름을 안 끝낸 동행과는 걸을 수 없다', () async {
      await expectLater(e.svc.walkWith('bright', _t0), throwsStateError);
      await e.start();
      await e.svc.addEventDistance(2100, _t1);
      final id = (await e.rows()).single.companionId;
      await expectLater(e.svc.walkWith(id, _t1), throwsStateError);
      expect(await e.stints(), isEmpty);
    });

    test('지금과 같으면 줄이 늘지 않는다', () async {
      await e.met('bright');
      await e.svc.walkWith(null, _t0);
      expect(await e.stints(), isEmpty, reason: '줄이 없으면 혼자라 그대로');
      await e.svc.walkWith('bright', _t0);
      await e.svc.walkWith('bright', _t1);
      expect(await e.stints(), hasLength(1));
      await e.svc.walkWith(null, _t1);
      expect((await e.stints()).map((s) => s.companionId), ['bright', null]);
    });

    test('만남 흐름 끝내기: 함께면 지금부터 그 동행, 아니면 걷던 대로', () async {
      final at = _t0.add(Duration(days: rules.companionGuaranteeDays.first));
      await e.met('rest');
      await e.svc.walkWith('rest', _t0);
      await e.start(at: at);
      await e.svc.addEventDistance(2100, at);
      final rows = await e.rows();
      final id = rows.firstWhere((r) => r.readChapter < 0).companionId;

      await e.svc.finishMeeting(id, at, together: false);
      expect(await e.svc.pendingMeeting(), isNull);
      expect((await e.row(id)).readChapter, 0);
      expect((await e.svc.companionsView()).walkingWith, 'rest');

      await e.svc.finishMeeting(id, at.add(const Duration(minutes: 1)), together: true);
      expect((await e.svc.companionsView()).walkingWith, id);
    });

    test('안 만난 동행의 흐름은 끝낼 수 없다', () async {
      await expectLater(e.svc.finishMeeting('bright', _t0, together: true), throwsStateError);
    });

    test('화면 값: 흐름을 안 끝낸 동행은 빠지고, 혼자일 때 마지막 동행을 안다', () async {
      expect((await e.svc.companionsView()).met, isEmpty);
      expect((await e.svc.companionsView()).lastWith, isNull);

      await e.met('rest', at: 2);
      await e.met('bright', at: 1);
      var v = await e.svc.companionsView();
      expect(v.met.map((m) => m.companion.id), ['bright', 'rest'], reason: '만난 순서');
      expect(v.walkingWith, isNull);
      expect(v.lastWith, 'bright', reason: '함께 걸은 적이 없으면 먼저 만난 동행');

      await e.svc.walkWith('rest', _t0);
      await e.svc.walkWith(null, _t1);
      v = await e.svc.companionsView();
      expect(v.walkingWith, isNull);
      expect(v.lastWith, 'rest');

      await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
            companionId: 'doctor',
            metUtc: 3,
            readChapter: const Value(-1),
          ));
      v = await e.svc.companionsView();
      expect(v.met.map((m) => m.companion.id), isNot(contains('doctor')));
      expect((await e.svc.pendingMeeting())!.id, 'doctor');
    });

    test('읽은 장은 줄지 않는다', () async {
      await e.met('bright');
      await e.svc.markStoryRead('bright', 3);
      await e.svc.markStoryRead('bright', 1);
      expect((await e.row('bright')).readChapter, 3);
    });
  });
}
