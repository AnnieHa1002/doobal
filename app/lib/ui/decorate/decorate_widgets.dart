import 'package:flutter/material.dart';

import '../../domain/color.dart';
import '../../domain/look.dart';
import '../../domain/spirit_palette.dart';
import '../common/app_text.dart';
import '../common/palette.dart';
import 'color_picker.dart';

/// 캔버스(9-2 꾸미기)의 보조 색: 옅은 선, 나무색
const lineColor = Color(0xFFD9C9AE);
const _woodColor = Color(0xFF8C6F4E);

/// 색 견본 동그라미. 이름은 접근성 label, 고른 것은 굵은 테두리와 체크
class SwatchDot extends StatelessWidget {
  const SwatchDot({
    super.key,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
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
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Palette.terracotta : Palette.ink,
                  width: selected ? 3 : InkLine.panel,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: color.computeLuminance() > 0.5 ? Palette.ink : Palette.paper,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// '+' 직접 고르기 동그라미 (견본 줄 맨 끝)
class _PlusDot extends StatelessWidget {
  const _PlusDot({super.key, required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '직접 고르기',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Palette.terracotta : _woodColor,
                  width: selected ? 3 : InkLine.panel,
                ),
              ),
              // 글자 대신 그림이라 글자 크기를 키워도 동그라미 안에 머문다
              child: const Icon(Icons.add, size: 22, color: Palette.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// 몸 색 고르기: 견본 10개와 '+' 직접 고르기, 직접 고르는 중이면 색상환 + 밝기 막대
/// (밝기 제한·채도 막대 없음). 꾸미기 내 모습 탭과 시작 화면이 같이 쓴다.
/// 칸의 key는 `'$keyPrefix-swatch-번호'`, 직접 고르기는 `'$keyPrefix-custom'`
class BodyColorSection extends StatelessWidget {
  const BodyColorSection({
    super.key,
    required this.palette,
    required this.color,
    required this.onChanged,
    this.label = '몸 색',
    this.keyPrefix = 'body',
  });

  final BodyPalette palette;
  final BodyColor color;
  final ValueChanged<BodyColor> onChanged;

  /// 제목 앞부분. 뒤에 고른 색 이름이 붙는다
  final String label;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final custom = color is CustomBodyColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          key: ValueKey('$keyPrefix-name'),
          TextSpan(
            children: [
              TextSpan(text: '$label '),
              TextSpan(text: palette.nameOf(color), style: context.display(14)),
            ],
          ),
          style: const TextStyle(fontSize: 14, color: Palette.ink),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in palette.swatches)
              SwatchDot(
                key: ValueKey('$keyPrefix-swatch-${s.id}'),
                name: s.name,
                color: Color(s.color),
                selected: color == SwatchBodyColor(s.id),
                onTap: () => onChanged(SwatchBodyColor(s.id)),
              ),
            _PlusDot(
              key: ValueKey('$keyPrefix-custom'),
              selected: custom,
              // 지금 색에서 이어서 고른다
              onTap: custom
                  ? () {}
                  : () => onChanged(CustomBodyColor(hexFromArgb(palette.argbOf(color)))),
            ),
          ],
        ),
        if (color case CustomBodyColor(:final hex))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ColorPickerPanel(
              hex: hex,
              minPercent: 0,
              maxPercent: 100,
              onChanged: (h) => onChanged(CustomBodyColor(h)),
            ),
          ),
      ],
    );
  }
}

/// 얼굴 파츠 한 줄 (눈·눈썹·코·입): 이름 글자 칸 + 파츠 칸들. 그림이 나오면 글자 대신 그림을 넣는다.
/// 칸의 key는 `'$keyPrefix-파츠id'`
class FacePartRow extends StatelessWidget {
  const FacePartRow({
    super.key,
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

  /// 칸에 들어가는 짧은 이름 (캔버스의 이름: '콩 눈' → '콩', '쑥스러움' → '///', '삐죽 미소' → '삐죽')
  static String shortName(String id, String name) => switch (id) {
        'shy' => '///',
        'smirk' => '삐죽',
        _ => name.replaceAll(' 눈', ''),
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(34),
          child: Text(title, style: const TextStyle(fontSize: 13, color: Palette.ink)),
        ),
        const SizedBox(width: 6),
        for (final p in parts)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: p == parts.last ? 0 : 6),
              child: PartCell(
                key: ValueKey('$keyPrefix-${p.id}'),
                label: '$title ${p.name}',
                text: shortName(p.id, p.name),
                selected: selected == p.id,
                onTap: () => onPick(p.id),
              ),
            ),
          ),
      ],
    );
  }
}

/// 얼굴 파츠 칸 하나: 짧은 이름, 고른 것은 굵은 테라코타 테두리. [label]은 접근성 이름
class PartCell extends StatelessWidget {
  const PartCell({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
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
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Palette.terracotta : lineColor,
              width: selected ? 3 : InkLine.pill,
            ),
          ),
          // 글자를 키워도 칸 안에서 줄어든다 (칸이 7개까지 좁아진다)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
