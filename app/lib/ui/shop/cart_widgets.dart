import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/shop.dart';
import '../../domain/shop_cart.dart';
import '../common/app_text.dart';
import '../common/item_cell.dart';
import '../common/paint_art.dart';
import '../common/palette.dart';

// 오늘의 수레 칸들 (캔버스 8-1, 16장 11/19·11/20): 여행 효과 고정 칸, 산 칸 도장, 아직 안 열린 칸, 수레 위 물건.
// 도장·칸 모양 값은 config shop.cart.soldMark와 캔버스 8-1 코드

/// 산 칸 도장 (config shop.cart.soldMark): 두 줄 동그라미 + 가운데 글자, 기울이고 조금 투명하게. 코드로 그린다
class SoldStamp extends StatelessWidget {
  const SoldStamp(this.mark, {super.key});

  final SoldMark mark;

  @override
  Widget build(BuildContext context) {
    final color = Color(mark.argb);
    final d = mark.diameterPt;
    return Opacity(
      opacity: mark.opacity,
      child: Transform.rotate(
        angle: mark.rotateDeg * math.pi / 180,
        child: SizedBox(
          key: const ValueKey('sold-stamp'),
          width: d,
          height: d,
          child: CustomPaint(
            painter: _StampRings(color, mark),
            child: Center(
              child: Text(
                mark.text,
                maxLines: 1,
                // 정해진 동그라미 안이라 글자를 키우지 않는다
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: mark.textPt,
                  letterSpacing: mark.letterSpacingPt,
                  fontWeight: FontWeight.values[(mark.textWeight ~/ 100 - 1).clamp(0, 8)],
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StampRings extends CustomPainter {
  const _StampRings(this.color, this.mark);

  final Color color;
  final SoldMark mark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mark.outerPt
      ..color = color;
    // 바깥 테두리는 상자 안쪽에 (CSS border와 같이)
    canvas.drawCircle(c, r - mark.outerPt / 2, outer);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mark.innerPt
      ..color = color;
    canvas.drawCircle(c, r - mark.innerInsetPt - mark.innerPt / 2, inner);
  }

  @override
  bool shouldRepaint(_StampRings old) => old.color != color || old.mark != mark;
}

/// 여행 효과 고정 칸 (캔버스 8-1 2열): 아이콘 40, 이름 14 / 설명 11 / 값 13
class TravelEffectCell extends StatelessWidget {
  const TravelEffectCell({super.key, required this.item, required this.price, required this.onTap});

  final ShopItem item;

  /// 값 글자 ('50 럭')
  final String price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: [item.name, ?item.desc, price].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.ink, width: InkLine.pill),
            boxShadow: [
              BoxShadow(color: Palette.ink.withValues(alpha: 0.18), offset: const Offset(0, InkLine.shadow)),
            ],
          ),
          child: Row(
            children: [
              SizedBox(width: 40, height: 40, child: _EffectIcon(item)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.name, style: context.display(14, weight: FontWeight.w600)),
                    if (item.desc case final d?)
                      Text(d, style: const TextStyle(fontSize: 11, height: 1.3, color: Palette.subInk)),
                    Text(price, style: context.display(13, color: Palette.terracottaDeep, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 여행 효과 아이콘: 파일이 있으면 그 그림, 없으면 작은 점선 칸 (40pt 상자라 이름은 안 쓴다)
class _EffectIcon extends ConsumerWidget {
  const _EffectIcon(this.item);

  final ShopItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(assetIndexProvider).value?.itemIcon(item.id);
    const none = CustomPaint(key: ValueKey('effect-icon-placeholder'), painter: DashedBoxPainter());
    if (path == null) return none;
    return ItemImage(path, size: const Size(40, 40), fallback: none);
  }
}

/// 아직 안 열린 칸 (캔버스 8-1): 점선 칸 + 자물쇠 + 열리는 누적 거리
class LockedCartSlot extends StatelessWidget {
  const LockedCartSlot({super.key, required this.number, required this.km});

  /// 몇 번째 칸인가 (1부터)
  final int number;
  final double km;

  @override
  Widget build(BuildContext context) {
    final label = '${_km(km)}km';
    return Semantics(
      label: '$number번째 칸, 누적 $label에 열림',
      excludeSemantics: true,
      child: SizedBox(
        height: 64,
        child: CustomPaint(
          painter: const DashedBoxPainter(),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: Palette.subInk),
                  const SizedBox(width: 4),
                  Text(label, style: context.display(12, color: Palette.subInk, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 수레 종류의 화면 이름 (캔버스 8-1 ‘누적 n km를 걸으면 ○○도 수레에 실려요’). 모르는 종류는 null
String? cartKindName(String kind) => switch (kind) {
      'cloth' || 'hat' || 'shoe' => '꾸밈',
      'trail' => '물감 길 무늬',
      'pet' => '미니 친구',
      'face' || 'hand' || 'float' => '액세서리',
      'decor' => '쉼터 물품',
      'effect' => '꾸밈 효과',
      'boat' => '배',
      'paintTube' => '물감 통',
      _ => null,
    };

/// 다음 종류 한 줄: ‘누적 25km를 걸으면 미니 친구도 수레에 실려요’. 다 열렸으면 null
String? nextKindText(CartRules rules, double totalKm) {
  final step = nextKindStep(rules, totalKm);
  if (step == null) return null;
  final names = <String>{
    for (final k in step.kinds)
      if (!rules.fixedKinds.contains(k)) ?cartKindName(k),
  }.toList();
  if (names.isEmpty) return null;
  return '누적 ${_km(step.km)}km를 걸으면 ${names.join('·')}도 수레에 실려요';
}

/// 수레 칸 머리 옆 글: ‘새벽 5시에 바뀌어요’ (config shop.cart.refreshHour)
String cartRefreshText(CartRules rules) {
  final h = rules.refreshHour;
  return h >= 1 && h <= 6 ? '새벽 $h시에 바뀌어요' : '$h시에 바뀌어요';
}

String _km(double km) => km == km.roundToDouble() ? km.round().toString() : km.toStringAsFixed(1);

/// 쉼터 수레 위에 얹는 그날 물건 (camp_wide v5 cart itemsOn, 자리 가안: 캔버스 2-2에 아직 없음).
/// 팔리지 않은 칸만 [max]개까지, 수레 그림 상자([box]) 위쪽에 한두 줄로. 아이콘 그림이 없으면 작은 짐 상자
class CartItemsOnTop extends StatelessWidget {
  const CartItemsOnTop({super.key, required this.slots, required this.max, required this.iconPt});

  final List<CartSlot> slots;
  final int max;

  /// 장면 pt 아이콘 크기 (부르는 쪽이 장면 배율을 곱해 넘긴다)
  final double iconPt;

  @override
  Widget build(BuildContext context) {
    final shown = [for (final s in slots) if (!s.sold) s].take(max).toList();
    if (shown.isEmpty || iconPt <= 0) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      // 한 줄에 셋까지, 넘치면 뒷줄(위)에. 수레 짐칸은 그림 상자 위쪽 약 1/3 (가안)
      final perRow = math.min(3, shown.length);
      final rows = (shown.length / perRow).ceil();
      final bedY = box.maxHeight * 0.34;
      final span = box.maxWidth * 0.72;
      final children = <Widget>[];
      for (var row = rows - 1; row >= 0; row--) {
        final inRow = shown.skip(row * perRow).take(perRow).toList();
        for (final (i, s) in inRow.indexed) {
          final step = inRow.length == 1 ? 0.0 : span / (inRow.length - 1) * 0.8;
          final x = box.maxWidth / 2 + (i - (inRow.length - 1) / 2) * math.max(step, iconPt * 0.8);
          final y = bedY - row * iconPt * 0.55;
          children.add(Positioned(
            key: ValueKey('cart-top-${s.slot}'),
            left: x - iconPt / 2,
            top: y - iconPt,
            width: iconPt,
            height: iconPt,
            child: _CartTopIcon(s),
          ));
        }
      }
      return Stack(clipBehavior: Clip.none, children: children);
    });
  }
}

/// 수레 위 물건 하나: 아이콘 그림 → 물감 통은 그날 색 통 → 그 밖에는 짐 상자 자리표시
class _CartTopIcon extends ConsumerWidget {
  const _CartTopIcon(this.slot);

  final CartSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = slot.item;
    if (slot.tubeColor case final color?) {
      final pc = ref.watch(rulesProvider).value?.paintColor;
      if (pc != null) return PaintTubeArt(color: Color(pc.hexOf(color)));
    }
    final path = ref.watch(assetIndexProvider).value?.itemIcon(item.propId ?? item.id);
    if (path != null) {
      return Image.asset(path, fit: BoxFit.contain, excludeFromSemantics: true, errorBuilder: (_, _, _) => const _Parcel());
    }
    return const _Parcel();
  }
}

/// 그림이 오기 전 수레 위 물건: 종이색 둥근 상자
class _Parcel extends StatelessWidget {
  const _Parcel();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => Center(
          child: Container(
            key: const ValueKey('cart-top-parcel'),
            width: box.maxWidth * 0.78,
            height: box.maxHeight * 0.66,
            decoration: BoxDecoration(
              color: Palette.card,
              borderRadius: BorderRadius.circular(box.maxWidth * 0.18),
              border: Border.all(color: Palette.ink, width: 1.2),
            ),
          ),
        ),
      );
}
