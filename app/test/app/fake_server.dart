import 'dart:async';

import 'package:doobal/data/backup_store.dart';
import 'package:doobal/data/server.dart';

/// 가짜 서버 한 벌 (Firebase 없이 계정·방명록 흐름을 시험한다). 서버 쪽 판단(카카오 연결, 다른 계정)은
/// 시험이 값을 미리 넣어 정한다
class FakeServer {
  final auth = FakeAuth();
  late final api = FakeApi(this);
  final store = FakeRemoteStore();
  final backup = FakeBackupStore();
  final kakao = FakeKakao();

  ServerBackend get backend => ServerBackend(
        auth: auth,
        api: api,
        store: store,
        backup: backup,
        kakao: kakao,
        label: '가짜 서버',
      );
}

class FakeAuth implements AuthGateway {
  AuthUser? user;
  final _changes = StreamController<AuthUser?>.broadcast();
  var _next = 1;

  /// 부른 순서 ('anon', 'custom:토큰', 'link:google', 'switch:google', 'unlink:apple', 'signOut')
  final calls = <String>[];

  /// 익명 로그인을 실패시킨다 (오프라인)
  Object? failSignIn;

  /// 구글·애플 연결 결과: 이 자격이 이미 다른 계정(uid)에 연결돼 있다
  final conflicts = <LinkProvider, String>{};

  /// 연결 창을 닫는다
  var cancel = false;

  /// 커스텀 토큰 → uid (kakaoSignIn이 만든다)
  final tokens = <String, String>{};

  void _set(AuthUser? u) {
    user = u;
    _changes.add(u);
  }

  @override
  AuthUser? get current => user;

  @override
  Stream<AuthUser?> changes() async* {
    yield user;
    yield* _changes.stream;
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    calls.add('anon');
    final e = failSignIn;
    if (e != null) throw e;
    _set(AuthUser(uid: 'anon${_next++}'));
    return user!;
  }

  @override
  Future<AuthUser> signInWithCustomToken(String token) async {
    calls.add('custom:$token');
    _set(AuthUser(uid: tokens[token]!, customToken: true));
    return user!;
  }

  @override
  Future<AuthUser> link(LinkProvider provider) async {
    calls.add('link:${provider.name}');
    if (cancel) throw const LinkCancelled();
    final other = conflicts[provider];
    if (other != null) throw LinkConflict(provider, other);
    final u = user!;
    _set(AuthUser(uid: u.uid, idpLinks: {...u.idpLinks, provider}, customToken: u.customToken));
    return user!;
  }

  @override
  Future<AuthUser> signInWithConflict(LinkConflict conflict) async {
    calls.add('switch:${conflict.provider.name}');
    _set(AuthUser(uid: conflict.payload as String, idpLinks: {conflict.provider}));
    return user!;
  }

  @override
  Future<AuthUser> unlink(LinkProvider provider) async {
    calls.add('unlink:${provider.name}');
    final u = user!;
    _set(AuthUser(
      uid: u.uid,
      idpLinks: {...u.idpLinks}..remove(provider),
      customToken: u.customToken,
    ));
    return user!;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _set(null);
  }
}

/// 서버에 올라간 방명록 글
class FakePost {
  FakePost(this.uid, this.ticketId, this.scope, this.text);

  final String uid;
  final String ticketId;
  final String scope;
  final String text;
  var hearts = 0;
}

class FakeApi implements ServerApi {
  FakeApi(this.server);

  final FakeServer server;

  /// 부른 함수 이름 순서
  final calls = <String>[];

  /// 다음 부름(들)을 이 오류로 실패시킨다 (한 번 쓰면 빠진다)
  final failNext = <ServerError>[];

  /// 늘 이 오류로 실패한다 (오프라인)
  ServerError? failAlways;

  /// 올라간 글: postId → 글
  final posts = <String, FakePost>{};

  /// users 문서가 있어야 글을 받는다 (서버 no-profile)
  var needProfile = false;

  /// readGuestbook이 돌려줄 글
  GuestbookPage page = const GuestbookPage(0, []);

  /// 카카오 id → 연결된 uid (kakaoLinks), 백업 있는 uid
  final kakaoLinks = <String, String>{};

