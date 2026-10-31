import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/landmark.dart';
import '../../domain/look.dart';
import '../../domain/look_palette.dart';
import '../../domain/prop.dart';
import '../album/prop_text.dart';
import '../common/confirm_sheet.dart';
import '../common/figure_painter.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../common/toast.dart';
import 'decorate_tabs.dart';
import 'decorate_widgets.dart';
import 'figure_preview.dart';

const _myTabs = {'hair': '머리', 'face': '얼굴', 'skin': '피부'};

/// 꾸미기 (UI 명세 12장): 위 절반은 캐릭터 미리보기와 끼운 소품 줄, 아래는 9개 탭
/// (내 모습: 머리 · 얼굴 · 피부 / 소품: 옷 · 모자 · 손 · 가방 · 신발 · 어깨 친구)과 저장·되돌리기.
/// 고르는 대로 미리보기가 바뀌고, 저장해야 프로필(Profile.look)에 남는다.
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

  /// 지금 탭: 'hair' · 'face' · 'skin' 또는 소품 칸 이름
  var _tab = 'hair';
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
    final palette = ref.watch(lookPaletteProvider).value;
    final props = ref.watch(propsProvider).value;
    final owned = ref.watch(ownedPropIdsProvider).value;
    // 잠긴 소품을 얻는 방법(누적 거리·걸음·다녀온 곳)에 쓴다
    final snap = ref.watch(snapshotProvider).value;
    final landmarks = ref.watch(landmarksProvider).value ?? const <Landmark>[];
    final paintings = ref.watch(paintingsProvider).value ?? const [];
    final look = _look;
    final ready = look != null && palette != null && props != null && owned != null;
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
                        palette,
                        dirty,
                        props: props,
                        // 기본 소품은 처음부터 가진 것이라, 아직 기록이 없어도 고를 수 있다
                        have: {
                          ...owned,
                          for (final p in props)
                            if (p.kind == PropUnlockKind.initial) p.id,
                        },
                        howTo: (p) => propHowTo(
                          p,
                          totalKm: snap?.totalKm ?? 0,
                          totalSteps: snap?.totalSteps ?? 0,
                          progress: regionProgress({
                            for (final v in paintings)
                              if (!v.isFirstPack) v.landmark.id,
                          }, landmarks),
                        ),
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
    LookPalette palette,
    bool dirty, {
    required List<Prop> props,
    required Set<String> have,
    required String? Function(Prop) howTo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: FigurePreview(painter: figureOf(look, palette))),
              EquippedRow(look: look, props: props),
            ],
          ),
        ),
        _TabStrip(selected: _tab, onSelect: (id) => setState(() => _tab = id)),
        Expanded(
          child: SingleChildScrollView(
            // 탭마다 맨 위에서 시작한다
            key: ValueKey('body-$_tab'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: switch (_tab) {
              'hair' => HairTab(look: look, palette: palette, onChanged: _set),
              'face' => FaceTab(look: look, onChanged: _set),
              'skin' => SkinTab(look: look, palette: palette, onChanged: _set),
              final slot => PropTab(
                  slot: slot,
                  look: look,
                  props: [for (final p in props) if (p.slot == slot) p],
                  owned: have,
                  onPick: (id) => _set(look.withSlot(slot, id)),
                  // 잠긴 소품은 얻는 방법을 토스트로 (화집 소품 탭과 같은 문구)
                  onLocked: (p) {
                    final text = howTo(p);
                    if (text != null) showToast(context, text);
                  },
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

/// 탭 두 묶음: 위에 "내 모습" · "소품" 머리줄, 아래에 탭 9개. 좁으면 옆으로 민다
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Palette.subInk,
            ),
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
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Palette.terracotta : Palette.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.ink, width: 2.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
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
