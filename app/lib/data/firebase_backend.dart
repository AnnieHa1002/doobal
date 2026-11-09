import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'backup_store.dart';
import 'server.dart';

/// 서버를 어디에 붙일까 (빌드 때 --dart-define=DOOBAL_SERVER=…).
/// - off(기본): 서버 없이 돈다. 실제 프로젝트 옵션(firebase_options.dart)이 생기기 전까지 기본이다
/// - emulator: 맥에서 켠 에뮬레이터(demo-doobal). 디버그 빌드에서만 듣는다
/// - real: 실제 프로젝트(doobal-47236). [realFirebaseOptions]가 생긴 뒤에 쓴다
const serverModeName = String.fromEnvironment('DOOBAL_SERVER', defaultValue: 'off');

/// 에뮬레이터 주소. 비우면 127.0.0.1이고 안드로이드 에뮬레이터에서는 패키지가 10.0.2.2로 바꾼다.
/// 무선 adb 실기기는 맥의 LAN 주소를 주거나, `adb reverse`로 포트를 넘기고 127.0.0.1을 준다
/// (주소를 주면 바꾸지 않는다)
const _emulatorHost = String.fromEnvironment('DOOBAL_EMULATOR_HOST');

/// 에뮬레이터에서 구글·애플·카카오를 가짜 자격으로 연결한다 (Auth 에뮬레이터는 서명 없는 토큰을 받는다).
/// 같은 값을 주면 같은 사람이라서 다른 기기에서 '그 계정으로 바꾸기'를 시험할 수 있다
const _fakeLoginId = String.fromEnvironment('DOOBAL_FAKE_LOGIN', defaultValue: '1');

/// 구글 로그인의 서버 클라이언트 id (안드로이드 Credential Manager가 요구한다).
/// 실제 프로젝트를 등록하면 google-services.json의 웹 클라이언트 id다
const _googleServerClientId = String.fromEnvironment('DOOBAL_GOOGLE_SERVER_CLIENT_ID');

const _region = 'asia-northeast3';
const _emulatorProject = 'demo-doobal';

/// 함수 하나를 기다리는 시간. 방명록 화면이 오래 멈추지 않게 짧게 둔다
const _callTimeout = Duration(seconds: 20);

/// Firestore 쓰기를 기다리는 시간. 오프라인이면 쓰기는 기기에 쌓였다가 연결되면 올라가므로
/// 이 시간 뒤에는 기다리지 않는다
const _writeTimeout = Duration(seconds: 20);

/// 실제 프로젝트 옵션. `flutterfire configure`가 만드는 firebase_options.dart의
/// DefaultFirebaseOptions.currentPlatform으로 바꾼다 (Annie와 같이, 아직 안 함)
FirebaseOptions? realFirebaseOptions() => null;

/// 서버를 켠다. 꺼 둔 빌드거나 옵션이 없거나 실패하면 null (앱은 서버 없이 돈다).
/// 네트워크는 기다리지 않는다 (초기화는 기기 안의 일)
Future<ServerBackend?> startServer() async {
  final emulator = serverModeName == 'emulator' && !kReleaseMode;
  final real = serverModeName == 'real';
  if (!emulator && !real) return null;
  try {
    final options = emulator
        // 가짜 값. 꼴만 맞춘다 (함수 SDK가 Firebase Installations로 API 키 꼴 AIza…·39자를 검사한다)
        ? const FirebaseOptions(
            apiKey: 'AIzaSyDemoKeyForFirebaseEmulatorOnly000',
            appId: '1:1234567890:android:0000000000000000',
            messagingSenderId: '1234567890',
            projectId: _emulatorProject,
          )
        : realFirebaseOptions();
    if (options == null) {
      debugPrint('서버: 실제 프로젝트 옵션이 아직 없어서 끈다');
      return null;
    }
    final app = await Firebase.initializeApp(options: options);
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    final functions = FirebaseFunctions.instanceFor(app: app, region: _region);
    var label = '실제 프로젝트 ${options.projectId}';
    if (emulator) {
      final host = _emulatorHost.isEmpty ? '127.0.0.1' : _emulatorHost;
      final mapped = _emulatorHost.isEmpty;
      await auth.useAuthEmulator(host, 9099, automaticHostMapping: mapped);
      firestore.useFirestoreEmulator(host, 8080, automaticHostMapping: mapped);
      functions.useFunctionsEmulator(host, 5001, automaticHostMapping: mapped);
      label = '에뮬레이터 ${mapped && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : host}';
    }
    // 에뮬레이터는 App Check를 보지 않는다. 가짜 API 키로 켜면 토큰을 받다 실패해서 함수·Firestore 호출이
    // 모두 막히므로(손 확인 11/9) 실제 프로젝트에서만 켠다
    if (real) await _startAppCheck(app);
    final fake = emulator && _fakeLoginId.isNotEmpty;
    return ServerBackend(
      auth: FirebaseAuthGateway(auth, fakeLoginId: fake ? _fakeLoginId : null),
      api: FirebaseServerApi(functions),
      store: FirestoreRemoteStore(firestore),
      backup: FirestoreBackupStore(firestore),
      kakao: fake ? FakeKakaoLogin(_fakeLoginId) : const NoKakaoLogin(),
      label: label,
    );
  } catch (e) {
    debugPrint('서버 시작 실패: $e');
    return null;
  }
}

