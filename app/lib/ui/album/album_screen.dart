import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/landmark.dart';
import '../../domain/sketch.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/palette.dart';
import 'album_widgets.dart';
import 'painting_detail_screen.dart';

/// 그림 탭에 얻은 그림이 첫 그림뿐이거나 없을 때 격자 아래에 붙이는 한 줄
const albumFirstOnlyHint = '걸어서 명소에 닿으면 여기에 걸려요';

/// 소품 탭에 얻은 소품이 하나도 없을 때의 한 줄. 가안
const albumNoPropsLine = '아직 모은 소품이 없어요';

/// 화집: 벽에 건 액자 4칸, 그림 탭(얻은 그림만: 첫 그림 + 얻은 명소)과 소품 탭(얻은 소품만).
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
                  Text(
                    '화집',
                    style: context.display(22),
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
                  Text(
                    '바꿀 액자를 누르세요',
                    textAlign: TextAlign.center,
                    style: context.display(14, color: Palette.terracotta),
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
        if (_tab == 0) ..._paintingSlivers(owned, landmarks) else _propSliver(),
      ],
    );
  }

  /// 그림 탭: 권역 칩과 얻은 그림 3열 (첫 그림이 맨 앞, 명소는 landmarks.json 순서).
  /// 못 얻은 그림은 그리지 않는다. 칩은 `전체` + 얻은 그림이 있는 권역만이고,
  /// 첫 그림은 권역이 없어서 칩이 `전체`일 때만 나온다
  List<Widget> _paintingSlivers(Map<String, OwnedPaintingView> owned, List<Landmark> landmarks) {
    final mine = [for (final l in landmarks) if (owned.containsKey(l.id)) l];
    final regions = {
      for (final r in regionLabels.entries)
        if (mine.any((l) => l.region == r.key)) r.key: r.value,
    };
    final region = regions.containsKey(_region) ? _region : null;
    final cells = [
      if (region == null && owned.containsKey(sketchId)) owned[sketchId]!,
      for (final l in mine)
        if (region == null || l.region == region) owned[l.id]!,
    ];
    // 얻은 명소 그림이 아직 없으면 (첫 그림뿐이거나 아무것도 없으면) 격자 아래에 안내를 붙인다
    final hint = mine.isEmpty;
    void openDetail(String id) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => PaintingDetailScreen(landmarkId: id)));
    return [
      SliverToBoxAdapter(
        child: RegionFilterChips(
          labels: regions,
          region: region,
          onSelect: (r) => setState(() => _region = r),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, hint ? 12 : 24),
        sliver: SliverGrid.builder(
          gridDelegate: paintingGridDelegate(context),
          itemCount: cells.length,
          itemBuilder: (context, i) {
            final p = cells[i];
            final id = p.landmark.id;
            return ownedPaintingCell(
              p,
              key: ValueKey('cell-$id'),
              isNew: _newIds.contains(id),
              onTap: () => openDetail(id),
            );
          },
        ),
      ),
      if (hint)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              albumFirstOnlyHint,
              key: ValueKey('album-first-only-hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Palette.subInk),
            ),
          ),
        ),
    ];
  }

  /// 소품 탭: 얻은 소품만 칸별로 (모자·옷·손·가방·신발·어깨 친구). 얻은 소품이 없는 칸은 감추고,
  /// 하나도 없으면 한 줄 안내. 얻는 방법은 꾸미기의 잠긴 칸에서 본다
  Widget _propSliver() {
    final props = ref.watch(propsProvider).value;
    final ownedProps = ref.watch(ownedPropIdsProvider).value;
    // 읽어 오는 동안은 비워 둔다 (안내 글이 잠깐 비치지 않게)
    if (props == null || ownedProps == null) return const SliverToBoxAdapter();

    final children = <Widget>[];
    for (final slot in propSlotLabels.entries) {
      final mine = [
        for (final p in props)
          if (p.slot == slot.key && ownedProps.contains(p.id)) p,
      ];
      if (mine.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          slot.value,
          style: context.display(16),
        ),
      ));
      for (final p in mine) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PropRow(key: ValueKey('prop-${p.id}'), prop: p),
        ));
      }
    }
    if (children.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          albumNoPropsLine,
          key: ValueKey('album-no-props'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Palette.subInk),
        ),
      ));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }
}
