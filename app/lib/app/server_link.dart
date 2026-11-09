import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/onboarding.dart';
import 'providers.dart';

/// 서버와 조용히 맞추는 일 (T1b). 화면을 막지 않고 실패하면 다음 기회에 한다:
/// - 만 14세 확인 뒤 익명 로그인 (그 전에는 Auth를 부르지 않는다)
/// - 로그인하면, 동기화로 누적 걸음이 바뀌면 users/{uid}에 닉네임·누적 걸음을 올린다
/// - 이 기기에만 남은 방명록 글을 올린다 (로그인·동기화 뒤, 앱이 앞으로 올 때)
/// 서버가 없는 빌드·시험에서는 아무것도 하지 않는다
class ServerLink extends ConsumerStatefulWidget {
  const ServerLink({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ServerLink> createState() => _ServerLinkState();
}

class _ServerLinkState extends ConsumerState<ServerLink> with WidgetsBindingObserver {
  late final bool _on = ref.read(serverBackendProvider) != null;

  @override
  void initState() {
    super.initState();
    if (!_on) return;
    WidgetsBinding.instance.addObserver(this);
    // 만 14세 확인(환영 화면)을 지나면 로그인. 닉네임을 정하면 users 문서를 올린다
    ref.listenManual(onboardingStepProvider, (prev, next) {
      if (next.value != null && next.value != OnboardingStep.welcome) _catchUp();
    }, fireImmediately: true);
    ref.listenManual(authUserProvider, (prev, next) {
      if (next.value != null && prev?.value?.uid != next.value?.uid) _catchUp();
    });
    // 자동 백업(BackupRunner)은 백업 uid를 read로만 읽는다. Riverpod 3은 듣는 곳이 없는 provider를
    // 멈춰 두므로 여기서 계속 들어 로그인·연결이 바뀌면 바로 따라가게 한다
    ref.listenManual(backupUidProvider, (_, _) {});
  }

  @override
  void dispose() {
    if (_on) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _catchUp();
  }

  /// 로그인(필요하면) → users 문서 → 못 올린 글
  Future<void> _catchUp() async {
    final account = ref.read(accountServiceProvider);
    if (account == null) return;
    try {
      if (await account.ensureSignedIn() == null) return;
      await account.pushProfile();
    } catch (e) {
      debugPrint('users 문서 올리기 실패 (다음에 다시): $e');
    }
    try {
      await (await ref.read(guestbookServerProvider.future)).uploadPending();
    } catch (e) {
      debugPrint('못 올린 방명록 올리기 실패 (다음에 다시): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_on) return widget.child;
    final step = ref.watch(onboardingStepProvider).value;
    // 시작 흐름을 마친 뒤에만 상태를 듣는다 (그 전에는 동기화가 돌지 않는다)
    if (step == OnboardingStep.done) {
      ref.listen(snapshotProvider, (prev, next) {
        if (next.value?.totalSteps != prev?.value?.totalSteps || prev?.value == null) _catchUp();
      });
    }
    return widget.child;
  }
}