/// App Check: 디버그 빌드는 디버그 제공자(로그에 나오는 토큰을 콘솔에 등록해야 통과), 출시 빌드는
/// Play Integrity·App Attest. 강제는 서버(함수 enforceAppCheck)와 콘솔이 정한다. 에뮬레이터에서는 켜지 않는다.
/// 실패해도 앱은 돈다 (토큰 없이 부르면 강제하는 곳에서만 거절된다)
Future<void> _startAppCheck(FirebaseApp app) async {
  try {
    await FirebaseAppCheck.instanceFor(app: app).activate(
      providerAndroid:
          kReleaseMode ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
  } catch (e) {
    debugPrint('App Check 시작 실패: $e');
  }
}

/// Firebase Auth
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._auth, {this.fakeLoginId});

  final FirebaseAuth _auth;

  /// 에뮬레이터의 가짜 구글·애플 사람 번호. null이면 진짜 로그인 창
  final String? fakeLoginId;

  var _googleReady = false;

  @override
  AuthUser? get current => _of(_auth.currentUser, null);

  @override
  Stream<AuthUser?> changes() => _auth.userChanges().asyncMap((u) async {
        if (u == null) return null;
        String? provider;
        try {
          provider = (await u.getIdTokenResult()).signInProvider;
        } catch (_) {
          // 오프라인에 토큰이 만료됐으면 사용자 정보로만 판단한다
        }
        return _of(u, provider);
      });

  AuthUser? _of(User? u, String? signInProvider) {
    if (u == null) return null;
    final links = <LinkProvider>{
      for (final p in u.providerData)
        if (p.providerId == GoogleAuthProvider.PROVIDER_ID)
          LinkProvider.google
        else if (p.providerId == AppleAuthProvider.PROVIDER_ID)
          LinkProvider.apple,
    };
    final custom = signInProvider != null
        ? signInProvider == 'custom'
        : !u.isAnonymous && u.providerData.isEmpty;
    return AuthUser(uid: u.uid, idpLinks: links, customToken: custom);
  }

  AuthUser _now() => _of(_auth.currentUser, null)!;

  @override
  Future<AuthUser> signInAnonymously() async {
    await _auth.signInAnonymously();
    return _now();
  }

  @override
  Future<AuthUser> signInWithCustomToken(String token) async {
    await _auth.signInWithCustomToken(token);
    return _of(_auth.currentUser, 'custom')!;
  }

  @override
  Future<AuthUser> link(LinkProvider provider) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인 전이에요');
    try {
      if (provider == LinkProvider.apple && fakeLoginId == null) {
        // 애플은 Firebase가 창을 띄운다 (iOS는 기기 창, 안드로이드는 웹 창)
        await user.linkWithProvider(AppleAuthProvider());
      } else {
        await user.linkWithCredential(await _credential(provider));
      }
    } on FirebaseAuthException catch (e) {
      final credential = e.credential;
      if ((e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') &&
          credential != null) {
        throw LinkConflict(provider, credential);
      }
      if (e.code == 'web-context-canceled' || e.code == 'canceled') throw const LinkCancelled();
      if (e.code == 'provider-already-linked') return _now();
      rethrow;
    }
    await _auth.currentUser?.reload();
    return _now();
  }

  /// 구글 자격 (애플 진짜는 [link]가 따로 한다). 가짜는 Auth 에뮬레이터가 받는 서명 없는 토큰
  Future<AuthCredential> _credential(LinkProvider provider) async {
    final fake = fakeLoginId;
    if (fake != null) {
      final token = jsonEncode({
        'sub': 'fake-${provider.name}-$fake',
        'email': 'fake-${provider.name}-$fake@example.com',
        'email_verified': true,
      });
      return provider == LinkProvider.google
          ? GoogleAuthProvider.credential(idToken: token)
          : OAuthProvider(AppleAuthProvider.PROVIDER_ID).credential(idToken: token);
    }
    if (provider != LinkProvider.google) throw const LinkUnavailable();
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      if (defaultTargetPlatform == TargetPlatform.android && _googleServerClientId.isEmpty) {
        throw const LinkUnavailable();
      }
      await google.initialize(
        serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
      );
      _googleReady = true;
    }
    if (!google.supportsAuthenticate()) throw const LinkUnavailable();
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const LinkCancelled();
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const LinkCancelled();
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<AuthUser> signInWithConflict(LinkConflict conflict) async {
    await _auth.signInWithCredential(conflict.payload as AuthCredential);
    return _now();
  }

  @override
  Future<AuthUser> unlink(LinkProvider provider) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인 전이에요');
    await user.unlink(provider == LinkProvider.google
        ? GoogleAuthProvider.PROVIDER_ID
        : AppleAuthProvider.PROVIDER_ID);
    await _auth.currentUser?.reload();
    return _now();
  }

  @override
  Future<void> signOut() async {
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }
}

