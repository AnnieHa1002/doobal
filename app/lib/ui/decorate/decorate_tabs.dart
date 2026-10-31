import 'package:flutter/material.dart';

import '../../domain/color.dart';
import '../../domain/look.dart';
import '../../domain/look_palette.dart';
import '../../domain/prop.dart';
import '../../domain/tint.dart';
import '../common/palette.dart';
import 'color_picker.dart';
import 'decorate_widgets.dart';

/// 소품 칸을 한 줄에 몇 개씩 놓을지 (UI 명세 12장: 4열)
const _propColumns = 4;

List<SwatchItem> _hairItems(HairPalette p) =>
    [for (final s in p.swatches) (id: s.id, name: s.name, color: s.color)];

/// 머리 탭: 모양 6칸, 색 견본 10개, 직접 고르기(색상환 + 밝기), 그라데이션(뿌리색 → 끝색)
class HairTab extends StatefulWidget {
  const HairTab({super.key, required this.look, required this.palette, required this.onChanged});

  final Look look;
  final LookPalette palette;
  final ValueChanged<Look> onChanged;

  @override
  State<HairTab> createState() => _HairTabState();
}

class _HairTabState extends State<HairTab> {
  /// 그러데이션에서 지금 고르는 쪽: false 뿌리색, true 끝색
  var _tip = false;

  /// 고르는 쪽을 직접 고르기(색상환 + 밝기)로 열어 둔다. 견본이 아닌 색이면 저절로 열린다
  var _endCustom = false;

  HairPalette get _hair => widget.palette.hair;
  Look get _look => widget.look;

  /// 지금 머리색을 밝기 범위로 자른 "#RRGGBB" (직접 고르기·그라데이션 끝의 시작 색)
  String _clampedHex(int argb) => hexFromArgb(
        clampLightness(argb, minPercent: _hair.lightMin, maxPercent: _hair.lightMax),
      );

  void _setColor(HairColor c) => widget.onChanged(_look.copyWith(hairColor: c));

  void _startCustom() =>
      _setColor(CustomHairColor(_clampedHex(hairArgb(_look.hairColor, _hair.swatches))));

  void _startGradient() {
    final hex = hexFromArgb(hairArgb(_look.hairColor, _hair.swatches));
    setState(() {
      _tip = false;
      _endCustom = false;
    });
    _setColor(GradientHairColor(hex, hex));
  }

