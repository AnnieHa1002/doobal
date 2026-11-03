import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../domain/onboarding.dart';
import 'providers.dart';

/// 백그라운드 동기화 작업 이름 (WorkManager의 고유 이름이자 작업 이름)
const backgroundSyncTask = 'doobal-sync';

/// 앱이 닫혀 있어도 걸음을 가져와 동기화하는 주기 작업 (기술 설계서 3장, 안드로이드 WorkManager).
/// 그 동기화가 만든 N1(걸음 숫자)·N2(도착)·N4(10km)는 앱이 앞에 없으니 시스템 알림으로 나간다.
/// iOS는 나중에 (11/1 Annie: 안드로이드 먼저)
abstract class BackgroundSync {
  /// 주기 작업을 건다. 이미 걸려 있으면 간격만 지금 config로 맞춘다
  Future<void> start(int everyMin);
}

/// 안드로이드: WorkManager 주기 작업 (15분 이상, 실제로 도는 때는 안드로이드가 정한다)
class WorkmanagerBackgroundSync implements BackgroundSync {
  @override
  Future<void> start(int everyMin) async {
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundSyncTask,
      backgroundSyncTask,
      frequency: Duration(minutes: everyMin),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }
}

/// iOS·데스크톱·테스트: 걸지 않는다
class NoopBackgroundSync implements BackgroundSync {
  const NoopBackgroundSync();

  @override
  Future<void> start(int everyMin) async {}
}

final backgroundSyncProvider = Provider<BackgroundSync>(
    (ref) => Platform.isAndroid ? WorkmanagerBackgroundSync() : const NoopBackgroundSync());

/// 앱 화면 없이 도는 동기화에서는 앱이 앞에 없다 (알림 판단이 시스템 알림을 고른다)
class _InBackground extends AppForeground {
  @override
  bool build() => false;
}

/// WorkManager가 부르는 곳. 앱과 다른 Flutter 엔진에서 돌아서 앱의 상태를 쓰지 않고 새로 만든다
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, input) async {
    if (task != backgroundSyncTask) return true;
    final container = ProviderContainer(
      overrides: [appForegroundProvider.overrideWith(_InBackground.new)],
    );
    try {
      return await runBackgroundSync(container, DateTime.now());
    } finally {
      container.dispose();
    }
  });
}

/// 앱이 '살아 있다'고 적는 간격(aliveSaveSec)의 몇 배 동안 소식이 없으면 앱이 꺼진 것으로 보는가
const _staleAliveTimes = 3;

/// 백그라운드 동기화 한 번. 시작 흐름을 끝내지 않았으면(또는 계정을 지웠으면) 하지 않는다.
/// 앱이 걷는 중에 꺼진 채라면 그 앱 걷기를 닫고 동기화한다 (그래서 다음에 앱을 켤 때 '걷기가 멈췄어요'
/// 토스트는 뜨지 않을 수 있다).
/// 실패해도 true를 돌려준다: 다시 시도는 다음 주기에 한다 (안드로이드의 재시도 대기에 쌓이지 않게)
Future<bool> runBackgroundSync(ProviderContainer container, DateTime now) async {
  try {
    if (await container.read(profileServiceProvider).step() != OnboardingStep.done) return true;
    final rules = await container.read(rulesProvider.future);
    final svc = await container.read(syncServiceProvider.future);
    // 앱이 걷는 중에 꺼졌으면 그 앱 걷기를 먼저 닫는다. 살아 있는 앱은 aliveSaveSec마다 적으니
    // 세 번 거를 만큼 오래 소식이 없을 때만 꺼진 것으로 본다
    await svc.closeStaleAppWalks(now, Duration(seconds: rules.aliveSaveSec * _staleAliveTimes));
    await svc.sync(now);
  } catch (e) {
    debugPrint('백그라운드 동기화 실패: $e');
  }
  return true;
}
