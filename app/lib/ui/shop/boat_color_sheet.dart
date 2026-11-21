import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/boat_providers.dart';
import '../../app/shop_providers.dart';
import '../../app/sync_service.dart' show BoatColorSync;
import '../../domain/boat.dart';
import '../../domain/color.dart';
import '../../domain/look.dart';
import '../../domain/spirit_palette.dart';
import '../boat/boat_art_loader.dart';
import '../common/app_text.dart';
import '../common/game_button.dart';
import '../common/item_cell.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../decorate/color_picker.dart';

// 상점 배 색 시트 (T4c, 캔버스 8-1 ‘가진 배 · 색 바꾸기’ → 색 시트, 16장 11/6 배 색, boats.json recolorRule).
// 배 미리보기(걷는 중 배 구간과 같은 그림·같은 계산), 고른 색 점 3, 구역 탭 3, 견본(기본 + 몸 색 10 + 직접),
// 직접 고르기 색상환, 원래 색으로 되돌리기, 취소·저장. 무료(recolorRule.price 0)

/// 직접 고르기를 처음 누를 때의 색 (캔버스 8-1 cust 처음 값 테라코타)
const _customStart = '#C9775A';

/// 견본 칸 크기 (캔버스 44 동그라미)
const _swatch = 44.0;

/// 미리보기 상자 (캔버스 150×80)
const _previewSize = Size(150, 80);

/// [boat]의 색 시트를 연다. 저장하면 true
Future<bool?> showBoatColorSheet(BuildContext context, Boat boat) => showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Palette.card,
      barrierColor: Palette.ink.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: Palette.ink, width: InkLine.panel),
      ),
      builder: (context) => BoatColorSheet(boat: boat),
    );

/// 색 시트 본문. 처음 값은 저장된 색, ‘저장’을 누를 때만 쓴다
class BoatColorSheet extends ConsumerStatefulWidget {
  const BoatColorSheet({super.key, required this.boat});

  final Boat boat;

  @override
  ConsumerState<BoatColorSheet> createState() => _BoatColorSheetState();
}

class _BoatColorSheetState extends ConsumerState<BoatColorSheet> {
  BoatColors? _colors;
  late BoatZone _zone = widget.boat.recolor!.zones.first;
  var _saving = false;

