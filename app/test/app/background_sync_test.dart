import 'package:doobal/app/background_sync.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/notifier.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart' show StepRecord;
import 'package:doobal/domain/notification_policy.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/ui_env.dart';

/// [fail]을 켜면 건강 앱에서 걸음을 못 가져오는 기기 (권한이 백그라운드에서 막힌 경우 등)
class _FailingSource extends FakeStepSource {
  var fail = false;

  @override
  Future<List<StepRecord>> fetch(DateTime fromUtc, DateTime toUtc) async =>
      fail ? throw StateError('읽을 수 없다') : super.fetch(fromUtc, toUtc);
}

/// 앱 화면 없이 도는 동기화처럼 앱이 앞에 없다
class _Background extends AppForeground {
  @override
  bool build() => false;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  ProviderContainer containerOf(UiEnv e) => ProviderContainer(
      overrides: [...e.overrides, appForegroundProvider.overrideWith(_Background.new)]);

  testWidgets('시작 흐름을 끝냈으면 걸음을 가져와 동기화하고, 넘은 걸음 숫자는 시스템 알림(N1)으로 보낸다',
      (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    // 한국 9시부터 40분 동안 분당 100보 = 4,000보: 걸음 숫자 100·1,000·…을 넘는다
    e.source.records.add(walkRecord(t0, 40, 100));
    final c = containerOf(e);
    addTearDown(c.dispose);

    final ok = await tester.runAsync(() => runBackgroundSync(c, e.now));
    expect(ok, isTrue);
    final day = await tester.runAsync(() => e.db.select(e.db.daySummaries).getSingle());
    expect(day!.steps, 4000);
    // 앞에 앱이 없으니 화면 안 표시가 아니라 시스템 알림이다 (한국 10시라 조용한 시간이 아니다)
    final shown = [for (final call in e.notifier.calls) if (call.op == NotifierOp.show) call];
    expect(shown.single.kind, NoticeKind.n1);
    await tester.runAsync(e.db.close);
  });

  testWidgets('걷는 중에 앱이 꺼진 채면 그 앱 걷기를 닫고 동기화한다 (꺼진 뒤 걸음엔 보너스가 없다)',
      (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    final svc = e.svc;
    await tester.runAsync(() async {
      // 한국 9시에 출발하기, 9시 10분까지 살아 있다가 꺼졌다. 그 뒤 40분 동안 걸었다
      await e.db
          .into(e.db.appWalks)
          .insert(AppWalksCompanion.insert(startUtc: t0.millisecondsSinceEpoch));
      await svc.saveAlive(t0.add(const Duration(minutes: 10)));
    });
    e.source.records.add(walkRecord(t0.add(const Duration(minutes: 15)), 40, 100));
    final c = containerOf(e);
    addTearDown(c.dispose);

    await tester.runAsync(() => runBackgroundSync(c, e.now));
    final walk = await tester.runAsync(() => e.db.select(e.db.appWalks).getSingle());
    expect(walk!.endUtc, t0.add(const Duration(minutes: 10)).millisecondsSinceEpoch);
    expect(walk.endReason, AppWalkEnd.appEnded);
    final day = await tester.runAsync(() => e.db.select(e.db.daySummaries).getSingle());
    expect((day!.steps, day.bonusM), (4000, 0));
    await tester.runAsync(e.db.close);
  });

  testWidgets('시작 흐름을 끝내지 않았으면(계정을 지운 뒤 등) 동기화하지 않는다', (tester) async {
    final e = UiEnv();
    e.source.records.add(walkRecord(t0, 40, 100));
    final c = containerOf(e);
    addTearDown(c.dispose);

    expect(await tester.runAsync(() => runBackgroundSync(c, e.now)), isTrue);
    expect(await tester.runAsync(() => e.db.select(e.db.daySummaries).get()), isEmpty);
    expect(await tester.runAsync(() => e.db.select(e.db.syncState).get()), isEmpty);
    expect(e.notifier.calls, isEmpty);
    await tester.runAsync(e.db.close);
  });

  testWidgets('걸음을 못 가져와도 true (다음 주기에 다시 한다)', (tester) async {
    final source = _FailingSource();
    final e = UiEnv(source: source);
    await e.seed(tester);
    source.fail = true;
    final c = containerOf(e);
    addTearDown(c.dispose);

    expect(await tester.runAsync(() => runBackgroundSync(c, e.now)), isTrue);
    expect(e.notifier.calls, isEmpty);
    await tester.runAsync(e.db.close);
  });

  test('테스트·데스크톱에서는 주기 작업을 걸지 않는다', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(backgroundSyncProvider), isA<NoopBackgroundSync>());
    await c.read(backgroundSyncProvider).start(15);
  });
}
