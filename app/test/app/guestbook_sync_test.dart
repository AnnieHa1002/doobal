import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

final _landmarks = {
  for (final l in (jsonDecode(File('assets/data/landmarks.json').readAsStringSync())
          as Map<String, dynamic>)['landmarks'] as List)
    l['id'] as String: Landmark.fromJson(l as Map<String, dynamic>),
};

// 경복궁에서 동쪽으로 약 1km
const _nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

// 설치 KST 2026-11-18 09:00, 걷기 시작은 한 시간 뒤
final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

DateTime _after(DateTime t, int minutes) => t.add(Duration(minutes: minutes));

int _ms(DateTime t) => t.millisecondsSinceEpoch;

/// start부터 minutes분 동안 분당 spm보로 걸은 기록 하나
StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: _after(start, minutes),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

/// start가 속한 한 분 동안 [steps]보 (걸음 수를 정확히 맞출 때)
StepRecord _burst(DateTime start, int steps) => StepRecord(
      start: start,
      end: _after(start, 1),
      steps: steps,
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
      landmarks: _landmarks,
      props: props,
      milestones: milestones,
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  Future<List<GuestbookTicketRow>> tickets([TicketKind? kind]) async => [
        for (final r in await db.select(db.guestbookTickets).get())
          if (kind == null || r.kind == kind) r,
      ];

  Future<GuestbookTicketRow> ticket(String id) =>
      (db.select(db.guestbookTickets)..where((t) => t.id.equals(id))).getSingle();

  Future<List<GuestbookPostRow>> posts() => db.select(db.guestbookPosts).get();

  /// 같은 기록이면 같아야 하는 값 (동기화 시각에 따라 달라지는 SyncState·fundedUntilUtc는 뺀다)
  Future<Map<String, Object?>> dump() async => {
        'minutes': await db.select(db.stepMinutes).get(),
        'days': await db.select(db.daySummaries).get(),
        'journeys': await db.select(db.journeys).get(),
        'paintings': await db.select(db.paintingsOwned).get(),
        'tickets': await db.select(db.guestbookTickets).get(),
        'posts': await db.select(db.guestbookPosts).get(),
      };

  /// 기회 행을 직접 넣는다 (동기화를 거치지 않고 상태를 만들 때)
  Future<void> putTicket(
    String id,
    TicketKind kind,
    String scope,
    DateTime openedAt, {
    DateTime? used,
    DateTime? closed,
  }) =>
      db.into(db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
            id: id,
            kind: kind,
            scope: scope,
            openedUtc: _ms(openedAt),
            usedUtc: Value(used == null ? null : _ms(used)),
            closedUtc: Value(closed == null ? null : _ms(closed)),
          ));
}

/// [home]이 true면 출발 동네를 testHome으로 골라 둔다. 설치(= _t0)까지 해 둔다
Future<_Env> _env({bool home = true}) async {
  final e = _Env();
  addTearDown(e.db.close);
  if (home) await e.svc.setHome(testHomeName, testHome);
  await e.svc.sync(_t0);
  return e;
}

/// 경복궁 근처에서 출발해 경비 없이 경복궁까지 걷는다. 도착을 동기화한 시각을 돌려준다
Future<DateTime> _arriveAtGyeongbok(_Env e) async {
  await placeAt(e.db, _nearGyeongbok, _t0);
  await e.svc.startJourney('kr001', _t1, useFund: false);
  e.source.records.add(_walk(_after(_t1, 5), 30, 100));
  final end = _t1.add(const Duration(hours: 2));
  await e.svc.sync(end);
  return end;
}

/// 첫 여정 '내 동네 스케치'를 정하고 걸어서 도착한다. 도착을 동기화한 시각을 돌려준다
Future<DateTime> _arriveAtSketch(_Env e) async {
  expect(await e.svc.startSketch(_t1), isTrue);
  final km = (await e.svc.snapshot(_t1)).journey!.totalKm;
  final minutes = (km * 1000 / (rules.walkStrideM * 100)).ceil() + 1;
  e.source.records.add(_walk(_after(_t1, 5), minutes, 100));
  final end = _t1.add(const Duration(hours: 2));
  await e.svc.sync(end);
  return end;
}

