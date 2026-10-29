import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/camp_theme.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/name_tag.dart';
import '../common/palette.dart';
import '../placeholder/placeholder_screens.dart';
import '../scene/scene_view.dart';
import '../walking/walking_screen.dart';

/// 쉼터 (홈, 루트 화면). 하늘 → 후경 → 캠프 → 캐릭터 → 물건·버튼 → 상태 알약
class RestScreen extends ConsumerWidget {
  const RestScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider).value;
    final landmarks = ref.watch(landmarksProvider).value;
    final camp = ref.watch(campThemeProvider).value;
    final snap = ref.watch(snapshotProvider).value;
    final now = ref.watch(minuteClockProvider).value ?? ref.watch(clockProvider)();
    // 데이터가 올 때까지는 종이색 빈 화면
    if (rules == null || landmarks == null || camp == null || snap == null) {
      return const Scaffold(body: SizedBox.expand());
    }

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        return Stack(
          children: [
            SceneView(
              mode: SceneMode.rest,
              distanceM: 0,
              nowUtc: now,
              position: snap.position,
              onSea: snap.onSea,
              rules: rules,
              landmarks: landmarks,
              camp: camp,
            ),
            for (final o in camp.objects)
              _campObject(context, box.biggest, o),
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
                        child: _StatusPill(_statusText(snap)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: CornerButton(
                        icon: Icons.directions_walk,
                        label: '출발하기',
                        tag: '출발하기',
                        size: 72,
                        primary: true,
                        onPressed: () => _push(
                          context,
                          snap.journey == null ? const MapScreen() : const WalkingScreen(),
                        ),
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
    return '쉬는 중 · 목적지까지 ${formatKm(j.progress.remainingKm)}';
  }

  /// 물건: 테마가 정한 비율 위치에 중심을 두고, 아래에 이름표를 붙인다
  Widget _campObject(BuildContext context, Size screen, CampObject o) {
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
            Container(
              width: o.size,
              height: o.size,
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.ink, width: 2.5),
              ),
              child: Icon(_iconOf(o.id), size: o.size * 0.5, color: Palette.ink),
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