/// 서버 함수 (Callable)
class FirebaseServerApi implements ServerApi {
  FirebaseServerApi(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(String name, [Map<String, Object?>? data]) async {
    try {
      final result = await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: _callTimeout))
          .call<Object?>(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, Object?>.from(e.details as Map) : const <String, Object?>{};
      throw ServerError(
        e.code,
        reason: details['reason'] as String?,
        message: e.message,
        details: details,
      );
    } on TimeoutException {
      throw const ServerError.offline();
    }
  }

  @override
  Future<String> postGuestbook({
    required String ticketId,
    required String scope,
    required String text,
  }) async =>
      (await _call('postGuestbook', {'ticketId': ticketId, 'scope': scope, 'text': text}))['postId']
          as String;

  @override
  Future<GuestbookPage> readGuestbook(String scope) async {
    final r = await _call('readGuestbook', {'scope': scope});
    return GuestbookPage(
      (r['total'] as num).toInt(),
      [
        for (final p in (r['posts'] as List).cast<Map<Object?, Object?>>())
          OtherPost(
            postId: p['postId'] as String,
            nickname: p['nickname'] as String,
            text: p['text'] as String,
            hearts: (p['hearts'] as num).toInt(),
            createdAt:
                DateTime.fromMillisecondsSinceEpoch((p['createdAt'] as num).toInt(), isUtc: true),
            myReaction: p['myReaction'] as String?,
          ),
      ],
    );
  }

  @override
  Future<({int hearts, String? myReaction})> react(String postId, String? kind) async {
    final r = await _call('react', {'postId': postId, 'kind': kind});
    return (hearts: (r['hearts'] as num).toInt(), myReaction: r['myReaction'] as String?);
  }

  @override
  Future<KakaoSignIn> kakaoSignIn(String kakaoAccessToken, {bool confirmSwitch = false}) async {
    final r = await _call('kakaoSignIn', {
      'kakaoAccessToken': kakaoAccessToken,
      if (confirmSwitch) 'confirmSwitch': true,
    });
    return switch (r['status']) {
      'linked' => KakaoLinked(r['uid'] as String, r['customToken'] as String),
      'needsConfirm' => KakaoNeedsConfirm(r['hasBackup'] == true),
      'switched' => KakaoSwitched(
          uid: r['uid'] as String,
          customToken: r['customToken'] as String,
          merged: r['merged'] == true,
          backupMoved: r['backupMoved'] == true,
          hasBackup: r['hasBackup'] == true,
        ),
      final s => throw ServerError('internal', message: '모르는 카카오 결과: $s'),
    };
  }

