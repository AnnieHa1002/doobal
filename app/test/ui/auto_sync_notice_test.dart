import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/notifier.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

/// 앱이 백그라운드로 간다 (실제로는 inactive → hidden → paused 순서로 온다)
void _toBackground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

/// 앱이 앞으로 돌아온다
void _toForeground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

List<NotifierCall> _calls(UiEnv e, NotifierOp op) => [
      for (final c in e.notifier.calls)
        if (c.op == op) c,
    ];

Future<List<(NoticeKind, NoticeStatus)>> _log(WidgetTester tester, UiEnv e) async => [
      for (final r in (await tester.runAsync(() => (e.db.select(e.db.notificationLog)
                ..orderBy([(t) => OrderingTerm(expression: t.id)]))
              .get()))!)
        (r.kind, r.status),
    ];

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<ProviderContainer> openApp(WidgetTester tester, UiEnv e,
      {Future<void> Function()? seed}) async {
    await e.seed(tester, seed);
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(RestScreen)));
  }

  testWidgets('백그라운드로 가면 N5를 지금 + 72시간에 예약하고, 돌아오면 취소한다', (tester) async {
    final e = UiEnv();
    final container = await openApp(tester, e);
    expect(container.read(appForegroundProvider), isTrue);
    expect(e.notifier.calls, isEmpty);

    _toBackground(tester);
    await settle(tester, () => _calls(e, NotifierOp.schedule).isNotEmpty);
    expect(container.read(appForegroundProvider), isFalse);
    // 숨김과 일시정지가 연달아 와도 한 번만 예약한다
    final scheduled = _calls(e, NotifierOp.schedule).single;
    expect(scheduled.kind, NoticeKind.n5);
    expect(scheduled.at, t1.add(const Duration(hours: 72)));
    expect(await _log(tester, e), [(NoticeKind.n5, NoticeStatus.scheduled)]);

    _toForeground(tester);
    await settle(tester, () => _calls(e, NotifierOp.cancel).isNotEmpty);
    expect(container.read(appForegroundProvider), isTrue);
    expect(_calls(e, NotifierOp.cancel).single.id, scheduled.id);
    expect(await _log(tester, e), [(NoticeKind.n5, NoticeStatus.cancelled)]);

    // 또 백그라운드로 가면 새로 예약한다
    _toBackground(tester);
    await settle(tester, () => _calls(e, NotifierOp.schedule).length == 2);
    expect(_calls(e, NotifierOp.schedule), hasLength(2));
    expect(await _log(tester, e),
        [(NoticeKind.n5, NoticeStatus.cancelled), (NoticeKind.n5, NoticeStatus.scheduled)]);
    await end(tester, e);
  });

  testWidgets('앱을 켤 때도 앞 실행이 남긴 N5 예약을 취소한다', (tester) async {
    final e = UiEnv();
    await openApp(tester, e, seed: () async {
      await e.db.into(e.db.notificationLog).insert(NotificationLogCompanion.insert(
            kind: NoticeKind.n5,
            refKey: '',
            atUtc: t1.add(const Duration(hours: 40)).millisecondsSinceEpoch,
            status: NoticeStatus.scheduled,
          ));
    });
    await settle(tester, () => _calls(e, NotifierOp.cancel).isNotEmpty);
    expect(_calls(e, NotifierOp.cancel).single.id, 1);
    expect(await _log(tester, e), [(NoticeKind.n5, NoticeStatus.cancelled)]);
    await end(tester, e);
  });

  testWidgets('앱이 앞에 있을 때의 동기화는 화면 안 표시만, 백그라운드 동기화는 시스템 알림', (tester) async {
    final e = UiEnv();
    final container = await openApp(tester, e);
    final svc = (await tester.runAsync(() => container.read(syncServiceProvider.future)))!;
    // 앱이 하는 것처럼 화면(가짜 시계) 영역에서 돌리고 끝날 때까지 화면을 갱신한다.
    // runAsync 안에서 돌리면 앱 쪽 일이 가짜 시계 영역에 남긴 뒷정리를 못 기다려서 멈춘다 (테스트에서만)
    Future<void> syncNow() async {
      var done = false;
      final run = svc.sync(e.now).whenComplete(() => done = true);
      await settle(tester, () => done, tries: 80);
      await run;
    }

    // 앞: 300보를 걸어 방명록 걸음 숫자 100을 넘었다 → 화면 안만
    e.source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), 3, 100));
    e.now = t1.add(const Duration(minutes: 30));
    await syncNow();
    expect(e.notifier.calls, isEmpty);
    expect(await _log(tester, e), [(NoticeKind.n1, NoticeStatus.inApp)]);

    // 백그라운드: 1,000보를 넘었다 → 시스템 알림 (N5 예약도 한 줄)
    _toBackground(tester);
    await settle(tester, () => _calls(e, NotifierOp.schedule).isNotEmpty);
    e.source.records.add(walkRecord(t1.add(const Duration(minutes: 40)), 10, 100));
    e.now = t1.add(const Duration(minutes: 60));
    await syncNow();
    final show = _calls(e, NotifierOp.show).single;
    expect((show.kind, show.payload), (NoticeKind.n1, 'N1:m:1000'));
    expect(await _log(tester, e), [
      (NoticeKind.n1, NoticeStatus.inApp),
      (NoticeKind.n5, NoticeStatus.scheduled),
      (NoticeKind.n1, NoticeStatus.sent),
    ]);

    // 다시 앞으로 오면 또 화면 안만 (1,000보에서 더 걸어 5,000보 가까이)
    _toForeground(tester);
    await settle(tester, () => _calls(e, NotifierOp.cancel).isNotEmpty);
    e.source.records.add(walkRecord(t1.add(const Duration(minutes: 70)), 40, 100));
    e.now = t1.add(const Duration(minutes: 130));
    await syncNow();
    expect(_calls(e, NotifierOp.show), hasLength(1));
    expect((await _log(tester, e)).last, (NoticeKind.n1, NoticeStatus.inApp));
    await end(tester, e);
  });
}