  /// 구역마다 직접 고르기에서 마지막으로 고른 색 (견본으로 갔다 돌아와도 그 색부터)
  final _custom = <BoatZone, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = await ref.read(syncServiceProvider.future);
    final saved = await svc.boatColors(widget.boat.id);
    if (!mounted) return;
    setState(() {
      _colors = saved;
      for (final e in saved.zones.entries) {
        if (e.value case CustomBodyColor(:final hex)) _custom[e.key] = hex;
      }
    });
  }

  void _pick(BodyColor? c) => setState(() => _colors = (_colors ?? BoatColors.none).withZone(_zone, c));

  Future<void> _save() async {
    final colors = _colors;
    if (colors == null || _saving) return;
    setState(() => _saving = true);
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.setBoatColors(widget.boat.id, colors);
      ref.invalidate(boatColorsProvider(widget.boat.id));
      ref.invalidate(sceneBoatProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      // 시트가 닫힌 뒤 아래 화면에 토스트 (캔버스 ‘유람선 색을 바꿨어요’)
      final host = nav.context;
      nav.pop(true);
      if (host.mounted) showToast(host, '${widget.boat.name} 색을 바꿨어요');
    } catch (e) {
      debugPrint('배 색 저장 실패: $e');
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, '저장하지 못했어요');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recolor = widget.boat.recolor!;
    final rule = ref.watch(boatCatalogProvider).value?.recolorRule;
    final palette = ref.watch(spiritPaletteProvider).value?.body;
    final colors = _colors;
    String zoneName(BoatZone z) => rule?.zoneNames[z] ?? z.name;
    final current = colors?[_zone];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.boat.name} 색',
                key: const ValueKey('boat-color-title'), style: context.display(21, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (colors == null || palette == null)
              const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Palette.ink)))
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BoatColorPreview(boat: widget.boat, colors: colors, palette: palette, size: _previewSize),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Semantics(
                      label: '고른 색',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final z in recolor.zones)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: _ZoneDot(
                                key: ValueKey('boat-zone-dot-${z.name}'),
                                label: '${zoneName(z)} ${_colorName(colors[z], palette)}',
                                color: colors[z] == null ? recolor.defaults[z] : palette.argbOf(colors[z]!),
                                original: colors[z] == null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Semantics(
                container: true,
                label: '색 구역',
                child: Row(
                  children: [
                    for (final (i, z) in recolor.zones.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _ZoneTab(
                          key: ValueKey('boat-zone-${z.name}'),
                          label: zoneName(z),
                          selected: z == _zone,
                          onTap: () => setState(() => _zone = z),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Swatches(
                palette: palette,
                current: current,
                original: recolor.defaults[_zone],
                onOriginal: () => _pick(null),
                onSwatch: (id) => _pick(SwatchBodyColor(id)),
                onCustom: () => _pick(CustomBodyColor(_custom[_zone] ?? _customStart)),
              ),
              if (current case CustomBodyColor(:final hex)) ...[
                const SizedBox(height: 10),
                ColorPickerPanel(
                  key: ValueKey('boat-color-picker-${_zone.name}'),
                  hex: hex,
                  minPercent: 0,
                  maxPercent: 100,
                  onChanged: (h) {
                    _custom[_zone] = h;
                    _pick(CustomBodyColor(h));
                  },
                ),
                const SizedBox(height: 4),
                Text('직접 고른 색 $hex',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Palette.ink)),
              ],
              if (!colors.isEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    key: const ValueKey('boat-color-reset'),
                    onPressed: () => setState(() => _colors = BoatColors.none),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: Palette.terracottaDeep,
                    ),
                    child: const Text('원래 색으로 되돌리기',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    key: const ValueKey('boat-color-cancel'),
                    label: '취소',
                    kind: GameButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    key: const ValueKey('boat-color-save'),
                    label: '저장',
                    onPressed: colors == null || _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 고른 색 이름: 견본 이름, 직접, 고르지 않았으면 ‘기본’
String _colorName(BodyColor? c, BodyPalette palette) => switch (c) {
      null => '기본',
      CustomBodyColor() => '직접',
      final SwatchBodyColor s => palette.nameOf(s),
    };

/// 고른 색 점 한 줄 (캔버스: 16 동그라미 + 구역 이름 12). 원래 색은 빗금 (대표색을 알면 그 색 위에 빗금)
class _ZoneDot extends StatelessWidget {
  const _ZoneDot({super.key, required this.label, required this.color, required this.original});

  final String label;
  final int? color;
  final bool original;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CustomPaint(painter: _DotPainter(color: color, hatched: original)),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12, color: Palette.ink))),
        ],
      );
}

class _DotPainter extends CustomPainter {
  const _DotPainter({required this.color, required this.hatched});

  final int? color;
  final bool hatched;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(color ?? Palette.card.toARGB32()));
    if (hatched) {
      // 캔버스 repeating-linear-gradient(45deg, card 3px, line 3px)
      final line = Paint()
        ..color = Palette.line
        ..strokeWidth = 2.1;
      for (var x = -size.height; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
      }
    }
    canvas.restore();
    canvas.drawCircle(
        c,
        r - .7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = InkLine.pill
          ..color = Palette.ink);
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color || old.hatched != hatched;
}

/// 구역 탭 (캔버스: 44 높이, 둥근 12, 고른 탭은 잉크 바탕·카드 글자)
class _ZoneTab extends StatelessWidget {
  const _ZoneTab({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? Palette.ink : Palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Palette.ink : Palette.line, width: InkLine.pill),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Palette.card : Palette.ink,
              ),
            ),
          ),
        ),
      );
}

