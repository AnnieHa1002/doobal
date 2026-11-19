import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paint_providers.dart';
import '../../app/providers.dart';
import '../../app/screen_providers.dart';
import '../../app/shop_providers.dart';
import '../../app/sync_service.dart';
import '../../domain/camp_theme.dart';
import '../../domain/rest_camera.dart';
import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
import '../../domain/sketch.dart';
import '../album/album_screen.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/notice_dot.dart';
import '../common/palette.dart';
import '../debug/debug_screen.dart';
import '../decorate/decorate_screen.dart';
import '../map/map_screen.dart';
import '../scene/scene_view.dart';
import '../shop/shop_art.dart';
import '../shop/shop_slots.dart';
import '../tabs/home_tabs.dart';
import 'prop_wiggle.dart';
import 'rest_gestures.dart';
import 'rest_slots.dart';

/// 쉼터 (아래 탭 ‘쉼터’의 처음 화면, 16장 11/18·11/19, 캔버스 2-2). 장면(하늘 → 후경 → 캠프 뒤 → 물건 → 정령 →
/// 캠프 앞 → 불꽃)은 화면 폭의 1.5배이고 좌우로 민다. 장면 아래는 탭 바 위로 30pt 겹친다.
/// 위에는 럭 보석(왼쪽)과 ‘쉬는 중 · 목적지까지 n km’ 알약(가운데)만 고정이다 (나의 정보·설정은 ‘나’ 탭으로).
/// 오른쪽에 게임식 세로 버튼 지도·배낭(화집)·상점·쉼터 꾸미기 (config rest.sideButtons, 56pt).
/// 쉼터 꾸미기 버튼은 쉼터 꾸미기(T15)가 서랍과 함께 켠다 (그 전에는 그리지 않는다).
/// 땅 위 누르는 물건(배낭·노트·지도)·불 옆 동행·방명록 표지판은 없다 (camp_wide v5, 동행·표지판은 걷기 탭).
/// 수레는 테마에 자리가 있으면 서고 누르면 상점이다 (M2~M6 AC 가안).
/// 출발하기 버튼은 없다 (16장 11/13 물감 길). 걸어도 화면은 그대로이고, 걷는 중이면 아래 걷기 탭 아이콘의
/// 발자국이 움직인다 (16장 11/18 ⑤).
/// 첫 여정을 아직 안 걸었으면 아래 가운데 말풍선 ‘걸으면 출발해요’ (캔버스 2-1), 여정이 없으면 지도 버튼에 알림 점.
/// 수레는 3~6초마다 살짝 흔들린다 (연출 값은 prop_wiggle.dart).
/// 하루 카드(캔버스 2-3)는 탭 바 위에 뜨도록 탭 뼈대가 띄운다.
/// 정령은 떠 있기 정면·앉기 정면을 20~40초마다 바꾸고(같은 자세 연속 없음), 밤에는 잠든다
/// (config character.rive.restSwap, 16장 11/19 쉼터는 정면). 새 소품이 생기면 잠깐 놀란다 (palette newProp).
/// 정령을 길게 누르면 정령 꾸미기 (config character.tapReaction.longPress, 16장 11/19 ③).
/// 새 소식 점은 config ui.newDot에 있는 자리만 (배낭·상점, 16장 11/13·11/18)
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

/// 위 고정 줄 (캔버스 2-2: 왼쪽·오른쪽 14pt, 높이 48)
const _hudSide = 14.0;
const _hudRow = 48.0;

/// 위 고정 줄의 위 끝: 상태 표시줄 아래 (캔버스 390×844 54pt, 375×667 24pt)
double _hudTop(EdgeInsets padding) => math.max(padding.top + 6, 24);

/// 첫날 말풍선의 아래 여백 (캔버스 2-1: 탭 바 위 16pt, 탭 바가 없으면 40pt)
const _hintBottom = 40.0;
const _hintAboveBar = 16.0;

class _RestScreenState extends ConsumerState<RestScreen> with SingleTickerProviderStateMixin {
  late final PropWiggler _wiggler;
  final _camera = ValueNotifier(const RestCamera());

