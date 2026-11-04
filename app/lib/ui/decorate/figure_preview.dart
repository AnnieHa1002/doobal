import 'package:flutter/material.dart';

import '../../domain/rules.dart';
import '../../domain/spirit_look.dart';
import '../common/app_text.dart';
import '../common/palette.dart';
import '../scene/spirit_character.dart';
import 'decorate_widgets.dart';

/// 표정 미리보기 단추: (이름, Rive 표정 번호). 저장하지 않는 미리보기다 (palette.json expressions)
const previewExpressions = [
  ('기본', 0),
  ('행복', 1),
  ('울먹임', 2),
  ('놀람', 3),
  ('졸림', 4),
  ('화남', 5),
];

/// 꾸미기 위 미리보기: 쉼터와 같은 정령을 정면으로 풀밭 위에 세운다. 머리·배를 누르면 정령이 반응하고
/// 연타하면 화낸다. 아래에 입고 있는 소품 요약 줄, 오른쪽 위에 표정 미리보기 단추 여섯.
/// 고르는 대로 얼굴·몸 색이 바뀌고, Rive에 붙은 소품(domain/spirit_look.dart)도 입는다
class SpiritPreview extends StatelessWidget {
  const SpiritPreview({
    super.key,
    required this.look,
    required this.summary,
    required this.expression,
    required this.onExpression,
    this.tapRules,
  });

  final SpiritLook look;

  /// 입고 있는 소품 이름을 이은 줄 ("소품 없음"이면 비었다는 뜻)
  final String summary;
  final int expression;
  final ValueChanged<int> onExpression;
  final Rules? tapRules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: DecoratedBox(
        key: const ValueKey('preview'),
        decoration: BoxDecoration(
          color: const Color(0xFFE9DFC9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 풀밭 자리
              Positioned.fill(
                child: FractionallySizedBox(
                  heightFactor: 0.22,
                  alignment: Alignment.bottomCenter,
                  child: const ColoredBox(color: Color(0xFFD8CBB0)),
                ),
              ),
              Positioned.fill(
                child: SpiritStanding(look: look, expression: expression, tapRules: tapRules),
              ),
              Positioned(
                left: 12,
                bottom: 10,
                right: 76,
                child: Container(
                  key: const ValueKey('summary'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Palette.card.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$summary${expression == 0 ? '' : '  ·  표정 미리보기'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.4, color: Palette.ink),
                  ),
                ),
              ),
              // 미리보기가 낮아도 단추가 잘리지 않게 줄어든다
              Positioned(
                right: 8,
                top: 8,
                bottom: 8,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (name, value) in previewExpressions) ...[
                        if (value > 0) const SizedBox(height: 3),
                        _ExpressionButton(
                          key: ValueKey('expr-$value'),
                          name: name,
                          selected: expression == value,
                          onTap: () => onExpression(value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpressionButton extends StatelessWidget {
  const _ExpressionButton({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '표정 $name',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // 글자 크기를 키우면 단추도 같이 커진다 (바깥 FittedBox가 칸에 맞춰 줄인다)
          constraints: const BoxConstraints(minWidth: 56, minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.ink : Palette.card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? Palette.ink : lineColor, width: InkLine.pill),
          ),
          child: Text(
            name,
            style: context.display(12, color: selected ? Palette.card : Palette.ink),
          ),
        ),
      ),
    );
  }
}
