import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paint_providers.dart';
import '../../app/paint_trail_controller.dart';
import '../../app/providers.dart';
import '../../app/report_providers.dart';
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
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/notice_dot.dart';
import '../common/palette.dart';
import '../day_card/day_card_view.dart';
import '../debug/debug_screen.dart';
import '../guestbook/guestbook_write_screen.dart';
import '../map/map_screen.dart';
import '../note/note_screen.dart';
import '../profile/profile_screen.dart';
import '../scene/scene_view.dart';
import '../settings/settings_screen.dart';
import '../walking/paint_trail_host.dart';
import 'prop_wiggle.dart';
import 'rest_gestures.dart';
import 'rest_slots.dart';

/// 쉼터 (홈, 루트 화면). 장면(하늘 → 후경 → 캠프 뒤 → 물건 → 정령 → 동행 → 캠프 앞 → 불꽃)은 화면 폭의
/// 1.5배이고 좌우로 민다. 프로필·설정·상태 알약은 고정이다 (캔버스 2-2).
/// 출발하기 버튼은 없다 (16장 11/13 물감 길): 앱을 연 채 걸으면 저절로 걷는 중으로 넘어간다 (PaintTrailHost).
/// 첫 여정을 아직 안 걸었으면 아래 가운데 말풍선 ‘걸으면 출발해요’ (캔버스 2-1), 여정이 없으면 지도에 알림 점.
/// 물감 길이 이어지는 동안(걷는 중에서 쉼터 아이콘으로 왔을 때) 위 가운데는 ‘걷는 중 · 물감 길 n km ›’(지금 물감 색 점,
/// 44pt, 캔버스 2-2 11/16)이고 누르면 걷는 중으로 (16장 11/16 쉼터↔걷는 중 ④).
/// 물건은 3~6초마다 하나씩 살짝 흔들린다 (알림 점이 있는 물건 우선, 연출 값은 prop_wiggle.dart).
/// 불 옆 동행은 알림 점(안 읽은 장)이 있을 때만 흔들림에 든다 (평소에는 캔버스대로 둥실, 그림 쪽 몫).
/// 새벽 5시 뒤 그날 처음 열면 하루 카드(캔버스 2-3)가 위에 겹쳐 뜬다 (pendingDayCardProvider, 닫으면 본 것으로).
/// 도착·걷는 중은 그 위에 올라가니 그것을 끝내고 쉼터로 돌아오면 카드가 보인다.
/// 정령은 떠 있기 정면·앉기 정면·앉기 옆을 20~40초마다 바꾸고(같은 자세 연속 없음), 밤에는 잠든다
/// (config character.rive.restSwap, 16장 11/11). 새 소품이 생기면 잠깐 놀란다 (palette newProp).
/// 새 소식 점은 config ui.newDot에 있는 자리만 (배낭·동행·수레, 16장 11/13)
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

/// 흔들림 id: 캠프 물건은 테마의 id(지도·배낭·노트), 방명록 표지판은 이것
const _guestbookWiggleId = 'guestbook';

// 고정 HUD 자리 (캔버스 2-2)
const _hudInset = 16.0;
const _hudButton = 56.0;
const _gemGap = 10.0;

/// 첫날 말풍선의 아래 여백 (캔버스 2-1: 40pt, 작은 화면 24pt)
const _hintBottom = 40.0;

