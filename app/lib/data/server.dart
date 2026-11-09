import 'backup_store.dart';

/// 서버(Firebase)와 앱 사이의 약속. Firebase 패키지를 읽지 않아서 시험은 가짜로 돈다.
/// 진짜는 firebase_backend.dart, 함수 입출력은 functions/README.md

/// 계정을 연결하는 곳. 구글·애플은 Firebase Auth 연결, 카카오는 서버 함수(kakaoSignIn)
enum LinkProvider { google, apple, kakao }

/// 지금 로그인한 사용자
class AuthUser {
  const AuthUser({
    required this.uid,
    this.idpLinks = const {},
    this.customToken = false,
  });

  final String uid;

  /// Firebase Auth에 연결된 구글·애플 (카카오는 들어가지 않는다)
  final Set<LinkProvider> idpLinks;

  /// 커스텀 토큰으로 들어왔는가. 커스텀 토큰은 kakaoSignIn만 주므로 카카오로 들어온 세션이다
  final bool customToken;
}

/// 구글·애플 자격이 이미 다른 계정에 연결돼 있다. [payload]는 그 계정으로 들어갈 때 쓰는 자격
/// (Firebase AuthCredential, 가짜는 아무 값)
class LinkConflict implements Exception {
  const LinkConflict(this.provider, this.payload);

  final LinkProvider provider;
  final Object payload;
}

/// 사용자가 로그인 창을 닫았다
class LinkCancelled implements Exception {
  const LinkCancelled();
}

/// 이 기기·빌드에서 쓸 수 없는 연결 (카카오 앱 키 전, 구글 클라이언트 id 전)
class LinkUnavailable implements Exception {
  const LinkUnavailable();
}

/// 로그인 (Firebase Auth)
abstract class AuthGateway {
  AuthUser? get current;

  /// 로그인 상태가 바뀔 때마다 (처음 듣을 때 지금 값도 온다)
  Stream<AuthUser?> changes();

  Future<AuthUser> signInAnonymously();

  Future<AuthUser> signInWithCustomToken(String token);

  /// 지금 계정에 구글·애플을 연결한다. 이미 다른 계정에 연결된 자격이면 [LinkConflict],
  /// 창을 닫으면 [LinkCancelled], 쓸 수 없으면 [LinkUnavailable]
  Future<AuthUser> link(LinkProvider provider);

  /// [LinkConflict]의 계정으로 바꿔 들어간다 (지금 계정은 이 기기에서 떠난다)
  Future<AuthUser> signInWithConflict(LinkConflict conflict);

  /// 구글·애플 연결을 끊는다 (서버 기록은 그대로)
  Future<AuthUser> unlink(LinkProvider provider);

  Future<void> signOut();
}

/// 서버 함수가 돌려준 오류. [reason]은 details.reason (functions/README.md 오류 표).
/// 연결이 안 됐거나 시간이 지나면 [offline]
class ServerError implements Exception {
  const ServerError(this.code, {this.reason, this.message, this.details = const {}});

  /// 연결이 안 되거나 응답이 늦을 때
  const ServerError.offline()
      : code = 'unavailable',
        reason = null,
        message = null,
        details = const {};

  final String code;
  final String? reason;
  final String? message;
  final Map<String, Object?> details;

  /// 다시 해 볼 만한 오류 (연결·장애). 사용자의 글이나 계정 탓이 아니다
  bool get offline => const {'unavailable', 'deadline-exceeded', 'internal', 'unknown'}.contains(code);

  @override
  String toString() => 'ServerError($code, $reason, $message)';
}

/// 다른 사람 방명록 글 하나 (readGuestbook)
class OtherPost {
  const OtherPost({
    required this.postId,
    required this.nickname,
    required this.text,
    required this.hearts,
    required this.createdAt,
    required this.myReaction,
  });

  final String postId;
  final String nickname;
  final String text;
  final int hearts;
  final DateTime createdAt;

  /// 내가 누른 반응: 'heart' · 'report' · null
  final String? myReaction;

  OtherPost withReaction(int hearts, String? myReaction) => OtherPost(
        postId: postId,
        nickname: nickname,
        text: text,
        hearts: hearts,
        createdAt: createdAt,
        myReaction: myReaction,
      );
}