  /// 쉼터 정령 자세 바꾸기 (config restSwap). 규칙을 읽은 첫 화면에서 시작한다
  Timer? _swapTimer;
  int? _restPose;

  /// 정령에 잠깐 보일 표정 (새 소품)
  SpiritCue? _cue;

  void _startSwap(RestSwapRules r) {
    if (_swapTimer != null) return;
    _restPose ??= r.poses.first;
    _scheduleSwap(r);
  }

  void _scheduleSwap(RestSwapRules r) {
    final random = ref.read(restSwapRandomProvider);
    _swapTimer = Timer(nextRestGap(r, random), () {
      if (!mounted) return;
      setState(() => _restPose = nextRestPose(r, _restPose, random));
      _scheduleSwap(r);
    });
  }

  /// 얻은 소품이 늘면(안 본 소품 수가 늘면) 정령이 잠깐 놀란다 (처음 읽을 때는 아니다)
  void _onSnapshot(AsyncValue<Snapshot>? prev, AsyncValue<Snapshot> next) {
    final before = prev?.value?.unseenProps;
    final after = next.value?.unseenProps;
    if (before == null || after == null || after <= before) return;
    final c = ref.read(spiritPaletteProvider).value?.cues.of('newProp');
    if (c != null) setState(() => _cue = SpiritCue(c.expr, holdSec: c.holdSec, trigger: c.trigger));
  }

  @override
  void initState() {
    super.initState();
    _wiggler = PropWiggler(vsync: this, spec: ref.read(restWiggleProvider), pool: _wigglePool);
  }

  @override
  void dispose() {
    _swapTimer?.cancel();
    _wiggler.dispose();
    _camera.dispose();
    super.dispose();
  }

  /// 아직 안 본 소품·그림·도장·새 물감 색이 있는가 (배낭의 알림 점, 물감은 처음 모은 색만 M2~M6 v0.20 Y).
  /// config ui.newDot.on에 배낭이 없으면 점도 없다
  bool _hasNew(Snapshot snap) =>
      (ref.read(rulesProvider).value?.screen.dotOn('backpack') ?? true) &&
      (snap.unseenProps > 0 ||
      snap.unseenPaintings > 0 ||
      snap.unseenBadges > 0 ||
      (ref.read(unseenPaintsProvider).value ?? 0) > 0);

