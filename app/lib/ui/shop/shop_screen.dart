import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paint_providers.dart';
import '../../app/providers.dart';
import '../../app/shop_providers.dart';
import '../../app/sync_service.dart';
import '../../domain/boat.dart';
import '../../domain/format_int.dart';
import '../../domain/prop.dart';
import '../../domain/rules.dart';
import '../../domain/shop.dart';
import '../../domain/shop_cart.dart';
import '../common/app_text.dart';
import '../common/confirm_sheet.dart';
import '../common/item_cell.dart';
import '../common/paint_art.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../common/toast.dart';
import 'cart_widgets.dart';
import 'shop_art.dart';

/// 상점 화면 제목 (캔버스 8-1, 16장 11/19 오늘의 수레)
const shopTitle = '오늘의 수레';

/// 여행 효과 머리와 옆 글 (캔버스 8-1)
const travelTitle = '여행 효과';
const travelNote = '늘 있어요';

/// 가진 상점 배 줄 머리 (캔버스 8-1, 16장 11/20)
const ownedBoatsTitle = '가진 배 · 색 바꾸기';

/// 오늘의 수레 (캔버스 8-1, 16장 11/19·11/20): 가진 럭, 여행 효과 고정 칸 2열, 그날 수레 칸(선반 3열, 산 칸은
/// SOLD 도장), 아직 안 열린 칸·다음 종류 한 줄, 가진 상점 배 줄. 칸을 누르면 구매 시트.
/// 광고 카드는 T7, 배 색 시트는 T4c (가진 배 줄의 알약은 아직 눌리지 않는다)
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  @override
  void initState() {
    super.initState();
    // 상점을 열면 그날 새 상품을 본 것으로 (옆 상점 버튼 점이 꺼진다, DB 19). 연 동안 새벽에 수레가 바뀌어도
    ref.listenManual(todayCartProvider, (_, cart) {
      if (cart.value?.news ?? false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) markShopSeen(ref);
        });
      }
    }, fireImmediately: true);
  }

  /// 시트를 열거나 사는 중이면 다른 칸을 받지 않는다
  bool _busy = false;

  /// 여행 효과 칸을 눌렀을 때: 못 사면 까닭만 보여 주고, 살 수 있으면 물어본 뒤 산다
  Future<void> _pickFixed(ShopItem item, Rules rules) => _pick(
        item,
        rules,
        why: (svc) => svc.whyNotBuy(item.id),
        buy: (svc, now) => svc.buyItem(item.id, now),
      );

  /// 수레 칸을 눌렀을 때. 산 칸은 누를 수 없다
  Future<void> _pickSlot(TodayCart cart, CartSlot slot, Rules rules) => _pick(
        slot.item,
        rules,
        why: (svc) => svc.whyNotBuyCart(cart.day, slot.slot, ref.read(clockProvider)()),
        buy: (svc, now) => svc.buyCartSlot(cart.day, slot.slot, now),
      );

  Future<void> _pick(
    ShopItem item,
    Rules rules, {
    required Future<ShopBlock?> Function(SyncService svc) why,
    required Future<void> Function(SyncService svc, DateTime now) buy,
  }) async {
    if (_busy) return;
    _busy = true;
    try {
      final svc = await ref.read(syncServiceProvider.future);
      final block = await why(svc);
      if (!mounted) return;
      if (block != null) {
        showToast(context, block.message);
        return;
      }
      final left = await svc.coinBalance() - item.price;
      if (!mounted) return;
      final yes = await showConfirmSheet(
        context,
        buyQuestionText(item.name, item.price, rules),
        rules.coinBuyButton,
        '취소',
        detail: coinsLeftText(left),
      );
      if (yes != true || !mounted) return;
      try {
        await buy(svc, ref.read(clockProvider)());
      } on ShopBlocked catch (e) {
        if (mounted) showToast(context, e.block.message);
        return;
      }
      if (!mounted) return;
      ref.invalidate(snapshotProvider);
      if (item.propId != null) ref.invalidate(ownedPropIdsProvider);
      if (item.paintTubes != null) {
        ref.invalidate(paintShelfProvider);
        ref.invalidate(unseenPaintsProvider);
      }
      showToast(context, boughtText(item.name));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final boats = ref.watch(boatCatalogProvider).value;
    final rules = ref.watch(rulesProvider).value;
    final props = ref.watch(propsProvider).value;
    final balance = ref.watch(coinBalanceProvider).value;
    final cart = ref.watch(todayCartProvider).value;
    final ownedBoats = ref.watch(ownedBoatIdsProvider).value;
    final shop = ref.watch(shopCatalogProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(shopTitle, trailing: _Balance(balance ?? 0)),
            if (cart != null && rules != null && boats != null && props != null)
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('shop-scroll'),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cart.fixed.isNotEmpty) ...[
                        const _SectionHead(travelTitle, note: travelNote),
                        const SizedBox(height: 10),
                        _Grid(columns: 2, gap: 8, children: [
                          for (final item in cart.fixed)
                            TravelEffectCell(
                              key: ValueKey('shop-item-${item.id}'),
                              item: item,
                              price: coinAmountText(item.price, rules),
                              onTap: () => _pickFixed(item, rules),
                            ),
                        ]),
                        const SizedBox(height: 20),
                      ],
                      _SectionHead(shopTitle, note: cartRefreshText(rules.shopCart)),
                      const SizedBox(height: 14),
                      ItemShelf(
                        key: const ValueKey('cart-shelf'),
                        cells: [
                          for (final (i, slot) in cart.slots.indexed) _cell(cart, slot, i, rules, boats, props),
                        ],
                      ),
                      ..._locked(cart, rules.shopCart),
                      if (nextKindText(rules.shopCart, cart.totalKm) case final line?) ...[
                        const SizedBox(height: 12),
                        Text(
                          line,
                          key: const ValueKey('cart-next-kind'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Palette.subInk),
                        ),
                      ],
                      ..._ownedBoats(shop, boats, ownedBoats),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 수레 칸 하나: 산 칸은 도장만(누를 수 없음), 아니면 그림 + 꼬리표(이름·값)
  Widget _cell(TodayCart cart, CartSlot slot, int tilt, Rules rules, BoatCatalog boats, List<Prop> props) {
    final item = slot.item;
    final key = ValueKey('cart-slot-${slot.slot}');
    final mark = rules.shopCart.soldMark;
    if (slot.sold) {
      return ItemCell(
        key: key,
        name: item.name,
        art: const SizedBox.shrink(),
        tilt: tilt,
        // 꼬리표는 안 그리고 읽어 주는 글에만 (캔버스 8-1 aria '이름, SOLD')
        state: mark?.text ?? '',
        stamp: mark == null ? const SizedBox(width: 56, height: 56) : SoldStamp(mark),
      );
    }
    final pc = rules.paintColor;
    return ItemCell(
      key: key,
      name: item.name,
      // 물감 통 칸만 그날 색 이름 (가안)
      desc: slot.tubeColor == null ? null : pc.nameOf(slot.tubeColor!),
      art: _art(slot, boats, props, rules),
      tilt: tilt,
      state: coinAmountText(item.price, rules),
      stateColor: Palette.terracottaDeep,
      onTap: () => _pickSlot(cart, slot, rules),
    );
  }

  Widget _art(CartSlot slot, BoatCatalog boats, List<Prop> props, Rules rules) {
    final item = slot.item;
    if (slot.tubeColor case final color?) {
      return SizedBox.fromSize(
        size: itemArtSize,
        child: PaintTubeArt(color: Color(rules.paintColor.hexOf(color))),
      );
    }
    if (item.boatId case final id?) {
      if (boats.byId(id) case final boat?) return BoatShelfArt(boat: boat);
    }
    for (final p in props) {
      if (p.id == item.propId) return ItemArt.prop(p);
    }
    return ItemArt(id: item.propId ?? item.id, name: item.name);
  }

  /// 아직 안 열린 칸 (칸 수가 다 차기 전): 칸이 늘어나는 누적 거리마다
  List<Widget> _locked(TodayCart cart, CartRules rules) {
    final kms = lockedSlotKms(rules, cart.cartKm);
    if (kms.isEmpty) return const [];
    final first = rules.slotsAt(cart.cartKm);
    return [
      const SizedBox(height: 14),
      _Grid(columns: 3, gap: 8, children: [
        for (final (i, km) in kms.indexed)
          LockedCartSlot(key: ValueKey('cart-locked-$i'), number: first + i + 1, km: km),
      ]),
    ];
  }

  /// 가진 상점 배 (수레에는 안 나온다, 16장 11/20). 색 시트는 T4c라 알약은 아직 눌리지 않는다
  List<Widget> _ownedBoats(ShopCatalog? shop, BoatCatalog boats, Set<String>? owned) {
    if (shop == null || owned == null) return const [];
    final mine = [
      for (final i in shop.items)
        if (i.boatId case final id? when owned.contains(id)) ?boats.byId(id),
    ];
    if (mine.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      const _SectionHead(ownedBoatsTitle),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final b in mine) _BoatPill(key: ValueKey('owned-boat-${b.id}'), boat: b)],
      ),
    ];
  }
}

