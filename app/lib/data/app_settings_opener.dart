import 'package:app_settings/app_settings.dart';

/// 휴대폰 설정 앱을 여는 곳. 권한을 거부한 사용자를 설정으로 보낼 때 쓴다. 테스트는 FakeAppSettingsOpener를 쓴다
abstract class AppSettingsOpener {
  /// 이 앱의 설정 화면 (iOS 설정 → 두발, 안드로이드 앱 정보)
  Future<void> openApp();

  /// 이 앱의 알림 설정 (안드로이드·iOS 16 이상). 그보다 낮은 iOS는 앱 설정 화면이 열린다
  Future<void> openNotifications();
}

/// app_settings 패키지로 연다. 열지 못하면(지원하지 않는 기기 등) 예외가 나니 부르는 쪽에서 잡는다
class PlatformAppSettingsOpener implements AppSettingsOpener {
  const PlatformAppSettingsOpener();

  @override
  Future<void> openApp() => AppSettings.openAppSettings(type: AppSettingsType.settings);

  @override
  Future<void> openNotifications() =>
      AppSettings.openAppSettings(type: AppSettingsType.notification);
}

class FakeAppSettingsOpener implements AppSettingsOpener {
  /// 앱 설정을 연 횟수
  int appOpens = 0;

  /// 알림 설정을 연 횟수
  int noticeOpens = 0;

  /// true면 열 때 예외를 던진다 (열지 못하는 기기를 흉내 낼 때)
  bool fail = false;

  @override
  Future<void> openApp() async {
    appOpens++;
    if (fail) throw StateError('설정을 열 수 없다');
  }

  @override
  Future<void> openNotifications() async {
    noticeOpens++;
    if (fail) throw StateError('설정을 열 수 없다');
  }
}
