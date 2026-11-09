import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account_service.dart';
import '../../app/providers.dart';
import '../../data/server.dart';
import '../common/app_text.dart';
import '../common/confirm_sheet.dart';
import '../common/toast.dart';
import 'settings_rows.dart';

/// 계정 이름 (설정 줄·토스트)
String providerName(LinkProvider p) => switch (p) {
      LinkProvider.google => '구글',
      LinkProvider.apple => '애플',
      LinkProvider.kakao => '카카오',
    };

/// 연결 동의 한 줄 (캔버스 10-1). 연결 전에만 보인다
const linkConsentText = '연결하면 이용약관·개인정보처리방침에 동의하고 걷기 기록을 서버에 백업해요.';

/// 연결 해제 안내 (가안, 캔버스에 없음): 다른 연결이 없으면 앱을 지운 뒤나 다른 기기에서 찾을 수 없다
const unlinkWarning = '해제하면 앱을 지우거나 기기를 바꿨을 때 이 기록을 찾을 수 없어요. 해제할까요?';

/// 설정의 계정 연결 (캔버스 10-1, M5·M6): 상태 한 줄('연결 안 함 (익명)' / '구글로 연결됨'),
/// 연결 전에는 구글·애플·카카오와 동의 한 줄, 연결 뒤에는 `연결 해제`.
/// 이미 다른 계정에 연결된 계정이면 "그 계정의 기록으로 바꿀까요?"를 묻고, 바꾸면 그 계정의 백업으로
/// 이 기기 기록을 바꾼다 (백업이 없으면 그대로 둔다). 카카오는 SDK가 오기 전(1월 초) '준비 중'
class SettingsAccount extends ConsumerStatefulWidget {
  const SettingsAccount({super.key});

  @override
  ConsumerState<SettingsAccount> createState() => _SettingsAccountState();
}

class _SettingsAccountState extends ConsumerState<SettingsAccount> {
  var _busy = false;

  Future<void> _run(Future<String?> Function(AccountService a) job) async {
    final account = ref.read(accountServiceProvider);
    if (account == null || _busy) return;
    setState(() => _busy = true);
    String? toast;
    try {
      toast = await job(account);
    } catch (e) {
      debugPrint('계정 작업 실패: $e');
      toast = '하지 못했어요. 인터넷 연결을 확인해 주세요';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(accountStateProvider);
    if (toast != null) showToast(context, toast);
  }

  Future<void> _link(LinkProvider p) => _run((account) async {
        final outcome = await account.link(p);
        switch (outcome) {
          case LinkDone():
            return '${providerName(p)}로 연결했어요';
          case LinkDismissed():
            return null;
          case LinkFailed(:final message):
            return message;
          case LinkNeedsConfirm():
            return _switch(account, outcome);
        }
      });

  /// "그 계정의 기록으로 바꿀까요?" (명세 M5). 카카오가 그 계정에 백업이 없다고 알려 주면 기록이 사라지지 않는다고 묻는다
  Future<String?> _switch(AccountService account, LinkNeedsConfirm c) async {
    if (!mounted) return null;
    final keep = c.hasBackup == false;
    final yes = await showConfirmSheet(
      context,
      keep
          ? '이미 다른 기록에 연결된 계정이에요. 그 계정으로 바꿀까요? 이 기기의 기록은 그 계정으로 이어져요'
          : '그 계정의 기록으로 바꿀까요? 이 기기의 기록은 사라져요',
      '바꾸기',
      '그대로 두기',
    );
    if (yes != true) return null;
    final result = await account.confirmSwitch(c);
    refreshAfterAccountSwitch(ref);
    return switch (result) {
      SwitchResult.restored => '그 계정의 기록으로 바꿨어요',
      SwitchResult.kept => '그 계정으로 바꿨어요',
    };
  }

  Future<void> _unlink(LinkProvider p) async {
    final yes = await showConfirmSheet(context, unlinkWarning, '해제', '그대로 두기');
    if (yes != true || !mounted) return;
    await _run((account) async => await account.unlink(p) ?? '연결을 해제했어요');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountStateProvider).value;
    final kakao = ref.watch(serverBackendProvider)?.kakao.available ?? false;
    final linked = state?.linked;
    final rows = <Widget>[
      SettingsRow(
        linked == null ? '연결 안 함 (익명)' : '${providerName(linked)}로 연결됨',
        key: const ValueKey('account-state'),
      ),
      if (linked != null)
        SettingsRow('연결 해제', onTap: _busy ? null : () => _unlink(linked))
      else ...[
        for (final p in LinkProvider.values)
          if (p == LinkProvider.kakao && !kakao)
            SettingsRow(providerName(p), note: '준비 중')
          else
            SettingsRow(providerName(p), onTap: _busy ? null : () => _link(p)),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(rows),
        if (linked == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(linkConsentText, key: ValueKey('link-consent'), style: AppText.label),
          ),
      ],
    );
  }
}

/// 다른 계정으로 바꾸고(복원했을 수 있다) 기기 기록이 바뀐 뒤: 그 기록을 쥔 상태를 모두 다시 읽는다
void refreshAfterAccountSwitch(WidgetRef ref) {
  ref.invalidate(accountStateProvider);
  ref.invalidate(syncServiceProvider);
  ref.invalidate(snapshotProvider);
  ref.invalidate(onboardingStepProvider);
  ref.invalidate(meProvider);
  ref.invalidate(myPostsProvider);
}
