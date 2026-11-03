import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/look.dart';
import '../../domain/prop.dart';
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

/// 내 모습 탭. 정령에는 머리·피부가 없어 얼굴만 둔다 (11/4 임시, 정령 꾸미기로 바꾸기 전).
/// 머리·피부 탭(HairTab·SkinTab)은 정령 몸 색·베레모 색 견본에 다시 쓸 때까지 남겨 둔다
const _myTabs = {'face': '얼굴'};

/// 탭 줄 글자 배율 상한
const _tabMaxTextScale = 1.5;

/// 꾸미기 (UI 명세 12장): 위 절반은 정령 미리보기와 끼운 소품 줄, 아래는 7개 탭
/// (내 모습: 얼굴 / 소품: 옷 · 모자 · 손 · 가방 · 신발 · 어깨 친구)과 저장·되돌리기.
/// 고른 것은 끼운 소품 줄에 바로 보이고, 저장해야 프로필(Profile.look)에 남는다.
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

  /// 지금 탭: 'face' 또는 소품 칸 이름
  var _tab = 'face';
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
      // 나의 정보 초상이 새 모습을 읽게 한다
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
    // 다음 거리 소품까지 남은 거리: 거리 소품은 앱 걷기 이동 거리로 센다 (Snapshot.walkTravelKm)
    final snap = ref.watch(snapshotProvider).value;
    final look = _look;
    final ready = look != null && props != null && owned != null;
    final dirty = ready && look != _saved;

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
              const ScreenHeader('꾸미기'),
              Expanded(
                child: ready
                    ? _content(
                        look,
                        dirty,
                        props: props,
                        // 기본 소품은 처음부터 가진 것이라, 아직 기록이 없어도 고를 수 있다
                        have: {
                          ...owned,
                          for (final p in props)
                            if (p.kind == PropUnlockKind.initial) p.id,
                        },
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

  Widget _content(
    Look look,
    bool dirty, {
    required List<Prop> props,
    required Set<String> have,
    required double? nextKm,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              const Expanded(child: SpiritPreview()),
              EquippedRow(look: look, props: props),
            ],
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: switch (_tab) {
              'face' => FaceTab(look: look, onChanged: _set),
              final slot => PropTab(
                  slot: slot,
                  look: look,
                  props: [
                    for (final p in props)
                      if (p.slot == slot && have.contains(p.id)) p,
                  ],
                  nextKm: nextKm,
                  onPick: (id) => _set(look.withSlot(slot, id)),
                ),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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

/// 탭 두 묶음: 위에 "내 모습" · "소품" 머리줄, 아래에 탭 7개. 좁으면 옆으로 민다
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Group(
            title: '내 모습',
            tabs: _myTabs,
            selected: selected,
            onSelect: onSelect,
          ),
          const SizedBox(width: 16),
          _Group(
            title: '소품',
            tabs: {for (final s in decorateSlotOrder) s: propSlotLabels[s]!},
            selected: selected,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final String title;

  /// 탭 id → 이름
  final Map<String, String> tabs;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.display(12, color: Palette.subInk),
          ),
          const SizedBox(height: 2),
          Container(height: 2, color: Palette.ink.withValues(alpha: 0.25)),
          Row(
            children: [
              for (final e in tabs.entries) ...[
                if (e.key != tabs.keys.first) const SizedBox(width: 6),
                _TabChip(
                  key: ValueKey('tab-${e.key}'),
                  label: e.value,
                  selected: selected == e.key,
                  onTap: () => onSelect(e.key),
                ),
              ],
            ],
          ),
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
        // 누르는 자리는 44pt, 눈에 보이는 칩은 36pt가 최소다 (글자 크기를 키우면 같이 커진다)
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Palette.terracotta : Palette.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.ink, width: InkLine.panel),
              ),
              child: Text(
                label,
                style: context.display(15, color: selected ? Palette.paper : Palette.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
