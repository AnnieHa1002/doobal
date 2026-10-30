import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/landmark.dart';
import '../../domain/map_projection.dart';
import '../../domain/map_regions.dart';
import '../../domain/time_kst.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../walking/walking_screen.dart';
import 'landmark_card.dart';
import 'map_geometry.dart';
import 'map_painter.dart';
import 'map_sheets.dart';
import 'map_widgets.dart';

const _maxZoom = 6.0;

/// 명소를 찾았을 때 맞추는 확대 배율
const _focusZoom = 4.0;
const _searchMax = 6;
const _moveDuration = Duration(milliseconds: 350);

/// 지도를 맞출 때 가리지 않는 가운데 영역: 위 조작(뒤로·검색·칩)과 아래 카드를 뺀 여백.
/// 위쪽은 상태 표시줄 높이를 더한다
const _topReserve = 108.0;
const _bottomReserve = 270.0;

/// 지도: 전국 시도 경계 위에 명소·지나온 길·지금 위치를 보여 주고, 명소를 골라 출발한다.
/// [walkAfterStart]가 true면(쉼터에서 여정 없이 출발하기로 들어왔을 때) 출발한 뒤 걷는 중으로 간다
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.walkAfterStart = false});

  final bool walkAfterStart;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final AnimationController _anim;
  late final Animation<double> _curve;
  Matrix4Tween? _tween;

  /// 첫 화면을 그릴 때(화면 크기를 알 때) 만든다
  TransformationController? _tc;
  MapGeometry? _geometry;
  Size _view = Size.zero;
  EdgeInsets _padding = EdgeInsets.zero;

  /// 고른 명소. 처음엔 여정이 있으면 그 목적지, 빈 곳을 누르면 비운다
  String? _selectedId;
  var _selectionReady = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: _moveDuration)..addListener(_onMove);
    _curve = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc?.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onMove() {
    final t = _tween;
    if (t != null) _tc?.value = t.evaluate(_curve);
  }

  MapGeometry _geometryOf(MapProjection p, List<MapRegion> r, List<Landmark> l) {
    final g = _geometry;
    if (g != null &&
        identical(g.projection, p) &&
        identical(g.regions, r) &&
        identical(g.landmarks, l)) {
      return g;
    }
    return _geometry = MapGeometry(projection: p, regions: r, landmarks: l);
  }

  /// [rect](캔버스 px)를 위·아래 가린 곳을 뺀 영역 가운데에 맞추는 변환.
  /// [zoom]이 null이면 영역에 꽉 차게(여백 10%) 맞추고, 확대는 1~최대 사이로 자른다
  Matrix4 _matrixFor(MapGeometry g, MapRect rect, {double? zoom}) {
    final base = g.baseScale(_view.width);
    final top = _padding.top + _topReserve;
    final width = _view.width - 32;
    final height = math.max(100.0, _view.height - _padding.bottom - _bottomReserve - top);
    final fit = math.min(
          width / (math.max(rect.width, 1) * base),
          height / (math.max(rect.height, 1) * base),
        ) *
        0.9;
    final z = (zoom ?? fit).clamp(1.0, _maxZoom);
    final c = Offset(rect.center.x, rect.center.y) * base;
    final t = Offset(_view.width / 2, top + height / 2) - c * z;
    // 열 우선: 확대 z 다음에 t만큼 옮긴다
    return Matrix4(z, 0, 0, 0, 0, z, 0, 0, 0, 0, 1, 0, t.dx, t.dy, 0, 1);
  }

  void _animateTo(Matrix4 end) {
    final tc = _tc;
    if (tc == null) return;
    _tween = Matrix4Tween(begin: tc.value, end: end);
    _anim.forward(from: 0);
  }

  void _onRegion(String region) {
    final g = _geometry;
    if (g == null) return;
    _searchFocus.unfocus();
    _animateTo(_matrixFor(g, g.boundsOfRegion(region)));
  }

  void _onPick(Landmark l) {
    final g = _geometry;
    if (g == null) return;
    _searchFocus.unfocus();
    _search.text = l.name;
    setState(() => _selectedId = l.id);
    final p = g.landmarkPoints[l.id]!;
    _animateTo(_matrixFor(g, MapRect(p.dx, p.dy, p.dx, p.dy), zoom: _focusZoom));
  }

  /// 지도를 눌렀을 때: 가까운 명소를 고르고, 없으면 고른 것을 푼다
  void _onMapTap(Offset local) {
    final g = _geometry;
    final tc = _tc;
    if (g == null || tc == null) return;
    _searchFocus.unfocus();
    final id = nearestLandmark(
      local,
      g.landmarkPoints,
      base: g.baseScale(_view.width),
      zoom: tc.value.getMaxScaleOnAxis(),
    );
    setState(() => _selectedId = id);
  }

  /// 여기로 가기 / 목적지 바꾸기. 바꾸기는 먼저 확인하고, 경비가 있으면 쓸지 묻는다.
  /// 시트를 밖에서 눌러 닫으면 출발하지 않는다
  Future<void> _onGo(Landmark l, Snapshot snap, {required bool change}) async {
    if (_busy) return;
    _busy = true;
    try {
      if (change) {
        final ok = await showChangeSheet(context);
        if (ok != true || !mounted) return;
      }
      var useFund = true;
      if (snap.fundKm > 0) {
        final add = await showFundSheet(context, snap.fundKm);
        if (add == null || !mounted) return;
        useFund = add;
      }
      await _start(l.id, useFund);
    } finally {
      _busy = false;
    }
  }

  Future<void> _start(String destId, bool useFund) async {
    final svc = await ref.read(syncServiceProvider.future);
    try {
      await svc.startJourney(destId, ref.read(clockProvider)(), useFund: useFund);
    } on StateError catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    ref.invalidate(mapDataProvider);
    ref.invalidate(snapshotProvider);
    if (!widget.walkAfterStart) return;
    // 걷는 중이 첫 화면부터 새 여정으로 시작하도록 새 상태가 올 때까지 기다린다
    await ref.read(snapshotProvider.future);
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => const WalkingScreen()));
  }

  /// 여정 멈추기: 먼저 확인하고, 멈춘 자리에서 다시 출발하게 둔다. 시트를 밖에서 눌러 닫으면 아무 일도 없다
  Future<void> _onStop() async {
    if (_busy) return;
    _busy = true;
    try {
      final capKm = (await ref.read(rulesProvider.future)).travelFundCapKm;
      if (!mounted) return;
      final ok = await showStopSheet(context, capKm);
      if (ok != true || !mounted) return;
      final svc = await ref.read(syncServiceProvider.future);
      // 확인하는 사이 도착했으면 멈춘 게 아니다 (도착 화면은 하던 대로 뜬다)
      final stopped = await svc.stopJourney(ref.read(clockProvider)());
      if (!mounted) return;
      ref.invalidate(mapDataProvider);
      ref.invalidate(snapshotProvider);
      if (stopped) showToast(context, '여정을 멈췄어요');
    } finally {
      _busy = false;
    }
  }

  String _distanceLine(double km, int days) => '남은 거리 ${formatKm(km)} · 약 ${math.max(1, days)}일';

  @override
  Widget build(BuildContext context) {
    final projection = ref.watch(mapProjectionProvider).value;
    final regions = ref.watch(mapRegionsProvider).value;
    final landmarks = ref.watch(landmarksProvider).value;
    final data = ref.watch(mapDataProvider).value;
    final snap = ref.watch(snapshotProvider).value;
    // 데이터가 올 때까지는 종이색 빈 화면
    if (projection == null ||
        regions == null ||
        landmarks == null ||
        data == null ||
        snap == null) {
      return const Scaffold(backgroundColor: Palette.paper, body: SizedBox.expand());
    }
    final geometry = _geometryOf(projection, regions, landmarks);
    if (!_selectionReady) {
      _selectionReady = true;
      _selectedId = data.destId;
    }

    return Scaffold(
      backgroundColor: Palette.paper,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(builder: (context, box) {
        _view = box.biggest;
        _padding = MediaQuery.paddingOf(context);
        final tc = _tc ??=
            TransformationController(_matrixFor(geometry, geometry.bounds, zoom: 1));
        return Stack(
          children: [
            Positioned.fill(child: _map(geometry, data, tc)),
            _topBar(landmarks, data, geometry),
            ..._searchResults(landmarks),
            ..._selectedCard(geometry, data, snap),
          ],
        );
      }),
    );
  }

  /// 확대·이동할 수 있는 지도. 캔버스는 화면 너비에 맞추고, 처음엔 확대 1배
  Widget _map(MapGeometry g, MapData data, TransformationController tc) {
    final size = Size(_view.width, _view.width * g.projection.height / g.projection.width);
    return InteractiveViewer(
      transformationController: tc,
      constrained: false,
      minScale: 1,
      maxScale: _maxZoom,
      // 지도를 통째로 밀어내서 잃어버리지 않게 화면 반만큼만 벗어나게 한다
      boundaryMargin: EdgeInsets.symmetric(horizontal: _view.width / 2, vertical: _view.height / 2),
      onInteractionStart: (_) => _anim.stop(),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onMapTap(d.localPosition),
          child: RepaintBoundary(
            // 확대 배율이 바뀔 때만 다시 그린다 (MapPainter.shouldRepaint)
            child: ListenableBuilder(
              listenable: tc,
              builder: (context, _) => CustomPaint(
                painter: MapPainter(
                  geometry: g,
                  data: data,
                  selectedId: _selectedId,
                  zoom: tc.value.getMaxScaleOnAxis(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(List<Landmark> landmarks, MapData data, MapGeometry g) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CornerButton(
                      icon: Icons.arrow_back,
                      label: '뒤로',
                      size: 44,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MapSearchField(
                        controller: _search,
                        focusNode: _searchFocus,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              RegionChips(
                progress: regionProgress(data.visited.keys.toSet(), landmarks),
                onTap: _onRegion,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 글자를 쓰는 동안 이름에 그 글자가 들어간 명소를 최대 [_searchMax]곳
  List<Widget> _searchResults(List<Landmark> landmarks) {
    final query = _search.text.trim();
    if (!_searchFocus.hasFocus || query.isEmpty) return const [];
    final results = [for (final l in landmarks) if (l.name.contains(query)) l].take(_searchMax);
    if (results.isEmpty) return const [];
    return [
      Positioned(
        top: _padding.top + 8 + 44 + 6,
        left: 16 + 44 + 8,
        right: 16,
        child: SearchResults(results: results.toList(), onPick: _onPick),
      ),
    ];
  }

  /// 고른 명소가 있으면 아래 카드. 현재 목적지는 보조 버튼 `여정 멈추기`,
  /// 여정이 없으면 `여기로 가기`, 있으면 다른 명소에 `목적지 바꾸기`
  List<Widget> _selectedCard(MapGeometry g, MapData data, Snapshot snap) {
    final id = _selectedId;
    final l = g.byId[id];
    if (id == null || l == null) return const [];
    final isDest = id == data.destId;

    // 현재 목적지는 쉼터와 같은 남은 거리·도착 예정일, 다른 명소는 지금 자리에서 가는 거리
    String? distance;
    final j = snap.journey;
    final isJourneyDest = j != null && j.dest.id == id;
    if (isJourneyDest) {
      distance = _distanceLine(
        j.progress.remainingKm,
        j.eta.difference(dayFromKey(snap.today)).inDays,
      );
    } else {
      final preview = ref.watch(journeyPreviewProvider(id)).value;
      if (preview != null) distance = _distanceLine(preview.totalKm, preview.etaDays);
    }

    final change = data.destId != null;
    return [
      Positioned(
        left: 16,
        right: 16,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LandmarkCard(
              landmark: l,
              frame: data.visited[id],
              distance: distance,
              buttonLabel: isJourneyDest
                  ? '여정 멈추기'
                  : (isDest ? null : (change ? '목적지 바꾸기' : '여기로 가기')),
              secondary: isJourneyDest,
              onPressed: isJourneyDest ? _onStop : () => _onGo(l, snap, change: change),
            ),
          ),
        ),
      ),
    ];
  }
}
