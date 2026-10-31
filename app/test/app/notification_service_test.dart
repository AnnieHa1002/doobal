import 'package:doobal/app/notification_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/notifier.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

/// 한국 시각 → UTC (한국은 UTC+9)
DateTime _kst(int month, int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, month, day, hour - 9, minute);

NoticeCandidate _n2(String journey) =>
    NoticeCandidate(NoticeKind.n2, key: journey, vars: const {'dest': '경복궁'});

NoticeCandidate _n1(int milestone) => NoticeCandidate(NoticeKind.n1,
    key: 'm:$milestone', vars: {'milestone': milestone});

NoticeCandidate _n4(String journey) => NoticeCandidate(NoticeKind.n4,
    key: journey, vars: const {'dest': '경복궁', 'remainingKm': 9.5});

/// 처음 [failures]번은 보내다 실패하는 알림 보내는 곳
class _FlakyNotifier extends PlaceholderNotifier {
  _FlakyNotifier(this.failures);

  int failures;

  @override
  Future<void> show(int id, NoticeKind kind, String title, String body, String payload) {
    if (failures-- > 0) throw StateError('알림을 못 띄운다');
    return super.show(id, kind, title, body, payload);
  }
}

class _Env {
  _Env({PlaceholderNotifier? notifier})
      : db = AppDb(NativeDatabase.memory()),
        notifier = notifier ?? PlaceholderNotifier() {
    svc = NotificationService(
      db: db,
      rules: rules,
      catalog: noticeCatalog,
      notifier: this.notifier,
      inForeground: () => foreground,
    );
    addTearDown(db.close);
  }

  final AppDb db;
  final PlaceholderNotifier notifier;
  late final NotificationService svc;

  /// 앱이 앞에 있는가. 기본은 꺼져 있다 (백그라운드 동기화처럼)
  bool foreground = false;