  @override
  Widget build(BuildContext context) {
    final items = _hairItems(_hair);
    final color = _look.hairColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('모양'),
        NumberRow(
          keyPrefix: 'hair',
          label: '머리 모양',
          count: hairShapeCount,
          selected: _look.hair,
          onPick: (n) => widget.onChanged(_look.copyWith(hair: n)),
        ),
        const SectionLabel('색'),
        SwatchGrid(
          keyPrefix: 'hair-swatch',
          items: items,
          isSelected: (s) => color == SwatchHairColor(s.id),
          onPick: (s) => _setColor(SwatchHairColor(s.id)),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            OptionChip(
              key: const ValueKey('hair-custom'),
              label: '직접 고르기',
              selected: color is CustomHairColor,
              onTap: color is CustomHairColor ? () {} : _startCustom,
            ),
            OptionChip(
              key: const ValueKey('hair-gradient'),
              label: '그라데이션',
              selected: color is GradientHairColor,
              onTap: color is GradientHairColor ? () {} : _startGradient,
            ),
          ],
        ),
        if (color is CustomHairColor)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ColorPickerPanel(
              hex: color.hex,
              minPercent: _hair.lightMin,
              maxPercent: _hair.lightMax,
              onChanged: (hex) => _setColor(CustomHairColor(hex)),
            ),
          ),
        if (color is GradientHairColor) _gradient(color, items),
      ],
    );
  }

  /// 그러데이션: 뿌리색·끝색 두 칸 중 하나를 골라 견본이나 직접 고르기로 바꾼다
  Widget _gradient(GradientHairColor g, List<SwatchItem> items) {
    final rootArgb = argbFromHex(g.root);
    final tipArgb = argbFromHex(g.tip);
    final endArgb = _tip ? tipArgb : rootArgb;
    final isSwatch = items.any((s) => s.color == endArgb);
    final showPicker = _endCustom || !isSwatch;

    GradientHairColor withEnd(String hex) =>
        _tip ? GradientHairColor(g.root, hex) : GradientHairColor(hex, g.tip);

    void selectEnd(bool tip) => setState(() {
          _tip = tip;
          _endCustom = false;
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EndCell(
                key: const ValueKey('grad-root'),
                label: '뿌리색',
                color: Color(rootArgb),
                selected: !_tip,
                onTap: () => selectEnd(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EndCell(
                key: const ValueKey('grad-tip'),
                label: '끝색',
                color: Color(tipArgb),
                selected: _tip,
                onTap: () => selectEnd(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwatchGrid(
          keyPrefix: 'grad-swatch',
          items: items,
          isSelected: (s) => !showPicker && s.color == endArgb,
          onPick: (s) {
            setState(() => _endCustom = false);
            _setColor(withEnd(hexFromArgb(s.color)));
          },
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OptionChip(
            key: const ValueKey('grad-custom'),
            label: '직접 고르기',
            selected: showPicker,
            onTap: () {
              setState(() => _endCustom = true);
              final hex = _clampedHex(endArgb);
              if (hex != (_tip ? g.tip : g.root)) _setColor(withEnd(hex));
            },
          ),
        ),
        if (showPicker)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ColorPickerPanel(
              hex: _tip ? g.tip : g.root,
              minPercent: _hair.lightMin,
              maxPercent: _hair.lightMax,
              onChanged: (hex) => _setColor(withEnd(hex)),
            ),
          ),
      ],
    );
  }
}

/// 그러데이션의 뿌리색·끝색 칸: 색 상자와 이름. 지금 고르는 쪽은 굵은 테라코타 테두리
class _EndCell extends StatelessWidget {
  const _EndCell({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        child: Column(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? Palette.terracotta : Palette.ink,
                  width: selected ? 4 : 2.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: Palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 얼굴 탭: 눈 · 코 · 눈썹 · 귀를 줄마다 번호로 고른다. 그림이 나오면 번호 대신 그림을 넣는다
class FaceTab extends StatelessWidget {
  const FaceTab({super.key, required this.look, required this.onChanged});

  final Look look;
  final ValueChanged<Look> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget row(String title, String key, int count, int selected, Look Function(int) set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(title),
            NumberRow(
              keyPrefix: key,
              label: title,
              count: count,
              selected: selected,
              onPick: (n) => onChanged(set(n)),
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('눈', 'eyes', eyeShapeCount, look.eyes, (n) => look.copyWith(eyes: n)),
        row('코', 'nose', noseShapeCount, look.nose, (n) => look.copyWith(nose: n)),
        row('눈썹', 'brows', browShapeCount, look.brows, (n) => look.copyWith(brows: n)),
        row('귀', 'ears', earShapeCount, look.ears, (n) => look.copyWith(ears: n)),
      ],
    );
  }
}

/// 피부 탭: 견본 7개, 직접 고르기(색상환 + 밝기)
class SkinTab extends StatelessWidget {
  const SkinTab({super.key, required this.look, required this.palette, required this.onChanged});

  final Look look;
  final LookPalette palette;
  final ValueChanged<Look> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = palette.skin;
    final color = look.skin;
    void set(SkinColor c) => onChanged(look.copyWith(skin: c));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('피부색'),
        SwatchGrid(
          keyPrefix: 'skin-swatch',
          items: [for (final s in skin.swatches) (id: s.id, name: s.name, color: s.color)],
          isSelected: (s) => color == SwatchSkinColor(s.id),
          onPick: (s) => set(SwatchSkinColor(s.id)),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OptionChip(
            key: const ValueKey('skin-custom'),
            label: '직접 고르기',
            selected: color is CustomSkinColor,
            onTap: color is CustomSkinColor
                ? () {}
                : () => set(CustomSkinColor(hexFromArgb(clampLightness(
                      skinArgb(color, skin.swatches),
                      minPercent: skin.lightMin,
                      maxPercent: skin.lightMax,
                    )))),
          ),
        ),
        if (color is CustomSkinColor)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ColorPickerPanel(
              hex: color.hex,
              minPercent: skin.lightMin,
              maxPercent: skin.lightMax,
              onChanged: (hex) => set(CustomSkinColor(hex)),
            ),
          ),
      ],
    );
  }
}

/// 소품 탭: 한 칸([slot])의 MVP 소품을 4열로. 옷이 아니면 맨 앞에 "없음" 칸.
/// 가진 소품은 골라 끼우고, 잠긴 소품은 흐리게 보이며 누르면 [onLocked]
class PropTab extends StatelessWidget {
  const PropTab({
    super.key,
    required this.slot,
    required this.look,
    required this.props,
    required this.owned,
    required this.onPick,
    required this.onLocked,
  });

  final String slot;
  final Look look;

  /// 그 칸의 소품 (props.json 순서)
  final List<Prop> props;

  /// 가진 소품 id
  final Set<String> owned;

  /// 고른 소품 id, "없음"이면 null
  final ValueChanged<String?> onPick;
  final ValueChanged<Prop> onLocked;

  @override
  Widget build(BuildContext context) {
    final current = look.slots[slot];
    final cells = <Widget>[
      if (slot != alwaysWornSlot)
        PropCell(
          key: const ValueKey('prop-none'),
          name: '없음',
          icon: null,
          selected: current == null,
          locked: false,
          onTap: () => onPick(null),
        ),
      for (final p in props)
        PropCell(
          key: ValueKey('prop-${p.id}'),
          name: p.name,
          icon: slotIcons[slot],
          selected: current == p.id,
          locked: !owned.contains(p.id),
          onTap: owned.contains(p.id) ? () => onPick(p.id) : () => onLocked(p),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          for (var start = 0; start < cells.length; start += _propColumns) ...[
            if (start > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < start + _propColumns; i++) ...[
                  if (i > start) const SizedBox(width: 8),
                  Expanded(child: i < cells.length ? cells[i] : const SizedBox.shrink()),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