/// 묶음 머리: 제목 15 + 옆 글 12 (캔버스 8-1)
class _SectionHead extends StatelessWidget {
  const _SectionHead(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(title, style: context.display(15, weight: FontWeight.w600)),
          if (note case final n?) Text(n, style: const TextStyle(fontSize: 12, color: Palette.subInk)),
        ],
      );
}

/// 칸 [columns]열 (남는 자리는 비운다)
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.gap, required this.children});

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) SizedBox(width: gap),
                    Expanded(child: i < children.length ? children[i] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
}

/// 가진 배 알약 (캔버스 8-1: 44 높이, 둥근 끝, 14pt)
class _BoatPill extends StatelessWidget {
  const _BoatPill({super.key, required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: false,
        label: boat.name,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.ink, width: InkLine.pill),
          ),
          // 글자 폭만큼 (줄을 꽉 채우지 않는다)
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(boat.name, style: context.display(14, weight: FontWeight.w600)),
          ),
        ),
      );
}

/// 제목 오른쪽 가진 럭: 보석 + 숫자
class _Balance extends StatelessWidget {
  const _Balance(this.luck);

  final int luck;

  @override
  Widget build(BuildContext context) {
    final number = formatInt(luck);
    return Semantics(
      label: '가진 럭 $number개',
      excludeSemantics: true,
      // 글자를 키운 작은 화면에서는 제목 자리를 남기고 줄어든다
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 32, height: 29.5, child: LuckGemArt()),
              const SizedBox(width: 4),
              Text(
                number,
                key: const ValueKey('shop-balance'),
                style: context.display(18, weight: FontWeight.w600).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
