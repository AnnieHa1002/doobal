import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/look.dart';
import '../../domain/profile.dart';
import '../../domain/rules.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import 'start_layout.dart';

/// 머리색 견본을 한 줄에 몇 개씩 놓을지
const _swatchesPerRow = 5;

/// 시작 ② 나: 닉네임·머리 모양·머리색을 고른다. 얼굴·피부·옷은 기본값이고 꾸미기(M4)에서 바꾼다.
/// 위 미리보기는 자리표시 그림이다
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key, required this.rules});

  final Rules rules;

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  final _name = TextEditingController();
  var _look = Look.initial;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  NicknameCheck get _check => checkNickname(_name.text, widget.rules);

  Future<void> _submit() async {
    final check = _check;
    if (!check.ok) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(profileServiceProvider).saveMe(check.value, _look);
    ref.invalidate(onboardingStepProvider);
  }

  @override
  Widget build(BuildContext context) {
    final swatches = ref.watch(hairSwatchesProvider).value;
    if (swatches == null) return const Scaffold(body: SizedBox.expand());
    final rules = widget.rules;
    final check = _check;

    return StartLayout(
      top: _FigurePreview(
        hair: _look.hair,
        hairColor: Color(hairArgb(_look.hairColor, swatches)),
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
        // 금칙어 안내도 여기 (M5 금칙어 문서가 나오면). 빨간색 대신 테라코타 글자
        SizedBox(
          height: 24,
          child: check.ok
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '${rules.nicknameMin}~${rules.nicknameMax}자로 지어 주세요',
                    style: const TextStyle(fontSize: 13, color: Palette.terracotta),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        const StartLabel('머리 모양'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= hairShapeCount; i++) ...[
              if (i > 1) const SizedBox(width: 8),
              Expanded(
                child: _HairCell(
                  number: i,
                  selected: _look.hair == i,
                  onTap: () => setState(() => _look = _look.copyWith(hair: i)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const StartLabel('머리색'),
        const SizedBox(height: 8),
        // TODO(M4): 머리색 직접 고르기는 꾸미기에서 붙인다 (여기는 견본만)
        for (var start = 0; start < swatches.length; start += _swatchesPerRow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in swatches.skip(start).take(_swatchesPerRow))
                _SwatchDot(
                  swatch: s,
                  selected: _look.hairColor == SwatchHairColor(s.id),
                  onTap: () => setState(
                    () => _look = _look.copyWith(hairColor: SwatchHairColor(s.id)),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        const StartNote('얼굴·피부·옷은 나중에 꾸미기에서 바꿀 수 있어요'),
        const SizedBox(height: 16),
        GameButton(label: '이 모습으로', onPressed: check.ok ? _submit : null),
      ],
    );
  }
}

/// 머리 모양 칸 하나 (자리표시: 번호만)
class _HairCell extends StatelessWidget {
  const _HairCell({required this.number, required this.selected, required this.onTap});

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '머리 모양 $number',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('hair-$number'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.terracotta : Palette.paper,
            borderRadius: BorderRadius.circular(startRadius),
            border: Border.all(color: Palette.ink, width: 2.5),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: selected ? Palette.paper : Palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 머리색 견본 동그라미. 이름은 접근성 label, 고른 것은 굵은 테두리와 체크
class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.swatch, required this.selected, required this.onTap});

  final HairSwatch swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(swatch.color);
    return Semantics(
      button: true,
      selected: selected,
      label: swatch.name,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('swatch-${swatch.id}'),
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
                border: Border.all(color: Palette.ink, width: selected ? 4 : 2),
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

/// 위 미리보기 (자리표시): 종이색 바탕에 얼굴 원과 고른 머리 모양·머리색.
/// 캐릭터 그림(쉼터 캠프에 서서 숨 쉬는 모습)이 나오면 바꾼다. 높이가 모자라면 줄거나 사라진다
class _FigurePreview extends StatelessWidget {
  const _FigurePreview({required this.hair, required this.hairColor});

  final int hair;
  final Color hairColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final side = math.min(180.0, math.min(box.maxHeight, box.maxWidth)) - 16;
      if (side < 40) return const SizedBox.shrink();
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: CustomPaint(painter: _FigurePainter(hair, hairColor)),
        ),
      );
    });
  }
}

class _FigurePainter extends CustomPainter {
  const _FigurePainter(this.hair, this.hairColor);

  final int hair;
  final Color hairColor;

  /// 자리표시 얼굴색
  static const _skin = Color(0xFFF6E1D3);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height * 0.5);
    final r = s * 0.26;
    final fill = Paint()..color = hairColor;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Palette.ink;
    void hairShape(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, line);
    }

    Path ball(Offset center, double radius) =>
        Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    Path block(double extraBottom) => Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(c.dx - r * 1.25, c.dy - r * 1.1, c.dx + r * 1.25, c.dy + r + extraBottom),
        Radius.circular(r * 0.6),
      ));
    // 앞머리: 얼굴 위쪽 반원
    Path cap(double extra) =>
        Path()..addArc(Rect.fromCircle(center: c, radius: r + extra), math.pi, math.pi);

    // 몸 (어깨)
    final shoulders = RRect.fromRectAndCorners(
      Rect.fromLTRB(c.dx - r * 1.5, c.dy + r * 1.05, c.dx + r * 1.5, size.height),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(shoulders, Paint()..color = Palette.moss);
    canvas.drawRRect(shoulders, line);

    // 얼굴 뒤에 오는 머리: 2 단발 · 3 긴 머리 · 4 올림머리 · 5 두 갈래
    switch (hair) {
      case 2:
        hairShape(block(r * 0.15));
      case 3:
        hairShape(block(r * 1.1));
      case 4:
        hairShape(ball(c.translate(0, -r * 1.25), r * 0.4));
      case 5:
        hairShape(ball(c.translate(-r * 1.1, r * 0.2), r * 0.38));
        hairShape(ball(c.translate(r * 1.1, r * 0.2), r * 0.38));
    }

    final face = ball(c, r);
    canvas.drawPath(face, Paint()..color = _skin);
    canvas.drawPath(face, line);

    // 앞머리 (6은 짧게 친 머리라 얇게)
    hairShape(cap(hair == 6 ? s * 0.01 : s * 0.04));
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.hair != hair || old.hairColor != hairColor;
}
