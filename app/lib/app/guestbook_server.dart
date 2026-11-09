import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/db/app_db.dart';
import '../data/server.dart';
import '../domain/guestbook.dart';
import '../domain/rules.dart';
import 'account_service.dart';
import 'sync_service.dart';

/// 방명록 남기기 결과
sealed class SendOutcome {
  const SendOutcome();
}

/// 서버에 올렸다 (이 기기에도 남김)
class SendDone extends SendOutcome {
  const SendDone();
}

/// 이 기기에만 남겼다. 연결되면 올라간다 (오프라인, 로그인 전, 서버 장애)
class SendQueued extends SendOutcome {
  const SendQueued();
}

/// 서버가 글을 받지 않았다 (금칙어·길이). 이 기기에 남기지 않고 초안을 그대로 두어 고치게 한다
class SendBlocked extends SendOutcome {
  const SendBlocked(this.message);

  final String message;
}

/// 작성 제한 중이다. 초안을 그대로 둔다
class SendBanned extends SendOutcome {
  const SendBanned(this.until);

  final DateTime until;
}

/// 기회가 없거나 이미 썼거나 지났다 (StateError 문구)
class SendClosed extends SendOutcome {
  const SendClosed(this.message);

  final String message;
}

/// 금칙어에 막혔을 때 서버 문구가 없으면 쓰는 문구 (명세 M5)
const blockedFallback = '이 표현은 방명록에 남길 수 없어요';

/// 방명록을 서버와 잇는다 (M5): 남기기, 못 올린 글 다시 올리기, 다른 사람 글 읽기, 하트·신고, 내 글의 하트.
/// 남기기는 연결돼 있으면 서버에 먼저 올리고 이 기기에 적는다 (금칙어에 막히면 초안을 고치게).
/// 연결이 안 되면 이 기기에만 적고(pending) 연결되면 [uploadPending]이 올린다.
/// 서버가 없는 빌드(시험 포함)는 지금처럼 이 기기에만 적는다
class GuestbookServer {
  GuestbookServer({
    required this.server,
    required this.account,
    required this.db,
    required this.sync,
    required this.rules,
    required this.clock,
  });

  final ServerBackend? server;
  final AccountService? account;
  final AppDb db;
  final Future<SyncService> Function() sync;
  final Rules rules;
  final DateTime Function() clock;

  Future<int>? _uploading;

  /// 글을 남긴다
  Future<SendOutcome> send(String ticketId, String text) async {
    final svc = await sync();
    final now = clock();
    final ticket = await svc.guestbookTicket(ticketId, now);
    final body = cleanPost(text, rules.guestbookMaxChars);
    final api = server?.api;
    final user = ticket == null || body == null ? null : await account?.ensureSignedIn();
    if (api == null || user == null || ticket == null || body == null) {
      return _writeLocal(svc, ticketId, text, PostStatus.pending);
    }
    try {
      await _post(api, ticketId, ticket.scope, body);
    } on ServerError catch (e) {
      switch (e.reason) {
        case 'duplicate':
          break;
        case 'moderation' || 'bad-length' || 'bad-text':
          return SendBlocked(e.message ?? blockedFallback);
        case 'banned':
          final until = e.details['banUntil'];
          if (until is num) {
            return SendBanned(DateTime.fromMillisecondsSinceEpoch(until.toInt(), isUtc: true));
          }
          return SendBlocked(e.message ?? '지금은 방명록을 쓸 수 없어요');
        case 'bad-scope' || 'bad-ticket':
          // 앱이 잘못 만든 기회라 다시 보내도 안 된다. 이 기기에만 남긴다
          debugPrint('방명록 기회를 서버가 받지 않음: $e');
          return _writeLocal(svc, ticketId, body, PostStatus.rejected);
        default:
          return _writeLocal(svc, ticketId, body, PostStatus.pending);
      }
    } catch (e) {
      debugPrint('방명록 올리기 실패: $e');
      return _writeLocal(svc, ticketId, body, PostStatus.pending);
    }
    return _writeLocal(svc, ticketId, body, PostStatus.sent);
  }

