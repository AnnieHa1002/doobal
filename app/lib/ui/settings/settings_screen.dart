import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/ink_card.dart';
import '../common/screen_header.dart';
import '../common/toast.dart';
import '../debug/backup_debug_screen.dart';
import '../debug/debug_screen.dart';
import 'settings_about_screen.dart';
import 'settings_notice_screen.dart';
import 'settings_rows.dart';

/// 설정 (캔버스 10-1): 계정 연결(M5), 걸음 데이터, 알림 ›, 광고 동의 다시 고르기(M4.5), 앱 정보 ›,
/// 계정 삭제. 개발자 화면은 출시 빌드에 나오지 않는다
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// 걸음 권한을 다시 묻는다. 건강 앱이 없는 기기처럼 묻지 못한 것도 못 연 것으로 본다.
  /// 거부돼도 앱 설정으로 보내지 않고 글로만 안내한다 (안드로이드의 Health Connect 권한은 앱 정보에
  /// 없고, iOS는 거부해도 요청이 성공으로 돌아와서 이 토스트가 뜨는 건 건강 앱이 없는 기기 정도다)
  Future<void> _reopenPermission() async {
    var ok = false;
    try {
      ok = await ref.read(stepSourceProvider).requestPermission();
    } catch (e) {
      debugPrint('권한 요청 실패: $e');
    }
    if (!mounted) return;
    showToast(context, ok ? '걸음 기록을 읽을 수 있어요' : '걸음 권한을 열지 못했어요. 건강 앱 설정에서 켜 주세요');
  }

  /// 두 번 확인한 뒤 이 기기의 기록을 모두 지우고 시작 흐름 첫 화면으로 돌아간다.
  /// 예약해 둔 알림은 기록을 지우기 전에 취소한다.
  /// TODO(M5·M6): 서버의 계정·방명록 삭제는 서버가 생기면 여기서 이어 부른다
  Future<void> _deleteAccount() async {
    final first = await _confirm(
      title: '계정을 삭제할까요?',
      message: '이 기기의 기록이 모두 지워져요',
      confirmLabel: '계속',
    );
    if (!first || !mounted) return;
    final second = await _confirm(
      title: '정말 삭제할까요?',
      message: '되돌릴 수 없어요',
      confirmLabel: '삭제',
      danger: true,
    );
    if (!second || !mounted) return;

    try {
      final notices = await ref.read(notificationServiceProvider.future);
      await notices.cancelAllPending(ref.read(clockProvider)());
    } catch (e) {
      debugPrint('예약 알림 취소 실패: $e');
    }
    await ref.read(profileServiceProvider).deleteAllLocal();
    if (!mounted) return;
    // 지운 값을 쥔 상태를 비운다. 시작 관문이 프로필을 다시 읽어 환영 화면을 띄운다.
    // 쉼터가 사라지기 전에 걸음·여정 상태를 다시 읽어서 설치 기록(SyncState·TravelFund 한 줄씩,
    // 경비 0)이 새로 생길 수 있다. 처음 설치해서 첫 동기화가 만드는 것과 같은 빈 상태다
    ref.invalidate(onboardingStepProvider);
    ref.invalidate(snapshotProvider);
    ref.invalidate(mapDataProvider);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        danger: danger,
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final lastFetched = ref.watch(snapshotProvider).value?.lastFetched;
    // 읽는 동안에는 글을 비워 둔다
    final settings = ref.watch(noticeSettingsProvider).value;
    final granted = ref.watch(notificationGrantedProvider).value;
    final noticeNote = settings == null ? null : (settings.all && granted != false ? '켜짐' : '꺼짐');

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('설정'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const SettingsLabel('계정 연결'),
                  const SettingsGroup([
                    SettingsRow('구글', note: '준비 중'),
                    SettingsRow('애플', note: '준비 중'),
                    SettingsRow('카카오', note: '준비 중'),
                  ]),
                  const SizedBox(height: 20),
                  const SettingsLabel('걸음 데이터'),
                  SettingsGroup([
                    SettingsRow(
                      lastFetched == null
                          ? '아직 가져온 기록이 없어요'
                          : '마지막 기록 ${formatMonthDay(kstDate(lastFetched))} '
                              '${formatKstClock(lastFetched)}',
                    ),
                    SettingsRow('권한 다시 열기', onTap: _reopenPermission),
                  ]),
                  const SizedBox(height: 20),
                  SettingsGroup([
                    SettingsRow(
                      '알림',
                      value: noticeNote,
                      onTap: () => _push(const SettingsNoticeScreen()),
                    ),
                    // TODO(M4.5): 광고 SDK를 붙일 때 UMP 동의 창을 다시 연다
                    const SettingsRow('광고 동의 다시 고르기', note: '준비 중'),
                    SettingsRow('앱 정보', onTap: () => _push(const SettingsAboutScreen())),
                  ]),
                  if (!kReleaseMode) ...[
                    const SizedBox(height: 20),
                    SettingsGroup([
                      SettingsRow('개발자 화면', onTap: () => _push(const DebugScreen())),
                      if (kDebugMode)
                        SettingsRow('백업 시험', onTap: () => _push(const BackupDebugScreen())),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  GameButton(
                    label: '계정 삭제',
                    kind: GameButtonKind.danger,
                    onPressed: _deleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 확인 창: 카드 모양, 버튼은 `취소`와 [confirmLabel]. [danger]면 확인 버튼만 테라코타
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.danger,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.cardTitle(context)),
            const SizedBox(height: 8),
            Text(message, style: AppText.body),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: '취소',
                    kind: GameButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GameButton(
                    label: confirmLabel,
                    kind: danger ? GameButtonKind.danger : GameButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