/// 그림으로 서는 물건 (수레·표지판·동행은 따로)
const _artObjects = {'map', 'backpack', 'note'};

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

  /// 흔들 수 있는 물건과 그 중 알림 점이 있는 물건 (화면에 서 있는 것만)
  ({List<String> all, Set<String> notice}) _wigglePool() {
    final camp = ref.read(campThemeProvider).value;
    final snap = ref.read(snapshotProvider).value;
    if (camp == null || snap == null || snap.position == null) {
      return (all: const [], notice: const {});
    }
    // 테마에 자리가 있는 물건만 (camp_wide v5는 수레만 남아 배낭·지도·노트·표지판·동행이 없다)
    bool has(String id) => camp.objectOrNull(id) != null;
    final sign = snap.guestbookTicket != null && has(campGuestbookSignId);
    final companion = (ref.read(restSlotsProvider).companion?.notice ?? false) && has(campCompanionId);
    return (
      all: [
        for (final id in _artObjects)
          if (has(id)) id,
        if (sign) _guestbookWiggleId,
        if (companion) campCompanionId,
      ],
      notice: {
        if (_hasNew(snap) && has('backpack')) 'backpack',
        if (snap.journey == null && has('map')) 'map',
        if (sign) _guestbookWiggleId,
        if (companion) campCompanionId,
      },
    );
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
    final trailOn = ref.watch(paintTrailProvider.select((s) => s.active));
    final dayCard = ref.watch(pendingDayCardProvider);
    void closeCard() => ref.read(pendingDayCardProvider.notifier).dismiss();

    return PopScope(
      // 하루 카드가 떠 있으면 뒤로 가기는 카드를 닫는다
      canPop: dayCard == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && dayCard != null) closeCard();
      },
      child: Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final stage = RestGeometry(camp, rules.rest, box.maxWidth, box.maxHeight);
        final ticket = snap.guestbookTicket;
        final shown = {
          for (final o in camp.objects)
            if (_artObjects.contains(o.id)) o.id,
          if (ticket != null) campGuestbookSignId,
          if (slots.cart != null) campCartId,
          if (slots.companion != null && camp.companion != null) campCompanionId,
        };
        final padding = MediaQuery.viewPaddingOf(context);
        return Stack(
          children: [
            Positioned.fill(
              child: RestGestures(
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
                  sceneBehind: [
                    if (firstSketch != null) _firstSign(stage, camp.firstSign),
                    for (final o in camp.objects)
                      if (shown.contains(o.id))
                        o.id == campCartId
                            ? _slotArt(stage, o, slots.cart!)
                            : _objectArt(
                                stage,
                                o,
                                hasNew: _hasNew(snap),
                                noJourney: snap.journey == null,
                              ),
                  ],
                  sceneBeside: [
                    if ((slots.companion, camp.companion) case (final slot?, final seat?))
                      _slotArt(stage, seat, slot),
                  ],
                  sceneAbove: [
                    for (final id in camp.hitStack(shown))
                      _hitBox(
                        context,
                        stage,
                        // hitStack은 테마에 자리가 있는 물건만 준다
                        camp.objectOrNull(id)!,
                        ticket,
                        id == campCompanionId
                            ? slots.companion
                            : id == campCartId
                            ? slots.cart
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(_hudInset),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: CornerButton(
                        icon: Icons.person,
                        label: '나의 정보',
                        radius: 18,
                        onPressed: () => _push(context, const ProfileScreen()),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: CornerButton(
                        icon: Icons.settings,
                        label: '설정',
                        radius: 18,
                        onPressed: () => _push(context, const SettingsScreen()),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        // 양쪽 모서리 버튼(56pt + 간격) 사이에 들어가게
                        padding: const EdgeInsets.symmetric(horizontal: 72),
                        child: IgnorePointer(
                          ignoring: !trailOn,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (trailOn)
                                _WalkingPill(onPressed: () => openWalking(Navigator.of(context)))
                              else
                                _StatusPill(_statusText(snap)),
                              if (scale != 1) ...[
                                const SizedBox(height: 6),
                                _ScaleBadge(distanceScaleBadge(scale)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 럭 보석: 프로필 바로 아래, 첫날도 '0'으로 늘 보인다
            Positioned(
              left: 14,
              top: padding.top + _hudInset + _hudButton + _gemGap,
              child: _LuckGem(luck: luck, slot: slots.gem),
            ),
            if (firstSketch != null)
              Positioned(
                left: _hudInset,
                right: _hudInset,
                bottom: math.max(padding.bottom, _hintBottom),
                child: IgnorePointer(
                  child: Center(
                    child: _WalkHint(key: const ValueKey('first-sketch-bubble'), sub: firstSketch),
                  ),
                ),
              ),
            if (dayCard != null)
              Positioned.fill(
                child: DayCardOverlay(
                  key: const ValueKey('rest-day-card'),
                  card: dayCard,
                  onClose: closeCard,
                ),
              ),
          ],
        );
      }),
      ),
    );
  }

  /// 상태 알약 글 (물감 길이 닫혀 있을 때): ‘쉬는 중 · 목적지까지 n km’
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

  /// 물건 그림 (장면 층, 정령 뒤). 누름 상자·이름표는 [_hitBox]가 맡는다
  Widget _objectArt(
    RestGeometry stage,
    CampObject o, {
    required bool hasNew,
    bool noJourney = false,
  }) {
    final k = stage.k;
    final sign = o.id == campGuestbookSignId;
    final art = o.art;
    return Positioned(
      left: stage.sx(o.box.x),
      top: stage.sy(o.box.y),
      width: o.artW * k,
      height: o.artH * k,
      child: IgnorePointer(
        child: PropWiggle(
          key: ValueKey('wiggle-${sign ? _guestbookWiggleId : o.id}'),
          wiggler: _wiggler,
          id: sign ? _guestbookWiggleId : o.id,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (art != null)
                Positioned.fill(
                  child: _CampArtImage(art, fallback: _objectBox(o.artW * k, _iconOf(o.id))),
                )
              else
                // TODO: 그림(ui_signpost)이 나오면 자리표시를 바꾼다
                _objectBox(o.artW * k, _iconOf(o.id)),
              if (o.id == 'backpack' && hasNew)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: NoticeDot(key: ValueKey('backpack-dot')),
                ),
              // 여정이 없으면 지도에 점 (출발하기 버튼이 없어서 목적지를 고르는 곳을 알린다, 캔버스 2-2)
              if (o.id == 'map' && noJourney)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: NoticeDot(key: ValueKey('map-dot')),
                ),
              if (sign)
                const Positioned(top: -4, right: -4, child: NoticeDot()),
            ],
          ),
        ),
      ),
    );
  }

  /// 다른 트랙이 끼운 물건의 그림 (수레·동행). 알림 점까지 여기서 붙인다.
  /// 흔들림은 [_wigglePool]이 고를 때만 (지금은 알림 점 있는 동행)
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: Builder(builder: slot.art)),
              if (slot.notice)
                Positioned(top: 4, right: 4, child: NoticeDot(key: ValueKey('${o.id}-dot'))),
            ],
          ),
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

  /// 누름 상자와 이름표 (장면 맨 위). 쌓는 순서가 곧 겹칠 때 누름 순서다 (테마의 hitOrder)
  Widget _hitBox(
    BuildContext context,
    RestGeometry stage,
    CampObject o,
    GuestbookTicket? ticket,
    RestObjectSlot? slot,
  ) {
    final k = stage.k;
    final sign = o.id == campGuestbookSignId;
    final label = sign ? '방명록' : slot?.label ?? o.label;
    return Positioned(
      left: stage.sx(o.box.x),
      top: stage.sy(o.box.y),
      width: o.box.w * k,
      height: o.box.h * k,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey(sign ? 'signpost' : 'camp-object-${o.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => slot != null
              ? slot.onTap(context)
              : _push(
                  context,
                  sign ? GuestbookWriteScreen(ticketId: ticket!.id) : _screenOf(o.id),
                ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: o.labelTop * k,
                child: _SceneLabel(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 그림이 없을 때의 몸통: 카드색 바탕, 잉크 테두리, 가운데 아이콘
  Widget _objectBox(double size, IconData icon) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.ink, width: InkLine.panel),
        ),
        child: Icon(icon, size: size * 0.5, color: Palette.ink),
      );

  Widget _screenOf(String id) => switch (id) {
        'map' => const MapScreen(),
        'backpack' => const AlbumScreen(),
        'note' => const NoteScreen(),
        _ => throw StateError('알 수 없는 쉼터 물건: $id'),
      };

  IconData _iconOf(String id) => switch (id) {
        'map' => Icons.map_outlined,
        'backpack' => Icons.backpack_outlined,
        campGuestbookSignId => Icons.edit_note_outlined,
        _ => Icons.menu_book_outlined,
      };
}

/// 물건 그림: 파일의 투명 여백을 뺀 상자가 이 위젯 크기에 맞는다. 화면에 필요한 크기로만 푼다
class _CampArtImage extends StatelessWidget {
  const _CampArtImage(this.art, {required this.fallback});

  final CampArt art;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, box) {
      final sx = box.maxWidth / art.bbox[2];
      final sy = box.maxHeight / art.bbox[3];
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -art.bbox[0] * sx,
            top: -art.bbox[1] * sy,
            width: art.canvas[0] * sx,
            height: art.canvas[1] * sy,
            child: Image.asset(
              art.file,
              fit: BoxFit.fill,
              cacheWidth: (art.canvas[0] * sx * ratio).ceil(),
              errorBuilder: (_, error, stack) => fallback,
            ),
          ),
        ],
      );
    });
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

