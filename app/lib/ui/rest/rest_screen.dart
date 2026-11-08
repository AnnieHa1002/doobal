import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shop_providers.dart';
import '../../app/sync_service.dart';
import '../../domain/camp_theme.dart';
import '../../domain/rest_camera.dart';
import '../../domain/rules.dart';
import '../../domain/sketch.dart';
import '../album/album_screen.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/ink_press.dart';
import '../common/notice_dot.dart';
import '../common/palette.dart';
import '../debug/debug_screen.dart';
import '../guestbook/guestbook_write_screen.dart';
import '../map/map_screen.dart';
import '../note/note_screen.dart';
import '../profile/profile_screen.dart';
import '../scene/scene_view.dart';
import '../settings/settings_screen.dart';
import '../walking/walking_screen.dart';
import 'prop_wiggle.dart';
import 'rest_gestures.dart';
import 'rest_slots.dart';

/// 쉼터 (홈, 루트 화면). 장면(하늘 → 후경 → 캠프 뒤 → 물건 → 정령 → 동행 → 캠프 앞 → 불꽃)은 화면 폭의
/// 1.5배이고 좌우로 민다. 프로필·설정·상태 알약·출발하기는 고정이다 (캔버스 2-2).
/// 물건은 3~6초마다 하나씩 살짝 흔들린다 (알림 점이 있는 물건 우선, 연출 값은 prop_wiggle.dart).
/// 불 옆 동행은 알림 점(안 읽은 장)이 있을 때만 흔들림에 든다 (평소에는 캔버스대로 둥실, 그림 쪽 몫)
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
const _departBottom = 20.0;

/// 그림으로 서는 물건 (수레·표지판·동행은 따로)
const _artObjects = {'map', 'backpack', 'note'};

class _RestScreenState extends ConsumerState<RestScreen> with SingleTickerProviderStateMixin {
  late final PropWiggler _wiggler;
  final _camera = ValueNotifier(const RestCamera());

  @override
  void initState() {
    super.initState();
    _wiggler = PropWiggler(vsync: this, spec: ref.read(restWiggleProvider), pool: _wigglePool);
  }

  @override
  void dispose() {
    _wiggler.dispose();
    _camera.dispose();
    super.dispose();
  }

  /// 아직 안 본 소품·그림·도장이 있는가 (배낭의 알림 점)
  bool _hasNew(Snapshot snap) =>
      snap.unseenProps > 0 || snap.unseenPaintings > 0 || snap.unseenBadges > 0;

