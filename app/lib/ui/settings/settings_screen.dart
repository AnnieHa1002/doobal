import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/notification_service.dart';
import '../../app/providers.dart';
import '../../domain/notification_policy.dart';
import '../../domain/rules.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/ink_card.dart';
import '../common/notice_page.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../common/toast.dart';
import '../debug/backup_debug_screen.dart';
import '../debug/debug_screen.dart';

/// 문서 화면의 안내. 원문이 아직 리포에 없다.
/// TODO: 기획/약관_초안.md v03이 들어오면 그림 출처·AI 사용 고지·이용약관·개인정보처리방침 원문을
/// 붙인다 (법률 문장은 원문 그대로만 쓴다. 임의로 지어 쓰지 않는다)
const _docPending = '문서를 준비하고 있어요';

/// 설정: 계정 연결(M5), 걸음 데이터, 알림(전체·종류별 켜고 끄기), 안내 문서, 오픈소스 라이선스,
/// 개발자 화면, 계정 삭제
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openDoc(String title) => _push(NoticePage(title: title, message: _docPending));

  /// 화면을 떠났다 돌아오면 휴대폰 설정에서 알림 권한이 바뀌었을 수 있어서 다시 읽는다
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(notificationGrantedProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 걸음 권한을 다시 묻는다. 건강 앱이 없는 기기처럼 묻지 못한 것도 못 연 것으로 본다
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

  /// 알림 켜고 끄기를 저장하고 다시 읽는다
  Future<void> _changeNotice(
    Future<NoticeSettings> Function(NotificationService svc, DateTime now) change,
  ) async {
    try {
      final svc = await ref.read(notificationServiceProvider.future);
      await change(svc, ref.read(clockProvider)());
    } catch (e) {
      debugPrint('알림 설정 저장 실패: $e');
    }
    if (mounted) ref.invalidate(noticeSettingsProvider);
  }

  /// 휴대폰 알림 권한이 꺼져 있을 때의 "설정 열기".
  /// TODO(M6): 거부된 뒤에는 휴대폰의 앱 알림 설정을 열어야 한다 (지금은 열 방법이 없어서 권한을 다시 묻는다.
  /// flutter_local_notifications를 넣을 때 방법을 정한다)
  Future<void> _askNoticePermission() async {
    try {
      await ref.read(notificationPermissionProvider).requestPermission();
    } catch (e) {
      debugPrint('알림 권한 요청 실패: $e');
    }
    if (mounted) ref.invalidate(notificationGrantedProvider);
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
    // 읽는 동안·읽지 못하면 알림 줄은 아직 안 보인다
    final rules = ref.watch(rulesProvider).value;
    final settings = ref.watch(noticeSettingsProvider).value;
    // null은 모른다 (아직 읽는 중이거나 자리표시): 꺼진 것으로 보지 않는다
    final granted = ref.watch(notificationGrantedProvider).value;

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
                  const _SectionLabel('계정 연결'),
                  const _Group([
                    _Row('구글', note: '준비 중'),
                    _Row('애플', note: '준비 중'),
                    _Row('카카오', note: '준비 중'),
                  ]),
                  const SizedBox(height: 20),
                  const _SectionLabel('걸음 데이터'),
                  _Group([
                    _Row(
                      lastFetched == null
                          ? '아직 가져온 기록이 없어요'
                          : '마지막 기록 ${formatMonthDay(kstDate(lastFetched))} '
                              '${formatKstClock(lastFetched)}',
                    ),
                    _Row('권한 다시 열기', onTap: _reopenPermission),
                  ]),
                  const SizedBox(height: 20),
                  if (rules != null && settings != null) ...[
                    _NoticeSection(
                      rules: rules,
                      settings: settings,
                      granted: granted,
                      onAskPermission: _askNoticePermission,
                      onAll: (on) => _changeNotice((svc, now) => svc.setAll(on, now)),
                      onKind: (kind, on) =>
                          _changeNotice((svc, now) => svc.setKind(kind, on, now)),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _Group([
                    _Row('그림 출처', onTap: () => _openDoc('그림 출처')),
                    _Row('AI 사용 고지', onTap: () => _openDoc('AI 사용 고지')),
                    _Row('이용약관', onTap: () => _openDoc('이용약관')),
                    _Row('개인정보처리방침', onTap: () => _openDoc('개인정보처리방침')),
                    _Row(
                      '오픈소스 라이선스',
                      onTap: () => showLicensePage(context: context, applicationName: '두발'),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _Group([
                    _Row('개발자 화면', onTap: () => _push(const DebugScreen())),
                    if (kDebugMode) _Row('백업 시험', onTap: () => _push(const BackupDebugScreen())),
                  ]),
                  const SizedBox(height: 20),
                  _Group([_Row('계정 삭제', onTap: _deleteAccount)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 위 작은 제목
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// 줄들을 한 카드에 담고 줄 사이에 잉크 줄을 긋는다
class _Group extends StatelessWidget {
  const _Group(this.rows);

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 2, thickness: 2, color: Palette.ink),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// 설정 한 줄 (높이 52 이상). [onTap]이 있으면 눌리고 오른쪽에 화살표, 없으면 글만 보인다.
/// [note]가 있으면 눌리지 않는 줄로 흐리게 두고 오른쪽에 그 글을 쓴다 ("준비 중")
class _Row extends StatelessWidget {
  const _Row(this.title, {this.onTap, this.note});

  final String title;
  final VoidCallback? onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final off = note != null;
    return Semantics(
      button: onTap != null,
      enabled: !off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: off ? AppText.bodySub : AppText.body),
                ),
                if (note != null) Text(note!, style: AppText.label),
                if (onTap != null) const Icon(Icons.chevron_right, color: Palette.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 알림: 휴대폰 권한이 꺼져 있다는 안내(꺼져 있을 때만), 전체 켜기, 종류별 다섯 줄, 안내 글.
/// 권한이 확실히 꺼져 있거나([granted]가 false) 전체가 꺼져 있으면 토글이 흐려져서 눌리지 않는다
/// (전체가 꺼져 있으면 종류별만 흐려지고 전체는 그대로 눌린다). 모르면([granted]가 null) 꺼진 것으로 보지 않는다.
/// 숫자(하루 최대·조용한 시간·10km·3일)는 config에서 읽는다
class _NoticeSection extends StatelessWidget {
  const _NoticeSection({
    required this.rules,
    required this.settings,
    required this.granted,
    required this.onAskPermission,
    required this.onAll,
    required this.onKind,
  });

  final Rules rules;
  final NoticeSettings settings;
  final bool? granted;
  final VoidCallback onAskPermission;
  final ValueChanged<bool> onAll;
  final void Function(NoticeKind kind, bool on) onKind;

  String _label(NoticeKind kind) => switch (kind) {
        NoticeKind.n1 => '방명록 기회',
        NoticeKind.n2 => '도착',
        NoticeKind.n3 => '이야기',
        NoticeKind.n4 => '거의 다 왔어(${_trim(rules.notificationNearDestKm)}km)',
        NoticeKind.n5 => '다시 부르기(${_hours(rules.notificationInactiveHours)})',
      };

  @override
  Widget build(BuildContext context) {
    final blocked = granted == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('알림'),
        _Group([
          if (blocked)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('휴대폰 설정에서 알림을 켜 주세요', style: AppText.body),
                  const SizedBox(height: 12),
                  GameButton(
                    label: '설정 열기',
                    kind: GameButtonKind.secondary,
                    onPressed: onAskPermission,
                  ),
                ],
              ),
            ),
          _ToggleRow(
            '알림 받기',
            value: settings.all,
            onChanged: blocked ? null : onAll,
          ),
          for (final kind in NoticeKind.values)
            _ToggleRow(
              _label(kind),
              value: !settings.off.contains(kind),
              onChanged: blocked || !settings.all ? null : (on) => onKind(kind, on),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            '하루 최대 ${rules.notificationDailyMax}개, '
            '${formatHourKo(rules.notificationQuietFromHour)}~'
            '${formatHourKo(rules.notificationQuietToHour)}에는 보내지 않아요',
            style: AppText.label,
          ),
        ),
      ],
    );
  }
}

/// 10.0 → '10', 7.5 → '7.5'
String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// 72시간 → '3일', 하루로 안 나눠지면 '36시간'
String _hours(int hours) => hours % 24 == 0 ? '${hours ~/ 24}일' : '$hours시간';

/// 켜고 끄는 한 줄 (높이 52 이상). 줄 어디를 눌러도 바뀐다. [onChanged]가 null이면 흐리게 두고 눌리지 않는다
class _ToggleRow extends StatelessWidget {
  const _ToggleRow(this.title, {required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        toggled: value,
        enabled: enabled,
        label: title,
        onTap: enabled ? () => onChanged!(!value) : null,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: AppText.body)),
                  // 눌림은 줄이 받는다 (스위치는 모양만)
                  IgnorePointer(
                    child: Switch(
                      value: value,
                      onChanged: (_) {},
                      activeThumbColor: Palette.card,
                      activeTrackColor: Palette.terracotta,
                      inactiveThumbColor: Palette.subInk,
                      inactiveTrackColor: Palette.card,
                      trackOutlineColor: const WidgetStatePropertyAll(Palette.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            Text(title, style: AppText.cardTitle),
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
                    kind: danger ? GameButtonKind.primary : GameButtonKind.secondary,
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
