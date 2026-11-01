import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/format_int.dart';
import 'live_steps.dart';
import 'local_notifications.dart';

/// 걷는 중 상시 알림. 본격 걷기(출발하기 ~ 걷기 마치기)는 화면이 꺼져도 앱이 살아 있는 동안 이어지는데,
/// 안드로이드는 백그라운드 앱을 말없이 죽이므로 걷는 중에는 포그라운드 서비스와 알림으로 앱을 살려 둔다.
/// iOS에는 같은 것이 없어서 아무것도 하지 않는다. 테스트는 [FakeWalkNotice]를 쓴다
abstract class WalkNotice {
  /// 걷기 시작: 상시 알림을 띄우고 포그라운드 서비스를 시작한다. 알림에 걸음 [steps]와 거리 [distanceM]이 보인다.
  /// [focus]는 본격 걷기 중일 때의 배수 글(`×1.3`, focusBadgeText): 있으면 본문 끝에 ` · 본격 걷기 ×1.3`이 붙는다
  /// [isRunning]이면 제목이 `두발 · 달리는 중`이 된다
  Future<void> start(int steps, double distanceM, {String? focus, bool isRunning = false});

  /// 알림의 걸음·거리·본격 걷기 표시를 새로 쓴다. 시작하지 않았으면 아무 일도 없다
  Future<void> update(int steps, double distanceM, {String? focus, bool isRunning = false});

  /// 끝: 알림을 지우고 서비스를 멈춘다. 여러 번 불러도 된다
  Future<void> stop();
}

/// 알림에 쓰는 거리 글: 미터를 km로 0.1 단위까지 (`1.2`). 알림 글이 바뀌는지 가늠할 때도 이 글로 견준다
String noticeKm(double distanceM) => (distanceM / 1000).toStringAsFixed(1);

/// 알림 본문: `1,234보 · 1.2km`, 본격 걷기 중이면 끝에 ` · 본격 걷기 ×1.3` (UI 명세 13장)
/// 알림 제목: 뛰고 있으면 `두발 · 달리는 중`, 아니면 `두발 · 걷는 중` (16장 11/1, UI 명세 13장)
String noticeTitle({required bool isRunning}) => isRunning ? '두발 · 달리는 중' : '두발 · 걷는 중';

String noticeBody(int steps, double distanceM, {String? focus}) =>
    '${formatInt(steps)}보 · ${noticeKm(distanceM)}km${focus == null ? '' : ' · 본격 걷기 $focus'}';

/// iOS·데스크톱·테스트 기본값: 아무것도 하지 않는다
class NoopWalkNotice implements WalkNotice {
  const NoopWalkNotice();

  @override
  Future<void> start(int steps, double distanceM, {String? focus, bool isRunning = false}) async {}

  @override
  Future<void> update(int steps, double distanceM, {String? focus, bool isRunning = false}) async {}

  @override
  Future<void> stop() async {}
}

/// 안드로이드: flutter_local_notifications의 포그라운드 서비스(유형 health)에 알림을 건다.
/// 알림은 제목 `두발 · 걷는 중`(뛰면 `두발 · 달리는 중`), 본문 `1,234보 · 1.2km` (본격 걷기 중이면 끝에 ` · 본격 걷기 ×1.3`)
/// (UI 명세 13장. 소리·진동 없음, 시간은 안 보인다).
/// 갱신은 서비스를 다시 시작하지 않고 같은 id의 알림을
/// 다시 쓴다 (안드로이드 12부터 앱이 뒤에 있을 때 포그라운드 서비스 시작을 막을 수 있어서).
/// 알림을 눌러 앱으로 돌아오면 singleTop 액티비티가 이어진다.
/// 서비스는 AndroidManifest에서 stopWithTask라서 앱을 화면에서 밀어 끄면 함께 끝난다
/// (앱이 종료되면 본격 걷기도 끝난다). 프로세스가 죽어도 서비스를 되살리지 않는다 (START_NOT_STICKY)
class AndroidWalkNotice implements WalkNotice {
  AndroidWalkNotice(this._notifications, this._steps);

