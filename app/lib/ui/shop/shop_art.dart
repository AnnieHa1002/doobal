import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/boat.dart';
import '../../domain/camp_theme.dart';
import '../../domain/scene.dart';
import '../../domain/sky.dart';
import '../common/item_cell.dart';
import '../common/palette.dart';
import '../scene/scene_art.dart' show WideCampImages;

// 상점 그림 셋: 럭 보석·수레·선반의 배. 모두 파일이 있으면 읽고, 없으면 자리표시로 그린다.
// 받은 그림은 폴더에 넣기만 하면 된다 (docs/트랙/상점_T4b.md)

/// 럭 보석: `assets/ui/ui_gem_sky*`. 없으면 보석색 둥근 덩어리. 받은 상자를 채운다
class LuckGemArt extends ConsumerWidget {
  const LuckGemArt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(assetIndexProvider).value?.gem;
    return LayoutBuilder(builder: (context, box) {
      if (path == null) return _GemPlaceholder(width: box.maxWidth);
      return Image.asset(
        path,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        cacheWidth: artCacheWidth(box.maxWidth),
        errorBuilder: (_, _, _) => _GemPlaceholder(width: box.maxWidth),
      );
    });
  }
}

/// 쉼터 보석 자리표시(44pt)와 같은 모양을 폭에 맞춰 그린다
class _GemPlaceholder extends StatelessWidget {
  const _GemPlaceholder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final k = width / 44;
    return Container(
      key: const ValueKey('gem-placeholder'),
      decoration: BoxDecoration(
        color: Palette.gem,
        borderRadius: BorderRadius.circular(16 * k),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      alignment: const Alignment(-0.45, -0.5),
      child: Container(
        width: 9 * k,
        height: 7 * k,
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(4 * k),
        ),
      ),
    );
  }
}

/// 행상 수레 (camp_wide.json artSource). 그림 폴더에 파일이 있으면 그 그림, 밤에는 랜턴 층을 얹는다.
/// 없으면 점선 칸 + 상점 표시. 받은 상자(테마의 artW×artH)를 채운다
class ShopCartArt extends ConsumerWidget {
  const ShopCartArt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(assetIndexProvider).value;
    final cart = ref.watch(campThemeProvider).value?.object(campCartId);
    String? find(String? name) =>
        index == null || name == null ? null : index.file(WideCampImages.dir, name);
    final file = find(cart?.artSourceFile);
    if (file == null) return const _CartPlaceholder();
    final lantern = find(cart?.artSourceNight);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, box) {
      Widget image(String path, Widget onError) => Image.asset(
            path,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            excludeFromSemantics: true,
            cacheWidth: (box.maxWidth * ratio).ceil(),
            errorBuilder: (_, _, _) => onError,
          );
      return Stack(
        fit: StackFit.expand,
        children: [
          image(file, const _CartPlaceholder()),
          if (lantern != null && _isNight(ref)) image(lantern, const SizedBox.shrink()),
        ],
      );
    });
  }

  /// 장면과 같은 기준의 밤·새벽 (배 창 불빛과 같다)
  bool _isNight(WidgetRef ref) {
    final rules = ref.watch(rulesProvider).value;
    final landmarks = ref.watch(landmarksProvider).value;
    final position = ref.watch(snapshotProvider).value?.position;
    if (rules == null || landmarks == null || position == null) return false;
    final now = ref.watch(minuteClockProvider).value ?? ref.read(clockProvider)();
    final phase = sceneLook(now, position, false, landmarks, rules).phase;
    return phase == SkyPhase.night || phase == SkyPhase.dawn;
  }
}

class _CartPlaceholder extends StatelessWidget {
  const _CartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const ValueKey('cart-placeholder'),
      painter: DashedBoxPainter(fill: Palette.card.withValues(alpha: 0.85)),
      child: const Center(
        child: Icon(Icons.storefront_outlined, size: 44, color: Palette.ink),
      ),
    );
  }
}

/// 선반의 배: 칸 그림 파일이 있으면 그것, 없으면 배 뒤판 + 앞판을 줄여 얹는다.
/// 둘 다 없으면 점선 칸 + 이름
class BoatShelfArt extends ConsumerWidget {
  const BoatShelfArt({super.key, required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(assetIndexProvider).value;
    final catalog = ref.watch(boatCatalogProvider).value;
    final fallback = ItemArt(id: boat.id, name: boat.name, size: boatArtSize);
    if (index == null || catalog == null || index.itemIcon(boat.id) != null) return fallback;
    final art = catalog.artOf(boat);
    if (!index.has(art.rear) || !index.has(art.front)) return fallback;
    final none = ItemPlaceholder(name: boat.name);
    return SizedBox.fromSize(
      size: boatArtSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ItemImage(art.rear, size: boatArtSize, fallback: none),
          ItemImage(art.front, size: boatArtSize, fallback: const SizedBox.shrink()),
        ],
      ),
    );
  }
}