  Future<List<NotificationLogRow>> log() =>
      (db.select(db.notificationLog)..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

  /// 기록을 (종류, 키, 상태)로 줄인 것
  Future<List<(NoticeKind, String, NoticeStatus)>> rows() async =>
      [for (final r in await log()) (r.kind, r.refKey, r.status)];

  List<NotifierCall> calls(NotifierOp op) => [
        for (final c in notifier.calls)
          if (c.op == op) c,
      ];
}

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('동기화 끝 (N1~N4)', () {
    test('앱이 앞에 있으면 시스템 알림 없이 화면 안 표시만 하고 기록한다', () async {
      final e = _Env()..foreground = true;
      final now = _kst(11, 18, 12);
      await e.svc.afterSync([_n2('j1')], now);

      expect(e.notifier.calls, isEmpty);
      expect(await e.rows(), [(NoticeKind.n2, 'j1', NoticeStatus.inApp)]);
      expect(_utc((await e.log()).single.atUtc), now);
    });

    test('낮에 앱이 꺼져 있으면 지금 보내고 보낸 시각을 기록한다', () async {
      final e = _Env();
      final now = _kst(11, 18, 12);
      await e.svc.afterSync([_n2('j1')], now);

      final row = (await e.log()).single;
      expect((row.kind, row.refKey, row.status), (NoticeKind.n2, 'j1', NoticeStatus.sent));
      expect(_utc(row.atUtc), now);
      final show = e.calls(NotifierOp.show).single;
      // 알림 id는 기록 id라서 나중에 취소할 수 있다
      expect(show.id, row.id);
      expect(show.kind, NoticeKind.n2);
      expect(show.payload, 'N2:j1');
      expect(show.title, isNotEmpty);
      expect('${show.title}${show.body}', isNot(contains('{')));
      expect(e.calls(NotifierOp.schedule), isEmpty);
    });

    test('같은 동기화의 N1+N2는 N1만 보내고 N2는 버린다', () async {
      final e = _Env();
      await e.svc.afterSync([_n2('j1'), _n1(1000)], _kst(11, 18, 12));

      expect(e.calls(NotifierOp.show).map((c) => c.kind), [NoticeKind.n1]);
      expect(e.calls(NotifierOp.show).single.payload, 'N1:m:1000');
      expect(await e.rows(), [
        (NoticeKind.n1, 'm:1000', NoticeStatus.sent),
        (NoticeKind.n2, 'j1', NoticeStatus.dropped),
      ]);
    });

    test('하루 3번째는 안 보낸다', () async {
      final e = _Env();
      await e.svc.afterSync([_n2('j1')], _kst(11, 18, 10));
      await e.svc.afterSync([_n1(100)], _kst(11, 18, 11));
      await e.svc.afterSync([_n4('j2')], _kst(11, 18, 12));

      expect(e.calls(NotifierOp.show), hasLength(2));
      expect(await e.rows(), [
        (NoticeKind.n2, 'j1', NoticeStatus.sent),
        (NoticeKind.n1, 'm:100', NoticeStatus.sent),
        (NoticeKind.n4, 'j2', NoticeStatus.dropped),
      ]);
    });

    test('한국 자정이 지나면 개수가 초기화된다', () async {
      final e = _Env();
      await e.svc.afterSync([_n2('j1')], _kst(11, 18, 20));
      await e.svc.afterSync([_n1(100)], _kst(11, 18, 21, 59));
      await e.svc.afterSync([_n4('j2')], _kst(11, 18, 21, 59));
      expect(e.calls(NotifierOp.show), hasLength(2));

      // 다음 날 낮에는 다시 보낸다
      await e.svc.afterSync([_n1(1000)], _kst(11, 19, 9));
      await e.svc.afterSync([_n4('j3')], _kst(11, 19, 10));
      expect(e.calls(NotifierOp.show), hasLength(4));
    });

    test('조용한 시간에 생기면 08:00에 1개만 예약한다', () async {
      final e = _Env();
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 23));

      expect(e.calls(NotifierOp.show), isEmpty);
      final s = e.calls(NotifierOp.schedule).single;
      expect(s.at, _kst(11, 19, 8));
      expect(s.kind, NoticeKind.n4);
      final row = (await e.log()).single;
      expect((row.kind, row.status, _utc(row.atUtc)),
          (NoticeKind.n4, NoticeStatus.scheduled, _kst(11, 19, 8)));
      expect(s.id, row.id);
    });

    test('08:00 예약보다 높은 우선순위가 오면 바꿔 끼우고, 낮으면 그대로 둔다', () async {
      final e = _Env();
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 23));
      final oldId = (await e.log()).single.id;

      // 더 높은 N2: 앞 예약을 취소하고 새로 예약
      await e.svc.afterSync([_n2('j2')], _kst(11, 18, 23, 20));
      expect(e.calls(NotifierOp.cancel).map((c) => c.id), [oldId]);
      expect(e.calls(NotifierOp.schedule), hasLength(2));
      expect(await e.rows(), [
        (NoticeKind.n4, 'j1', NoticeStatus.cancelled),
        (NoticeKind.n2, 'j2', NoticeStatus.scheduled),
      ]);

