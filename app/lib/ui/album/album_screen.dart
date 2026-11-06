import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/badge.dart' as stamp;
import '../../domain/landmark.dart';
import '../../domain/sketch.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/palette.dart';
import 'album_diary.dart';
import 'album_stamps.dart';
import 'album_widgets.dart';
import 'painting_detail_screen.dart';

/// 그림 탭에 얻은 그림이 첫 그림뿐이거나 없을 때 격자 아래에 붙이는 한 줄
const albumFirstOnlyHint = '걸어서 명소에 닿으면 여기에 걸려요';

/// 소품 탭에 얻은 소품이 하나도 없을 때의 한 줄. 가안
const albumNoPropsLine = '아직 모은 소품이 없어요';

/// 화집: 그림 탭(얻은 그림만: 첫 그림 + 얻은 명소)과 소품 탭(얻은 소품만). 위 배경·벽 액자는 없다 (11/4).
/// 그림 탭은 ‘일기 · 전체’ 두 보기이고 기본은 일기다 (캔버스 6-1, 16장 11/2)
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  var _tab = 0;

  /// 그림 탭 보기: 일기(기본)인가, 전체(3열 격자)인가
  var _diary = true;

  /// 그림 탭의 권역 거르기. null이면 전체
  String? _region;

  /// 이번에 연 화집에서 새 그림으로 보이는 명소 id (열 때 한 번 정하고, 나갈 때까지 그대로)
  var _newIds = const <String>{};

  @override
  void initState() {
    super.initState();
    _seePaintings();
  }

  void _openTab(int i) {
    setState(() => _tab = i);
    if (i == 1) _seeProps();
    if (i == 2) _seeStamps();
  }

  /// 도장 탭을 열면 새 도장 표시(배낭의 점)를 지운다
  Future<void> _seeStamps() async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.markBadgesSeen();
    if (mounted) ref.invalidate(snapshotProvider);
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
    final landmarks = ref.watch(landmarksProvider).value;
    final ready = paintings != null && landmarks != null;

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
            Expanded(child: ready ? _content(paintings, landmarks) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _content(List<OwnedPaintingView> paintings, List<Landmark> landmarks) {
    final owned = {for (final p in paintings) p.landmark.id: p};
    final snap = ref.watch(snapshotProvider).value;
    final propsDot = (snap?.unseenProps ?? 0) > 0;
    // 도장 탭 안에 있으면 그 자리에서 바로 본 것이라 점을 달지 않는다
    final stampsDot = (snap?.unseenBadges ?? 0) > 0 && _tab != 2;
    final badges = ref.watch(badgeCatalogProvider).value?.badges;
    final ownedBadges = ref.watch(ownedBadgesProvider).value;
    final stampsLabel = badges == null || ownedBadges == null
        ? '도장'
        : '도장 ${badges.where((b) => ownedBadges.containsKey(b.id)).length} / ${badges.length}';
    const gutter = EdgeInsets.symmetric(horizontal: 16);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AlbumTabs(
                  selected: _tab,
                  onSelect: _openTab,
                  propsDot: propsDot,
                  stampsDot: stampsDot,
                  stampsLabel: stampsLabel,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (_tab == 0) ...[
          SliverToBoxAdapter(
            child: _ViewSwitch(diary: _diary, onSelect: (d) => setState(() => _diary = d)),
          ),
          if (_diary) ..._diarySlivers() else ..._paintingSlivers(owned, landmarks),
        ] else if (_tab == 1)
          _propSliver()
        else
          _stampSliver(),
      ],
    );
  }

  /// 도장 탭: 묶음별 격자. 받은 도장만 진하게, 못 받은 도장은 흐린 빈 고리 (이름·진행도 없음)
  Widget _stampSliver() {
    final badges = ref.watch(badgeCatalogProvider).value?.badges;
    final owned = ref.watch(ownedBadgesProvider).value;
    // 읽어 오는 동안은 비워 둔다
    if (badges == null || owned == null) return const SliverToBoxAdapter();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverToBoxAdapter(
        child: StampSections(sections: stamp.badgeSections(badges), owned: owned),
      ),
    );
  }

  void _openDetail(String id) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => PaintingDetailScreen(landmarkId: id)));

  /// 그림 탭의 일기: 도착마다 한 항목, 최근이 위 (읽는 동안은 비워 둔다)
  List<Widget> _diarySlivers() {
    final entries = ref.watch(diaryProvider).value;
    if (entries == null) return const [SliverToBoxAdapter()];
    return diarySlivers(context, entries, onOpen: _openDetail);
  }

  /// 그림 탭의 전체: 권역 칩과 얻은 그림 3열 (첫 그림이 맨 앞, 명소는 landmarks.json 순서).
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
              onTap: () => _openDetail(id),
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

  /// 소품 탭: 얻은 소품만 칸별로 (모자·얼굴 소품·옷·신발·손·가방·미니 친구·둥실·효과). 얻은 소품이 없는 칸은 감추고,
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
        padding: const EdgeInsets.only(top: 10),
        child: PropSlotCard(name: slot.value, props: mine),
      ));
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

/// 그림 탭 아래 작은 밑줄 전환 `일기 · 전체`. 고른 쪽은 표시 글꼴 + 잉크 밑줄
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.diary, required this.onSelect});

  final bool diary;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool isDiary) {
      final on = diary == isDiary;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          key: ValueKey(isDiary ? 'view-diary' : 'view-all'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(isDiary),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Center(
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: on ? Palette.ink : Colors.transparent,
                      width: InkLine.panel,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: on ? context.display(14) : AppText.label.copyWith(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          option('일기', true),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('·', style: TextStyle(fontSize: 14, color: Palette.subInk)),
          ),
          option('전체', false),
        ],
      ),
    );
  }
}