  @override
  Future<int> kakaoUnlink() async => ((await _call('kakaoUnlink'))['unlinked'] as num).toInt();

  @override
  Future<void> deleteAccount() => _call('deleteAccount');
}

/// Firestore 직접 읽기·쓰기
class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> pushProfile(String uid, {required String nickname, required int totalSteps}) async {
    final ref = _db.doc('users/$uid');
    final fields = {'nickname': nickname, 'totalSteps': totalSteps};
    try {
      // 규칙: 만들 때만 createdAt(서버 시각), 고칠 때는 닉네임·걸음만
      final snap = await ref.get().timeout(_writeTimeout);
      if (snap.exists) {
        await ref.update(fields).timeout(_writeTimeout);
      } else {
        await ref
            .set({...fields, 'createdAt': FieldValue.serverTimestamp()}).timeout(_writeTimeout);
      }
    } on FirebaseException catch (e) {
      throw ServerError(e.code, message: e.message);
    } on TimeoutException {
      throw const ServerError.offline();
    }
  }

  @override
  Future<Map<String, int>> myHearts(String uid) async {
    try {
      final q = await _db
          .collection('guestbook')
          .where('uid', isEqualTo: uid)
          .get()
          .timeout(_writeTimeout);
      return {
        for (final d in q.docs)
          if (d.data()['ticketId'] is String)
            d.data()['ticketId'] as String: (d.data()['hearts'] as num? ?? 0).toInt(),
      };
    } on FirebaseException catch (e) {
      throw ServerError(e.code, message: e.message);
    } on TimeoutException {
      throw const ServerError.offline();
    }
  }

  @override
  Future<Map<String, dynamic>?> moderationDoc() async {
    final ref = _db.doc('config/moderation');
    try {
      // 서버를 먼저 보고, 안 되면 기기에 남은 마지막 값 (Firestore 기기 저장)
      return (await ref.get().timeout(_writeTimeout)).data();
    } catch (_) {
      try {
        return (await ref.get(const GetOptions(source: Source.cache))).data();
      } catch (_) {
        return null;
      }
    }
  }
}

/// 백업 문자열을 users/{uid}/backup/state 한 문서에 둔다 (M5 명세). 문자열은 data,
/// 올린 시각은 savedAt (서버 시각)
class FirestoreBackupStore implements BackupStore {
  FirestoreBackupStore(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String uid) => _db.doc('users/$uid/backup/state');

  /// 오프라인이면 쓰기는 기기에 쌓여 연결될 때 올라간다. 그때는 기다리다 시간이 지나면 ServerError.offline
  @override
  Future<void> save(String uid, String text) async {
    try {
      await _ref(uid)
          .set({'data': text, 'savedAt': FieldValue.serverTimestamp()}).timeout(_writeTimeout);
    } on FirebaseException catch (e) {
      throw ServerError(e.code, message: e.message);
    } on TimeoutException {
      throw const ServerError.offline();
    }
  }

  /// 복원은 서버 값만 쓴다 (기기에 남은 옛 값으로 되돌리지 않게)
  @override
  Future<String?> load(String uid) async {
    try {
      final snap = await _ref(uid).get(const GetOptions(source: Source.server)).timeout(_callTimeout);
      return snap.data()?['data'] as String?;
    } on FirebaseException catch (e) {
      throw ServerError(e.code, message: e.message);
    } on TimeoutException {
      throw const ServerError.offline();
    }
  }
}

/// 에뮬레이터용 가짜 카카오: 토큰 'valid:<카카오 id>'. 함수 에뮬레이터는 KAKAO_API_BASE의 가짜 카카오 서버
/// (functions/scripts/fake_kakao.ts)에 물어 이 id를 받는다. 같은 번호면 같은 카카오 사람이다
class FakeKakaoLogin implements KakaoLogin {
  const FakeKakaoLogin(this.id);

  final String id;

  @override
  bool get available => true;

  @override
  Future<String?> accessToken() async => 'valid:${9000 + (int.tryParse(id) ?? 1)}';
}
