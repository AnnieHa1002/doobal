import 'package:flutter/material.dart';

import 'app_text.dart';

/// 큰 숫자 40 (UI 명세 0장). [unit]은 작은 글자로 뒤에 붙고, 칸이 좁으면 통째로 줄어든다
class BigNumber extends StatelessWidget {
  const BigNumber(this.value, {super.key, this.unit, this.alignment = Alignment.center});

  final String value;
  final String? unit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(
          text: value,
          style: AppText.bigNumber,
          children: [if (unit != null) TextSpan(text: ' $unit', style: AppText.bodySub)],
        ),
      ),
    );
  }
}
