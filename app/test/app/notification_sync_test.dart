import 'package:doobal/app/notification_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/notifier.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart';

// 설치 KST 2026-11-18 09:00, 걷기 시작은 한 시간 뒤 (낮)
final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

final _byId = {for (final l in landmarks) l.id: l};

// 경복궁에서 동쪽으로 약 1km
const _nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

/// start부터 minutes분 동안 분당 spm보로 걸은 기록 하나
StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

DateTime _after(DateTime t, int minutes) => t.add(Duration(minutes: minutes));

/// 알림 판단을 붙인 동기화. [milestones]를 비우면 걸음 숫자 기회(N1)가 생기지 않는다
class _Env {
  _Env({List<int>? milestones, bool notices = true})
      : db = AppDb(NativeDatabase.memory()),
        source = FakeStepSource(),
        notifier = PlaceholderNotifier() {
    if (notices) {
      noticeService = NotificationService(
        db: db,
        rules: rules,
        catalog: noticeCatalog,
        notifier: notifier,
        inForeground: () => foreground,
      );
    }
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _byId,
      props: props,
      milestones: milestones ?? const [],
      notificationService: noticeService,
    );
    addTearDown(db.close);
  }

  final AppDb db;
  final FakeStepSource source;
  final PlaceholderNotifier notifier;
  late final SyncService svc;
  NotificationService? noticeService;

  /// 앱이 앞에 있는가 (기본은 앞: 앱 안 동기화)
  bool foreground = true;

  Future<List<(NoticeKind, String, NoticeStatus)>> rows() async => [
        for (final r in await (db.select(db.notificationLog)
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get())
          (r.kind, r.refKey, r.status),
      ];

  /// 설치(= _t0)하고 출발 동네를 골라 둔다
  Future<void> install() async {
    await svc.setHome(testHomeName, testHome);
    await svc.sync(_t0);
  }

  /// 경복궁 근처에서 경비 없이 경복궁으로 출발해, 30분 걷고 [syncAt]에 동기화한다 (도착한다)
  Future<SyncReport> arriveAtGyeongbok(DateTime syncAt) async {
    await placeAt(db, _nearGyeongbok, _t0);
    await svc.startJourney('kr001', _t1, useFund: false);
    source.records.add(_walk(_after(_t1, 5), 30, 100));
    return svc.sync(syncAt);
  }

  /// 환산 거리 [km]인 가상 목적지로 가는 여정을 t1에 직접 넣는다 (북동쪽, 출발은 testHome)
  Future<String> insertJourney(double km) async {
    final dest = destinationPoint(testHome, 45, km, rules.earthRadiusKm);
    await db.into(db.journeys).insert(JourneysCompanion.insert(
          id: 'j${_t1.millisecondsSinceEpoch}',
          originLat: testHome.lat,
          originLng: testHome.lng,
          destId: sketchId,
          startUtc: _t1.millisecondsSinceEpoch,
          fundKm: 0,
          totalEffectiveKm: km,
          status: JourneyStatus.active,
          destLat: Value(dest.lat),
          destLng: Value(dest.lng),
        ));
    return 'j${_t1.millisecondsSinceEpoch}';
  }
}