/// 견본 (캔버스: 44 동그라미 6열, 기본(점선) + 몸 색 10 + 직접(색상환). 고른 칸은 잉크 테두리 + 카드 3 + 테라코타 2 고리)
class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.palette,
    required this.current,
    required this.original,
    required this.onOriginal,
    required this.onSwatch,
    required this.onCustom,
  });

  final BodyPalette palette;
  final BodyColor? current;
  final int? original;
  final VoidCallback onOriginal;
  final ValueChanged<int> onSwatch;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _SwatchCell(
        key: const ValueKey('boat-swatch-original'),
        label: '기본 색',
        mark: '기본',
        selected: current == null,
        dashed: true,
        onTap: onOriginal,
      ),
      for (final s in palette.swatches)
        _SwatchCell(
          key: ValueKey('boat-swatch-${s.id}'),
          label: s.name,
          color: Color(s.color),
          selected: current == SwatchBodyColor(s.id),
          onTap: () => onSwatch(s.id),
        ),
      _SwatchCell(
        key: const ValueKey('boat-swatch-custom'),
        label: '직접 고르기',
        mark: '직접',
        color: switch (current) {
          CustomBodyColor(:final hex) => Color(argbFromHex(hex)),
          _ => null,
        },
        wheel: current is! CustomBodyColor,
        selected: current is CustomBodyColor,
        onTap: onCustom,
      ),
    ];
    return LayoutBuilder(builder: (context, box) {
      // 6열 (캔버스), 좁으면 들어가는 만큼
      final columns = math.max(1, math.min(6, ((box.maxWidth + 6) / (_swatch + 6)).floor()));
      final gap = columns <= 1 ? 0.0 : (box.maxWidth - columns * _swatch) / (columns - 1);
      return Wrap(
        spacing: math.max(0, gap - .5),
        runSpacing: 10,
        children: cells,
      );
    });
  }
}

class _SwatchCell extends StatelessWidget {
  const _SwatchCell({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.mark,
    this.dashed = false,
    this.wheel = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final String? mark;
  final bool dashed;
  final bool wheel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: _swatch,
            height: _swatch,
            child: CustomPaint(
              painter: _SwatchPainter(
                color: color,
                dashed: dashed,
                wheel: wheel,
                selected: selected,
              ),
              child: mark == null
                  ? null
                  : Center(
                      child: MediaQuery.withNoTextScaling(
                        child: Text(mark!,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: Palette.ink)),
                      ),
                    ),
            ),
          ),
        ),
      );
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({required this.color, required this.dashed, required this.wheel, required this.selected});

  final Color? color;
  final bool dashed;
  final bool wheel;
  final bool selected;

  /// 캔버스 직접 고르기 conic-gradient
  static const _wheel = [
    Color(0xFFC9775A),
    Color(0xFFC4A07C),
    Color(0xFF9FAE7E),
    Color(0xFFBCD9E8),
    Color(0xFF7F8DB3),
    Color(0xFFD3C6E6),
    Color(0xFFEFC0BE),
    Color(0xFFC9775A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final face = Rect.fromCircle(center: c, radius: r);
    if (wheel) {
      canvas.drawCircle(c, r, Paint()..shader = const SweepGradient(colors: _wheel).createShader(face));
    } else {
      canvas.drawCircle(c, r, Paint()..color = color ?? Palette.card);
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = InkLine.panel;
    if (selected) {
      canvas.drawCircle(c, r - .9, edge..color = Palette.ink);
      // 고리: 카드 3pt 띄우고 테라코타 2pt (캔버스 box-shadow 0 0 0 3px card, 0 0 0 5px terracotta)
      canvas.drawCircle(
          c,
          r + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Palette.terracotta);
    } else if (dashed) {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = InkLine.panel
        ..color = const Color(0xFF8C6F4E);
      const n = 14;
      for (var i = 0; i < n; i++) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r - .9), i * 2 * math.pi / n, math.pi / n, false, dash);
      }
    } else {
      canvas.drawCircle(c, r - .9, edge..color = Palette.ink);
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.color != color || old.dashed != dashed || old.wheel != wheel || old.selected != selected;
}