  /// 흔들 수 있는 물건 (화면에 서 있는 것만: 수레). 알림 점은 옆 버튼에 붙어 흔들림을 고르지 않는다
  ({List<String> all, Set<String> notice}) _wigglePool() {
    final camp = ref.read(campThemeProvider).value;
    final snap = ref.read(snapshotProvider).value;
    final cart = ref.read(restSlotsProvider).cart != null && camp?.objectOrNull(campCartId) != null;
    if (snap == null || snap.position == null || !cart) return (all: const [], notice: const {});
    return (all: const [campCartId], notice: const {});
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value;
    final landmarks = ref.watch(landmarksProvider).value;
    final camp = ref.watch(campThemeProvider).value;
    final snap = ref.watch(snapshotProvider).value;
    // 새 물감 색이 생기면 배낭 점 (_hasNew)
    ref.watch(unseenPaintsProvider);
    final now = ref.watch(minuteClockProvider).value ?? ref.watch(clockProvider)();
    final spirit = ref.watch(spiritLookProvider);
    final slots = ref.watch(restSlotsProvider);
    final luck = ref.watch(coinBalanceProvider).value ?? 0;
    // 테스트용 거리 배수가 켜져 있으면 알려 준다 (켜 둔 채 잊지 않게)
    final scale = kDebugMode ? ref.watch(debugDistanceScaleProvider) : 1.0;
    ref.listen(snapshotProvider, _onSnapshot);
    final cues = ref.watch(spiritPaletteProvider).value?.cues;
    // 데이터가 올 때까지는 종이색 빈 화면
    if (rules == null || landmarks == null || camp == null || snap == null) {
      return const Scaffold(body: SizedBox.expand());
    }
    _startSwap(rules.screen.spirit.restSwap);
    // 시작 관문이 출발 동네를 먼저 고르게 하므로 위치는 늘 있다 (없으면 빈 화면)
    final position = snap.position;
    if (position == null) return const Scaffold(body: SizedBox.expand());
    final firstSketch = _firstSketchHint(snap, rules);
    final padding = MediaQuery.viewPaddingOf(context);
    final sceneBottom = TabBarSpace.sceneBottom(context);
    final barSpace = TabBarSpace.of(context);
    final hudTop = _hudTop(padding);
    final small = MediaQuery.sizeOf(context).height < 700;
    final cart = slots.cart != null && camp.objectOrNull(campCartId) != null;
    final shopDot = slots.cart?.notice ?? false;
    final buttons = <_SideButtonSpec>[
      for (final id in rules.screen.tabs.sideButtons) ?_sideButton(context, id, snap, shopDot),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: sceneBottom,
            child: LayoutBuilder(builder: (context, box) {
              final stage = RestGeometry(camp, rules.rest, box.maxWidth, box.maxHeight);
              return RestGestures(
                stage: stage,
                camera: _camera,
                child: SceneView(
                  mode: SceneMode.rest,
                  distanceM: 0,
                  nowUtc: now,
                  position: position,
                  onSea: snap.onSea,
                  rules: rules,
                  landmarks: landmarks,
                  camp: camp,
                  sceneSeed: snap.journey?.dest.id ?? 'home',
                  spirit: spirit,
                  seated: false,
                  restPose: _restPose,
                  spiritCue: _cue,
                  spiritCues: cues,
                  camera: _camera,
                  onSpiritLongPress: rules.screen.tabs.spiritLongPressCustomize
                      ? () => _push(context, const DecorateScreen())
                      : null,
                  sceneBehind: [
                    if (firstSketch != null) _firstSign(stage, camp.firstSign),
                    if (cart) _slotArt(stage, camp.objectOrNull(campCartId)!, slots.cart!),
                  ],
                  sceneAbove: [
                    if (cart) _hitBox(context, stage, camp.objectOrNull(campCartId)!, slots.cart!),
                  ],
                ),
              );
            }),
          ),
          // 위 고정 줄: 럭 보석(왼쪽) + 쉬는 중 알약(가운데, 오른쪽 56pt를 비워 가운데처럼 보이게)
          Positioned(
            left: _hudSide + padding.left,
            right: _hudSide + padding.right,
            top: hudTop,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: _hudRow, child: _LuckGem(luck: luck, slot: slots.gem)),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 56),
                    child: Column(
                      children: [
                        SizedBox(height: _hudRow, child: Center(child: _StatusPill(_statusText(snap)))),
                        if (scale != 1) _ScaleBadge(distanceScaleBadge(scale)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽 세로 버튼 (캔버스 2-2: 오른쪽 12pt, 위 줄 아래 30pt(작은 폰 16pt), 간격 10)
          Positioned(
            right: _sideRight + padding.right,
            top: hudTop + _hudRow + (small ? 16 : 30),
            child: _SideButtons(buttons),
          ),
          if (firstSketch != null)
            Positioned(
              left: _hudSide,
              right: _hudSide,
              bottom: barSpace > 0 ? barSpace + _hintAboveBar : math.max(padding.bottom, _hintBottom),
              child: IgnorePointer(
                child: Center(
                  child: _WalkHint(key: const ValueKey('first-sketch-bubble'), sub: firstSketch),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 옆 버튼 [id] (config rest.sideButtons.items). 아직 열 화면이 없으면(쉼터 꾸미기, T15) null
  _SideButtonSpec? _sideButton(BuildContext context, String id, Snapshot snap, bool shopDot) =>
      switch (id) {
        'map' => _SideButtonSpec(
            id: id,
            label: '지도',
            // 여정이 없으면 점 (출발하기 버튼이 없어서 목적지를 고르는 곳을 알린다, 캔버스 2-2)
            dot: snap.journey == null,
            icon: const _SideImage('assets/backgrounds/v11/obj_rest_map_v11_clean.png', Icons.map_outlined),
            onTap: () => _push(context, const MapScreen()),
          ),
        'backpack' => _SideButtonSpec(
            id: id,
            label: '배낭',
            dot: _hasNew(snap),
            icon: const _SideImage(
                'assets/backgrounds/v11/obj_rest_backpack_v11_clean.png', Icons.backpack_outlined),
            onTap: () => _push(context, const AlbumScreen()),
          ),
        // 상품이 없으면(수레 자리가 비면) 상점 입구를 숨긴다 (스키마 13장)
        'shop' when ref.read(restSlotsProvider).cart != null => _SideButtonSpec(
            id: id,
            label: '상점',
            dot: shopDot,
            icon: const ShopCartArt(),
            onTap: () => openShop(context),
          ),
        _ => null,
      };

  /// 상태 알약 글: ‘쉬는 중 · 목적지까지 n km’ (걷는 중에도 같다, 걷는 중은 걷기 탭 발자국이 알린다)
  String _statusText(Snapshot snap) {
    const state = '쉬는 중';
    final j = snap.journey;
    if (j == null) return '$state · 목적지를 골라 보세요';
    // 첫 여정은 이름이 있는 목적지가 아니라 내 동네 스케치
    final dest = j.dest.id == sketchId ? sketchName : '목적지';
    return '$state · $dest까지 ${formatKm(j.progress.remainingKm)}';
  }

  /// 첫 여정 '내 동네 스케치'를 아직 한 걸음도 안 걸었을 때 아래 말풍선 ‘걸으면 출발해요’ 밑의 작은 줄
  /// (캔버스 2-1: `0.6km · 약 860보`). 그 밖에는 null (걷기 시작해서 진행이 생기면 말풍선·첫날 이정표가
  /// 함께 사라진다)
  String? _firstSketchHint(Snapshot snap, Rules rules) {
    final j = snap.journey;
    if (j == null || snap.home == null || j.dest.id != sketchId || j.progress.progressKm > 0) {
      return null;
    }
    final km = j.progress.remainingKm;
    return '${formatKm(km)} · 약 ${formatInt(sketchSteps(km, rules))}보';
  }

  /// 다른 트랙이 끼운 물건의 그림 (수레). 알림 점은 옆 상점 버튼에 붙는다
  Widget _slotArt(RestGeometry stage, CampObject o, RestObjectSlot slot) {
    final k = stage.k;
    return Positioned(
      left: stage.sx(o.box.x),
      top: stage.sy(o.box.y),
      width: o.artW * k,
      height: o.artH * k,
      child: IgnorePointer(
        child: PropWiggle(
          key: ValueKey('wiggle-${o.id}'),
          wiggler: _wiggler,
          id: o.id,
          child: Builder(builder: slot.art),
        ),
      ),
    );
  }

  /// 첫날 이정표 글 (이정표 판 위). 눌리지 않는다
  Widget _firstSign(RestGeometry stage, CampSign sign) {
    final k = stage.k;
    return Positioned(
      key: const ValueKey('first-sign'),
      left: stage.sx(sign.box.x),
      top: stage.sy(sign.box.y),
      width: sign.box.w * k,
      height: sign.box.h * k,
      child: IgnorePointer(child: FittedBox(child: _SceneLabel(sign.label))),
    );
  }

  /// 수레 누름 상자 (장면 맨 위, 이름표 없음: 상점 이름은 옆 버튼에 있다)
  Widget _hitBox(BuildContext context, RestGeometry stage, CampObject o, RestObjectSlot slot) {
    final k = stage.k;
    return Positioned(
      left: stage.sx(o.box.x),
      top: stage.sy(o.box.y),
      width: o.box.w * k,
      height: o.box.h * k,
      child: Semantics(
        button: true,
        label: slot.label ?? o.label,
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey('camp-object-${o.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => slot.onTap(context),
        ),
      ),
    );
  }
}

/// 옆 버튼 오른쪽 여백 (캔버스 2-2 right 12)
const _sideRight = 12.0;

/// 옆 버튼 하나의 값
class _SideButtonSpec {
  const _SideButtonSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.dot = false,
  });

  final String id;
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool dot;
}

/// 오른쪽 세로 버튼 줄 (캔버스 2-2 .side: 56pt 둥근 네모 + 아래 이름표, 간격 10)
class _SideButtons extends StatelessWidget {
  const _SideButtons(this.buttons);

  final List<_SideButtonSpec> buttons;

  static const _box = 56.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '쉼터 메뉴',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, b) in buttons.indexed) ...[
            if (i > 0) const SizedBox(height: _gap),
            Semantics(
              button: true,
              label: b.dot ? '${b.label} (새 소식 있음)' : b.label,
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('rest-side-${b.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: b.onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _box,
                      height: _box,
                      decoration: BoxDecoration(
                        color: Palette.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Palette.ink, width: InkLine.panel),
                        boxShadow: const [
                          BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow)),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Padding(padding: const EdgeInsets.all(6), child: b.icon),
                          ),
                          if (b.dot)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: NoticeDot(key: ValueKey('rest-side-${b.id}-dot')),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    _SceneLabel(b.label),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 옆 버튼 그림 자리: 쉼터 물건 그림을 줄인 것 (Codex camp_deco_v01 T04 아이콘이 오면 바꾼다).
/// 그림을 못 읽으면 아이콘
class _SideImage extends StatelessWidget {
  const _SideImage(this.file, this.fallback);

  final String file;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      file,
      fit: BoxFit.contain,
      cacheWidth: (44 * ratio).ceil(),
      errorBuilder: (_, _, _) => Icon(fallback, color: Palette.ink, size: 28),
    );
  }
}

/// 물건 이름표 (캔버스 .lbl). 선 없는 작은 카드색 띠
class _SceneLabel extends StatelessWidget {
  const _SceneLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, maxLines: 1, softWrap: false, style: context.display(11)),
    );
  }
}