  /// 닉네임이 서버에 없으면(no-profile) 올리고 한 번 더
  Future<void> _post(ServerApi api, String ticketId, String scope, String body) async {
    try {
      await account?.pushProfile();
    } catch (e) {
      debugPrint('users 문서 올리기 실패: $e');
    }
    try {
      await api.postGuestbook(ticketId: ticketId, scope: scope, text: body);
    } on ServerError catch (e) {
      if (e.reason != 'no-profile' || account == null) rethrow;
      await account!.pushProfile(force: true);
      await api.postGuestbook(ticketId: ticketId, scope: scope, text: body);
    }
  }

  Future<SendOutcome> _writeLocal(
    SyncService svc,
    String ticketId,
    String text,
    PostStatus status,
  ) async {
    try {
      await svc.writeGuestbook(ticketId, text, clock());
    } on StateError catch (e) {
      return SendClosed(e.message);
    }
    if (status != PostStatus.pending) await _mark(ticketId, status);
    return status == PostStatus.sent ? const SendDone() : const SendQueued();
  }

  Future<void> _mark(String ticketId, PostStatus status) =>
      (db.update(db.guestbookPosts)..where((t) => t.ticketId.equals(ticketId)))
          .write(GuestbookPostsCompanion(status: Value(status)));

  /// 이 기기에만 남은 글(pending)을 올린다. 올린 수를 돌려준다. 연결이 안 되면 멈추고 다음에 다시.
  /// 서버가 글을 받지 않으면(금칙어 등) rejected로 바꾼다 (고쳐 쓰는 화면은 아직 없다, 노트 참고).
  /// 작성 제한 중이면 그대로 두었다가 다음에 다시
  Future<int> uploadPending() => _uploading ??= _upload().whenComplete(() => _uploading = null);

  Future<int> _upload() async {
    final api = server?.api;
    if (api == null) return 0;
    final rows = await (db.select(db.guestbookPosts)
          ..where((t) => t.status.equalsValue(PostStatus.pending))
          ..orderBy([(t) => OrderingTerm(expression: t.createdUtc)]))
        .get();
    if (rows.isEmpty || await account?.ensureSignedIn() == null) return 0;
    var sent = 0;
    for (final r in rows) {
      try {
        await _post(api, r.ticketId, r.scope, r.body);
      } on ServerError catch (e) {
        switch (e.reason) {
          case 'duplicate':
            break;
          case 'moderation' || 'bad-length' || 'bad-text' || 'bad-scope' || 'bad-ticket':
            await _mark(r.ticketId, PostStatus.rejected);
            continue;
          case 'banned':
            continue;
          default:
            debugPrint('못 올린 방명록 다시 올리기 멈춤: $e');
            return sent;
        }
      } catch (e) {
        debugPrint('못 올린 방명록 다시 올리기 멈춤: $e');
        return sent;
      }
      await _mark(r.ticketId, PostStatus.sent);
      sent++;
    }
    return sent;
  }

  /// 같은 장소·숫자의 다른 사람 글 (무작위 5개). 서버가 없거나 로그인 못 하면 ServerError.offline
  Future<GuestbookPage> read(String scope) async {
    final api = server?.api;
    if (api == null || await account?.ensureSignedIn() == null) {
      throw const ServerError.offline();
    }
    return api.readGuestbook(scope);
  }

  /// 반응 바꾸기 ('heart' · 'report' · null)
  Future<({int hearts, String? myReaction})> react(String postId, String? kind) async {
    final api = server?.api;
    if (api == null) throw const ServerError.offline();
    return api.react(postId, kind);
  }

  /// 내가 쓴 글의 하트: 기회 id → 하트. 서버가 없거나 로그인 전이면 빈 표
  Future<Map<String, int>> myHearts() async {
    final store = server?.store;
    final user = server?.auth.current;
    if (store == null || user == null) return const {};
    return store.myHearts(user.uid);
  }
}
