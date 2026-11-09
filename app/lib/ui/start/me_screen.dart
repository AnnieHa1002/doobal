import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/look.dart';
import '../../domain/profile.dart';
import '../../domain/prop.dart';
import '../../domain/rules.dart';
import '../../domain/spirit_look.dart';
import '../../domain/spirit_palette.dart';
import '../common/app_text.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../decorate/decorate_widgets.dart';
import '../scene/spirit_character.dart';
import 'start_layout.dart';

/// 시작 ② 나 (캔버스 1-2 v69): 3단계 중 1단계 표시, 제목 `내 정령 만들기`, 정령 미리보기, 닉네임,
/// 부위 탭(눈·눈썹·코·입·몸 색·옷 색) 한 화면 (16장 11/5·11/8). 옷 색은 기본 옷(여행복)의 시작 색 중 하나다.
/// 고른 옷 색은 값만 저장하고 정령에 보이는 것은 정령 새 방식(T5) 뒤다 (지금 Rive 정령은 옷 색을 못 바꾼다)
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key, required this.rules});

  final Rules rules;

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

/// 부위 탭: (palette faces 키 또는 몸·옷, 탭 이름)
const _tabs = [
  ('eyes', '눈'),
  ('brows', '눈썹'),
  ('nose', '코'),
  ('mouth', '입'),
  ('body', '몸 색'),
  ('cloth', '옷 색'),
];

class _MeScreenState extends ConsumerState<MeScreen> {
  final _name = TextEditingController();
  var _look = Look.initial;
  var _tab = _tabs.first.$1;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 금칙어 규칙은 화면을 열 때 받아 둔다. 아직 못 받았으면 글자 수만 본다
  NicknameCheck get _check =>
      checkNickname(_name.text, widget.rules, moderation: ref.read(moderationProvider).value);

  Future<void> _submit() async {
    final check = _check;
    if (!check.ok) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(profileServiceProvider).saveMe(check.value, _look);
    ref.invalidate(onboardingStepProvider);
  }

  void _set(Look look) => setState(() => _look = look);

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(spiritPaletteProvider).value;
    final props = ref.watch(propsProvider).value;
    ref.watch(moderationProvider);
    if (palette == null || props == null) return const Scaffold(body: SizedBox.expand());
    final rules = widget.rules;
    final check = _check;
    // 기본 옷(여행복)과 시작 색
    final cloth = props.firstWhere((p) => p.id == defaultSlots[alwaysWornSlot]);
    final colors = cloth.startColors;
    final clothColor = colors.isEmpty
        ? null
        : colors[(_look.clothColor - 1).clamp(0, colors.length - 1)];

    return StartLayout(
      top: _Top(
        spirit: spiritLookOf(
          _look,
          bodyArgb: palette.body.argbOf(_look.body),
          bodyBaseArgb: palette.body.baseArgb,
        ),
        // 고른 몸 색과 옷 색 (캔버스: '크림 · 여행복 카키')
        label:
            '${palette.body.nameOf(_look.body)} · ${cloth.name}'
            '${clothColor == null ? '' : ' ${clothColor.name}'}',
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
        // 빨간색 대신 테라코타 글자. 글자 크기를 키워 줄이 늘면 칸도 같이 늘어난다
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: check.ok
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(switch (check.problem!) {
                    NicknameProblem.swear => '닉네임으로 쓸 수 없는 말이 있어요',
                    _ => '${rules.nicknameMin}~${rules.nicknameMax}자로 지어 주세요',
                  }, style: const TextStyle(fontSize: 13, color: Palette.terracotta)),
                ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (id, name) in _tabs)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: id == _tabs.last.$1 ? 0 : 4),
                  child: _TabButton(
                    key: ValueKey('tab-$id'),
                    name: name,
                    selected: _tab == id,
                    onTap: () => setState(() => _tab = id),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 탭을 바꿔도 아래 버튼이 덜 움직이게 (캔버스 최소 96)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Align(alignment: Alignment.topLeft, child: _panel(palette, cloth)),
        ),
        const SizedBox(height: 16),
        GameButton(label: '이 모습으로', onPressed: check.ok ? _submit : null),
      ],
    );
  }

  Widget _panel(SpiritPalette palette, Prop cloth) {
    switch (_tab) {
      case 'body':
        return BodyColorSection(
          palette: palette.body,
          color: _look.body,
          onChanged: (c) => _set(_look.copyWith(body: c)),
        );
      case 'cloth':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, c) in cloth.startColors.indexed)
              _ClothChip(
                key: ValueKey('cloth-${i + 1}'),
                label: '${cloth.name} ${c.name}',
                name: c.name,
                color: Color(c.argb),
                selected: _look.clothColor == i + 1,
                onTap: () => _set(_look.copyWith(clothColor: i + 1)),
              ),
          ],
        );
      default:
        final key = _tab;
        return _PartGrid(
          keyPrefix: key,
          title: _tabs.firstWhere((t) => t.$1 == key).$2,
          parts: palette.faces[key]!,
          selected: switch (key) {
            'eyes' => _look.eyes,
            'brows' => _look.brows,
            'nose' => _look.nose,
            _ => _look.mouth,
          },
          onPick: (id) => _set(switch (key) {
            'eyes' => _look.copyWith(eyes: id),
            'brows' => _look.copyWith(brows: id),
            'nose' => _look.copyWith(nose: id),
            _ => _look.copyWith(mouth: id),
          }),
        );
    }
  }
}

/// 부위 탭 하나: 고른 탭은 잉크 바탕에 카드색 글자
class _TabButton extends StatelessWidget {
  const _TabButton({super.key, required this.name, required this.selected, required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 누르는 자리는 44pt
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: selected ? Palette.ink : Palette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? Palette.ink : lineColor, width: InkLine.pill),
              ),
              // 글자를 키워도 탭 안에서 줄어든다 (탭 6개가 한 줄)
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Palette.card : Palette.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 얼굴 부위 칸: 한 줄에 4칸씩 (캔버스 1-2). 칸의 key는 `'$keyPrefix-파츠id'`
class _PartGrid extends StatelessWidget {
  const _PartGrid({
    required this.keyPrefix,
    required this.title,
    required this.parts,
    required this.selected,
    required this.onPick,
  });

  final String keyPrefix;
  final String title;
  final List<({String id, String name})> parts;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in parts)
              SizedBox(
                width: width,
                child: PartCell(
                  key: ValueKey('$keyPrefix-${p.id}'),
                  label: '$title ${p.name}',
                  text: FacePartRow.shortName(p.id, p.name),
                  selected: selected == p.id,
                  onTap: () => onPick(p.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 옷 색 칸: 색 동그라미 + 이름. 고른 것은 굵은 테라코타 테두리. [label]은 접근성 이름
class _ClothChip extends StatelessWidget {
  const _ClothChip({
    super.key,
    required this.label,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? Palette.terracotta : lineColor,
              width: selected ? 3 : InkLine.pill,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.ink, width: InkLine.pill),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
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
