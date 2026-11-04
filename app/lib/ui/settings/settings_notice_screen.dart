import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/notification_service.dart';
import '../../app/providers.dart';
import '../../domain/notification_policy.dart';
import '../../domain/rules.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import 'settings_rows.dart';

/// 설정 · 알림 (캔버스 10-2): 휴대폰 알림이 꺼져 있으면 경고 줄, 알림 받기, 종류별 다섯 줄, 한 줄 안내.
/// 권한이 확실히 꺼져 있거나([granted]가 false) 전체가 꺼져 있으면 토글이 흐려져서 눌리지 않는다
/// (전체가 꺼져 있으면 종류별만 흐려지고 전체는 그대로 눌린다). 모르면 꺼진 것으로 보지 않는다.
/// 숫자(하루 최대·조용한 시간·10km·3일)는 config에서 읽는다
class SettingsNoticeScreen extends ConsumerStatefulWidget {
  const SettingsNoticeScreen({super.key});

  @override
  ConsumerState<SettingsNoticeScreen> createState() => _SettingsNoticeScreenState();
}

class _SettingsNoticeScreenState extends ConsumerState<SettingsNoticeScreen> {
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

  /// 알림 켜고 끄기를 저장하고 다시 읽는다
  Future<void> _change(
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

  /// 이 앱의 휴대폰 알림 설정을 연다. 켜고 돌아오면 lifecycle 리스너가 권한을 다시 읽는다
  Future<void> _openPhoneSettings() async {
    try {
      await ref.read(appSettingsOpenerProvider).openNotifications();
    } catch (e) {
      debugPrint('알림 설정 열기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value;
    final settings = ref.watch(noticeSettingsProvider).value;
    // null은 모른다 (아직 읽는 중이거나 자리표시): 꺼진 것으로 보지 않는다
    final blocked = ref.watch(notificationGrantedProvider).value == false;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('알림'),
            Expanded(
              child: rules == null || settings == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (blocked) ...[
                          _PhoneOffCard(onOpen: _openPhoneSettings),
                          const SizedBox(height: 12),
                        ],
                        SettingsGroup([
                          _ToggleRow(
                            '알림 받기',
                            value: settings.all,
                            onChanged: blocked
                                ? null
                                : (on) => _change((svc, now) => svc.setAll(on, now)),
                          ),
                          for (final kind in NoticeKind.values)
                            _ToggleRow(
                              _noticeName(kind),
                              detail: _noticeDetail(kind, rules),
                              value: !settings.off.contains(kind),
                              onChanged: blocked || !settings.all
                                  ? null
                                  : (on) => _change((svc, now) => svc.setKind(kind, on, now)),
                            ),
                        ]),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Text(
                            '하루 ${rules.notificationDailyMax}개까지 · '
                            '${formatHourKo(rules.notificationQuietFromHour)}~'
                            '${formatHourKo(rules.notificationQuietToHour)} 쉼',
                            style: AppText.label,
                          ),
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

String _noticeName(NoticeKind kind) => switch (kind) {
      NoticeKind.n1 => '방명록 기회',
      NoticeKind.n2 => '도착',
      NoticeKind.n3 => '이야기',
      NoticeKind.n4 => '거의 다 왔어',
      NoticeKind.n5 => '다시 부르기',
    };

String _noticeDetail(NoticeKind kind, Rules rules) => switch (kind) {
      NoticeKind.n1 => '걸음 숫자 지점',
      NoticeKind.n2 => '목적지 도착',
      NoticeKind.n3 => '새 이야기',
      NoticeKind.n4 => '${_trim(rules.notificationNearDestKm)}km 남았을 때',
      NoticeKind.n5 => '${_hours(rules.notificationInactiveHours)} 쉬었을 때',
    };

/// 휴대폰 알림이 꺼져 있을 때의 경고 줄
class _PhoneOffCard extends StatelessWidget {
  const _PhoneOffCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('notice-phone-off'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.danger, width: InkLine.pill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: Palette.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text('알림이 꺼져 있어요 · 휴대폰 설정에서 켜 주세요', style: AppText.body),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GameButton(
            label: '휴대폰 설정',
            kind: GameButtonKind.secondary,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

/// 10.0 → '10', 7.5 → '7.5'
String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// 72시간 → '3일', 하루로 안 나눠지면 '36시간'
String _hours(int hours) => hours % 24 == 0 ? '${hours ~/ 24}일' : '$hours시간';

/// 켜고 끄는 한 줄 (높이 52 이상). 줄 어디를 눌러도 바뀐다. [onChanged]가 null이면 흐리게 두고 눌리지 않는다
class _ToggleRow extends StatelessWidget {
  const _ToggleRow(this.title, {this.detail, required this.value, required this.onChanged});

  final String title;

  /// 이름 아래 작은 글
  final String? detail;
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.body),
                        if (detail != null) Text(detail!, style: AppText.label),
                      ],
                    ),
                  ),
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
