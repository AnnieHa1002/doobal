import 'package:flutter/material.dart';

import '../../domain/color.dart';
import '../../domain/look.dart';
import '../../domain/prop.dart';
import '../../domain/spirit_palette.dart';
import '../common/app_text.dart';
import '../common/palette.dart';
import 'decorate_widgets.dart';

/// 소품 칸을 한 줄에 몇 개씩 놓을지 (캔버스 9-2: 선반 3열)
const _propColumns = 3;

/// 아직 가진 게 없을 때 안내에 쓰는 칸 이름 (얼굴 소품·둥실·효과). 나머지 칸은 늘 맨 처음 소품이 있다
const _emptyNames = {'face': '얼굴 소품', 'float': '둥실 소품', 'effect': '효과'};

/// 그림이 나오기 전 소품 칸의 자리표시 색 (카드보다 한 단계 진한 종이색)
const _placeholder = Color(0xFFE4D6BC);

/// 내 모습 탭: 눈·눈썹·코·입 줄과 몸 색 (견본 10 + 직접 고르기). 정령에는 머리·피부가 없다
class MeTab extends StatelessWidget {
  const MeTab({super.key, required this.look, required this.palette, required this.onChanged});

  final Look look;
  final SpiritPalette palette;
  final ValueChanged<Look> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget row(String title, String key, String selected, Look Function(String) set) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FacePartRow(
            keyPrefix: key,
            title: title,
            parts: palette.faces[key]!,
            selected: selected,
            onPick: (id) => onChanged(set(id)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('눈', 'eyes', look.eyes, (id) => look.copyWith(eyes: id)),
          row('눈썹', 'brows', look.brows, (id) => look.copyWith(brows: id)),
          row('코', 'nose', look.nose, (id) => look.copyWith(nose: id)),
          row('입', 'mouth', look.mouth, (id) => look.copyWith(mouth: id)),
          const SizedBox(height: 4),
          BodyColorSection(
            palette: palette.body,
            color: look.body,
            label: '색 견본 · 몸 색',
            onChanged: (c) => onChanged(look.copyWith(body: c)),
          ),
        ],
      ),
    );
  }
}

/// 한국어 주어 조사: 받침이 있으면 이, 없으면 가
String _ga(String word) {
  final c = word.codeUnitAt(word.length - 1);
  return c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0 ? '이' : '가';
}

/// 소품 탭: 한 칸([slot])의 가진 소품만 선반 3열로. 옷이 아니면 맨 앞에 "없음"(손은 "맨손") 칸.
/// 잠긴 소품은 보여 주지 않고, 칸 위에 다음 거리 소품까지 남은 본격 걷기 거리 한 줄만 둔다
/// (무엇인지는 숨긴다, UI 명세 12장·16장 11/3). 거리 소품을 다 얻었으면 그 줄도 없다.
/// 입고 있는 소품에 tint가 있으면(베레모) 색 줄이 칸 위에 붙는다
class PropTab extends StatelessWidget {
  const PropTab({
    super.key,
    required this.slot,
    required this.look,
    required this.props,
    required this.nextKm,
    required this.palette,
    required this.onPick,
    required this.onTint,
  });

  final String slot;
  final Look look;

  /// 그 칸의 가진 소품 (props.json 순서)
  final List<Prop> props;

  /// 다음 거리 소품까지 남은 km ([kmToNextDistanceProp]), 없으면 null
  final double? nextKm;
  final SpiritPalette palette;

  /// 고른 소품 id, "없음"이면 null
  final ValueChanged<String?> onPick;

  /// 소품 색을 고른다 (기본 색이면 null)
  final void Function(String propId, BodyColor? color) onTint;

  /// 소품의 그림 자리표시 색: 색을 고를 수 있으면 지금 고른 색(없으면 기본 색)
  Color _swatchOf(Prop p) {
    if (!p.tintable) return _placeholder;
    final c = look.tints[p.id];
    final rule = palette.tints[p.id];
    return Color(c != null
        ? palette.body.argbOf(c)
        : rule == null
            ? palette.body.swatches.first.color
            : argbFromHex(rule.defaultHex));
  }

  @override
  Widget build(BuildContext context) {
    final current = look.slots[slot];
    final next = nextKm;
    final emptyName = _emptyNames[slot];
    final empty = emptyName != null && props.isEmpty;
    final worn = props.where((p) => p.id == current && p.tintable).firstOrNull;
    final rule = worn == null ? null : palette.tints[worn.id];

    final cells = <Widget>[
      if (!empty && slot != alwaysWornSlot)
        ShelfCell(
          key: const ValueKey('prop-none'),
          name: slot == 'hand' ? '맨손' : '없음',
          state: '',
          selected: current == null,
          swatch: null,
          tilt: 0,
          onTap: () => onPick(null),
        ),
      if (!empty)
        for (final p in props)
          ShelfCell(
            key: ValueKey('prop-${p.id}'),
            name: p.name,
            state: current == p.id ? '입는 중' : '가짐',
            selected: current == p.id,
            swatch: _swatchOf(p),
            tilt: props.indexOf(p) + 1,
            onTap: () => onPick(p.id),
          ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (next != null) ...[
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 18, color: Palette.moss),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nextPropText(next),
                    key: const ValueKey('next-prop'),
                    style: AppText.bodySub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (worn != null && rule != null) ...[
            TintRow(
              propName: worn.name,
              defaultHex: rule.defaultHex,
              body: palette.body,
              selected: look.tints[worn.id],
              onPick: (c) => onTint(worn.id, c),
            ),
            const SizedBox(height: 10),
          ],
          if (empty) ...[
            Text(
              '아직 가진 $emptyName${_ga(emptyName)} 없어요',
              key: const ValueKey('empty-slot'),
              style: AppText.bodySub,
            ),
            const SizedBox(height: 10),
          ],
          for (var start = 0; start < cells.length; start += _propColumns) ...[
            if (start > 0) const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < start + _propColumns; i++)
                  Expanded(child: i < cells.length ? cells[i] : const SizedBox.shrink()),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
