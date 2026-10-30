import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/camp_theme.dart';
import '../../domain/rules.dart';
import '../../domain/sketch.dart';
import '../album/album_screen.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/name_tag.dart';
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

/// 쉼터 (홈, 루트 화면). 하늘 → 후경 → 캠프 → 캐릭터 → 물건·버튼 → 상태 알약.
/// 물건은 3~6초마다 하나씩 살짝 흔들린다 (알림 점이 있는 물건 우선, 연출 값은 prop_wiggle.dart)
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

/// 흔들림 id: 캠프 물건은 테마의 id(지도·배낭·노트), 방명록 표지판은 이것
const _guestbookSignId = 'guestbook';

class _RestScreenState extends ConsumerState<RestScreen> with SingleTickerProviderStateMixin {
  late final PropWiggler _wiggler;

  @override
  void initState() {
    super.initState();
    _wiggler = PropWiggler(vsync: this, spec: ref.read(restWiggleProvider), pool: _wigglePool);
  }

  @override
  void dispose() {
    _wiggler.dispose();
    super.dispose();
  }

  /// 아직 안 본 소품이나 그림이 있는가 (배낭의 알림 점)
  bool _hasNew(Snapshot snap) => snap.unseenProps > 0 || snap.unseenPaintings > 0;

  /// 흔들 수 있는 물건과 그 중 알림 점이 있는 물건 (화면에 서 있는 것만)
  ({List<String> all, Set<String> notice}) _wigglePool() {
    final camp = ref.read(campThemeProvider).value;
    final snap = ref.read(snapshotProvider).value;
    if (camp == null || snap == null || snap.position == null) {
      return (all: const [], notice: const {});
    }
    final sign = snap.guestbookTicket != null;
    return (
      all: [for (final o in camp.objects) o.id, if (sign) _guestbookSignId],
      notice: {if (_hasNew(snap)) 'backpack', if (sign) _guestbookSignId},
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
    // 테스트용 거리 배수가 켜져 있으면 알려 준다 (켜 둔 채 잊지 않게)
    final scale = kDebugMode ? ref.watch(debugDistanceScaleProvider) : 1.0;
    // 데이터가 올 때까지는 종이색 빈 화면
    if (rules == null || landmarks == null || camp == null || snap == null) {
      return const Scaffold(body: SizedBox.expand());
    }
    // 출발 동네를 아직 안 골랐으면 장면 대신 고르라는 카드만 (위치가 있어야 장면을 그린다)
    final position = snap.position;
    if (position == null) return _pickHome(context);
    final firstSketch = _firstSketchBubble(snap, rules);

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        return Stack(
          children: [
            SceneView(
              mode: SceneMode.rest,
              distanceM: 0,
              nowUtc: now,
              position: position,
              onSea: snap.onSea,
              rules: rules,
              landmarks: landmarks,
              camp: camp,
            ),
            for (final o in camp.objects)
              _campObject(
                context,
                box.biggest,
                o,
                hasNew: _hasNew(snap),
              ),
            // 방명록 표지판은 쓸 기회가 있을 때만 선다
            if (snap.guestbookTicket != null)
              _guestbookSign(context, box.biggest, camp.guestbookSign, snap.guestbookTicket!),
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
                        onPressed: () => _push(context, const ProfileScreen()),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: CornerButton(
                        icon: Icons.settings,
                        label: '설정',
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
                                      ? const MapScreen(walkAfterStart: true)
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

  /// 출발 동네를 고르라는 화면 (종이색 바탕 + 카드). 고르기는 시·군·구 목록이 생길 때까지 임시 화면
  Widget _pickHome(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Palette.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.ink, width: 2.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '출발 동네를 골라 주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GameButton(
                      label: '고르기',
                      onPressed: () => _push(context, const DebugScreen(title: '출발 동네 (임시)')),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topRight,
                child: CornerButton(
                  icon: Icons.settings,
                  label: '설정',
                  onPressed: () => _push(context, const SettingsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
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

  /// 방명록 표지판 (이정표 옆): 물건과 같은 모양의 자리표시에 이름표 "방명록".
  /// 테마의 footY에 표지판 아래 가장자리가 오고, 누르면 그 기회의 쓰기 화면으로 간다.
  /// TODO: 그림(ui_signpost)이 나오면 자리표시를 바꾼다
  Widget _guestbookSign(BuildContext context, Size screen, FootSpot spot, GuestbookTicket ticket) {
    const size = 56.0;
    const tagRoom = 40.0;
    return Positioned(
      left: spot.x * screen.width - size / 2 - tagRoom,
      top: spot.footY * screen.height - size,
      width: size + tagRoom * 2,
      child: GestureDetector(
        key: const ValueKey('signpost'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _push(context, GuestbookWriteScreen(ticketId: ticket.id)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PropWiggle(
              key: const ValueKey('wiggle-$_guestbookSignId'),
              wiggler: _wiggler,
              id: _guestbookSignId,
              child: _objectBox(size, Icons.edit_note_outlined),
            ),
            const SizedBox(height: 2),
            const NameTag('방명록'),
          ],
        ),
      ),
    );
  }

  /// 물건의 몸통: 카드색 바탕, 잉크 테두리, 가운데 아이콘
  Widget _objectBox(double size, IconData icon) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.ink, width: 2.5),
        ),
        child: Icon(icon, size: size * 0.5, color: Palette.ink),
      );

  /// 물건: 테마가 정한 비율 위치에 중심을 두고, 아래에 이름표를 붙인다.
  /// 배낭은 [hasNew]이면(아직 안 본 소품이나 그림이 있으면) 오른쪽 위에 알림 점이 붙는다
  Widget _campObject(BuildContext context, Size screen, CampObject o, {required bool hasNew}) {
    const tagRoom = 40.0;
    return Positioned(
      left: o.x * screen.width - o.size / 2 - tagRoom,
      top: o.y * screen.height - o.size / 2,
      width: o.size + tagRoom * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _push(context, _screenOf(o.id)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PropWiggle(
              key: ValueKey('wiggle-${o.id}'),
              wiggler: _wiggler,
              id: o.id,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _objectBox(o.size, _iconOf(o.id)),
                  if (o.id == 'backpack' && hasNew)
                    const Positioned(
                      top: -4,
                      right: -4,
                      child: NoticeDot(key: ValueKey('backpack-dot')),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            NameTag(o.label),
          ],
        ),
      ),
    );
  }

  Widget _screenOf(String id) => switch (id) {
        'map' => const MapScreen(),
        'backpack' => const AlbumScreen(),
        'note' => const NoteScreen(),
        _ => throw StateError('알 수 없는 쉼터 물건: $id'),
      };

  IconData _iconOf(String id) => switch (id) {
        'map' => Icons.map_outlined,
        'backpack' => Icons.backpack_outlined,
        _ => Icons.menu_book_outlined,
      };
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
        border: Border.all(color: Palette.ink, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Palette.ink),
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
        border: Border.all(color: Palette.ink, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.paper),
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
            border: Border.all(color: Palette.ink, width: 2),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Palette.ink),
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
