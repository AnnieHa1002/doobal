import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/db/app_db.dart';
import '../data/server.dart';
import 'backup_service.dart';

/// 설정 계정 줄의 상태
class AccountState {
  const AccountState(this.user, this.linked);

  /// 로그인 전(만 14세 확인 전, 오프라인)이면 null
  final AuthUser? user;

  /// 연결한 계정. 연결하지 않았으면(익명) null
  final LinkProvider? linked;
}

/// 연결한 계정. 구글·애플은 Firebase Auth가 안다. 카카오는 Auth 연결이 아니라서 커스텀 토큰 세션이면서
/// 연결 동의 시각(Profile.linkConsentAt)이 있을 때 카카오로 본다. 연결 해제하면 동의 시각을 지워서
/// 앱을 다시 켜도 연결 안 함으로 보인다 (카카오 연결 열이 생기기 전까지 이 열로 버틴다, 노트 참고)
LinkProvider? linkedOf(AuthUser? user, int? linkConsentAt) {
  if (user == null) return null;
  if (user.idpLinks.contains(LinkProvider.google)) return LinkProvider.google;
  if (user.idpLinks.contains(LinkProvider.apple)) return LinkProvider.apple;
  if (user.customToken && linkConsentAt != null) return LinkProvider.kakao;
  return null;
}

/// 연결 시도 결과
sealed class LinkOutcome {
  const LinkOutcome();
}

/// 지금 계정에 연결했다 (uid 그대로)
class LinkDone extends LinkOutcome {
  const LinkDone();
}

/// 그 자격이 다른 계정에 연결돼 있다. "그 계정의 기록으로 바꿀까요?"를 물은 뒤 [AccountService.confirmSwitch]
class LinkNeedsConfirm extends LinkOutcome {
  const LinkNeedsConfirm.idp(LinkConflict this.conflict)
      : provider = null,
        kakaoToken = null,
        hasBackup = null;

  const LinkNeedsConfirm.kakao(String this.kakaoToken, bool this.hasBackup)
      : provider = LinkProvider.kakao,
        conflict = null;

  final LinkConflict? conflict;
  final LinkProvider? provider;
  final String? kakaoToken;

  /// 그 계정에 백업이 있는가. 구글·애플은 들어가 보기 전에는 모른다(null)
  final bool? hasBackup;
}

/// 창을 닫았다 (아무 일 없음)
class LinkDismissed extends LinkOutcome {
  const LinkDismissed();
}

/// 하지 못했다. [message]는 토스트에 그대로 보여 준다
class LinkFailed extends LinkOutcome {
  const LinkFailed(this.message);

  final String message;
}

/// 계정을 바꾼 뒤
enum SwitchResult {
  /// 그 계정의 백업으로 이 기기 기록을 바꿨다
  restored,

  /// 그 계정에 백업이 없어서 이 기기 기록을 그대로 두었다 (다음 백업이 그 계정에 올라간다)
  kept,
}

const _offlineMessage = '인터넷에 연결한 뒤 다시 해 주세요';

/// 로그인·계정 연결·서버 계정 삭제·users 문서 (M5). 서버가 없는 빌드에서는 만들지 않는다.
/// 로그인은 만 14세 확인 뒤에만 하고(그 전 Auth 호출 0회), 실패해도 앱을 막지 않는다
class AccountService {
  AccountService({
    required this.server,
    required this.db,
    required this.backupService,
    required this.clock,
  });

  final ServerBackend server;
  final AppDb db;
  final Future<BackupService> Function() backupService;
  final DateTime Function() clock;

  AuthGateway get _auth => server.auth;

  Future<AuthUser?>? _signingIn;

  /// 마지막으로 올린 users 문서 값 (같은 값을 다시 올리지 않는다)
  String? _pushedKey;