      // 더 낮은 N4(다른 여정): 그대로 두고 버린다
      await e.svc.afterSync([_n4('j3')], _kst(11, 19, 1));
      expect(e.calls(NotifierOp.schedule), hasLength(2));
      expect(e.calls(NotifierOp.cancel), hasLength(1));
      expect((await e.rows()).last, (NoticeKind.n4, 'j3', NoticeStatus.dropped));
    });

    test('예약한 알림이 뜬 뒤에는 그 알림도 그날의 개수에 센다', () async {
      final e = _Env();
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 23));
      // 19일 09:00: 08:00 예약은 이미 떴다 → 1개. 하나 더 보내면 2개
      await e.svc.afterSync([_n2('j2')], _kst(11, 19, 9));
      await e.svc.afterSync([_n1(100)], _kst(11, 19, 10));
      expect(e.calls(NotifierOp.show).map((c) => c.kind), [NoticeKind.n2]);
      expect((await e.rows()).last, (NoticeKind.n1, 'm:100', NoticeStatus.dropped));
    });

    test('같은 일(종류·키)로는 다시 알리지 않는다: N4는 여정마다 1번', () async {
      final e = _Env();
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 12));
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 13));
      expect(e.calls(NotifierOp.show), hasLength(1));
      expect(await e.rows(), [(NoticeKind.n4, 'j1', NoticeStatus.sent)]);

      // 다른 여정은 다시 알린다
      await e.svc.afterSync([_n4('j2')], _kst(11, 18, 14));
      expect(e.calls(NotifierOp.show), hasLength(2));
    });

    test('버려진 N4도 다시 알리지 않는다 (같은 동기화의 N1에 졌을 때)', () async {
      final e = _Env();
      await e.svc.afterSync([_n4('j1'), _n1(100)], _kst(11, 18, 12));
      expect((await e.rows()).last, (NoticeKind.n4, 'j1', NoticeStatus.dropped));
      await e.svc.afterSync([_n4('j1')], _kst(11, 19, 12));
      expect(e.calls(NotifierOp.show), hasLength(1));
      expect(await e.log(), hasLength(2));
    });

    test('앞에 있을 때 화면 안만 한 일도 다시 알리지 않는다', () async {
      final e = _Env()..foreground = true;
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 12));
      e.foreground = false;
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 13));
      expect(e.notifier.calls, isEmpty);
      expect(await e.log(), hasLength(1));
    });

    test('보내다 실패하면 기록을 보내지 못한 것(dropped)으로 고치고, 하루 개수에 안 센다', () async {
      final e = _Env(notifier: _FlakyNotifier(1));
      await e.svc.afterSync([_n2('j1')], _kst(11, 18, 12));
      expect(await e.rows(), [(NoticeKind.n2, 'j1', NoticeStatus.dropped)]);

      // 실패한 것을 세면 둘째는 나가고 셋째가 막힌다. 안 세니까 둘 다 나간다
      await e.svc.afterSync([_n1(100)], _kst(11, 18, 13));
      await e.svc.afterSync([_n1(1000)], _kst(11, 18, 14));
      expect((await e.rows()).map((r) => r.$3),
          [NoticeStatus.dropped, NoticeStatus.sent, NoticeStatus.sent]);
    });

    test('후보가 없으면 아무것도 적지 않는다', () async {
      final e = _Env();
      await e.svc.afterSync([], _kst(11, 18, 12));
      expect(await e.log(), isEmpty);
      expect(e.notifier.calls, isEmpty);
    });
  });

  group('종류별 켜고 끄기', () {
    test('처음에는 모두 켜져 있고, 저장하면 다시 읽어도 그대로다', () async {
      final e = _Env();
      expect((await e.svc.settings()).enabled, NoticeKind.values.toSet());

      await e.svc.setKind(NoticeKind.n3, false, _kst(11, 18, 12));
      final s = await e.svc.settings();
      expect(s.all, isTrue);
      expect(s.off, {NoticeKind.n3});

      await e.svc.setAll(false, _kst(11, 18, 12));
      // 같은 DB를 다시 연 서비스도 같은 값을 읽는다
      final again = NotificationService(
        db: e.db,
        rules: rules,
        catalog: noticeCatalog,
        notifier: e.notifier,
      );
      final restored = await again.settings();
      expect(restored.all, isFalse);
      expect(restored.off, {NoticeKind.n3});

      await again.setAll(true, _kst(11, 18, 12));
      expect((await again.settings()).enabled, {
        NoticeKind.n1,
        NoticeKind.n2,
        NoticeKind.n4,
        NoticeKind.n5,
      });
    });

    test('꺼진 종류는 판정에서 빠진다', () async {
      final e = _Env();
      await e.svc.setKind(NoticeKind.n1, false, _kst(11, 18, 11));
      await e.svc.afterSync([_n2('j1'), _n1(100)], _kst(11, 18, 12));
      expect(e.calls(NotifierOp.show).map((c) => c.kind), [NoticeKind.n2]);
      expect(await e.rows(), [
        (NoticeKind.n2, 'j1', NoticeStatus.sent),
        (NoticeKind.n1, 'm:100', NoticeStatus.dropped),
      ]);
    });

    test('전체를 끄면 아무것도 안 보낸다', () async {
      final e = _Env();
      await e.svc.setAll(false, _kst(11, 18, 11));
      await e.svc.afterSync([_n2('j1')], _kst(11, 18, 12));
      expect(e.notifier.calls, isEmpty);
      expect(await e.rows(), [(NoticeKind.n2, 'j1', NoticeStatus.dropped)]);
    });

    test('끄면 그 종류의 예약된 알림은 취소된다', () async {
      final e = _Env();
      await e.svc.afterSync([_n1(100)], _kst(11, 18, 23));
      await e.svc.onBackground(_kst(11, 18, 23, 1));
      final ids = [for (final r in await e.log()) r.id];
      expect(ids, hasLength(2));

      // N1만 끈다: N5 예약은 남는다
      await e.svc.setKind(NoticeKind.n1, false, _kst(11, 18, 23, 5));
      expect(e.calls(NotifierOp.cancel).map((c) => c.id), [ids[0]]);
      expect((await e.rows()).map((r) => r.$3),
          [NoticeStatus.cancelled, NoticeStatus.scheduled]);

      // 전체를 끈다: N5도 취소
      await e.svc.setAll(false, _kst(11, 18, 23, 6));
      expect(e.calls(NotifierOp.cancel).map((c) => c.id), [ids[0], ids[1]]);
      expect((await e.rows()).map((r) => r.$3),
          [NoticeStatus.cancelled, NoticeStatus.cancelled]);
    });
  });

  group('N5 (3일 미접속)', () {
    test('백그라운드로 가면 지금 + 72시간에 예약한다', () async {
      final e = _Env();
      final now = _kst(11, 18, 14, 30);
      await e.svc.onBackground(now);

      final s = e.calls(NotifierOp.schedule).single;
      expect(s.kind, NoticeKind.n5);
      expect(s.at, now.add(const Duration(hours: 72)));
      expect(s.at, _kst(11, 21, 14, 30));
      expect(s.payload, 'N5:');
      final row = (await e.log()).single;
      expect((row.kind, row.status, _utc(row.atUtc)),
          (NoticeKind.n5, NoticeStatus.scheduled, _kst(11, 21, 14, 30)));
      expect(s.id, row.id);
    });

    test('연달아 백그라운드 신호가 와도 한 번만 예약한다', () async {
      final e = _Env();
      await e.svc.onBackground(_kst(11, 18, 14));
      await e.svc.onBackground(_kst(11, 18, 14));
      expect(e.calls(NotifierOp.schedule), hasLength(1));
      expect(await e.log(), hasLength(1));
    });

    test('다시 열면 취소하고, 다시 백그라운드로 가면 새로 예약한다', () async {
      final e = _Env();
      await e.svc.onBackground(_kst(11, 18, 14));
      final firstId = (await e.log()).single.id;

      await e.svc.onOpen(_kst(11, 18, 20));
      expect(e.calls(NotifierOp.cancel).map((c) => c.id), [firstId]);
      expect(await e.rows(), [(NoticeKind.n5, '', NoticeStatus.cancelled)]);

      await e.svc.onBackground(_kst(11, 18, 21));
      final s = e.calls(NotifierOp.schedule);
      expect(s, hasLength(2));
      expect(s.last.at, _kst(11, 21, 21));
      expect(s.last.id, isNot(firstId));
    });

    test('열었는데 예약이 없어도 아무 일 없다 (처음 켤 때)', () async {
      final e = _Env();
      await e.svc.onOpen(_kst(11, 18, 9));
      expect(e.notifier.calls, isEmpty);
      expect(await e.log(), isEmpty);
    });

    test('이미 울렸는데 아직 안 열었으면 다시 예약하지 않고, 열면 다시 예약할 수 있다', () async {
      final e = _Env();
      await e.svc.onBackground(_kst(11, 18, 14));

      // 21일 14:00에 울렸다. 앱은 안 열고 백그라운드 신호만 온다
      await e.svc.onBackground(_kst(11, 21, 15));
      expect(e.calls(NotifierOp.schedule), hasLength(1));

      // 열면 울린 것으로 남기고(취소하지 않는다) 상태를 초기화한다
      await e.svc.onOpen(_kst(11, 21, 16));
      expect(e.calls(NotifierOp.cancel), isEmpty);
      expect(await e.rows(), [(NoticeKind.n5, '', NoticeStatus.sent)]);
      await e.svc.onBackground(_kst(11, 21, 17));
      expect(e.calls(NotifierOp.schedule), hasLength(2));
      expect(e.calls(NotifierOp.schedule).last.at, _kst(11, 24, 17));
    });

    test('꺼져 있으면 예약하지 않는다', () async {
      final e = _Env();
      await e.svc.setKind(NoticeKind.n5, false, _kst(11, 18, 9));
      await e.svc.onBackground(_kst(11, 18, 14));
      expect(e.notifier.calls, isEmpty);
      expect(await e.log(), isEmpty);
    });

    test('72시간 뒤가 조용한 시간이면 10:00에 울리도록 예약한다', () async {
      final e = _Env();
      await e.svc.onBackground(_kst(11, 18, 23));
      expect(e.calls(NotifierOp.schedule).single.at, _kst(11, 22, 10));
    });

    test('N5도 그날의 개수에 센다', () async {
      final e = _Env();
      await e.svc.onBackground(_kst(11, 18, 14));
      // N5가 뜨는 21일 14:00 전에 21일 오전 둘이 오면: 첫째는 나가고(N5와 합쳐 2개) 둘째는 막힌다
      await e.svc.afterSync([_n2('j1')], _kst(11, 21, 10));
      await e.svc.afterSync([_n1(100)], _kst(11, 21, 11));
      expect(e.calls(NotifierOp.show).map((c) => c.kind), [NoticeKind.n2]);
      expect((await e.rows()).last, (NoticeKind.n1, 'm:100', NoticeStatus.dropped));
    });

    test('N5는 N1~N4의 08:00 예약과 따로다 (서로 바꾸지 않는다)', () async {
      final e = _Env();
      await e.svc.onBackground(_kst(11, 18, 23, 30));
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 23, 40));
      expect(await e.rows(), [
        (NoticeKind.n5, '', NoticeStatus.scheduled),
        (NoticeKind.n4, 'j1', NoticeStatus.scheduled),
      ]);
      expect(e.calls(NotifierOp.cancel), isEmpty);
    });
  });

  group('예약 모두 취소', () {
    test('아직 안 뜬 예약만 취소한다 (이미 보낸 것은 그대로)', () async {
      final e = _Env();
      await e.svc.afterSync([_n2('j0')], _kst(11, 18, 12));
      await e.svc.afterSync([_n4('j1')], _kst(11, 18, 23));
      await e.svc.onBackground(_kst(11, 18, 23, 5));

      await e.svc.cancelAllPending(_kst(11, 18, 23, 10));
      expect((await e.rows()).map((r) => r.$3), [
        NoticeStatus.sent,
        NoticeStatus.cancelled,
        NoticeStatus.cancelled,
      ]);
      expect(e.calls(NotifierOp.cancel), hasLength(2));
    });
  });
}