  /// 알림 기록(NotificationLog)의 id와 겹치지 않게 큰 수
  static const _id = 2000000001;

  final LocalNotifications _notifications;
  final LiveSteps _steps;

  var _running = false;

  /// start·stop이 부를 때마다 올린다. 권한 확인 같은 await 사이에 stop이 불렸으면 뒤늦게 시작하지 않는다
  var _epoch = 0;

  @override
  Future<void> start(
    int steps,
    double distanceM, {
    String? focus,
    bool isRunning = false,
  }) async {
    final epoch = ++_epoch;
    try {
      // 안드로이드 14부터 '건강' 서비스는 동작 인식 권한이 허용돼 있어야 시작할 수 있다
      // (없으면 서비스를 시작하는 순간 앱이 멈춘다)
      if (!await _steps.hasPermission() || epoch != _epoch) return;
    } catch (e) {
      debugPrint('걷는 중 알림 권한 확인 실패: $e');
      return;
    }
    _running = true;
    if (!await _post(steps, distanceM, focus, isRunning, epoch, first: true) &&
        epoch == _epoch) {
      _running = false;
    }
  }

  @override
  Future<void> update(
    int steps,
    double distanceM, {
    String? focus,
    bool isRunning = false,
  }) async {
    if (!_running) return;
    await _post(steps, distanceM, focus, isRunning, _epoch, first: false);
  }

  @override
  Future<void> stop() async {
    _epoch++;
    _running = false;
    try {
      final plugin = _notifications.plugin;
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
      // show로 다시 쓴 알림이 서비스와 함께 지워지지 않는 기기가 있을 수 있어서 한 번 더 지운다
      await plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('걷는 중 알림 끄기 실패: $e');
    }
  }

  /// 알림을 띄우거나([first]: 서비스 시작) 새로 쓴다. 실패해도(로그만) 걷기는 계속된다.
  /// 성공했는가를 돌려준다
  Future<bool> _post(
    int steps,
    double distanceM,
    String? focus,
    bool isRunning,
    int epoch, {
    required bool first,
  }) async {
    try {
      final plugin = await _notifications.ready();
      if (epoch != _epoch) return false;
      final title = noticeTitle(isRunning: isRunning);
      final body = noticeBody(steps, distanceM, focus: focus);
      if (!first) {
        await plugin.show(
          id: _id,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(android: _details),
        );
        return true;
      }
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.startForegroundService(
            id: _id,
            title: title,
            body: body,
            notificationDetails: _details,
            startType: AndroidServiceStartType.startNotSticky,
            foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeHealth},
          );
      return true;
    } catch (e) {
      debugPrint('걷는 중 알림 실패: $e');
      return false;
    }
  }

  static const _details = AndroidNotificationDetails(
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
    // 걸린 시간은 알림에 보이지 않는다
    showWhen: false,
  );
}

/// [FakeWalkNotice]가 받은 부름을 쌓아 둔 기록
class FakeWalkNotice implements WalkNotice {
  /// start를 부른 (걸음, 거리 m), 부른 순서대로
  final starts = <(int, double)>[];

  /// update로 받은 (걸음, 거리 m), 부른 순서대로
  final updates = <(int, double)>[];

  /// start·update가 받은 본격 걷기 배수 글(`×1.3`, 없으면 null), [starts]·[updates]와 같은 순서
  final startFocus = <String?>[];
  final updateFocus = <String?>[];

  /// start·update가 받은 뛰는 중 여부, [starts]·[updates]와 같은 순서
  final startRunning = <bool>[];
  final updateRunning = <bool>[];

  /// stop을 부른 횟수
  var stops = 0;

  /// start 뒤 stop 전인가
  var running = false;

  @override
  Future<void> start(
    int steps,
    double distanceM, {
    String? focus,
    bool isRunning = false,
  }) async {
    starts.add((steps, distanceM));
    startFocus.add(focus);
    startRunning.add(isRunning);
    running = true;
  }

  @override
  Future<void> update(
    int steps,
    double distanceM, {
    String? focus,
    bool isRunning = false,
  }) async {
    updates.add((steps, distanceM));
    updateFocus.add(focus);
    updateRunning.add(isRunning);
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}
