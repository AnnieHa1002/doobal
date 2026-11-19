import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/profile.dart';
import '../../domain/rules.dart';
import '../common/app_text.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../start/start_layout.dart' show startInputDecoration;

/// 닉네임 바꾸기 시트 (나 탭 프로필 옆 연필, 16장 11/18 ⑥·캔버스 9-1 메모). 정령 만들기와 같은 검사
/// (글자 수·아주 명백한 욕설, [checkNickname])를 거쳐 저장한다. 탭 바까지 덮어 뜬다 (앱 Navigator).
/// 바꿨으면 true
Future<bool?> showNicknameSheet(BuildContext context, {required String current, required Rules rules}) =>
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Palette.card,
      barrierColor: Palette.ink.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: Palette.ink, width: InkLine.panel),
      ),
      builder: (_) => _NicknameSheet(current: current, rules: rules),
    );

class _NicknameSheet extends ConsumerStatefulWidget {
  const _NicknameSheet({required this.current, required this.rules});

  final String current;
  final Rules rules;

  @override
  ConsumerState<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends ConsumerState<_NicknameSheet> {
  late final _name = TextEditingController(text: widget.current);
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  NicknameCheck get _check => checkNickname(
        _name.text,
        widget.rules,
        moderation: ref.read(moderationProvider).value,
      );

  Future<void> _save() async {
    final check = _check;
    if (!check.ok || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileServiceProvider).saveNickname(check.value);
      ref.invalidate(meProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('닉네임 저장 실패: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(moderationProvider);
    final check = _check;
    final rules = widget.rules;
    return Padding(
      // 자판이 올라오면 그만큼 시트를 올린다
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('닉네임 바꾸기', style: AppText.cardTitle(context)),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('nickname-field'),
                controller: _name,
                autofocus: true,
                maxLength: rules.nicknameMax,
                textInputAction: TextInputAction.done,
                decoration: startInputDecoration(hint: '닉네임'),
                style: const TextStyle(fontSize: 16, color: Palette.ink),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              // 정령 만들기와 같은 안내 (테라코타 글자)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: check.ok
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          switch (check.problem!) {
                            NicknameProblem.swear => '닉네임으로 쓸 수 없는 말이 있어요',
                            _ => '${rules.nicknameMin}~${rules.nicknameMax}자로 지어 주세요',
                          },
                          style: const TextStyle(fontSize: 13, color: Palette.terracotta),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              GameButton(
                key: const ValueKey('nickname-save'),
                label: '저장',
                onPressed: check.ok && !_busy ? _save : null,
              ),
              const SizedBox(height: 8),
              GameButton(
                label: '취소',
                kind: GameButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
