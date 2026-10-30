import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/landmark.dart';
import '../../domain/prop.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/palette.dart';
import 'album_widgets.dart';
import 'painting_detail_screen.dart';
import 'prop_text.dart';

/// 화집: 벽에 건 액자 4칸, 그림 탭(명소 101곳 칸)과 소품 탭.
/// [hangLandmarkId]가 있으면 벽이 가득 찬 채 도착해서 연 것이라, 바꿀 액자를 눌러 거는 모드로 시작한다
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key, this.hangLandmarkId});

  final String? hangLandmarkId;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  /// 바꿀 칸을 기다리는 그림 (거는 모드). 칸을 누르면 비운다
  String? _hangId;
  var _tab = 0;

  /// 그림 탭의 권역 거르기. null이면 전체
  String? _region;

  /// 이번에 연 화집에서 새 그림으로 보이는 명소 id (열 때 한 번 정하고, 나갈 때까지 그대로)
  var _newIds = const <String>{};

  @override
  void initState() {
    super.initState();
    _hangId = widget.hangLandmarkId;
    _seePaintings();
  }

  Future<void> _setWall(int slot, String landmarkId) async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.setWall(slot, landmarkId);
    if (mounted) ref.invalidate(wallProvider);
  }

  Future<void> _onSlotTap(int slot) async {
    final id = _hangId;
    if (id == null) return;
    await _setWall(slot, id);
    if (mounted) setState(() => _hangId = null);
  }

  /// 칸을 길게 누르면 얻은 그림 중에서 골라 건다 (얻은 그림이 없으면 아무 일도 없다)
  Future<void> _onSlotLongPress(int slot, List<OwnedPaintingView> paintings) async {
    if (paintings.isEmpty) return;
    final id = await showPaintingPicker(context, paintings);
    if (id == null || !mounted) return;
    await _setWall(slot, id);
  }

  void _openTab(int i) {
    setState(() => _tab = i);
    if (i == 1) _seeProps();
  }

  /// 화집을 열면 안 본 그림을 이번 방문의 새 그림 칸으로 담고, 새 그림 표시(배낭의 점)를 지운다
  Future<void> _seePaintings() async {
    final svc = await ref.read(syncServiceProvider.future);
    final ids = await svc.unseenPaintingIds();
    if (ids.isEmpty) return;
    if (mounted) setState(() => _newIds = ids.toSet());
    await svc.markPaintingsSeen();
    if (mounted) ref.invalidate(snapshotProvider);
  }

  /// 소품 탭을 열면 새 소품 표시(배낭의 점)를 지운다
  Future<void> _seeProps() async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.markPropsSeen();
    if (mounted) ref.invalidate(snapshotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final paintings = ref.watch(paintingsProvider).value;
    final wall = ref.watch(wallProvider).value;
    final landmarks = ref.watch(landmarksProvider).value;
    final ready = paintings != null && wall != null && landmarks != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  CornerButton(
                    icon: Icons.arrow_back,
                    label: '뒤로',
                    size: 44,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '화집',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ink),
                  ),
                ],
              ),
            ),
            Expanded(child: ready ? _content(paintings, wall, landmarks) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _content(List<OwnedPaintingView> paintings, List<String?> wall, List<Landmark> landmarks) {
    final owned = {for (final p in paintings) p.landmark.id: p};
    final propsDot = (ref.watch(snapshotProvider).value?.unseenProps ?? 0) > 0;
    const gutter = EdgeInsets.symmetric(horizontal: 16);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hangId != null) ...[
                  const Text(
                    '바꿀 액자를 누르세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Palette.terracotta,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                WallRow(
                  wall: wall,
                  owned: owned,
                  replacing: _hangId != null,
                  onTap: _onSlotTap,
                  onLongPress: (slot) => _onSlotLongPress(slot, paintings),
                ),
                const SizedBox(height: 16),
                AlbumTabs(selected: _tab, onSelect: _openTab, propsDot: propsDot),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (_tab == 0)
          ..._paintingSlivers(owned, landmarks)
        else
          _propSliver(owned.keys, landmarks),
      ],
    );
  }

  /// 그림 탭: 권역 칩과 명소 칸 3열 (landmarks.json 순서)
  List<Widget> _paintingSlivers(Map<String, OwnedPaintingView> owned, List<Landmark> landmarks) {
    final shown = [for (final l in landmarks) if (_region == null || l.region == _region) l];
    return [
      SliverToBoxAdapter(
        child: RegionFilterChips(
          labels: regionLabels,
          region: _region,
          onSelect: (r) => setState(() => _region = r),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final l = shown[i];
            final p = owned[l.id];
            return PaintingCell(
              key: ValueKey('cell-${l.id}'),
              landmark: l,
              owned: p,
              isNew: _newIds.contains(l.id),
              onTap: p == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PaintingDetailScreen(landmarkId: l.id),
                      )),
            );
          },
        ),
      ),
    ];
  }

  /// 소품 탭: 소품 27개를 칸별로 (모자·옷·손·가방·신발·어깨 친구)
  Widget _propSliver(Iterable<String> visitedIds, List<Landmark> landmarks) {
    final props = ref.watch(propsProvider).value ?? const <Prop>[];
    final ownedProps = ref.watch(ownedPropIdsProvider).value ?? const <String>{};
    final snap = ref.watch(snapshotProvider).value;
    final progress = regionProgress(visitedIds.toSet(), landmarks);

    final children = <Widget>[];
    for (final slot in propSlotLabels.entries) {
      final inSlot = [for (final p in props) if (p.slot == slot.key) p];
      if (inSlot.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          slot.value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Palette.ink),
        ),
      ));
      for (final p in inSlot) {
        final has = ownedProps.contains(p.id);
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PropRow(
            key: ValueKey('prop-${p.id}'),
            prop: p,
            owned: has,
            howTo: has
                ? null
                : propHowTo(
                    p,
                    totalKm: snap?.totalKm ?? 0,
                    totalSteps: snap?.totalSteps ?? 0,
                    progress: progress,
                  ),
          ),
        ));
      }
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }
}