final _journeyId = 'j${_t1.millisecondsSinceEpoch}';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('N2 도착', () {
    test('도착한 동기화가 N2 후보를 만든다 (장소 이름은 명소 이름)', () async {
      final e = _Env(notices: false);
      await e.install();
      final report = await e.arriveAtGyeongbok(_after(_t1, 120));

      final n2 = report.notices.single;
      expect((n2.kind, n2.key), (NoticeKind.n2, _journeyId));
      expect(n2.vars, {'dest': '경복궁'});
    });

    test('도착 동기화 → N2 후보 → 앞에 있으면 화면 안 표시만 → 로그', () async {
      final e = _Env();
      await e.install();
      final report = await e.arriveAtGyeongbok(_after(_t1, 120));

      expect(report.notices.map((c) => c.kind), [NoticeKind.n2]);
      expect(e.notifier.calls, isEmpty);
      expect(await e.rows(), [(NoticeKind.n2, _journeyId, NoticeStatus.inApp)]);
    });

    test('앱이 꺼진 채(백그라운드) 도착하면 지금 알림을 보낸다', () async {
      final e = _Env()..foreground = false;
      await e.install();
      await e.arriveAtGyeongbok(_after(_t1, 120));

      final show = e.notifier.calls.single;
      expect((show.op, show.kind, show.payload),
          (NotifierOp.show, NoticeKind.n2, 'N2:$_journeyId'));
      expect(await e.rows(), [(NoticeKind.n2, _journeyId, NoticeStatus.sent)]);
    });

    test('밤에 도착을 알면 다음 날 08:00에 예약한다', () async {
      final e = _Env()..foreground = false;
      await e.install();
      // 한국 11월 18일 23:30 (UTC 14:30)에 동기화
      await e.arriveAtGyeongbok(DateTime.utc(2026, 11, 18, 14, 30));

      expect(e.notifier.calls.single.op, NotifierOp.schedule);
      expect(e.notifier.calls.single.at, DateTime.utc(2026, 11, 18, 23));
      expect(await e.rows(), [(NoticeKind.n2, _journeyId, NoticeStatus.scheduled)]);
    });

    test('첫 여정(내 동네 스케치)에 도착하면 장소 이름은 내 동네 스케치', () async {
      final e = _Env(notices: false);
      await e.install();
      await completeOnboarding(e.db);
      expect(await e.svc.startSketch(_t1), isTrue);
      final km = (await e.svc.snapshot(_t1)).journey!.totalKm;
      final minutes = (km * 1000 / (rules.walkStrideM * 100)).ceil() + 1;
      e.source.records.add(_walk(_after(_t1, 5), minutes, 100));
      final report = await e.svc.sync(_after(_t1, 120));

      final n2 = report.notices.single;
      expect((n2.kind, n2.key), (NoticeKind.n2, _journeyId));
      expect(n2.vars, {'dest': '내 동네 스케치'});
    });

    test('도착하지 않은 동기화에는 N2가 없다', () async {
      final e = _Env(notices: false);
      await e.install();
      await e.insertJourney(12);
      e.source.records.add(_walk(_after(_t1, 5), 10, 100));
      final report = await e.svc.sync(_after(_t1, 30));
      expect(report.notices, isEmpty);
    });
  });

  group('N1 방명록 걸음 숫자', () {
    test('이번에 새로 넘은 걸음 숫자만 후보가 된다', () async {
      final e = _Env(milestones: milestones, notices: false);
      await e.install();
      // 분당 100보로 15분 = 1,500보: 100과 1000을 넘는다
      e.source.records.add(_walk(_after(_t1, 5), 15, 100));
      final first = await e.svc.sync(_after(_t1, 30));
      // 가장 최근에 넘은 숫자가 앞이다
      expect(first.notices.map((c) => (c.kind, c.key)),
          [(NoticeKind.n1, 'm:1000'), (NoticeKind.n1, 'm:100')]);
      expect(first.notices.map((c) => c.vars['milestone']), [1000, 100]);

      // 같은 기록으로 또 돌리면 새로 생긴 일이 없다
      expect((await e.svc.sync(_after(_t1, 31))).notices, isEmpty);
    });

    test('같은 동기화의 N1+N2는 N1만 알리고 N2는 버린다', () async {
      final e = _Env(milestones: milestones)..foreground = false;
      await e.install();
      // 3,000보를 걸어 경복궁에 도착: 100·1000을 넘는다
      final report = await e.arriveAtGyeongbok(_after(_t1, 120));

      expect(report.notices.map((c) => c.kind),
          [NoticeKind.n2, NoticeKind.n1, NoticeKind.n1]);
      expect(e.notifier.calls.single.payload, 'N1:m:1000');
      expect(await e.rows(), [
        (NoticeKind.n1, 'm:1000', NoticeStatus.sent),
        (NoticeKind.n2, _journeyId, NoticeStatus.dropped),
        (NoticeKind.n1, 'm:100', NoticeStatus.dropped),
      ]);
    });

    test('방명록 기회의 열린 시각은 아직 동기화 시각이다 (알림이 실제로 뜨지 않으니)', () async {
      final e = _Env(milestones: milestones)..foreground = false;
      await e.install();
      e.source.records.add(_walk(_after(_t1, 5), 3, 100));
      // 한국 23:30 → 알림은 08:00 예약이어도 기회 열린 시각은 바꾸지 않는다 (TODO(M6))
      final syncAt = DateTime.utc(2026, 11, 18, 14, 30);
      await e.svc.sync(syncAt);
      final t = await (e.db.select(e.db.guestbookTickets)..where((t) => t.id.equals('m:100')))
          .getSingle();
      expect(t.openedUtc, syncAt.millisecondsSinceEpoch);
      expect(e.notifier.calls.single.op, NotifierOp.schedule);
    });
  });

  group('N4 목적지 10km 안', () {
    test('10km 밖에서 안으로 들어온 동기화에서 한 번만', () async {
      final e = _Env();
      await e.install();
      await e.insertJourney(12);

      // 2.1km 걷는다: 남은 거리 약 9.9km → 들어왔다
      e.source.records.add(_walk(_after(_t1, 5), 30, 100));
      final entered = await e.svc.sync(_after(_t1, 40));
      final n4 = entered.notices.single;
      expect((n4.kind, n4.key), (NoticeKind.n4, _journeyId));
      final remaining = (await e.svc.snapshot(_after(_t1, 40))).journey!.progress.remainingKm;
      expect(remaining, lessThanOrEqualTo(10));
      expect(n4.vars['dest'], '내 동네 스케치');
      expect(n4.vars['remainingKm'] as double, closeTo(remaining, 1e-9));
      expect(await e.rows(), [(NoticeKind.n4, _journeyId, NoticeStatus.inApp)]);

      // 더 걸어도 이미 안이라 다시 후보가 되지 않는다
      e.source.records.add(_walk(_after(_t1, 60), 20, 100));
      expect((await e.svc.sync(_after(_t1, 90))).notices, isEmpty);
      expect(await e.rows(), hasLength(1));
    });

    test('10km 안에서 시작한 여정은 N4가 없다', () async {
      final e = _Env();
      await e.install();
      await e.insertJourney(8);
      e.source.records.add(_walk(_after(_t1, 5), 30, 100));
      expect((await e.svc.sync(_after(_t1, 40))).notices, isEmpty);
    });

    test('아직 10km 밖이면 N4가 없다', () async {
      final e = _Env();
      await e.install();
      await e.insertJourney(15);
      e.source.records.add(_walk(_after(_t1, 5), 30, 100));
      expect((await e.svc.sync(_after(_t1, 40))).notices, isEmpty);
    });

    test('10km 안으로 들어오면서 도착까지 한 동기화는 N2만이다', () async {
      final e = _Env();
      await e.install();
      await e.insertJourney(12);
      // 분당 70m로 12km는 172분: 한 번에 넘어간다
      e.source.records.add(_walk(_after(_t1, 5), 180, 100));
      final report = await e.svc.sync(_after(_t1, 200));
      expect(report.notices.map((c) => c.kind), [NoticeKind.n2]);
    });
  });

  test('알림 판단을 안 붙여도 동기화는 그대로고 후보만 리포트에 있다', () async {
    final e = _Env(milestones: milestones, notices: false);
    await e.install();
    e.source.records.add(_walk(_after(_t1, 5), 3, 100));
    final report = await e.svc.sync(_after(_t1, 30));
    expect(report.notices.map((c) => c.kind), [NoticeKind.n1]);
    expect(await e.rows(), isEmpty);
    expect(e.notifier.calls, isEmpty);
  });
}