/// 배 미리보기: 걷는 중 배 구간과 같은 그림 읽기(`loadBoatLayers`)로 색 입힌 뒤판 + 앞판을 [size] 상자에 맞춰 그린다.
/// 배 그림 파일이 아직 없으면 점선 칸 + 이름 (캔버스 8-1 메모 ‘구역 그림이 오면 입힘, 지금은 구역별 색 점’)
class BoatColorPreview extends ConsumerStatefulWidget {
  const BoatColorPreview({
    super.key,
    required this.boat,
    required this.colors,
    required this.palette,
    required this.size,
  });

  final Boat boat;
  final BoatColors colors;
  final BodyPalette palette;
  final Size size;

  @override
  ConsumerState<BoatColorPreview> createState() => _BoatColorPreviewState();
}

class _BoatColorPreviewState extends ConsumerState<BoatColorPreview> {
  BoatLayerImages? _images;
  String? _loadedKey;
  String? _wantKey;
  var _missing = false;

  @override
  void dispose() {
    _disposeImages(_images);
    super.dispose();
  }

  static void _disposeImages(BoatLayerImages? i) {
    i?.rear.dispose();
    i?.front.dispose();
    i?.night?.dispose();
  }

  Future<void> _load(BoatArt art, int width) async {
    final key = '${art.key}@$width';
    if (_wantKey == key) return;
    _wantKey = key;
    BoatLayerImages? images;
    try {
      images = await loadBoatLayers(DefaultAssetBundle.of(context), art, width);
    } catch (e) {
      debugPrint('배 미리보기를 읽지 못했다: $e');
    }
    if (!mounted || _wantKey != key) {
      _disposeImages(images);
      return;
    }
    final old = _images;
    setState(() {
      _images = images;
      _loadedKey = key;
      _missing = images == null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _disposeImages(old));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(boatCatalogProvider).value;
    final art = catalog?.artOf(
      widget.boat,
      colors: widget.colors,
      argb: boatZoneArgb(widget.colors, widget.palette.argbOf),
    );
    if (art != null) {
      // 상자에 맞춰 판 전체(배 캔버스)를 줄인 폭 × 화면 배율
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final width = math.min(art.canvasWidth, widget.size.width * ratio).ceil().clamp(1, 4096);
      _load(art, width);
    }
    final images = _images;
    return SizedBox.fromSize(
      key: ValueKey('boat-color-preview-${_loadedKey ?? 'none'}'),
      size: widget.size,
      child: _missing || art == null
          ? Center(child: ItemPlaceholder(name: widget.boat.name))
          : images == null
              ? const SizedBox.shrink()
              : Semantics(
                  image: true,
                  label: '${widget.boat.name} 미리보기',
                  child: CustomPaint(painter: _BoatPreviewPainter(images)),
                ),
    );
  }
}

/// 뒤판 → 앞판 (같은 원점, 상자 아래 가운데에 맞춤). 정령은 그리지 않는다
class _BoatPreviewPainter extends CustomPainter {
  const _BoatPreviewPainter(this.images);

  final BoatLayerImages images;

  @override
  void paint(Canvas canvas, Size size) {
    final w = images.rear.width.toDouble();
    final h = images.rear.height.toDouble();
    final scale = math.min(size.width / w, size.height / h);
    final dst = Rect.fromLTWH((size.width - w * scale) / 2, size.height - h * scale, w * scale, h * scale);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final image in [images.rear, images.front]) {
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, w, h), dst, paint);
    }
  }

  @override
  bool shouldRepaint(_BoatPreviewPainter old) => !identical(old.images, images);
}