  /// react 결과: 글 → 하트
  final hearts = <String, int>{};

  Future<void> _gate(String name) async {
    calls.add(name);
    final always = failAlways;
    if (always != null) throw always;
    if (failNext.isNotEmpty) throw failNext.removeAt(0);
  }

  String _uid() {
    final u = server.auth.user;
    if (u == null) throw const ServerError('unauthenticated', reason: 'signed-out');
    return u.uid;
  }

  @override
  Future<String> postGuestbook({
    required String ticketId,
    required String scope,
    required String text,
  }) async {
    await _gate('postGuestbook');
    final uid = _uid();
    if (needProfile && !server.store.profiles.containsKey(uid)) {
      throw const ServerError('failed-precondition', reason: 'no-profile');
    }
    final id = '${uid}_$ticketId';
    if (posts.containsKey(id)) {
      throw ServerError('already-exists', reason: 'duplicate', details: {'postId': id});
    }
    posts[id] = FakePost(uid, ticketId, scope, text);
    return id;
  }

  @override
  Future<GuestbookPage> readGuestbook(String scope) async {
    await _gate('readGuestbook:$scope');
    _uid();
    return page;
  }

  @override
  Future<({int hearts, String? myReaction})> react(String postId, String? kind) async {
    await _gate('react:$postId:$kind');
    final h = hearts[postId] ?? 0;
    final next = kind == 'heart' ? h + 1 : h;
    return (hearts: next, myReaction: kind);
  }

  @override
  Future<KakaoSignIn> kakaoSignIn(String kakaoAccessToken, {bool confirmSwitch = false}) async {
    await _gate('kakaoSignIn${confirmSwitch ? ':confirm' : ''}');
    final uid = _uid();
    final owner = kakaoLinks.putIfAbsent(kakaoAccessToken, () => uid);
    final token = 'ct-$owner';
    server.auth.tokens[token] = owner;
    if (owner == uid) return KakaoLinked(uid, token);
    final has = server.backup.texts.containsKey(owner);
    if (!confirmSwitch) return KakaoNeedsConfirm(has);
    return KakaoSwitched(
      uid: owner,
      customToken: token,
      merged: true,
      backupMoved: false,
      hasBackup: has,
    );
  }

  @override
  Future<int> kakaoUnlink() async {
    await _gate('kakaoUnlink');
    final uid = _uid();
    final before = kakaoLinks.length;
    kakaoLinks.removeWhere((_, v) => v == uid);
    return before - kakaoLinks.length;
  }

  @override
  Future<void> deleteAccount() async {
    await _gate('deleteAccount');
    final uid = _uid();
    posts.removeWhere((_, p) => p.uid == uid);
    server.store.profiles.remove(uid);
    server.backup.texts.remove(uid);
  }
}

class FakeRemoteStore implements RemoteStore {
  /// users/{uid}: (닉네임, 누적 걸음)
  final profiles = <String, (String, int)>{};
  var pushes = 0;
  ServerError? fail;

  /// 처음 몇 번만 실패시킨다 (오프라인이었다가 돌아옴)
  var failTimes = 0;

  /// myHearts 결과
  Map<String, int> hearts = const {};

  /// config/moderation (없으면 null)
  Map<String, dynamic>? moderation;

  @override
  Future<void> pushProfile(String uid, {required String nickname, required int totalSteps}) async {
    final e = fail;
    if (e != null) throw e;
    if (failTimes > 0) {
      failTimes--;
      throw const ServerError.offline();
    }
    pushes++;
    profiles[uid] = (nickname, totalSteps);
  }

  @override
  Future<Map<String, int>> myHearts(String uid) async => hearts;

  @override
  Future<Map<String, dynamic>?> moderationDoc() async => moderation;
}

class FakeBackupStore implements BackupStore {
  final texts = <String, String>{};

  @override
  Future<void> save(String uid, String text) async => texts[uid] = text;

  @override
  Future<String?> load(String uid) async => texts[uid];
}

class FakeKakao implements KakaoLogin {
  @override
  var available = true;

  /// 다음 토큰 (null이면 창을 닫은 것)
  String? token = 'kakao-1';

  @override
  Future<String?> accessToken() async => token;
}
