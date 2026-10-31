import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'local_notifications.dart';

/// 알림 권한을 묻는 곳. 테스트는 가짜를 쓴다
abstract class NotificationPermission {
  /// 권한을 요청하고 허용됐는지 돌려준다
  Future<bool> requestPermission();

  /// 지금 허용돼 있는가. 모르면 null (설정 화면은 null이면 꺼진 것으로 보지 않는다)
  Future<bool?> isGranted();
}

/// flutter_local_notifications로 묻는다. 안드로이드 13 이상은 POST_NOTIFICATIONS 런타임 권한
/// (그 아래는 늘 허용, 알림을 끈 경우만 거부), iOS는 알림·배지·소리 권한.
/// 휴대폰이 아닌 곳(테스트·데스크톱)에서는 묻지 않고 거부로 답하고 상태는 모른다고 답한다.
/// 묻다가 예외가 나도 앱을 멈추지 않는다 (거부 / 모름)
class LocalNotificationPermission implements NotificationPermission {
  /// [isAndroid]·[isIOS]는 테스트가 플랫폼을 흉내 낼 때만 준다
  LocalNotificationPermission(this._notifications, {bool? isAndroid, bool? isIOS})
      : _isAndroid = isAndroid ?? Platform.isAndroid,
        _isIOS = isIOS ?? Platform.isIOS;

  final LocalNotifications _notifications;
  final bool _isAndroid;
  final bool _isIOS;

  @override
  Future<bool> requestPermission() async {
    if (!_isAndroid && !_isIOS) return false;
    try {
      final plugin = await _notifications.ready();
      if (_isAndroid) {
        return await plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (e) {
      debugPrint('알림 권한 요청 실패: $e');
      return false;
    }
  }

  @override
  Future<bool?> isGranted() async {
    if (!_isAndroid && !_isIOS) return null;
    try {
      final plugin = await _notifications.ready();
      if (_isAndroid) {
        return await plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
      }
      final options = await plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled;
    } catch (e) {
      debugPrint('알림 권한 확인 실패: $e');
      return null;
    }
  }
}
