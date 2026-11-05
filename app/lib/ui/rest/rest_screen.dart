import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/camp_theme.dart';
import '../../domain/rest_camera.dart';
import '../../domain/rules.dart';
import '../../domain/sketch.dart';
import '../album/album_screen.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
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

/// 쉼터 (홈, 루트 화면). 장면(하늘 → 후경 → 캠프 뒤 → 물건 → 정령 → 동행 → 캠프 앞 → 불꽃)은 화면 폭의
/// 1.5배이고 좌우로 민다. 프로필·설정·상태 알약·출발하기는 고정이다 (캔버스 2-2).
/// 물건은 3~6초마다 하나씩 살짝 흔들린다 (알림 점이 있는 물건 우선, 연출 값은 prop_wiggle.dart)
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

/// 흔들림 id: 캠프 물건은 테마의 id(지도·배낭·노트), 방명록 표지판은 이것
const _guestbookWiggleId = 'guestbook';

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
    return (
      all: [..._artObjects, if (sign) _guestbookWiggleId],
      notice: {if (_hasNew(snap)) 'backpack', if (sign) _guestbookWiggleId},
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
        };
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
                    for (final o in camp.objects)
                      if (shown.contains(o.id)) _objectArt(stage, o, hasNew: _hasNew(snap)),
                  ],
                  sceneAbove: [
                    for (final id in camp.hitStack(shown))
                      _hitBox(context, stage, camp.object(id), ticket),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (firstSketch != null) ...[
                            _SpeechBubble(key: const ValueKey('first-sketch-bubble'), firstSketch),
                            const SizedBox(height: 6),
                          ],
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CornerButton(
                                icon: Icons.directions_walk,
                                label: '출발하기',
                                tag: '출발하기',
                                size: 72,
                                primary: true,
                                onPressed: () => _push(
                                  context,
                                  snap.journey == null
                                      ? const MapScreen()
                                      : const WalkingScreen(),
                                ),
                              ),
                              if (firstSketch != null)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: NoticeDot(key: ValueKey('depart-dot')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
  /// 그 밖에는 null (걷기 시작해서 진행이 생기면 말풍선과 출발하기의 알림 점이 함께 사라진다).
  /// TODO: 첫날 이정표 "첫 스케치 →"는 쉼터에 이정표 물건이 생기면 붙인다 (UI 명세 2장)
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

  /// 누름 상자와 이름표 (장면 맨 위). 쌓는 순서가 곧 겹칠 때 누름 순서다 (테마의 hitOrder)
  Widget _hitBox(BuildContext context, RestGeometry stage, CampObject o, GuestbookTicket? ticket) {
    final k = stage.k;
    final sign = o.id == campGuestbookSignId;
    return Positioned(
      left: stage.sx(o.box.x),
      top: stage.sy(o.box.y),
      width: o.box.w * k,
      height: o.box.h * k,
      child: Semantics(
        button: true,
        label: o.label,
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey(sign ? 'signpost' : 'camp-object-${o.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _push(
            context,
            sign ? GuestbookWriteScreen(ticketId: ticket!.id) : _screenOf(o.id),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: o.labelTop * k,
                child: _SceneLabel(sign ? '방명록' : o.label),
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
