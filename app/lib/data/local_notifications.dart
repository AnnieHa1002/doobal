import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 안드로이드 알림 작은 아이콘 (res/drawable/ic_stat_walk). 알림 채널을 만들 때도 이 이름으로 쓴다
const walkNoticeIcon = 'ic_stat_walk';

/// flutter_local_notifications 플러그인 하나를 앱이 같이 쓴다 (알림 권한, 걷는 중 상시 알림).
/// 처음 쓸 때 한 번만 초기화한다. 휴대폰(안드로이드·iOS)이 아닌 곳에서는 초기화도 하지 않는다.
/// iOS 권한 창은 시작 흐름의 알림 권한 화면에서만 뜨도록 초기화 때는 묻지 않는다
class LocalNotifications {
  final plugin = FlutterLocalNotificationsPlugin();

  Future<void>? _init;

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
      );
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
  }
}
