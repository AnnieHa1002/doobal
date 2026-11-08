import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/color_props.dart';
import '../../domain/look.dart';
import '../../domain/prop.dart';
import '../../domain/rules.dart';
import '../../domain/spirit_look.dart';
import '../../domain/spirit_palette.dart';
import '../common/app_text.dart';
import '../common/confirm_sheet.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../common/toast.dart';
import 'decorate_tabs.dart';
import 'decorate_widgets.dart';
import 'figure_preview.dart';

/// 탭 줄 글자 배율 상한
const _tabMaxTextScale = 1.5;

/// 내 모습 탭의 id (나머지 탭 id는 소품 칸 이름)
const _meTab = 'me';

/// 꾸미기 (캔버스 9-2): 머리줄(제목 + 가진 소품 수) 아래 위 절반은 정령 미리보기(입고 있는 소품 요약 줄,
/// 표정 미리보기 단추), 아래는 탭 줄(내 모습 | 소품: 모자·얼굴 소품·옷·신발·손·가방·미니 친구·둥실·효과)과
/// 내용, 되돌리기·저장. 고른 것은 미리보기에 바로 보이고, 저장해야 프로필(Profile.look)에 남는다.
/// 저장하지 않고 나가려 하면 확인 시트를 띄운다
class DecorateScreen extends ConsumerStatefulWidget {
  const DecorateScreen({super.key});

  @override
  ConsumerState<DecorateScreen> createState() => _DecorateScreenState();
}

class _DecorateScreenState extends ConsumerState<DecorateScreen> {
  /// 저장된 모습과 지금 꾸미는 모습. 프로필을 읽기 전에는 null
  Look? _saved;
  Look? _look;

  /// 지금 탭: 'me' 또는 소품 칸 이름
  var _tab = 'hat';

  /// 표정 미리보기 번호 (저장하지 않는다)
  var _expression = 0;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await ref.read(profileServiceProvider).me();
    if (!mounted) return;
    setState(() {
      _saved = me.look;
      _look = me.look;
    });
  }

  void _set(Look look) => setState(() => _look = look);

  Future<void> _save() async {
    final look = _look;
    if (look == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileServiceProvider).saveLook(look);
      // 쉼터·나의 정보의 정령이 새 모습을 읽게 한다
      ref.invalidate(meProvider);
      if (!mounted) return;
      setState(() => _saved = look);
      showToast(context, '저장했어요');
    } on Object {
      if (mounted) showToast(context, '저장하지 못했어요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 저장하지 않고 나가려 할 때: 나가기면 그대로 닫는다
  Future<void> _confirmLeave() async {
    final leave = await showConfirmSheet(context, '저장하지 않고 나갈까요?', '나가기', '계속 꾸미기');
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(propsProvider).value;
    final owned = ref.watch(ownedPropIdsProvider).value;
    final palette = ref.watch(spiritPaletteProvider).value;
    final rules = ref.watch(rulesProvider).value;
    // 다음 거리 소품까지 남은 거리: 거리 소품은 앱 걷기 이동 거리로 센다 (Snapshot.walkTravelKm)
    final snap = ref.watch(snapshotProvider).value;
    final look = _look;
    final ready = look != null && props != null && owned != null && palette != null;
    final dirty = ready && look != _saved;
    // 기본 소품은 처음부터 가진 것이라, 아직 기록이 없어도 고를 수 있다
    final have = ready ? havePropIds(props, owned) : const <String>{};

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                '꾸미기',
                trailing: ready
                    ? Container(
                        key: const ValueKey('own-count'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Palette.card,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '가진 소품 ${have.length}개',
                          style: const TextStyle(fontSize: 12, color: Palette.ink),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: ready
                    ? _content(
                        look,
                        dirty,
                        props: props,
                        have: have,
                        palette: palette,
                        rules: rules,
                        nextKm: snap == null
                            ? null
                            : kmToNextDistanceProp(props, snap.walkTravelKm),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 입고 있는 소품 이름을 칸 순서대로 이은 줄
  String _summary(Look look, List<Prop> props) {
    final byId = {for (final p in props) p.id: p.name};
    final worn = [
      for (final slot in lookSlots)
        if (look.slots[slot] case final id? when byId[id] != null) byId[id]!,
    ];
    return worn.isEmpty ? '소품 없음' : worn.join(' · ');
  }

  Widget _content(
    Look look,
    bool dirty, {
    required List<Prop> props,
    required Set<String> have,
    required SpiritPalette palette,
    required Rules? rules,
    required double? nextKm,
  }) {
    final spirit = spiritLookOf(
      look,
      bodyArgb: palette.body.argbOf(look.body),
      bodyBaseArgb: palette.body.baseArgb,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SpiritPreview(
            look: spirit,
            summary: _summary(look, props),
            expression: _expression,
            onExpression: (v) => setState(() => _expression = v),
            tapRules: rules,
          ),
        ),
        // 탭 줄은 옆으로 밀리는 짧은 이름표라 글자를 1.5배까지만 키운다. 작은 화면·큰 글자·동글에서도
        // 미리보기·소품 칸·버튼 자리가 남게 (11/3 표시 글꼴)
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: _tabMaxTextScale,
          child: _TabStrip(selected: _tab, onSelect: (id) => setState(() => _tab = id)),
        ),
        Expanded(
          child: SingleChildScrollView(
            // 탭마다 맨 위에서 시작한다
            key: ValueKey('body-$_tab'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _tab == _meTab
                ? MeTab(look: look, palette: palette, onChanged: _set)
                : PropTab(
                    slot: _tab,
                    look: look,
                    // 색 소품은 기본 소품 바로 뒤 따로 된 칸, 기본 소품이 없으면 안 보인다 (명세 M4.5 D).
                    // 같은 칸이라 입으면 기본 소품은 벗겨진다
                    props: [
                      for (final p in variantsAfterBase(props))
                        if (p.slot == _tab && have.contains(p.id) && baseHeld(p, have)) p,
                    ],
                    nextKm: nextKm,
                    onPick: (id) => _set(look.withSlot(_tab, id)),
                  ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: lineColor, width: 1.5)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GameButton(
                  label: '되돌리기',
                  kind: GameButtonKind.secondary,
                  onPressed: dirty ? () => setState(() => _look = _saved) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: GameButton(label: '저장', onPressed: dirty && !_saving ? _save : null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 탭 줄: `내 모습` | 구분선 · `소품` 글 · 칸 아홉 탭. 한 줄로 옆으로 민다
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _TabChip(
            key: const ValueKey('tab-$_meTab'),
            label: '내 모습',
            selected: selected == _meTab,
            onTap: () => onSelect(_meTab),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: lineColor,
          ),
          const Text('소품', style: TextStyle(fontSize: 12, color: Palette.subInk)),
          for (final e in propSlotLabels.entries) ...[
            const SizedBox(width: 6),
            _TabChip(
              key: ValueKey('tab-${e.key}'),
              label: e.value,
              selected: selected == e.key,
              onTap: () => onSelect(e.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
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
        onTap: () {
          onTap();
          // 가려진 탭을 눌렀을 때 보이게 민다
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 200),
          );
        },
        // 누르는 자리는 44pt 이상 (글자 크기를 키우면 같이 커진다)
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Palette.ink : Palette.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? Palette.ink : lineColor,
                  width: InkLine.pill,
                ),
              ),
              child: Text(
                label,
                style: context.display(14, color: selected ? Palette.card : Palette.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