  /// 흔들 수 있는 물건과 그 중 알림 점이 있는 물건 (화면에 서 있는 것만)
  ({List<String> all, Set<String> notice}) _wigglePool() {
    final camp = ref.read(campThemeProvider).value;
    final snap = ref.read(snapshotProvider).value;
    if (camp == null || snap == null || snap.position == null) {
      return (all: const [], notice: const {});
    }
    final sign = snap.guestbookTicket != null;
    final companion = ref.read(restSlotsProvider).companion?.notice ?? false;
    return (
      all: [..._artObjects, if (sign) _guestbookWiggleId, if (companion) campCompanionId],
      notice: {
        if (_hasNew(snap)) 'backpack',
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
    final now = ref.watch(minuteClockProvider).value ?? ref.watch(clockProvider)();
    final spirit = ref.watch(spiritLookProvider);
    final slots = ref.watch(restSlotsProvider);
    final luck = ref.watch(coinBalanceProvider).value ?? 0;
    // 테스트용 거리 배수가 켜져 있으면 알려 준다 (켜 둔 채 잊지 않게)
    final scale = kDebugMode ? ref.watch(debugDistanceScaleProvider) : 1.0;
    // 데이터가 올 때까지는 종이색 빈 화면
    if (rules == null || landmarks == null || camp == null || snap == null) {
      return const Scaffold(body: SizedBox.expand());
    }
    // 시작 관문이 출발 동네를 먼저 고르게 하므로 위치는 늘 있다 (없으면 빈 화면)
    final position = snap.position;
    if (position == null) return const Scaffold(body: SizedBox.expand());
    final firstSketch = _firstSketchBubble(snap, rules);

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final stage = RestGeometry(camp, rules.rest, box.maxWidth, box.maxHeight);
        final ticket = snap.guestbookTicket;
        final shown = {
          for (final o in camp.objects)
            if (_artObjects.contains(o.id)) o.id,
          if (ticket != null) campGuestbookSignId,
          if (slots.cart != null) campCartId,
          if (slots.companion != null) campCompanionId,
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
                  camera: _camera,
                  sceneBehind: [
                    if (firstSketch != null) _firstSign(stage, camp.firstSign),
                    for (final o in camp.objects)
                      if (shown.contains(o.id))
                        o.id == campCartId
                            ? _slotArt(stage, o, slots.cart!)
                            : _objectArt(stage, o, hasNew: _hasNew(snap)),
                  ],
                  sceneBeside: [
                    if (slots.companion case final slot?) _slotArt(stage, camp.companion, slot),
                  ],
                  sceneAbove: [
                    for (final id in camp.hitStack(shown))
                      _hitBox(
                        context,
                        stage,
                        id == campCompanionId ? camp.companion : camp.object(id),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
            Positioned(
              right: _hudInset,
              bottom: math.max(padding.bottom, _departBottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (firstSketch != null) ...[
                    IgnorePointer(
                      child: _SpeechBubble(key: const ValueKey('first-sketch-bubble'), firstSketch),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _DepartButton(
                    notice: firstSketch != null,
                    onPressed: () => _push(
                      context,
                      snap.journey == null ? const MapScreen() : const WalkingScreen(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  String _statusText(Snapshot snap) {
    final j = snap.journey;
    if (j == null) return '쉬는 중 · 목적지를 골라 보세요';
    // 첫 여정은 이름이 있는 목적지가 아니라 내 동네 스케치
    final dest = j.dest.id == sketchId ? sketchName : '목적지';
    return '쉬는 중 · $dest까지 ${formatKm(j.progress.remainingKm)}';
  }

  /// 첫 여정 '내 동네 스케치'를 아직 한 걸음도 안 걸었을 때 출발하기 위에 띄우는 말풍선 글.
  /// 그 밖에는 null (걷기 시작해서 진행이 생기면 말풍선·첫날 이정표·출발하기의 알림 점이 함께 사라진다).
  String? _firstSketchBubble(Snapshot snap, Rules rules) {
    final j = snap.journey;
    final home = snap.home;
    if (j == null || home == null || j.dest.id != sketchId || j.progress.progressKm > 0) {
      return null;
    }
    final km = j.progress.remainingKm;
    return '첫 그림을 그리러 가요. ${home.name}에서 ${formatKm(km)} · '
        '약 ${formatInt(sketchSteps(km, rules))}보';
  }

  /// 물건 그림 (장면 층, 정령 뒤). 누름 상자·이름표는 [_hitBox]가 맡는다
  Widget _objectArt(RestGeometry stage, CampObject o, {required bool hasNew}) {
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

/// 출발하기: 테라코타 둥근 네모에 깃발과 글 (캔버스 2-2). 깃발 그림(ui_obj_flag_start_v01)이 오기 전에는 선으로 그린다
class _DepartButton extends StatelessWidget {
  const _DepartButton({required this.notice, required this.onPressed});

  final bool notice;
  final VoidCallback onPressed;

  static const _size = 72.0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '출발하기',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkPress(
            onPressed: onPressed,
            fill: Palette.terracotta,
            height: _size,
            width: _size,
            radius: 22,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(size: const Size(34, 28), painter: _FlagPainter()),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('출발하기', maxLines: 1, style: context.display(13, color: Palette.card)),
                ),
              ],
            ),
          ),
          if (notice)
            const Positioned(
              top: -4,
              right: -4,
              child: NoticeDot(key: ValueKey('depart-dot')),
            ),
        ],
      ),
    );
  }
}

/// 깃발: 깃대 하나와 꼬리가 갈라진 천 (캔버스 그대로의 선)
class _FlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(9, 26)
        ..lineTo(9, 3)
        ..moveTo(9, 4)
        ..lineTo(27, 4)
        ..lineTo(23, 10)
        ..lineTo(27, 16)
        ..lineTo(9, 16),
      Paint()
        ..color = Palette.card
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FlagPainter old) => false;
}

/// 위쪽 가운데 상태 알약 (카드색 90%)
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
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

/// 출발하기 위의 말풍선: 카드색, 잉크 2px 테두리, 아래 오른쪽(버튼 쪽)으로 작은 꼬리
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ink, width: InkLine.panel),
          ),
          child: Text(
            text,
            style: context.display(14),
          ),
        ),
        // 꼬리는 말풍선 아래 테두리를 살짝 덮어 이어 붙인다
        Padding(
          padding: const EdgeInsets.only(right: 28),
          child: Transform.translate(
            offset: const Offset(0, -2),
            child: CustomPaint(size: const Size(16, 9), painter: _TailPainter()),
          ),
        ),
      ],
    );
  }
}

/// 아래로 뾰족한 삼각형 꼬리: 카드색으로 채우고 윗변을 뺀 두 변만 잉크선
class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(Path.from(path)..close(), Paint()..color = Palette.card);
    canvas.drawPath(
      path,
      Paint()
        ..color = Palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}
