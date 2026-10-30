import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/rules.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import 'start_layout.dart';

/// 권한 하나의 지금 상태: 아직 안 물었다 · 허용됨 · 거부됨
enum _Ask { none, granted, denied }

/// 시작 ④ 권한: 걸음(필수)과 알림(선택) 두 줄. 위치 권한은 묻지 않는다.
/// 걸음을 허용해야 "쉼터로 가기"가 켜진다. 알림은 거부해도 그대로 간다.
/// 권한은 각 줄의 버튼을 눌렀을 때만 묻는다 (화면이 뜬다고 묻지 않는다).
/// "쉼터로 가기"는 시작 흐름을 끝내고 첫 여정 '내 동네 스케치'를 정한다
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key, required this.rules});

  final Rules rules;

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  var _steps = _Ask.none;
  var _notice = _Ask.none;

  /// 묻는 중에 또 누르지 않게
  var _asking = false;

  Future<void> _ask(Future<bool> Function() request, void Function(_Ask) set) async {
    if (_asking) return;
    _asking = true;
    var ok = false;
    try {
      ok = await request();
    } catch (e) {
      // 건강 앱이 없는 등 묻지 못한 것도 거부로 본다
      debugPrint('권한 요청 실패: $e');
    }
    _asking = false;
    if (mounted) setState(() => set(ok ? _Ask.granted : _Ask.denied));
  }

  /// 걸음 권한. 거부된 뒤의 "설정에서 켜기"도 지금은 이 요청을 다시 부른다
  /// TODO: 앱 설정 열기(패키지가 없어서 못 한다). 설정을 여는 방법이 정해지면 거부 뒤 버튼을 바꾼다
  Future<void> _askSteps() =>
      _ask(ref.read(stepSourceProvider).requestPermission, (a) => _steps = a);

  Future<void> _askNotice() =>
      _ask(ref.read(notificationPermissionProvider).requestPermission, (a) => _notice = a);

  /// 첫 여정 '내 동네 스케치'를 정한 뒤 끝났다고 적고 쉼터로 간다. 이 순서라 사이에 앱이 꺼지면
  /// 권한 단계가 다시 뜨고, 다시 눌러도 스케치는 한 번만 생긴다. 스케치를 못 정해도(실패) 쉼터로는 간다
  Future<void> _finish() async {
    final now = ref.read(clockProvider)();
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.startSketch(now);
      ref.invalidate(snapshotProvider);
      ref.invalidate(mapDataProvider);
    } catch (e) {
      debugPrint('첫 여정 정하기 실패: $e');
    }
    await ref.read(profileServiceProvider).finishOnboarding(now);
    ref.invalidate(onboardingStepProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '시작하기 전에',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Palette.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: startCardDecoration(),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _PermissionRow(
                                  title: '걸음',
                                  mandatory: true,
                                  description: '걸은 만큼 여행하려면 걸음 기록이 필요해요',
                                  state: _steps,
                                  // 거부되면 "설정에서 켜기"가 나오고 다음으로 못 간다
                                  actionLabel: _steps == _Ask.denied ? '설정에서 켜기' : '허용하기',
                                  onAction: _askSteps,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(height: 2, thickness: 2, color: Palette.ink),
                                ),
                                _PermissionRow(
                                  title: '알림',
                                  mandatory: false,
                                  description: '도착·방명록 기회 같은 소식만, '
                                      '하루 ${widget.rules.notificationDailyMax}개까지',
                                  state: _notice,
                                  actionLabel: '허용하기',
                                  onAction: _askNotice,
                                  deniedNote: '설정 → 알림에서 언제든 켤 수 있어요',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GameButton(label: '쉼터로 가기', onPressed: _steps == _Ask.granted ? _finish : null),
            ],
          ),
        ),
      ),
    );
  }
}

/// 권한 한 줄: 이름·필수/선택·왜 필요한지·버튼(허용되면 "허용됨").
/// [deniedNote]가 있으면 거부된 뒤 버튼 대신 그 안내를 보여 준다 (그대로 진행하는 권한)
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.mandatory,
    required this.description,
    required this.state,
    required this.actionLabel,
    required this.onAction,
    this.deniedNote,
  });

  final String title;
  final bool mandatory;
  final String description;
  final _Ask state;
  final String actionLabel;
  final VoidCallback onAction;
  final String? deniedNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
            const SizedBox(width: 8),
            Text(
              mandatory ? '필수' : '선택',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: mandatory ? Palette.terracotta : Palette.subInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        StartNote(description),
        const SizedBox(height: 12),
        switch (state) {
          _Ask.granted => const Row(
              children: [
                Icon(Icons.check_circle, color: Palette.moss, size: 22),
                SizedBox(width: 6),
                Text(
                  '허용됨',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.moss),
                ),
              ],
            ),
          _Ask.denied when deniedNote != null => StartNote(deniedNote!),
          _ => GameButton(label: actionLabel, onPressed: onAction, kind: GameButtonKind.secondary),
        },
      ],
    );
  }
}
