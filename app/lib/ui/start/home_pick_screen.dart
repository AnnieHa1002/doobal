import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sigungu.dart';
import '../common/app_text.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import 'start_layout.dart';

/// 시·군·구 칸이 이 높이를 넘으면 칸 묶음 안에서 스크롤한다 (한 줄 44pt + 간격 6)
const _listMaxHeight = 200.0;

/// 시·군·구 칸은 한 줄에 셋
const _townColumns = 3;

/// 시작 ③ 출발 동네 (캔버스 1-3): 시·도 칩이나 이름 검색으로 시·군·구 하나를 고른다.
/// 앱 안 데이터(sigungu.json)라 오프라인으로 된다. 고른 시·군·구의 대표 좌표가 첫 출발지다.
/// 위 이정표는 자리표시 카드이고 쉼터 캠프 그림이 나오면 바꾼다
class HomePickScreen extends ConsumerStatefulWidget {
  const HomePickScreen({super.key});

  @override
  ConsumerState<HomePickScreen> createState() => _HomePickScreenState();
}

class _HomePickScreenState extends ConsumerState<HomePickScreen> {
  final _query = TextEditingController();

  /// 고른 시·도. null이면 첫 시·도
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
    final sidos = sidoList(items);
    final sido = _sido ?? sidos.first;
    // 검색 중이면 전국에서 찾고, 아니면 고른 시·도의 시·군·구
    final shown = searching ? searchSigungu(items, _query.text) : inSido(items, sido);
    final picked = _picked;

    return StartLayout(
      top: _Signpost(picked == null ? '출발 동네 고르기' : '${picked.label}에서 출발'),
      children: [
        Text('어디서 출발할까요?', style: context.display(22)),
        const SizedBox(height: 4),
        const StartNote('위치 정보는 쓰지 않아요.'),
        const SizedBox(height: 12),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in sidos) ...[
                  if (s != sidos.first) const SizedBox(width: 6),
                  _SidoChip(
                    label: s,
                    selected: sido == s,
                    onTap: () => setState(() => _sido = s),
                  ),
                ],
              ],
            ),
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
            child: SingleChildScrollView(
              child: LayoutBuilder(builder: (context, box) {
                final width = (box.maxWidth - 6 * (_townColumns - 1)) / _townColumns;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in shown)
                      SizedBox(
                        width: width,
                        child: _TownCell(
                          // 검색은 전국이라 시·도를 붙여 보여 준다
                          text: searching ? s.label : s.name,
                          selected: picked?.id == s.id,
                          onTap: () => _pick(s),
                          key: ValueKey('sigungu-${s.id}'),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
        const SizedBox(height: 16),
        GameButton(
          label: picked == null ? '동네를 골라 주세요' : '여기서 출발',
          onPressed: picked == null ? null : _submit,
        ),
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
                border: Border.all(color: Palette.ink, width: InkLine.panel),
              ),
              child: Text(
                label,
                style: context.display(22),
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
            border: Border.all(color: Palette.ink, width: InkLine.panel),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: context.display(14, color: selected ? Palette.paper : Palette.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 시·군·구 칸 하나. 고른 칸은 테라코타 테두리와 굵은 글자로 강조한다
class _TownCell extends StatelessWidget {
  const _TownCell({
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
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // 44pt가 최소 높이다. 글자 크기를 키워 이름이 줄바꿈되면 칸도 같이 늘어난다
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.terracotta.withValues(alpha: 0.18) : Palette.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Palette.terracotta : Palette.ink,
              width: selected ? InkLine.focus : InkLine.pill,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            // 고른 칸만 표시 글꼴 굵은 글자
            style: selected ? context.display(15) : AppText.body,
          ),
        ),
      ),
    );
  }
}
