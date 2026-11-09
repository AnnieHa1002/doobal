import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/server.dart';
import 'account_service.dart';
import 'guestbook_server.dart';
import 'providers.dart';

/// 서버 한 벌 (T1b 앱 연결). main이 startServer() 결과로 덮어쓴다.
/// 기본은 null이라 시험과 서버를 끈 빌드는 지금처럼 서버 없이 돈다 (방명록 빼고 모두 오프라인 원칙)
final serverBackendProvider = Provider<ServerBackend?>((ref) => null);

/// 로그인 상태. 서버가 없으면 늘 null
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  final server = ref.watch(serverBackendProvider);
  if (server == null) return Stream.value(null);
  return server.auth.changes();
});

/// 로그인·계정 연결·서버 계정 삭제. 서버가 없으면 null
final accountServiceProvider = Provider<AccountService?>((ref) {
  final server = ref.watch(serverBackendProvider);
  if (server == null) return null;
  return AccountService(
    server: server,
    db: ref.watch(dbProvider),
    backupService: () => ref.read(backupServiceProvider.future),
    clock: ref.read(clockProvider),
  );
});

/// 설정 계정 줄의 상태. 로그인이 바뀌면 다시 읽고, 연결·해제 뒤에는 invalidate 한다
final accountStateProvider = FutureProvider<AccountState>((ref) async {
  final account = ref.watch(accountServiceProvider);
  final user = await ref.watch(authUserProvider.future);
  if (account == null) return const AccountState(null, null);
  return account.state(user);
});

/// 방명록 서버 잇기 (서버가 없으면 이 기기에만 적는다)
final guestbookServerProvider = FutureProvider<GuestbookServer>((ref) async {
  return GuestbookServer(
    server: ref.watch(serverBackendProvider),
    account: ref.watch(accountServiceProvider),
    db: ref.watch(dbProvider),
    sync: () => ref.read(syncServiceProvider.future),
    rules: await ref.watch(rulesProvider.future),
    clock: ref.read(clockProvider),
  );
});

/// 내가 쓴 글의 받은 하트 (노트): 기회 id → 하트. 모르면(오프라인·서버 없음) 빈 표
final myHeartsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  await ref.watch(authUserProvider.future);
  try {
    return await (await ref.watch(guestbookServerProvider.future)).myHearts();
  } catch (_) {
    return const {};
  }
});
