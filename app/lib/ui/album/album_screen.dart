import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paint_providers.dart';
import '../../app/paint_trail_controller.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/album_wear.dart';
import '../../domain/color_props.dart';
import '../../domain/landmark.dart';
import '../../domain/look.dart';
import '../../domain/map_album_rules.dart';
import '../../domain/motion_rules.dart';
import '../../domain/prop.dart';
import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
import '../../domain/sketch.dart';
import '../../domain/spirit_look.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/motion.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../decorate/decorate_screen.dart';
import '../scene/spirit_character.dart';
import 'album_diary.dart';
import 'album_flip.dart';
import 'album_paints.dart';
import 'album_widgets.dart';
import 'painting_viewer.dart';

/// 그림 탭에 얻은 그림이 첫 그림뿐이거나 없을 때 격자 아래에 붙이는 한 줄
const albumFirstOnlyHint = '걸어서 명소에 닿으면 여기에 걸려요';

/// 소품 탭에 얻은 소품이 하나도 없을 때의 한 줄. 가안
const albumNoPropsLine = '아직 모은 소품이 없어요';

/// 소품 탭 머리 카드 글 (캔버스 6-1)
const albumWearTitle = '누르면 바로 입어요';

/// 소품 탭 아래 꾸미기 링크 (16장 11/19 ③)
const albumDecorateLink = '꾸미기에서 색·얼굴 바꾸기';