  Future<ProfileRow?> _profile() =>
      (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();

  /// 지금 상태 (설정 계정 줄)
  Future<AccountState> state([AuthUser? user]) async {
    final u = user ?? _auth.current;
    return AccountState(u, linkedOf(u, (await _profile())?.linkConsentAt));
  }

  /// 로그인돼 있지 않으면 익명으로 들어간다. 만 14세 확인 전이면 하지 않는다. 실패하면 null (다음 기회에)
  Future<AuthUser?> ensureSignedIn() {
    final now = _auth.current;
    if (now != null) return Future.value(now);
    // 동시에 여러 곳에서 불러도 한 번만 들어간다
    return _signingIn ??= _signInAnonymously().whenComplete(() => _signingIn = null);
  }

  Future<AuthUser?> _signInAnonymously() async {
    if ((await _profile())?.ageConfirmedAt == null) return null;
    try {
      return _auth.current ?? await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('익명 로그인 실패 (다음 연결 때 다시): $e');
      return null;
    }
  }

  /// users/{uid}에 닉네임과 누적 걸음을 올린다. 닉네임이 없거나 로그인 전이면 하지 않고,
  /// 지난번과 같은 값이면 다시 올리지 않는다. 실패하면 ServerError (부른 쪽이 넘긴다).
  /// 여러 곳에서 동시에 불러도 하나씩 차례로 한다: 둘이 함께 '없음'을 보고 만들면 두 번째는 createdAt을
  /// 고치는 쓰기가 되어 규칙에 막힌다 (손 확인 11/9)
  Future<void> pushProfile({bool force = false}) {
    final next = _pushQueue.then((_) => _pushProfile(force));
    _pushQueue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _pushQueue = Future.value();

  Future<void> _pushProfile(bool force) async {
    final user = _auth.current;
    final nickname = (await _profile())?.nickname;
    if (user == null || nickname == null || nickname.isEmpty) return;
    final total = await totalSteps();
    final key = '${user.uid}|$nickname|$total';
    if (!force && key == _pushedKey) return;
    await server.store.pushProfile(user.uid, nickname: nickname, totalSteps: total);
    _pushedKey = key;
  }

  /// 누적 걸음 (하루 요약의 합, 나의 정보·도장과 같은 값)
  Future<int> totalSteps() async {
    final sum = db.daySummaries.steps.sum();
    final row = await (db.selectOnly(db.daySummaries)..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  /// 계정 연결. 연결되면 연결 동의 시각을 적는다 (처음 한 번)
  Future<LinkOutcome> link(LinkProvider provider) async {
    final user = await ensureSignedIn();
    if (user == null) return const LinkFailed(_offlineMessage);
    if (provider == LinkProvider.kakao) return _linkKakao();
    try {
      await _auth.link(provider);
    } on LinkConflict catch (c) {
      return LinkNeedsConfirm.idp(c);
    } on LinkCancelled {
      return const LinkDismissed();
    } on LinkUnavailable {
      return const LinkFailed('아직 준비 중이에요');
    } catch (e) {
      debugPrint('계정 연결 실패: $e');
      return const LinkFailed('연결하지 못했어요. 잠시 뒤 다시 해 주세요');
    }
    await _consent();
    return const LinkDone();
  }

  Future<LinkOutcome> _linkKakao() async {
    if (!server.kakao.available) return const LinkFailed('아직 준비 중이에요');
    final String? token;
    try {
      token = await server.kakao.accessToken();
    } catch (e) {
      debugPrint('카카오 로그인 실패: $e');
      return const LinkFailed('카카오 로그인을 하지 못했어요');
    }
    if (token == null) return const LinkDismissed();
    try {
      switch (await server.api.kakaoSignIn(token)) {
        case KakaoLinked(:final customToken):
          await _auth.signInWithCustomToken(customToken);
          await _consent();
          return const LinkDone();
        case KakaoNeedsConfirm(:final hasBackup):
          return LinkNeedsConfirm.kakao(token, hasBackup);
        case KakaoSwitched():
          // 확인 없이 바뀌는 일은 없다 (confirmSwitch를 보내지 않았다)
          return const LinkFailed('연결하지 못했어요. 잠시 뒤 다시 해 주세요');
      }
    } on ServerError catch (e) {
      return LinkFailed(_kakaoMessage(e));
    } catch (e) {
      debugPrint('카카오 연결 실패: $e');
      return const LinkFailed('연결하지 못했어요. 잠시 뒤 다시 해 주세요');
    }
  }

  String _kakaoMessage(ServerError e) => switch (e.reason) {
        'kakao-token' => '카카오 로그인이 끝났어요. 다시 해 주세요',
        'kakao-app' => '이 앱의 카카오 로그인이 아니에요',
        _ when e.offline => _offlineMessage,
        _ => '연결하지 못했어요. 잠시 뒤 다시 해 주세요',
      };

  /// "그 계정의 기록으로 바꿀까요?"에 예를 누른 뒤: 그 계정으로 들어가고, 백업이 있으면 이 기기 기록을
  /// 그 백업으로 바꾼다. 백업이 없으면 이 기기 기록을 그대로 둔다 (그 계정의 다음 백업이 된다).
  /// 구글·애플로 바꿀 때는 먼저 이 기기의 익명 계정을 서버에서 지운다(11/10 Annie): 바꾼 뒤에는 찾을 수 없는
  /// 기록이라서다(방명록 글·하트·백업도 같이, 화면 문구 ‘이 기기의 기록은 사라져요’). 카카오는 서버가 합친다.
  /// 실패하면 ServerError·그 밖의 예외를 그대로 던진다. 지우기에서 실패하면 지금 계정이 그대로 남고, 지운 뒤
  /// 들어가기에서 실패하면 로그아웃해 둔다 (기기 기록은 그대로, 다음 연결 때 새 익명 계정)
  Future<SwitchResult> confirmSwitch(LinkNeedsConfirm c) async {
    final AuthUser user;
    final conflict = c.conflict;
    if (conflict != null) {
      final before = _auth.current;
      final anonymous = before != null && before.idpLinks.isEmpty && !before.customToken;
      if (anonymous) await server.api.deleteAccount();
      try {
        user = await _auth.signInWithConflict(conflict);
      } catch (_) {
        if (anonymous) {
          _pushedKey = null;
          try {
            await _auth.signOut();
          } catch (e) {
            debugPrint('로그아웃 실패: $e');
          }
        }
        rethrow;
      }
    } else {
      final r = await server.api.kakaoSignIn(c.kakaoToken!, confirmSwitch: true);
      final token = switch (r) {
        KakaoSwitched(:final customToken) || KakaoLinked(:final customToken) => customToken,
        KakaoNeedsConfirm() => throw const ServerError('internal', message: '바꾸지 못했어요'),
      };
      user = await _auth.signInWithCustomToken(token);
    }
    await _consent();
    _pushedKey = null;
    final text = await server.backup.load(user.uid);
    if (text == null) return SwitchResult.kept;
    await (await backupService()).restoreBackup(text);
    return SwitchResult.restored;
  }

  /// 연결 해제. 구글·애플은 Auth 연결을 끊고, 카카오는 서버의 카카오 연결을 지운다. 서버 기록과
  /// 이 기기의 로그인은 그대로다. 실패하면 토스트 문구, 됐으면 null
  Future<String?> unlink(LinkProvider provider) async {
    try {
      if (provider == LinkProvider.kakao) {
        await server.api.kakaoUnlink();
      } else {
        await _auth.unlink(provider);
      }
    } on ServerError catch (e) {
      return e.offline ? _offlineMessage : '해제하지 못했어요';
    } catch (e) {
      debugPrint('연결 해제 실패: $e');
      return '해제하지 못했어요. 인터넷 연결을 확인해 주세요';
    }
    await (db.update(db.profile)..where((t) => t.id.equals(1)))
        .write(const ProfileCompanion(linkConsentAt: Value(null)));
    return null;
  }

  /// 서버 계정을 지우고 로그아웃한다 (계정 삭제의 서버 쪽, 기기 기록은 부른 쪽이 지운다).
  /// 로그인한 적이 없으면 서버에 지울 것이 없다. 실패하면 토스트 문구, 됐으면 null
  Future<String?> deleteServerAccount() async {
    if (_auth.current == null) return null;
    try {
      await server.api.deleteAccount();
    } on ServerError catch (e) {
      return e.offline ? _offlineMessage : '서버의 기록을 지우지 못했어요. 잠시 뒤 다시 해 주세요';
    } catch (e) {
      debugPrint('서버 계정 삭제 실패: $e');
      return _offlineMessage;
    }
    _pushedKey = null;
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('로그아웃 실패: $e');
    }
    return null;
  }

  Future<void> _consent() async {
    final row = await _profile();
    if (row?.linkConsentAt != null) return;
    await db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
          id: const Value(1),
          linkConsentAt: Value(clock().toUtc().millisecondsSinceEpoch),
        ));
  }
}
