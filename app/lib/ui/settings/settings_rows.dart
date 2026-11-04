import 'package:flutter/material.dart';

import '../common/app_text.dart';
import '../common/ink_card.dart';
import '../common/palette.dart';

/// 카드 위 작은 제목
class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: context.display(12, color: Palette.subInk)),
    );
  }
}

/// 줄들을 한 카드에 담고 줄 사이에 잉크 줄을 긋는다
class SettingsGroup extends StatelessWidget {
  const SettingsGroup(this.rows, {super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 2, thickness: InkLine.panel, color: Palette.ink),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// 설정 한 줄 (높이 52 이상). [onTap]이 있으면 눌리고 오른쪽에 화살표, 없으면 글만 보인다.
/// [note]가 있으면 눌리지 않는 줄로 흐리게 두고 오른쪽에 그 글을 쓴다 ("준비 중").
/// [value]는 눌리는 줄의 오른쪽 글이다 ("켜짐")
class SettingsRow extends StatelessWidget {
  const SettingsRow(this.title, {super.key, this.onTap, this.note, this.value});

  final String title;
  final VoidCallback? onTap;
  final String? note;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final off = note != null;
    return Semantics(
      button: onTap != null,
      enabled: !off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: off ? AppText.bodySub : AppText.body),
                ),
                if (note != null) Text(note!, style: AppText.label),
                if (value != null) Text(value!, style: AppText.label),
                if (onTap != null) const Icon(Icons.chevron_right, color: Palette.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