/// 럭 보석과 숫자 (캔버스 2-2). 판 없이 보석 그림 오른쪽에 테두리 글씨.
/// 그림은 T4b가 끼운다 (ui_gem 납품 전 자리표시)
class _LuckGem extends StatelessWidget {
  const _LuckGem({required this.luck, required this.slot});

  final int luck;
  final RestGemSlot slot;

  static const _width = 44.0;
  static const _height = 40.5;

  @override
  Widget build(BuildContext context) {
    final number = formatInt(luck);
    final style = context.display(18);
    final onTap = slot.onTap;
    final body = SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _width,
            height: _height,
            child: slot.art == null
                ? const _GemPlaceholder()
                : Builder(builder: slot.art!),
          ),
          const SizedBox(width: 4),
          Stack(
            children: [
              Text(
                number,
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 5
                    ..strokeJoin = StrokeJoin.round
                    ..color = Palette.ink,
                ),
              ),
              Text(number, key: const ValueKey('luck-number'), style: style.copyWith(color: Palette.card)),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '럭 $number',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('rest-gem'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap(context),
        child: body,
      ),
    );
  }
}

/// 보석 그림이 오기 전 자리표시: 보석색 둥근 덩어리 + 하이라이트 한 점
class _GemPlaceholder extends StatelessWidget {
  const _GemPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.gem,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      alignment: const Alignment(-0.45, -0.5),
      child: Container(
        width: 9,
        height: 7,
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// 위쪽 가운데 상태 알약 (카드색 90%, 물감 길이 닫혀 있을 때)
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.ink, width: InkLine.pill),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: context.display(14),
        ),
      ),
    );
    return pill;
  }
}

/// 상태 알약 아래의 "거리 ×10" 표시 (테라코타 바탕, 잉크 2px 테두리). 디버그 배수가 켜진 동안만
class _ScaleBadge extends StatelessWidget {
  const _ScaleBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('debug-scale-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.terracotta,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.ink, width: InkLine.pill),
      ),
      child: Text(
        text,
        style: context.display(12, color: Palette.paper),
      ),
    );
  }
}

/// 첫날 아래 가운데 말풍선 (캔버스 2-1): ‘걸으면 출발해요’ + 작은 줄 [sub] (`0.6km · 약 860보`)
class _WalkHint extends StatelessWidget {
  const _WalkHint({super.key, required this.sub});

  final String sub;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.ink, width: InkLine.pill),
          boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('걸으면 출발해요', textAlign: TextAlign.center, style: context.display(14)),
            Text(sub, textAlign: TextAlign.center, style: AppText.label),
          ],
        ),
      ),
    );
  }
}
