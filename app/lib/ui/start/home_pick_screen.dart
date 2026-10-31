import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sigungu.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import 'start_layout.dart';

/// 시·군·구 목록이 이 높이를 넘으면 목록 안에서 스크롤한다 (한 줄 44pt)
const _listMaxHeight = 176.0;

/// 시작 ③ 출발 동네: 시·도 칩이나 이름 검색으로 시·군·구 하나를 고른다.
/// 앱 안 데이터(sigungu.json)라 오프라인으로 된다. 고른 시·군·구의 대표 좌표가 첫 출발지다.
/// 위 이정표는 자리표시 카드이고 쉼터 캠프 그림이 나오면 바꾼다
class HomePickScreen extends ConsumerStatefulWidget {
  const HomePickScreen({super.key});

  @override
  ConsumerState<HomePickScreen> createState() => _HomePickScreenState();
}

class _HomePickScreenState extends ConsumerState<HomePickScreen> {
  final _query = TextEditingController();
  String? _sido;
  Sigungu? _picked;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _pick(Sigungu s) {
    // 키보드를 내려 아래 버튼이 보이게
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _picked = s);
  }

  Future<void> _submit() async {
    final picked = _picked;
    if (picked == null) return;
    await ref.read(profileServiceProvider).saveHome(picked);
    ref.invalidate(onboardingStepProvider);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(sigunguProvider).value;
    if (items == null) return const Scaffold(body: SizedBox.expand());
    final searching = _query.text.trim().isNotEmpty;
    // 검색 중이면 전국에서 찾고, 아니면 고른 시·도의 시·군·구
    final shown = searching
        ? searchSigungu(items, _query.text)
        : _sido == null
            ? const <Sigungu>[]
            : inSido(items, _sido!);

    return StartLayout(
      top: _Signpost(_picked?.label ?? '출발 동네'),
      children: [
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: startInputDecoration(
            hint: '동네 이름으로 찾기',
            prefix: const Icon(Icons.search, color: Palette.subInk),
          ),
          style: const TextStyle(fontSize: 16, color: Palette.ink),
          onChanged: (_) => setState(() {}),
        ),
        if (!searching) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final sido in sidoList(items))
                _SidoChip(
                  label: sido,
                  selected: _sido == sido,
                  onTap: () => setState(() => _sido = _sido == sido ? null : sido),
                ),
            ],
          ),
        ],
        if (searching && shown.isEmpty) ...[
          const SizedBox(height: 12),
          const StartNote('찾는 동네가 없어요'),
        ],
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _listMaxHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.paper,
                borderRadius: BorderRadius.circular(startRadius),
                border: Border.all(color: Palette.ink, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(startRadius - 2),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final s in shown)
                      _SigunguRow(
                        // 검색은 전국이라 시·도를 붙여 보여 준다
                        text: searching ? s.label : s.name,
                        selected: _picked?.id == s.id,
                        onTap: () => _pick(s),
                        key: ValueKey('sigungu-${s.id}'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const StartNote('지금 사는 곳이 아니어도 괜찮아요. 위치 정보는 쓰지 않아요'),
        const SizedBox(height: 16),
        GameButton(label: '여기서 출발', onPressed: _picked == null ? null : _submit),
      ],
    );
  }
}

/// 위 이정표 자리표시: 고른 동네 이름이 뜬다
class _Signpost extends StatelessWidget {
  const _Signpost(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(startRadius),
                border: Border.all(color: Palette.ink, width: 2.5),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink,
                ),
              ),
            ),
            Container(width: 12, height: 48, color: Palette.ink),
          ],
        ),
      ),
    );
  }
}

class _SidoChip extends StatelessWidget {
  const _SidoChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // 누르는 자리는 44pt. Container(alignment)는 Wrap 안에서 너비를 다 차지해서 Center를 쓴다
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? Palette.terracotta : Palette.paper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Palette.ink, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Palette.paper : Palette.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록 한 줄. 고른 줄은 테라코타 바탕·굵은 글자·체크로 강조한다
class _SigunguRow extends StatelessWidget {
  const _SigunguRow({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 44pt가 최소 높이다. 글자 크기를 키워 이름이 줄바꿈되면 줄이 같이 커진다
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        alignment: Alignment.centerLeft,
        color: selected ? Palette.terracotta.withValues(alpha: 0.18) : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: Palette.ink,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check, size: 20, color: Palette.terracotta),
          ],
        ),
      ),
    );
  }
}
