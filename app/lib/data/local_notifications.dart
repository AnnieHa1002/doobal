import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 안드로이드 알림 작은 아이콘 (res/drawable/ic_stat_walk). 알림 채널을 만들 때도 이 이름으로 쓴다
const walkNoticeIcon = 'ic_stat_doobal';

/// flutter_local_notifications 플러그인 하나를 앱이 같이 쓴다 (알림 권한, 걷는 중 상시 알림, 알림 5종).
/// 처음 쓸 때 한 번만 초기화한다. 휴대폰(안드로이드·iOS)이 아닌 곳에서는 초기화도 하지 않는다.
/// iOS 권한 창은 시작 흐름의 알림 권한 화면에서만 뜨도록 초기화 때는 묻지 않는다
class LocalNotifications {
  final plugin = FlutterLocalNotificationsPlugin();

  Future<void>? _init;

  final _taps = StreamController<String>.broadcast();

  /// 사용자가 누른 알림의 payload ('N1:m:3000' 꼴). 앱이 켜져 있거나 백그라운드에서 눌러 돌아올 때.
  /// payload가 없는 알림(걷는 중 상시 알림)은 흘리지 않는다
  Stream<String> get taps => _taps.stream;

  /// 앱이 알림을 눌러 새로 켜졌으면 그 알림의 payload, 아니면 null
  Future<String?> launchPayload() async {
    final p = await ready();
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      final details = await p.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      final payload = details.notificationResponse?.payload;
      return payload == null || payload.isEmpty ? null : payload;
    } catch (e) {
      debugPrint('알림으로 켜졌는지 읽기 실패: $e');
      return null;
    }
  }

  /// 초기화가 끝난 플러그인. 초기화에 실패해도 오류를 삼키고(로그만) 플러그인을 돌려준다
  Future<FlutterLocalNotificationsPlugin> ready() async {
    await (_init ??= _initialize());
    return plugin;
  }

  Future<void> _initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(walkNoticeIcon),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final payload = r.payload;
          if (payload != null && payload.isNotEmpty) _taps.add(payload);
        },
      );
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
  }
}
