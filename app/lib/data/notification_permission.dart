/// 알림 권한을 묻는 곳. 테스트는 가짜를 쓴다
abstract class NotificationPermission {
  /// 권한을 요청하고 허용됐는지 돌려준다
  Future<bool> requestPermission();
}

/// 자리표시: 아무것도 묻지 않고 늘 거부로 답한다.
/// M6에서 flutter_local_notifications로 바꾼다
class PlaceholderNotificationPermission implements NotificationPermission {
  const PlaceholderNotificationPermission();

  @override
  Future<bool> requestPermission() async => false;
}
