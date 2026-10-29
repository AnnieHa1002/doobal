import 'package:flutter/material.dart';

import 'palette.dart';

/// 막대의 한 구간. fraction은 전체 대비 0~1
class BarSegment {
  const BarSegment(this.fraction, this.color);

  final double fraction;
  final Color color;
}

/// 잉크 테두리 막대. 구간 합이 1보다 작으면 나머지는 카드색으로 비워 둔다.
/// 진행 막대는 이끼색 한 구간, 걷기/뛰기 비율은 이끼 + 테라코타 두 구간
class InkBar extends StatelessWidget {
  const InkBar({super.key, required this.segments, this.height = 14});

  final List<BarSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final used = segments.fold(0.0, (sum, s) => sum + s.fraction.clamp(0.0, 1.0));
    final rest = (1 - used).clamp(0.0, 1.0);
    int flex(double f) => (f * 1000).round();
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Palette.ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final s in segments)
            if (flex(s.fraction.clamp(0.0, 1.0)) > 0)
              Expanded(
                flex: flex(s.fraction.clamp(0.0, 1.0)),
                child: ColoredBox(color: s.color, child: const SizedBox.expand()),
              ),
          if (flex(rest) > 0) Spacer(flex: flex(rest)),
        ],
      ),
    );
  }
}