/// 같은 장소·숫자의 다른 사람 글 (내 글을 뺀 무작위 5개)과 그 범위의 글 수(내 글 포함)
class GuestbookPage {
  const GuestbookPage(this.total, this.posts);

  final int total;
  final List<OtherPost> posts;
}

/// kakaoSignIn 결과 (functions/README.md 표)
sealed class KakaoSignIn {
  const KakaoSignIn();
}

/// 처음 연결했거나 이미 내 연결. 토큰으로 들어가면 uid가 그대로다
class KakaoLinked extends KakaoSignIn {
  const KakaoLinked(this.uid, this.customToken);

  final String uid;
  final String customToken;
}

/// 다른 계정에 연결된 카카오. 확인 뒤 confirmSwitch로 다시 부른다
class KakaoNeedsConfirm extends KakaoSignIn {
  const KakaoNeedsConfirm(this.hasBackup);

  final bool hasBackup;
}

/// 그 계정으로 바꿨다. [hasBackup]이면 복원한다
class KakaoSwitched extends KakaoSignIn {
  const KakaoSwitched({
    required this.uid,
    required this.customToken,
    required this.merged,
    required this.backupMoved,
    required this.hasBackup,
  });

  final String uid;
  final String customToken;
  final bool merged;
  final bool backupMoved;
  final bool hasBackup;
}

/// 서버 함수 (Callable, asia-northeast3). 실패는 [ServerError]
abstract class ServerApi {
  /// 글을 올린다. 돌려주는 값은 postId
  Future<String> postGuestbook({
    required String ticketId,
    required String scope,
    required String text,
  });

  Future<GuestbookPage> readGuestbook(String scope);

  /// 반응을 바꾼다 ('heart' · 'report' · null은 취소). 돌려주는 값은 그 글의 하트 수와 내 반응
  Future<({int hearts, String? myReaction})> react(String postId, String? kind);

  Future<KakaoSignIn> kakaoSignIn(String kakaoAccessToken, {bool confirmSwitch = false});

  /// 이 계정의 카카오 연결을 지운다. 돌려주는 값은 지운 수
  Future<int> kakaoUnlink();

  /// 서버의 계정·글·반응·백업·연결을 모두 지운다 (Auth 계정도)
  Future<void> deleteAccount();
}

/// Firestore에 직접 읽고 쓰는 것 (보안 규칙 firestore.rules)
abstract class RemoteStore {
  /// users/{uid}의 닉네임과 누적 걸음. 처음이면 만든다 (createdAt은 서버 시각)
  Future<void> pushProfile(String uid, {required String nickname, required int totalSteps});

  /// 내가 쓴 글의 하트 수: 기회 id → 하트 (guestbook where uid == 나)
  Future<Map<String, int>> myHearts(String uid);

  /// config/moderation 문서. 연결이 안 되면 기기에 남은 마지막 값, 그것도 없으면 null
  Future<Map<String, dynamic>?> moderationDoc();
}

/// 카카오 로그인 SDK 자리. 앱 키가 오기 전(1월 초)에는 쓸 수 없다
abstract class KakaoLogin {
  bool get available;

  /// 카카오 액세스 토큰. 창을 닫으면 null
  Future<String?> accessToken();
}

/// 카카오 SDK가 아직 없다 (설정에 '준비 중')
class NoKakaoLogin implements KakaoLogin {
  const NoKakaoLogin();

  @override
  bool get available => false;

  @override
  Future<String?> accessToken() async => null;
}

/// 서버 한 벌. 서버를 쓰지 않는 빌드·시험에서는 없다(null)
class ServerBackend {
  const ServerBackend({
    required this.auth,
    required this.api,
    required this.store,
    required this.backup,
    required this.kakao,
    required this.label,
  });

  final AuthGateway auth;
  final ServerApi api;
  final RemoteStore store;
  final BackupStore backup;
  final KakaoLogin kakao;

  /// 개발자 화면에 보이는 연결 이름 ('에뮬레이터 10.0.2.2' 등)
  final String label;
}
