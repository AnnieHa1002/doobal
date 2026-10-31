import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/format_int.dart';
import 'live_steps.dart';
import 'local_notifications.dart';

/// 걷는 중 상시 알림. 본격 걷기(출발하기 ~ 걷기 마치기)는 화면이 꺼져도 앱이 살아 있는 동안 이어지는데,
/// 안드로이드는 백그라운드 앱을 말없이 죽이므로 걷는 중에는 포그라운드 서비스와 알림으로 앱을 살려 둔다.
/// iOS에는 같은 것이 없어서 아무것도 하지 않는다. 테스트는 [FakeWalkNotice]를 쓴다
abstract class WalkNotice {
  /// 걷기 시작: 상시 알림을 띄우고 포그라운드 서비스를 시작한다. 알림에 [startedAt]부터 흐른 시간이 보인다
  Future<void> start(DateTime startedAt, int steps);

  /// 알림의 걸음 수를 [steps]로 새로 쓴다. 시작하지 않았으면 아무 일도 없다
  Future<void> update(int steps);

  /// 끝: 알림을 지우고 서비스를 멈춘다. 여러 번 불러도 된다
  Future<void> stop();
}

/// iOS·데스크톱·테스트 기본값: 아무것도 하지 않는다
class NoopWalkNotice implements WalkNotice {
  const NoopWalkNotice();

  @override
  Future<void> start(DateTime startedAt, int steps) async {}

  @override
  Future<void> update(int steps) async {}

  @override
  Future<void> stop() async {}
}

/// 안드로이드: flutter_local_notifications의 포그라운드 서비스(유형 health)에 알림을 건다.
/// 알림은 시간이 스스로 흐르는 크로노미터와 `n보`. 같은 id로 서비스를 다시 시작해 문구를 새로 쓴다
/// (플러그인이 알려 주는 갱신 방법). 알림을 눌러 앱으로 돌아오면 singleTop 액티비티가 이어진다.
/// 서비스는 AndroidManifest에서 stopWithTask라서 앱을 화면에서 밀어 끄면 함께 끝난다
/// (앱이 종료되면 본격 걷기도 끝난다). 프로세스가 죽어도 서비스를 되살리지 않는다 (START_NOT_STICKY)
class AndroidWalkNotice implements WalkNotice {
  AndroidWalkNotice(this._notifications, this._steps);

  /// 알림 기록(NotificationLog)의 id와 겹치지 않게 큰 수
  static const _id = 2000000001;

  final LocalNotifications _notifications;
  final LiveSteps _steps;

  DateTime? _startedAt;
  var _running = false;

  /// start·stop이 부를 때마다 올린다. 권한 확인 같은 await 사이에 stop이 불렸으면 뒤늦게 시작하지 않는다
  var _epoch = 0;

  @override
  Future<void> start(DateTime startedAt, int steps) async {
    final epoch = ++_epoch;
    try {
      // 안드로이드 14부터 '건강' 서비스는 동작 인식 권한이 허용돼 있어야 시작할 수 있다
      // (없으면 서비스를 시작하는 순간 앱이 멈춘다)
      if (!await _steps.hasPermission() || epoch != _epoch) return;
    } catch (e) {
      debugPrint('걷는 중 알림 권한 확인 실패: $e');
      return;
    }
    _startedAt = startedAt;
    _running = true;
    if (!await _post(steps, epoch) && epoch == _epoch) _running = false;
  }

  @override
  Future<void> update(int steps) async {
    if (!_running) return;
    await _post(steps, _epoch);
  }

  @override
  Future<void> stop() async {
    _epoch++;
    _running = false;
    try {
      await _notifications.plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    } catch (e) {
      debugPrint('걷는 중 알림 끄기 실패: $e');
    }
  }

  /// 알림을 띄우거나 새로 쓴다. 실패해도(로그만) 걷기는 계속된다. 성공했는가를 돌려준다
  Future<bool> _post(int steps, int epoch) async {
    try {
      final plugin = await _notifications.ready();
      if (epoch != _epoch) return false;
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.startForegroundService(
            id: _id,
            title: '걷는 중이에요',
            body: '${formatInt(steps)}보',
            notificationDetails: _details(_startedAt!),
            startType: AndroidServiceStartType.startNotSticky,
            foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeHealth},
          );
      return true;
    } catch (e) {
      debugPrint('걷는 중 알림 실패: $e');
      return false;
    }
  }

  AndroidNotificationDetails _details(DateTime startedAt) => AndroidNotificationDetails(
        'walking',
        '걷는 중',
        channelDescription: '걷는 동안 걸음을 보여 줘요',
        icon: walkNoticeIcon,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        when: startedAt.millisecondsSinceEpoch,
        usesChronometer: true,
      );
}

/// [FakeWalkNotice]가 받은 부름을 쌓아 둔 기록
class FakeWalkNotice implements WalkNotice {
  /// start를 부른 (시작 시각, 걸음), 부른 순서대로
  final starts = <(DateTime, int)>[];

  /// update로 받은 걸음, 부른 순서대로
  final updates = <int>[];

  /// stop을 부른 횟수
  var stops = 0;

  /// start 뒤 stop 전인가
  var running = false;

  @override
  Future<void> start(DateTime startedAt, int steps) async {
    starts.add((startedAt, steps));
    running = true;
  }

  @override
  Future<void> update(int steps) async {
    updates.add(steps);
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}
