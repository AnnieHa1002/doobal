import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// 서버를 어디에 붙일까 (빌드 때 --dart-define=DOOBAL_SERVER=…, 기본 real)
/// - off: 서버 없이 돈다
/// - emulator: 맥에서 켠 에뮬레이터(demo-doobal). 디버그 빌드에서만 듣는다
/// - real: 실제 프로젝트(doobal-47236). 값([SecretKeys])이 하나라도 비면 off처럼 서버 없이 돈다
enum ServerMode { off, emulator, real }

/// 실제 프로젝트 값의 이름. 빌드 때 `--dart-define-from-file=secrets.json`(app/, 무시 목록)으로 받는다.
/// 값은 Annie의 비밀번호 관리자에만 둔다 (CLAUDE.md '비밀 값'). 견본은 app/secrets.json.example.
/// flutterfire의 firebase_options.dart·google-services.json·GoogleService-Info.plist는 쓰지 않는다
abstract final class SecretKeys {
  /// 프로젝트 id (doobal-47236). 두 플랫폼이 같이 쓴다
  static const projectId = 'DOOBAL_FIREBASE_PROJECT_ID';

  /// 프로젝트 번호(= messagingSenderId). 두 플랫폼이 같이 쓴다
  static const senderId = 'DOOBAL_FIREBASE_SENDER_ID';

  static const androidKey = 'DOOBAL_FIREBASE_ANDROID_API_KEY';
  static const androidAppId = 'DOOBAL_FIREBASE_ANDROID_APP_ID';

  /// iOS는 11/28 Apple Developer 뒤 앱을 등록하고 채운다
  static const iosKey = 'DOOBAL_FIREBASE_IOS_API_KEY';
  static const iosAppId = 'DOOBAL_FIREBASE_IOS_APP_ID';

  /// iOS 구글 로그인 클라이언트 id. 비어도 서버는 켜고 iOS 구글 연결만 '준비 중'
  static const iosClientId = 'DOOBAL_FIREBASE_IOS_CLIENT_ID';

  /// 구글 로그인 웹 클라이언트 id (안드로이드 Credential Manager). 비어도 서버는 켜고 구글 연결만 '준비 중'
  static const googleServerClientId = 'DOOBAL_GOOGLE_SERVER_CLIENT_ID';

  /// App Check 디버그 토큰 (디버그 빌드만). 비우면 기기가 만든 토큰이 로그에 나오고 설치할 때마다 바뀐다
  static const appCheckDebug = 'DOOBAL_APP_CHECK_DEBUG_TOKEN';

  /// 플랫폼마다 꼭 있어야 하는 값
  static const android = [projectId, senderId, androidKey, androidAppId];
  static const ios = [projectId, senderId, iosKey, iosAppId];
}

/// 빌드 때 받은 값 (없으면 빈 문자열)
const buildSecrets = <String, String>{
  SecretKeys.projectId: String.fromEnvironment(SecretKeys.projectId),
  SecretKeys.senderId: String.fromEnvironment(SecretKeys.senderId),
  SecretKeys.androidKey: String.fromEnvironment(SecretKeys.androidKey),
  SecretKeys.androidAppId: String.fromEnvironment(SecretKeys.androidAppId),
  SecretKeys.iosKey: String.fromEnvironment(SecretKeys.iosKey),
  SecretKeys.iosAppId: String.fromEnvironment(SecretKeys.iosAppId),
  SecretKeys.iosClientId: String.fromEnvironment(SecretKeys.iosClientId),
  SecretKeys.googleServerClientId: String.fromEnvironment(SecretKeys.googleServerClientId),
  SecretKeys.appCheckDebug: String.fromEnvironment(SecretKeys.appCheckDebug),
};

const emulatorProject = 'demo-doobal';
const iosBundleId = 'com.annieha.doobal';

/// 에뮬레이터 옵션. 가짜 값이고 꼴만 맞춘다 (함수 SDK가 Firebase Installations로 API 키 꼴 AIza…·39자를 검사한다)
const emulatorOptions = FirebaseOptions(
  apiKey: 'AIzaSyDemoKeyForFirebaseEmulatorOnly000',
  appId: '1:1234567890:android:0000000000000000',
  messagingSenderId: '1234567890',
  projectId: emulatorProject,
);

/// 값 하나. 비었거나 견본 값(`Fake`로 시작, app/secrets.json.example)이면 null
String? secretValue(Map<String, String> values, String key) {
  final v = values[key]?.trim() ?? '';
  return v.isEmpty || v.startsWith('Fake') ? null : v;
}

/// 서버를 어떻게 켤지. off면 [reason]에 까닭(키 이름만, 값은 담지 않는다)
class ServerPlan {
  const ServerPlan.off(String this.reason)
      : mode = ServerMode.off,
        options = null;

  const ServerPlan.on(this.mode, FirebaseOptions this.options) : reason = null;

  final ServerMode mode;
  final FirebaseOptions? options;
  final String? reason;
}

/// 어디에 붙일지 정한다 (순수 함수, 시험은 [values]·[platform]·[release]를 준다)
ServerPlan planServer({
  required String modeName,
  required Map<String, String> values,
  required TargetPlatform platform,
  required bool release,
}) {
  switch (modeName) {
    case 'off':
      return const ServerPlan.off('DOOBAL_SERVER=off');
    case 'emulator':
      return release
          ? const ServerPlan.off('출시 빌드는 에뮬레이터를 듣지 않는다')
          : const ServerPlan.on(ServerMode.emulator, emulatorOptions);
    case 'real':
      final options = realFirebaseOptions(values, platform);
      if (options != null) return ServerPlan.on(ServerMode.real, options);
      final need = switch (platform) {
        TargetPlatform.android => SecretKeys.android,
        TargetPlatform.iOS => SecretKeys.ios,
        _ => null,
      };
      if (need == null) return ServerPlan.off('실제 프로젝트 값이 없는 플랫폼 (${platform.name})');
      final missing = [for (final k in need) if (secretValue(values, k) == null) k];
      return ServerPlan.off('실제 프로젝트 값이 비었다: ${missing.join(', ')}');
    default:
      return ServerPlan.off('모르는 DOOBAL_SERVER: $modeName');
  }
}

/// 실제 프로젝트 옵션. 그 플랫폼 값이 하나라도 비었거나 견본 값이면 null (서버 없이 돈다)
FirebaseOptions? realFirebaseOptions(Map<String, String> values, TargetPlatform platform) {
  String? v(String key) => secretValue(values, key);
  final projectId = v(SecretKeys.projectId);
  final senderId = v(SecretKeys.senderId);
  if (projectId == null || senderId == null) return null;
  switch (platform) {
    case TargetPlatform.android:
      final apiKey = v(SecretKeys.androidKey);
      final appId = v(SecretKeys.androidAppId);
      if (apiKey == null || appId == null) return null;
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      );
    case TargetPlatform.iOS:
      final apiKey = v(SecretKeys.iosKey);
      final appId = v(SecretKeys.iosAppId);
      if (apiKey == null || appId == null) return null;
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosClientId: v(SecretKeys.iosClientId),
        iosBundleId: iosBundleId,
      );
    default:
      return null;
  }
}