/// 화집 = 배낭 (16장 11/19 ③·11/20, 캔버스 6-1): 탭은 config album.tabs 차례로 그림·소품·물감, 도장은 나 탭.
/// 가진 것만 보인다(album.ownedOnly): 그림 탭은 얻은 그림(첫 그림 + 얻은 명소), 소품 탭은 가진 소품, 물감 탭은 가진 물감.
/// 소품 탭은 누르면 바로 입고 다시 누르면 벗는다(옷은 안 벗음, album.propsTab): 위 정령이 바로 바뀌고 잠깐 기뻐하며 한 줄 토스트.
/// 위 배경·벽 액자는 없다 (11/4). 그림 탭은 ‘일기 · 전체’ 두 보기이고 기본은 일기다 (캔버스 6-1, 16장 11/2).
/// 연출 ⑤(config ui.motion.albumFlip): 일기·전체를 바꾸면 아래 내용이 오른쪽 끝을 축으로 종이처럼 넘어가고
/// (앞 절반은 전 보기, 뒤 절반은 새 보기), 일기에서 달 머리줄이 화면에 들어오면 그 줄이 넘어간다. 움직임 줄이기면 바로 바뀜
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> with SingleTickerProviderStateMixin {
  /// 지금 탭 id. null이면 config album.tabs의 첫 탭
  String? _tab;

  /// 바로 입기로 위 정령에 보낸 기쁨 신호 (입을 때마다 새 값)
  SpiritCue? _joy;
  var _wearing = false;

  /// 그림 탭 보기: 일기(기본)인가, 전체(3열 격자)인가 (바꾸기 단추가 보이는 값)
  var _diary = true;

  /// 지금 그리는 보기. 넘기는 동안 앞 절반은 전 보기라 [_diary]와 다를 수 있다
  var _diaryShown = true;

  /// 일기·전체 넘김 시계 (연출 ⑤). 넘기지 않을 때는 끝(1)
  late final AnimationController _flip = motionController(this, 0)..addListener(_onFlip);

  /// 그림 탭의 권역 거르기. null이면 전체
  String? _region;

  /// 이번에 연 화집에서 새 그림으로 보이는 명소 id (열 때 한 번 정하고, 나갈 때까지 그대로)
  var _newIds = const <String>{};

  @override
  void initState() {
    super.initState();
    _seePaintings();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  AlbumFlipMotion? get _flipMotion => ref.read(rulesProvider).value?.motion.albumFlip;

  /// 일기·전체 바꾸기. 넘기는 중에 또 누르면 하던 넘김은 끝으로 건너뛰고 지금 보기에서 다시 넘긴다
  void _switchView(bool diary) {
    if (diary == _diary) return;
    final m = _flipMotion;
    final flip = m != null && m.on.contains(AlbumFlipOn.diaryAllToggle) && !motionReduced(context);
    setState(() {
      _diaryShown = _diary;
      _diary = diary;
      if (!flip) _diaryShown = diary;
    });
    if (!flip) return;
    _flip
      ..duration = motionDuration(m.sec)
      ..forward(from: 0);
  }

  /// 넘김이 가운데(가로 0)를 지나면 새 보기를 그린다 (끝에 닿아도)
  void _onFlip() {
    final m = _flipMotion;
    if (_diaryShown == _diary) return;
    if (m == null || motionTime(_flip, m.sec) >= m.swapSec) setState(() => _diaryShown = _diary);
  }

  void _openTab(String id) {
    setState(() {
      _tab = id;
      // 소품 탭 정령은 다시 만들 때 남은 신호를 다시 받으므로 지운다 (돌아와도 다시 기뻐하지 않게)
      _joy = null;
    });
    if (id == 'props') _seeProps();
    if (id == 'paints') _seePaints();
  }

  /// 물감 탭을 열면 새 색·새 무늬 표시(배낭의 점)를 지운다. 이번에 연 탭의 무늬 칸 새 표시는 다시 읽을 때까지 남는다
  Future<void> _seePaints() async {
    final paint = await ref.read(paintServiceProvider.future);
    await paint.markSeen();
    if (mounted) ref.invalidate(unseenPaintsProvider);
  }

  /// 물감을 고른다 (누르면 바로 ‘쓰는 중’, 캔버스 6-1). 걷는 중이면 그 순간부터 그 색으로 칠한다 (16장 11/16)
  Future<void> _choosePaint(String colorId) async {
    await ref.read(paintTrailProvider.notifier).choosePaint(colorId);
    if (mounted) ref.invalidate(paintShelfProvider);
  }

  /// 무늬를 고른다 (맨 위 무늬 줄, 누르면 바로 ‘쓰는 중’). 걷는 중이면 그 순간부터 그 무늬로 칠한다 (16장 11/19)
  Future<void> _choosePattern(String patternId) async {
    await ref.read(paintTrailProvider.notifier).choosePattern(patternId);
    if (mounted) ref.invalidate(paintShelfProvider);
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
    final rules = ref.watch(rulesProvider).value;
    final ready = paintings != null && landmarks != null && rules != null;

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
            Expanded(child: ready ? _content(paintings, landmarks, rules) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _content(List<OwnedPaintingView> paintings, List<Landmark> landmarks, Rules rules) {
    final owned = {for (final p in paintings) p.landmark.id: p};
    final tabIds = rules.mapAlbum.albumTabs;
    final tab = tabIds.contains(_tab) ? _tab! : tabIds.first;
    final snap = ref.watch(snapshotProvider).value;
    final propsDot = (snap?.unseenProps ?? 0) > 0;
    final shelf = ref.watch(paintShelfProvider).value;
    final paintsLabel = shelf == null ? '물감' : '물감 ${shelf.colors.length}';
    // 그 탭 안에 있으면 그 자리에서 바로 본 것이라 점을 달지 않는다
    final paintsDot = (ref.watch(unseenPaintsProvider).value ?? 0) > 0 && tab != 'paints';
    final tabs = [
      for (final id in tabIds)
        switch (id) {
          'paintings' => const AlbumTab('paintings', '그림'),
          'props' => AlbumTab('props', '소품', dot: propsDot),
          _ => AlbumTab('paints', paintsLabel, dot: paintsDot),
        },
    ];
    const gutter = EdgeInsets.symmetric(horizontal: 16);
    // 그림 탭에 있는 동안은 전체를 보는 중에도 일기를 들고 있다 (일기로 넘길 때 뒤 절반이 빈 종이가 되지 않게)
    if (tab == 'paintings') ref.watch(diaryProvider);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AlbumTabs(tabs: tabs, selected: tab, onSelect: _openTab),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (tab == 'paintings') ...[
          SliverToBoxAdapter(
            child: _ViewSwitch(diary: _diary, onSelect: _switchView),
          ),
          _flipped(
            rules.motion.albumFlip,
            SliverMainAxisGroup(
              slivers: _diaryShown
                  ? _diarySlivers(owned, rules.motion.albumFlip)
                  : _paintingSlivers(owned, landmarks),
            ),
          ),
        ] else if (tab == 'props')
          ..._propSlivers(rules.mapAlbum.propsTab)
        else
          _paintSliver(),
      ],
    );
  }

  /// 물감 탭: 가진 물감 선반 (최근 → 계절 색 → 지역 색, 기본 물감이 맨 앞). 걷는 중에도 고른다
  /// (config paintColor.choose.whileWalking, 16장 11/16)
  Widget _paintSliver() {
    final shelf = ref.watch(paintShelfProvider).value;
    final rules = ref.watch(rulesProvider).value;
    if (shelf == null || rules == null) return const SliverToBoxAdapter();
    final walking = ref.watch(paintTrailProvider.select((s) => s.active));
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      sliver: SliverToBoxAdapter(
        child: PaintShelves(
          data: shelf,
          rules: rules,
          now: ref.read(clockProvider)(),
          canChoose: rules.paintColor.chooseWhileWalking || !walking,
          onChoose: _choosePaint,
          canChoosePattern: rules.paintPattern.whileWalking || !walking,
          onChoosePattern: _choosePattern,
        ),
      ),
    );
  }

  /// 그림 크게 보기 (16장 11/10): 지금 보기(일기·전체)의 순서로 넘긴다. [order]는 그 순서의 명소 id
  void _openViewer(Map<String, OwnedPaintingView> owned, List<String> order, String id) {
    final ids = [for (final i in {...order}) if (owned.containsKey(i)) i];
    final at = ids.indexOf(id);
    if (at < 0) return;
    openPaintingViewer(context, [for (final i in ids) BigPainting.owned(owned[i]!)], at);
  }

  /// 일기·전체 넘김 중이면 [sliver]를 그 모습으로 (아니면 그대로)
  Widget _flipped(AlbumFlipMotion? m, Widget sliver) {
    if (m == null) return sliver;
    return ListenableBuilder(
      listenable: _flip,
      builder: (context, child) {
        final t = motionTime(_flip, m.sec);
        return SliverFlip(key: const ValueKey('album-flip'), scaleX: m.scaleXAt(t), shadow: m.shadowAt(t), sliver: child!);
      },
      child: sliver,
    );
  }

  /// 그림 탭의 일기: 도착마다 한 항목, 최근이 위 (읽는 동안은 비워 둔다). 크게 보기는 다시 간 명소를
  /// 한 번만 (처음 나온 자리에서) 넘긴다. 달 머리줄은 화면에 들어올 때 넘긴다 (albumFlip.on monthHeader)
  List<Widget> _diarySlivers(Map<String, OwnedPaintingView> owned, AlbumFlipMotion? flip) {
    final entries = ref.watch(diaryProvider).value;
    if (entries == null) return const [SliverToBoxAdapter()];
    final order = [for (final e in entries) e.dest.id];
    return diarySlivers(
      context,
      entries,
      onOpen: (id) => _openViewer(owned, order, id),
      monthFlip: flip != null && flip.on.contains(AlbumFlipOn.monthHeader) ? flip : null,
    );
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
              onTap: () => _openViewer(owned, [for (final c in cells) c.landmark.id], id),
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

  /// 바로 입기 (16장 11/19, album.propsTab): 지금 모습에서 [p]를 입거나 벗고 꾸미기와 같은 저장(ProfileService.saveLook)으로
  /// 남긴다. 위 정령은 내 모습(meProvider)을 다시 읽어 바로 바뀌고, 잠깐 기뻐하며 한 줄 토스트
  Future<void> _wear(Prop p, PropsTabRules rules) async {
    if (_wearing) return;
    _wearing = true;
    try {
      final profile = ref.read(profileServiceProvider);
      final look = (await profile.me()).look;
      final out = tapToWear(look, p.slot, p.id, rules);
      if (out == null) return;
      await profile.saveLook(out.look);
      ref.invalidate(meProvider);
      if (!mounted) return;
      // 기쁨: 칭찬과 같은 표정(palette expressionTriggers happy) + Rive joy 트리거, joy.sec초
      final happy = ref.read(spiritPaletteProvider).value?.cues.of('praise');
      setState(() => _joy = SpiritCue(happy?.expr ?? 0, holdSec: rules.joySec, trigger: rules.joyTrigger));
      if (rules.toast) showToast(context, wearToast(p.name, p.slot, out.change));
    } catch (e) {
      // 가지지 않은 소품(StateError)이나 저장 실패
      debugPrint('바로 입기 실패: $e');
      if (mounted) showToast(context, '입지 못했어요');
    } finally {
      _wearing = false;
    }
  }

  /// 소품 탭: 위에 내 정령(누르면 바로 입어요 + 입은 소품 줄, 붙어 있음), 아래에 가진 소품만 칸별로
  /// (모자·얼굴 소품·옷·신발·손·가방·미니 친구·둥실·효과, 색 소품은 기본 소품 바로 뒤), 맨 아래 꾸미기 링크.
  /// 가진 소품이 없는 칸은 감추고, 하나도 없으면 한 줄 안내. 얻는 방법·잠긴 칸은 없다 (album.ownedOnly)
  List<Widget> _propSlivers(PropsTabRules rules) {
    final props = ref.watch(propsProvider).value;
    final ownedProps = ref.watch(ownedPropIdsProvider).value;
    final me = ref.watch(meProvider).value;
    // 읽어 오는 동안은 비워 둔다 (안내 글이 잠깐 비치지 않게)
    if (props == null || ownedProps == null || me == null) return const [SliverToBoxAdapter()];

    final worn = me.look.slots;
    final children = <Widget>[];
    for (final slot in propSlotLabels.entries) {
      final mine = [
        for (final p in variantsAfterBase(props))
          if (p.slot == slot.key && ownedProps.contains(p.id)) p,
      ];
      if (mine.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: PropSlotCard(
          name: slot.value,
          props: mine,
          worn: worn[slot.key],
          onTap: rules.tapToWear ? (p) => _wear(p, rules) : null,
        ),
      ));
    }
    if (children.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Text(
              albumNoPropsLine,
              key: ValueKey('album-no-props'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Palette.subInk),
            ),
          ),
        ),
      ];
    }
    final byId = {for (final p in props) p.id: p.name};
    final line = [
      for (final slot in lookSlots)
        if (worn[slot] case final id? when byId[id] != null) byId[id]!,
    ].join(' · ');
    children.add(Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: GameButton(
          key: const ValueKey('album-decorate-link'),
          label: albumDecorateLink,
          kind: GameButtonKind.secondary,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const DecorateScreen())),
        ),
      ),
    ));
    return [
      // 위 카드는 소품을 내려도 붙어 있다 (캔버스 6-1 sticky). 높이는 글자 크기에 따라 카드가 정한다
      PinnedHeaderSliver(
        child: ColoredBox(
          color: Palette.paper,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _WearCard(
              look: ref.watch(spiritLookProvider),
              cue: _joy,
              cues: ref.watch(spiritPaletteProvider).value?.cues,
              line: line,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
    ];
  }
}

/// 소품 탭 위 카드의 정령 상자와 글 스타일
const _wearSpiritBox = 92.0;
const _wearTitleGap = 3.0;
const _wearLineStyle = TextStyle(fontSize: 13, height: 1.4, color: Palette.subInk);

/// 소품 탭 위 카드 (캔버스 6-1): 내 정령(바로 입은 모습, 입으면 기뻐함) + `누르면 바로 입어요` + 입은 소품 줄
class _WearCard extends StatelessWidget {
  const _WearCard({required this.look, required this.cue, required this.cues, required this.line});

  final SpiritLook look;
  final SpiritCue? cue;
  final SpiritCues? cues;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('album-wear-card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.line, width: InkLine.pill),
      ),
      child: Row(
        children: [
          SizedBox(
            key: const ValueKey('album-wear-spirit'),
            width: 84,
            height: _wearSpiritBox,
            child: SpiritStanding(look: look, share: 0.8, footAt: 0.95, cue: cue, cues: cues),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 좁은 화면에서 글자를 키워도 한 줄 (넘치면 줄여 맞춘다)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(albumWearTitle, maxLines: 1, style: context.display(15)),
                ),
                const SizedBox(height: _wearTitleGap),
                Text(
                  line,
                  key: const ValueKey('album-wear-line'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _wearLineStyle,
                ),
              ],
            ),
          ),
        ],
      ),
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
