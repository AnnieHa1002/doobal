import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shop_providers.dart';
import '../../app/sync_service.dart';
import '../../domain/boat.dart';
import '../../domain/format_int.dart';
import '../../domain/rules.dart';
import '../../domain/shop.dart';
import '../common/app_text.dart';
import '../common/confirm_sheet.dart';
import '../common/item_cell.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../common/toast.dart';
import 'shop_art.dart';

/// 상점 화면 제목 (캔버스 8-1)
const shopTitle = '행상 수레';

/// 가진 상품의 꼬리표
const _ownedState = '가짐';

/// 행상 수레 (캔버스 8-1): 가진 럭, 탭 4, 선반 3열. 상품을 누르면 구매 시트.
/// 광고 카드는 T7, 색 소품과 배 색 시트는 T4c에서 붙인다
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  ShopTab _tab = ShopTab.travel;

  /// 시트를 열거나 사는 중이면 다른 칸을 받지 않는다
  bool _busy = false;

  /// 칸을 눌렀을 때: 못 사면 까닭만 보여 주고, 살 수 있으면 물어본 뒤 산다
  Future<void> _pick(ShopItem item, Rules rules) async {
    if (_busy) return;
    _busy = true;
    try {
      final svc = await ref.read(syncServiceProvider.future);
      final block = await svc.whyNotBuy(item.id);
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
      await _buy(svc, item);
    } finally {
      _busy = false;
    }
  }

  Future<void> _buy(SyncService svc, ShopItem item) async {
    try {
      await svc.buyItem(item.id, ref.read(clockProvider)());
    } on ShopBlocked catch (e) {
      if (mounted) showToast(context, e.block.message);
      return;
    }
    if (!mounted) return;
    ref.invalidate(snapshotProvider);
    if (item.propId != null) ref.invalidate(ownedPropIdsProvider);
    showToast(context, boughtText(item.name));
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopCatalogProvider).value;
    final boats = ref.watch(boatCatalogProvider).value;
    final rules = ref.watch(rulesProvider).value;
    final ownedProps = ref.watch(ownedPropIdsProvider).value;
    final ownedBoats = ref.watch(ownedBoatIdsProvider).value;
    final balance = ref.watch(coinBalanceProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(shopTitle, trailing: _Balance(balance ?? 0)),
            if (shop != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _Tabs(
                  labels: shop.tabLabels,
                  selected: _tab,
                  onSelect: (t) => setState(() => _tab = t),
                ),
              ),
              if (boats != null && rules != null && ownedProps != null && ownedBoats != null)
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey('shop-shelf-${_tab.name}'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: ItemShelf(
                      cells: _cells(shop, boats, rules, ownedProps, ownedBoats),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 지금 탭의 칸. 배 탭은 맨 앞에 처음부터 가진 배 (캔버스 8-1, 상품이 아니다)
  List<Widget> _cells(
    ShopCatalog shop,
    BoatCatalog boats,
    Rules rules,
    Set<String> ownedProps,
    Set<String> ownedBoats,
  ) {
    final first = _tab == ShopTab.boat ? boats.byId(shop.defaultBoat) : null;
    final cells = <Widget>[
      if (first != null)
        ItemCell(
          key: ValueKey('shop-item-${first.id}'),
          name: first.name,
          art: BoatShelfArt(boat: first),
          tilt: 0,
          state: _ownedState,
        ),
    ];
    for (final item in shop.inTab(_tab)) {
      final boat = item.boatId == null ? null : boats.byId(item.boatId!);
      final owned = switch (item) {
        ShopItem(propId: final id?) => ownedProps.contains(id),
        ShopItem(boatId: final id?) => ownedBoats.contains(id),
        _ => false,
      };
      cells.add(ItemCell(
        key: ValueKey('shop-item-${item.id}'),
        name: item.name,
        art: boat != null
            ? BoatShelfArt(boat: boat)
            : ItemArt(id: item.propId ?? item.id, name: item.name),
        tilt: cells.length,
        state: owned ? _ownedState : coinAmountText(item.price, rules),
        stateColor: owned ? Palette.moss : Palette.terracottaDeep,
        onTap: owned ? null : () => _pick(item, rules),
      ));
    }
    return cells;
  }
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

/// 탭 줄: 아래 옅은 선 위에 고른 탭만 테라코타 밑줄 (캔버스 8-1)
class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.selected, required this.onSelect});

  final Map<ShopTab, String> labels;
  final ShopTab selected;
  final ValueChanged<ShopTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 2,
          child: ColoredBox(color: Palette.line),
        ),
        // 글자를 키워도 네 칸의 밑줄이 같은 높이에 온다
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in labels.entries)
                Expanded(
                  child: _Tab(
                    key: ValueKey('shop-tab-${e.key.name}'),
                    label: e.value,
                    selected: e.key == selected,
                    onTap: () => onSelect(e.key),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
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
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Palette.terracotta : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          // 글자를 키워도 네 칸 안에 들어오게 줄인다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: selected
                  ? context.display(16, weight: FontWeight.w600)
                  : const TextStyle(fontSize: 15, color: Palette.subInk),
            ),
          ),
        ),
      ),
    );
  }
}