final _journeyId = 'j${_ms(_t1)}';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('도착 기회', () {
    test('명소에 도착하면 그 명소의 arrival 기회가 생기고, 열린 시각은 도착을 감지한 시각', () async {
      final e = await _env();
      expect(await e.tickets(TicketKind.arrival), isEmpty);
      final end = await _arriveAtGyeongbok(e);

      final t = (await e.tickets(TicketKind.arrival)).single;
      expect(t.id, 'a:$_journeyId');
      expect(t.scope, 'kr001');
      expect((t.openedUtc, t.usedUtc, t.closedUtc), (_ms(end), null, null));

      final open = (await e.svc.openTickets(end)).first;
      expect((open.id, open.kind, open.scope), ('a:$_journeyId', TicketKind.arrival, 'kr001'));
      expect((open.placeName, open.milestone, open.stepsLeft), ('경복궁', null, null));
      expect(open.openedAt, end);
    });

    test('여정 중에는 기회가 없다 (아직 도착하지 않았다)', () async {
      final e = await _env();
      await placeAt(e.db, _nearGyeongbok, _t0);
      await e.svc.startJourney('kr001', _t1, useFund: false);
      e.source.records.add(_walk(_after(_t1, 5), 5, 100));
      await e.svc.sync(_after(_t1, 30));
      expect(await e.tickets(TicketKind.arrival), isEmpty);
    });

    test('첫 여정(내 동네 스케치)에 도착해도 기회가 생긴다. scope는 sketch', () async {
      final e = await _env(home: false);
      await completeOnboarding(e.db);
      final end = await _arriveAtSketch(e);

      final t = (await e.tickets(TicketKind.arrival)).single;
      expect((t.id, t.scope, t.openedUtc), ('a:$_journeyId', sketchId, _ms(end)));
      final open = (await e.svc.openTickets(end)).first;
      expect((open.kind, open.scope, open.placeName), (TicketKind.arrival, 'sketch', '내 동네 스케치'));
    });

    test('새 여정을 시작하면 쓰지 않은 arrival이 닫힌다', () async {
      final e = await _env();
      await _arriveAtGyeongbok(e);
      final later = _t1.add(const Duration(hours: 3));
      await e.svc.startJourney('kr003', later, useFund: false);

      final t = (await e.tickets(TicketKind.arrival)).single;
      expect((t.usedUtc, t.closedUtc), (null, _ms(later)));
      expect(await e.svc.guestbookTicket('a:$_journeyId', later), isNull);
      expect((await e.svc.openTickets(later)).where((t) => t.kind == TicketKind.arrival), isEmpty);
    });

    test('이미 쓴 arrival은 새 여정을 시작해도 닫힘 시각이 붙지 않는다', () async {
      final e = await _env();
      final end = await _arriveAtGyeongbok(e);
      await e.svc.writeGuestbook('a:$_journeyId', '좋았어요', end);
      await e.svc.startJourney('kr003', _t1.add(const Duration(hours: 3)), useFund: false);

      final t = (await e.tickets(TicketKind.arrival)).single;
      expect((t.usedUtc, t.closedUtc), (_ms(end), null));
    });

    test('다른 걸음 숫자 기회는 새 여정을 시작해도 그대로 열려 있다', () async {
      final e = await _env();
      await _arriveAtGyeongbok(e);
      await e.svc.startJourney('kr003', _t1.add(const Duration(hours: 3)), useFund: false);
      for (final t in await e.tickets(TicketKind.milestone)) {
        expect(t.closedUtc, isNull);
      }
    });

    test('같은 도착을 다시 동기화해도 기회는 하나, 열린 시각도 그대로', () async {
      final e = await _env();
      final end = await _arriveAtGyeongbok(e);
      await e.svc.sync(end);
      await e.svc.sync(end.add(const Duration(hours: 5)));
      final t = (await e.tickets(TicketKind.arrival)).single;
      expect(t.openedUtc, _ms(end));
    });
  });

  group('걸음 숫자 기회', () {
    test('99보까지는 없고, 100보를 넘으면 100 기회가 생긴다 (열린 시각 = 동기화 시각)', () async {
      final e = await _env();
      e.source.records.add(_burst(_after(_t1, 0), 99));
      await e.svc.sync(_after(_t1, 10));
      expect(await e.tickets(), isEmpty);

      e.source.records.add(_burst(_after(_t1, 20), 1));
      final at = _after(_t1, 30);
      await e.svc.sync(at);
      final t = (await e.tickets()).single;
      expect((t.id, t.kind, t.scope), ('m:100', TicketKind.milestone, 'steps:100'));
      expect((t.openedUtc, t.usedUtc, t.closedUtc), (_ms(at), null, null));

      final open = (await e.svc.openTickets(at)).single;
      expect((open.milestone, open.stepsLeft, open.placeName), (100, 500, null));
    });

    test('누적 1,000보를 한 번에 넘으면 100과 1,000 기회가 각각 생긴다', () async {
      final e = await _env();
      e.source.records.add(_walk(_t1, 10, 100));
      final at = _after(_t1, 30);
      await e.svc.sync(at);

      final ts = await e.tickets(TicketKind.milestone);
      expect({for (final t in ts) t.id}, {'m:100', 'm:1000'});
      expect({for (final t in ts) t.openedUtc}, {_ms(at)});
      expect({for (final t in ts) t.scope}, {'steps:100', 'steps:1000'});
    });

    test('7,777보를 한 번에 넘으면 네 개 (100·1,000·5,000·7,777)', () async {
      final e = await _env();
      e.source.records.add(_walk(_t1, 78, 100));
      await e.svc.sync(_after(_t1, 100));
      expect({for (final t in await e.tickets()) t.id}, {'m:100', 'm:1000', 'm:5000', 'm:7777'});
    });

    test('이미 넘은 걸음 숫자인데 기회가 없으면 만든다 (누적은 하루 요약의 합)', () async {
      final e = await _env();
      // 설치 전날 하루의 요약 6,000보를 직접 심는다 (동기화는 설치 이후만 다시 계산한다)
      await e.db.into(e.db.daySummaries).insert(DaySummariesCompanion.insert(
          day: '2026-11-10', steps: 6000, distanceM: 0, countedSessions: 0));
      final at = _after(_t1, 10);
      await e.svc.sync(at);
      final ts = await e.tickets();
      expect({for (final t in ts) t.id}, {'m:100', 'm:1000', 'm:5000'});
      expect({for (final t in ts) t.openedUtc}, {_ms(at)});
    });

    test('열린 뒤 500보를 걸으면 닫히고, 499보까지는 열려 있다', () async {
      final e = await _env();
      e.source.records.add(_burst(_after(_t1, 0), 100));
      final opened = _after(_t1, 10);
      await e.svc.sync(opened);
      expect((await e.svc.openTickets(opened)).single.stepsLeft, 500);

      // 열린 뒤 499보: 남은 1보
      e.source.records.add(_burst(_after(opened, 1), 499));
      final b = _after(opened, 10);
      await e.svc.sync(b);
      expect((await e.ticket('m:100')).closedUtc, isNull);
      expect((await e.svc.openTickets(b)).single.stepsLeft, 1);

      // 1보 더 걸으면 500보: 닫힌다
      e.source.records.add(_burst(_after(opened, 20), 1));
      final c = _after(opened, 30);
      await e.svc.sync(c);
      expect((await e.ticket('m:100')).closedUtc, _ms(c));
      expect(await e.svc.openTickets(c), isEmpty);
      expect(await e.svc.guestbookTicket('m:100', c), isNull);
    });

    test('열린 뒤 한 번에 500보를 걸어도 닫힌다', () async {
      final e = await _env();
      e.source.records.add(_burst(_after(_t1, 0), 100));
      final opened = _after(_t1, 10);
      await e.svc.sync(opened);
      e.source.records.add(_burst(_after(opened, 1), 500));
      final b = _after(opened, 10);
      await e.svc.sync(b);
      expect((await e.ticket('m:100')).closedUtc, _ms(b));
    });

    test('열리기 전에 걸은 걸음은 창에 세지 않는다', () async {
      final e = await _env();
      // 1,200보를 걷고 나서야 처음 동기화: 100·1,000 기회가 이때 열리고 남은 걸음은 그대로 500
      e.source.records.add(_walk(_t1, 12, 100));
      final at = _after(_t1, 30);
      await e.svc.sync(at);
      final open = await e.svc.openTickets(at);
      expect([for (final t in open) (t.milestone, t.stepsLeft)], [(100, 500), (1000, 500)]);
    });

    test('이미 쓴 기회는 500보를 걸어도 닫힘 시각이 붙지 않는다', () async {
      final e = await _env();
      e.source.records.add(_burst(_after(_t1, 0), 100));
      final opened = _after(_t1, 10);
      await e.svc.sync(opened);
      await e.svc.writeGuestbook('m:100', '백 걸음', opened);

      e.source.records.add(_burst(_after(opened, 1), 600));
      await e.svc.sync(_after(opened, 10));
      final t = await e.ticket('m:100');
      expect((t.usedUtc, t.closedUtc), (_ms(opened), null));
    });

    test('닫힌 기회는 걸음 숫자를 또 지나도 다시 열리지 않는다', () async {
      final e = await _env();
      e.source.records.add(_burst(_after(_t1, 0), 100));
      final opened = _after(_t1, 10);
      await e.svc.sync(opened);
      e.source.records.add(_burst(_after(opened, 1), 500));
      await e.svc.sync(_after(opened, 10));
      await e.svc.sync(_after(opened, 20));

      final ts = await e.tickets();
      expect(ts, hasLength(1));
      expect(ts.single.closedUtc, _ms(_after(opened, 10)));
    });

    test('milestones를 안 주면 걸음 숫자 기회가 생기지 않는다', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final source = FakeStepSource([_walk(_t1, 20, 100)]);
      final svc = SyncService(
        db: db,
        source: source,
        rules: rules,
        allowedSources: const [],
        landmarks: _landmarks,
        props: props,
      );
      await svc.sync(_t0);
      await svc.sync(_after(_t1, 60));
      expect(await db.select(db.guestbookTickets).get(), isEmpty);
    });
  });

  group('같은 기록으로 동기화해도 같다', () {
    test('도착과 걸음 숫자 기회: 한 번 / 여러 번 결과가 같다', () async {
      final once = await _env();
      final twice = await _env();
      await _arriveAtGyeongbok(once);
      await _arriveAtGyeongbok(twice);
      final end = _t1.add(const Duration(hours: 2));
      await twice.svc.sync(end);
      await twice.svc.sync(end.add(const Duration(hours: 4)));

      final a = await once.dump();
      expect(await twice.dump(), a);
      // 기회가 실제로 들어 있다: 도착 1 + 걸음 숫자 2 (3,000보 → 100·1,000)
      expect(a['tickets'] as List, hasLength(3));
    });

    test('쓴 뒤에 다시 동기화해도 글·기회가 그대로다', () async {
      final e = await _env();
      final end = await _arriveAtGyeongbok(e);
      await e.svc.writeGuestbook('a:$_journeyId', '도착했어요', end);
      final before = await e.dump();
      await e.svc.sync(end);
      await e.svc.sync(end.add(const Duration(hours: 1)));
      expect(await e.dump(), before);
    });
  });

  group('openTickets·Snapshot', () {
    test('도착 기회가 먼저, 그다음 남은 걸음이 적은 걸음 숫자 기회 (같으면 숫자가 작은 쪽)', () async {
      final e = await _env();
      // 분 단위 걸음을 직접 넣는다. 100은 400보, 1,000은 100보 걸었다 (남은 100·400)
      final a100 = _after(_t1, 0);
      final a1000 = _after(_t1, 100);
      await e.putTicket('m:1000', TicketKind.milestone, 'steps:1000', a1000);
      await e.putTicket('m:100', TicketKind.milestone, 'steps:100', a100);
      await e.putTicket('m:5000', TicketKind.milestone, 'steps:5000', a1000);
      await e.putTicket('a:jx', TicketKind.arrival, 'kr001', _after(_t1, 50));
      Future<void> steps(DateTime at, int n) => e.db.into(e.db.stepMinutes).insert(
          StepMinutesCompanion.insert(minuteUtc: Value(epochMinute(at)), steps: n));
      await steps(_after(_t1, 50), 300);
      await steps(_after(_t1, 150), 100);
      final now = _after(_t1, 200);

      final open = await e.svc.openTickets(now);
      expect([for (final t in open) t.id], ['a:jx', 'm:100', 'm:1000', 'm:5000']);
      expect([for (final t in open) t.stepsLeft], [null, 100, 400, 400]);
      expect((await e.svc.snapshot(now)).guestbookTicket!.id, 'a:jx');

      // 도착 기회를 쓰면 남은 걸음이 가장 적은 걸음 숫자 기회가 대표가 된다
      await e.svc.writeGuestbook('a:jx', '도착', now);
      final snap = await e.svc.snapshot(now);
      expect((snap.guestbookTicket!.id, snap.guestbookTicket!.stepsLeft), ('m:100', 100));
    });

    test('도착 기회가 둘이면 나중에 연 쪽이 먼저', () async {
      final e = await _env();
      await e.putTicket('a:j1', TicketKind.arrival, 'kr001', _after(_t1, 0));
      await e.putTicket('a:j2', TicketKind.arrival, 'kr002', _after(_t1, 5));
      final open = await e.svc.openTickets(_after(_t1, 10));
      expect([for (final t in open) t.id], ['a:j2', 'a:j1']);
    });

    test('쓴 기회·닫힌 기회는 나오지 않는다. 기회가 없으면 Snapshot도 null', () async {
      final e = await _env();
      final now = _after(_t1, 10);
      expect((await e.svc.snapshot(now)).guestbookTicket, isNull);
      await e.putTicket('a:j1', TicketKind.arrival, 'kr001', _t1, used: _after(_t1, 1));
      await e.putTicket('a:j2', TicketKind.arrival, 'kr002', _t1, closed: _after(_t1, 2));
      expect(await e.svc.openTickets(now), isEmpty);
      expect((await e.svc.snapshot(now)).guestbookTicket, isNull);
      expect(await e.svc.guestbookTicket('a:j1', now), isNull);
      expect(await e.svc.guestbookTicket('a:j2', now), isNull);
      expect(await e.svc.guestbookTicket('없는-id', now), isNull);
    });

    test('남은 걸음은 now까지만 센다', () async {
      final e = await _env();
      await e.putTicket('m:100', TicketKind.milestone, 'steps:100', _t1);
      await e.db.into(e.db.stepMinutes).insert(StepMinutesCompanion.insert(
          minuteUtc: Value(epochMinute(_after(_t1, 10))), steps: 200));
      expect((await e.svc.openTickets(_after(_t1, 5))).single.stepsLeft, 500);
      expect((await e.svc.openTickets(_after(_t1, 10))).single.stepsLeft, 300);
    });
  });

  group('writeGuestbook', () {
    test('정상: 글(앞뒤 공백 자름)을 pending으로 저장하고 기회를 쓴 것으로 바꾼다', () async {
      final e = await _env();
      final end = await _arriveAtGyeongbok(e);
      final at = end.add(const Duration(minutes: 3));
      await e.svc.writeGuestbook('a:$_journeyId', '  경복궁 좋아요 \n', at);

      final p = (await e.posts()).single;
      expect((p.ticketId, p.scope, p.body), ('a:$_journeyId', 'kr001', '경복궁 좋아요'));
      expect((p.createdUtc, p.status), (_ms(at), PostStatus.pending));
      expect((await e.ticket('a:$_journeyId')).usedUtc, _ms(at));
      expect(await e.svc.guestbookTicket('a:$_journeyId', at), isNull);
      expect((await e.svc.openTickets(at)).where((t) => t.kind == TicketKind.arrival), isEmpty);

      final mine = await e.svc.myPosts();
      expect([for (final m in mine) (m.ticketId, m.scope, m.text, m.createdAt, m.status)],
          [('a:$_journeyId', 'kr001', '경복궁 좋아요', at, PostStatus.pending)]);
    });

    test('걸음 숫자 기회: scope는 steps:<숫자>', () async {
      final e = await _env();
      e.source.records.add(_burst(_after(_t1, 0), 100));
      final opened = _after(_t1, 10);
      await e.svc.sync(opened);
      await e.svc.writeGuestbook('m:100', '백 걸음', _after(opened, 2));
      final p = (await e.posts()).single;
      expect((p.ticketId, p.scope, p.body), ('m:100', 'steps:100', '백 걸음'));
    });

    test('닫힌 기회는 StateError, 글도 동의 시각도 안 남는다', () async {
      final e = await _env();
      final end = await _arriveAtGyeongbok(e);
      final later = end.add(const Duration(hours: 1));
      await e.svc.startJourney('kr003', later, useFund: false);

      await expectLater(e.svc.writeGuestbook('a:$_journeyId', '늦었다', later),
          throwsA(isA<StateError>()));
      expect(await e.posts(), isEmpty);
      expect(await e.svc.guestbookConsented(), isFalse);
    });

    test('걸음 숫자 기회가 닫혔어도(500보) StateError', () async {
      final e = await _env();
      e.source.records.add(_burst(_after(_t1, 0), 100));
      final opened = _after(_t1, 10);
      await e.svc.sync(opened);
      e.source.records.add(_burst(_after(opened, 1), 500));
      final later = _after(opened, 10);
      await e.svc.sync(later);
      await expectLater(
          e.svc.writeGuestbook('m:100', '늦었다', later), throwsA(isA<StateError>()));
      expect(await e.posts(), isEmpty);
    });

    test('동기화가 닫기 전이라도 저장된 걸음이 창을 채웠으면 StateError, 닫힘으로 적어 둔다', () async {
      final e = await _env();
      await e.putTicket('m:100', TicketKind.milestone, 'steps:100', _t1);
      await e.db.into(e.db.stepMinutes).insert(StepMinutesCompanion.insert(
          minuteUtc: Value(epochMinute(_after(_t1, 5))), steps: rules.guestbookWindowSteps));
      final now = _after(_t1, 6);

      await expectLater(e.svc.writeGuestbook('m:100', '늦었다', now), throwsA(isA<StateError>()));
      expect(await e.posts(), isEmpty);
      // 던져도 닫힘 기록은 남는다
      expect((await e.ticket('m:100')).closedUtc, _ms(now));
    });

    test('두 번째 쓰기는 StateError, 첫 글이 그대로다', () async {
      final e = await _env();
      final end = await _arriveAtGyeongbok(e);
      await e.svc.writeGuestbook('a:$_journeyId', '첫 글', end);
      await expectLater(
          e.svc.writeGuestbook('a:$_journeyId', '둘째 글', end.add(const Duration(minutes: 1))),
          throwsA(isA<StateError>()));
      expect([for (final p in await e.posts()) p.body], ['첫 글']);
    });

    test('없는 기회는 StateError', () async {
      final e = await _env();
      await expectLater(
          e.svc.writeGuestbook('a:없음', '글', _t1), throwsA(isA<StateError>()));
      expect(await e.posts(), isEmpty);
    });

    test('빈 글·공백뿐인 글·201자는 StateError, 기회는 열려 있다. 200자는 된다', () async {
      final e = await _env();
      await e.putTicket('a:j1', TicketKind.arrival, 'kr001', _t1);
      for (final bad in ['', '   ', '\n\n', '가' * 201]) {
        await expectLater(e.svc.writeGuestbook('a:j1', bad, _after(_t1, 1)),
            throwsA(isA<StateError>()), reason: '글: ${bad.length}자');
      }
      expect(await e.posts(), isEmpty);
      expect((await e.ticket('a:j1')).usedUtc, isNull);
      expect(await e.svc.guestbookConsented(), isFalse);

      await e.svc.writeGuestbook('a:j1', '가' * 200, _after(_t1, 2));
      expect((await e.posts()).single.body, '가' * 200);
    });

    test('첫 사용이면 동의 시각을 적고, 이어 쓸 때는 첫 시각을 그대로 둔다', () async {
      final e = await _env(home: false);
      await completeOnboarding(e.db);
      expect(await e.svc.guestbookConsented(), isFalse);
      await e.putTicket('a:j1', TicketKind.arrival, 'kr001', _t1);
      await e.putTicket('m:100', TicketKind.milestone, 'steps:100', _t1);

      final first = _after(_t1, 1);
      await e.svc.writeGuestbook('a:j1', '첫 글', first);
      var profile = await _profile(e);
      expect(profile.guestbookConsentAt, _ms(first));
      expect(await e.svc.guestbookConsented(), isTrue);
      // 다른 프로필 값은 건드리지 않는다
      expect((profile.nickname, profile.installId), ('화가', '0' * 32));

      await e.svc.writeGuestbook('m:100', '둘째 글', _after(_t1, 2));
      profile = await _profile(e);
      expect(profile.guestbookConsentAt, _ms(first));
      expect((await e.posts()).length, 2);
    });

    test('프로필 행이 아직 없어도 동의 시각을 적는다', () async {
      final e = await _env(home: false);
      expect(await e.db.select(e.db.profile).get(), isEmpty);
      await e.putTicket('a:j1', TicketKind.arrival, 'kr001', _t1);
      await e.svc.writeGuestbook('a:j1', '글', _after(_t1, 1));
      expect((await _profile(e)).guestbookConsentAt, _ms(_after(_t1, 1)));
    });

    test('글을 못 쓰면 동의 시각도 안 남는다', () async {
      final e = await _env(home: false);
      await completeOnboarding(e.db);
      await e.putTicket('a:j1', TicketKind.arrival, 'kr001', _t1, closed: _after(_t1, 1));
      await expectLater(
          e.svc.writeGuestbook('a:j1', '글', _after(_t1, 2)), throwsA(isA<StateError>()));
      expect((await _profile(e)).guestbookConsentAt, isNull);
    });
  });

  test('myPosts: 최근에 쓴 순서', () async {
    final e = await _env();
    expect(await e.svc.myPosts(), isEmpty);
    await e.putTicket('a:j1', TicketKind.arrival, 'kr001', _t1);
    await e.putTicket('a:j2', TicketKind.arrival, 'sketch', _t1);
    await e.svc.writeGuestbook('a:j1', '먼저', _after(_t1, 1));
    await e.svc.writeGuestbook('a:j2', '나중', _after(_t1, 2));
    expect([for (final p in await e.svc.myPosts()) (p.text, p.scope)],
        [('나중', 'sketch'), ('먼저', 'kr001')]);
  });
}

Future<ProfileRow> _profile(_Env e) => e.db.select(e.db.profile).getSingle();
