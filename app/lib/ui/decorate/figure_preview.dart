import 'package:flutter/material.dart';

import '../../domain/look.dart';
import '../../domain/prop.dart';
import '../../domain/spirit_look.dart';
import '../common/format.dart';
import '../common/palette.dart';
import '../scene/spirit_character.dart';
import 'decorate_widgets.dart';

/// 꾸미기 위 미리보기: 쉼터와 같은 정령을 정면으로 풀밭 위에 세운다. 머리·배를 누르면 정령이 반응한다.
/// 고르는 대로 얼굴이 바뀌고, Rive에 붙은 소품(domain/spirit_look.dart)도 입는다
class SpiritPreview extends StatelessWidget {
  const SpiritPreview({super.key, required this.look});

  final SpiritLook look;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: DecoratedBox(
        key: const ValueKey('preview'),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.ink, width: InkLine.panel),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9.5),
          child: Stack(
            children: [
              // 풀밭 자리
              Positioned.fill(
                child: FractionallySizedBox(
                  heightFactor: 0.22,
                  alignment: Alignment.bottomCenter,
                  child: ColoredBox(color: Palette.moss.withValues(alpha: 0.25)),
                ),
              ),
              Positioned.fill(child: SpiritStanding(look: look)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 미리보기 아래의 끼운 소품 줄: 칸마다 아이콘(자리표시)과 이름, 비운 칸은 흐리게 "없음"
class EquippedRow extends StatelessWidget {
  const EquippedRow({super.key, required this.look, required this.props});

  final Look look;
  final List<Prop> props;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in props) p.id: p};
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          for (final slot in decorateSlotOrder)
            Expanded(
              child: _Equipped(
                key: ValueKey('equip-$slot'),
                slot: slot,
                name: look.slots[slot] == null ? null : byId[look.slots[slot]]?.name,
              ),
            ),
        ],
      ),
    );
  }
}

class _Equipped extends StatelessWidget {
  const _Equipped({super.key, required this.slot, required this.name});

  final String slot;

  /// 끼운 소품 이름. 비었으면 null
  final String? name;

  @override
  Widget build(BuildContext context) {
    final worn = name != null;
    return Semantics(
      label: '${propSlotLabels[slot]} ${name ?? '없음'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: worn ? 1 : 0.4,
        child: Column(
          children: [
            Icon(slotIcons[slot], size: 22, color: Palette.ink),
            Text(
              name ?? '없음',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.2, color: Palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}