/// 물감 길이 열려 있을 때 위 가운데 알약 (캔버스 2-2 11/16): [지금 물감 색 점] **걷는 중** · 물감 길 1.2km ›.
/// 높이 44pt 이상, 누르면 걷는 중. 거리는 이번 물감 길 숫자(걷는 중 화면과 같은 값, 이정표를 넘길 때마다 새로)
class _WalkingPill extends ConsumerWidget {
  const _WalkingPill({required this.onPressed});

  final VoidCallback onPressed;

  /// 물감 색 점 지름
  static const _dot = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 이정표 거리를 넘기거나 기록을 새로 받을 때마다 다시 읽는다 (몇 초마다). 점 = 그 물감 길이 지금 칠하는 색
    final current =
        ref.watch(paintTrailProvider.select((s) => (s.flushes, s.refreshes, s.paintColorId))).$3;
    final summary = ref.read(paintTrailProvider.notifier).summaryAt(ref.read(clockProvider)());
    final km = formatKmShort(summary?.distanceM ?? 0);
    final pc = ref.watch(rulesProvider).value?.paintColor;
    final dot = Color(pc == null ? Palette.terracotta.toARGB32() : pc.hexOf(current ?? pc.defaultId));
    final style = context.display(13);
    return Semantics(
      button: true,
      label: '걷는 중으로 돌아가기, 물감 길 $km',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('rest-walking-pill'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          decoration: BoxDecoration(
            color: Palette.card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.ink, width: InkLine.panel),
            boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: const ValueKey('rest-walking-dot'),
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.ink, width: 1),
                  ),
                ),
                const SizedBox(width: 6),
                Text('걷는 중', style: style.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('· 물감 길 $km', key: const ValueKey('rest-walking-km'),
                    style: style.copyWith(color: Palette.subInk)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 16, color: Palette.ink),
              ],
            ),
          ),
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
