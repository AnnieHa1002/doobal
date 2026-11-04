import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/look.dart';
import '../../domain/profile.dart';
import '../../domain/rules.dart';
import '../../domain/spirit_look.dart';
import '../common/app_text.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../decorate/decorate_widgets.dart';
import '../scene/spirit_character.dart';
import 'start_layout.dart';

/// 시작 ② 나 (캔버스 1-2): 3단계 중 1단계 표시, 제목 `내 정령 만들기`, 정령 미리보기,
/// 닉네임, 눈 5칸, 몸 색(견본 10 + 직접 고르기). 눈썹·코·입과 소품은 꾸미기에서 바꾼다
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key, required this.rules});

  final Rules rules;

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  final _name = TextEditingController();
  var _look = Look.initial;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  NicknameCheck get _check => checkNickname(_name.text, widget.rules);

  Future<void> _submit() async {
    final check = _check;
    if (!check.ok) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(profileServiceProvider).saveMe(check.value, _look);
    ref.invalidate(onboardingStepProvider);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(spiritPaletteProvider).value;
    if (palette == null) return const Scaffold(body: SizedBox.expand());
    final rules = widget.rules;
    final check = _check;
    final eyes = palette.faces['eyes']!;
    final eye = eyes.firstWhere((p) => p.id == _look.eyes, orElse: () => eyes.first);

    return StartLayout(
      top: _Top(
        spirit: spiritLookOf(
          _look,
          bodyArgb: palette.body.argbOf(_look.body),
          bodyBaseArgb: palette.body.baseArgb,
        ),
        // 고른 눈과 몸 색 (캔버스: '점+반짝 눈 · 크림')
        label: '${FacePartRow.shortName(eye.id, eye.name)} 눈 · ${palette.body.nameOf(_look.body)}',
      ),
      children: [
        TextField(
          controller: _name,
          maxLength: rules.nicknameMax,
          textInputAction: TextInputAction.done,
          decoration: startInputDecoration(hint: '닉네임'),
          style: const TextStyle(fontSize: 16, color: Palette.ink),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        // 금칙어 안내도 여기 (M5 금칙어 문서가 나오면). 빨간색 대신 테라코타 글자.
        // 글자 크기를 키워 줄이 늘면 칸도 같이 늘어난다
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: check.ok
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '${rules.nicknameMin}~${rules.nicknameMax}자로 지어 주세요',
                    style: const TextStyle(fontSize: 13, color: Palette.terracotta),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '눈 '),
            TextSpan(text: eye.name, style: context.display(14)),
          ]),
          style: const TextStyle(fontSize: 14, color: Palette.ink),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final p in eyes)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: p == eyes.last ? 0 : 6),
                  child: PartCell(
                    key: ValueKey('eyes-${p.id}'),
                    label: p.name,
                    text: FacePartRow.shortName(p.id, p.name),
                    selected: _look.eyes == p.id,
                    onTap: () => setState(() => _look = _look.copyWith(eyes: p.id)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        BodyColorSection(
          palette: palette.body,
          color: _look.body,
          onChanged: (c) => setState(() => _look = _look.copyWith(body: c)),
        ),
        const SizedBox(height: 16),
        const StartNote('눈썹·코·입과 소품은 나중에 꾸미기에서 바꿀 수 있어요'),
        const SizedBox(height: 16),
        GameButton(label: '이 모습으로', onPressed: check.ok ? _submit : null),
      ],
    );
  }
}

/// 위쪽 장면 자리: 3단계 표시, 제목, 정령 미리보기(고른 눈·몸 색, 오른쪽 위에 이름 알약).
/// 키보드가 올라와 낮아지면 통째로 접힌다
class _Top extends StatelessWidget {
  const _Top({required this.spirit, required this.label});

  final SpiritLook spirit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxHeight < 150) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '3단계 중 1단계',
              excludeSemantics: true,
              child: Row(
                key: const ValueKey('steps'),
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Container(
                      width: 28,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == 0 ? Palette.terracotta : lineColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '내 정령 만들기',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(context),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                key: const ValueKey('me-preview'),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9DFC9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FractionallySizedBox(
                          heightFactor: 0.2,
                          alignment: Alignment.bottomCenter,
                          child: const ColoredBox(color: Color(0xFFD8CBB0)),
                        ),
                      ),
                      Positioned.fill(child: SpiritStanding(look: spirit)),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          key: const ValueKey('picked-label'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Palette.card,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 12, color: Palette.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
