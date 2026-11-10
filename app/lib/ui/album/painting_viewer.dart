import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/painting_saver_provider.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/painting_saver.dart';
import '../../domain/journey.dart';
import '../../domain/landmark.dart';
import '../common/framed_painting.dart';
import '../common/palette.dart';
import 'painting_share.dart';

/// 크게 보기 한 장: 명소(첫 그림이면 가짜 명소), 액자, 첫 그림인지
class BigPainting {
  const BigPainting({required this.landmark, required this.frame, this.isFirstPack = false});

  BigPainting.owned(OwnedPaintingView p)
      : landmark = p.landmark,
        frame = p.frame,
        isFirstPack = p.isFirstPack;

  final Landmark landmark;
  final Frame frame;
  final bool isFirstPack;
}

/// 그림 크게 보기를 연다 (화집·도착, 16장 11/10). [items]를 좌우로 넘기고 [index]에서 시작한다.
/// 도착은 한 장만 넘긴다
Future<void> openPaintingViewer(BuildContext context, List<BigPainting> items, int index) =>
    Navigator.of(context).push(PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => PaintingViewer(items: items, initialIndex: index),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ));

/// 크게 보기 바탕 (캔버스 6-1·3-2)과 위 아이콘 색
const _background = Color(0xFF1E1611);
const _iconColor = Color(0xFFFBF6EC);

/// 아래로 이만큼(pt) 끌거나 이 속도(pt/초)로 밀면 닫는다
const _closeDragPt = 120.0;
const _closeVelocity = 800.0;

/// 좌우로 이 속도(pt/초)보다 빠르게 밀면 끈 거리와 상관없이 다음·이전 장
const _pageFlingVelocity = 500.0;

/// 한 번의 몸짓이 무엇인지: 두 손가락 확대, 확대한 채 옮기기, 좌우 넘기기, 아래로 밀어 닫기
enum _Gesture { undecided, zoom, pan, page, close }

/// 그림 크게 보기 (캔버스 6-1 화집·3-2 도착): 검은 바탕에 액자째 화면 가득, 화면 글 없음.
/// 두 손가락으로 1~config 배(ui.bigView.maxZoom) 확대, 좌우로 다음·이전, 아래로 밀거나 뒤로 가면 닫힘.
/// 위 왼쪽 저장(사진첩, ‘저장했어요’), 오른쪽 닫기. 확대한 동안 한 손가락은 그림을 옮긴다(넘기기·닫기 없음).
/// 몸짓은 한 곳(확대 인식기)에서 나눠 받는다: 넘기기 인식기와 겨루면 두 손가락 확대가 넘기기에 먹힌다
class PaintingViewer extends ConsumerStatefulWidget {
  const PaintingViewer({super.key, required this.items, this.initialIndex = 0});

  final List<BigPainting> items;
  final int initialIndex;

  @override
  ConsumerState<PaintingViewer> createState() => _PaintingViewerState();
}

class _PaintingViewerState extends ConsumerState<PaintingViewer> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late var _index = widget.initialIndex;

  /// 지금 장의 확대 배율과 옮긴 자리(왼쪽 위 기준, pt). 장을 넘기면 원래 크기로
  var _scale = 1.0;
  var _shift = Offset.zero;

  /// 그림을 그리는 화면 크기 (확대한 그림이 이 밖으로 비어 보이지 않게)
  var _viewport = Size.zero;

  /// 지금 몸짓과, 그 몸짓이 시작될 때의 값
  var _gesture = _Gesture.undecided;
  var _startScale = 1.0;
  var _startShift = Offset.zero;
  var _startFocal = Offset.zero;
  var _startPixels = 0.0;

  /// 장마다 저장할 때 뜨는 액자 그림 (RepaintBoundary)
  late final _boundaries = [for (final _ in widget.items) GlobalKey()];

  /// 아래로 끈 거리(pt)
  var _dragY = 0.0;

  var _saving = false;
  String? _toast;
  Timer? _toastTimer;

  bool get _zoomed => _scale > 1.01;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  /// 확대한 그림이 화면 밖으로 비지 않게 옮긴 자리를 자른다
  Offset _clampShift(Offset t, double scale) => Offset(
        t.dx.clamp(_viewport.width * (1 - scale), 0.0),
        t.dy.clamp(_viewport.height * (1 - scale), 0.0),
      );

  void _onStart(ScaleStartDetails d) {
    _startScale = _scale;
    _startShift = _shift;
    _startFocal = d.localFocalPoint;
    _startPixels = _pages.hasClients ? _pages.position.pixels : 0;
    _gesture = d.pointerCount >= 2
        ? _Gesture.zoom
        : _zoomed
            ? _Gesture.pan
            : _Gesture.undecided;
  }

  void _onUpdate(ScaleUpdateDetails d, double maxZoom) {
    final move = d.localFocalPoint - _startFocal;
    switch (_gesture) {
      case _Gesture.zoom:
        final scale = (_startScale * d.scale).clamp(1.0, maxZoom);
        // 시작할 때 손가락 사이에 있던 그림 자리가 손가락을 따라오게
        final content = (_startFocal - _startShift) / _startScale;
        setState(() {
          _scale = scale;
          _shift = _clampShift(d.localFocalPoint - content * scale, scale);
        });
      case _Gesture.pan:
        setState(() => _shift = _clampShift(_startShift + move, _scale));
      case _Gesture.undecided:
        if (move.distance < kTouchSlop) return;
        _gesture = move.dx.abs() > move.dy.abs() ? _Gesture.page : _Gesture.close;
        _onUpdate(d, maxZoom);
      case _Gesture.page:
        if (!_pages.hasClients) return;
        final p = _pages.position;
        p.jumpTo((_startPixels - move.dx).clamp(p.minScrollExtent, p.maxScrollExtent));
      case _Gesture.close:
        setState(() => _dragY = math.max(0, move.dy));
    }
  }

  void _onEnd(ScaleEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    switch (_gesture) {
      case _Gesture.page when _pages.hasClients:
        final width = _pages.position.viewportDimension;
        final from = (_startPixels / width).round();
        var target = (_pages.position.pixels / width).round();
        if (v.dx < -_pageFlingVelocity) target = from + 1;
        if (v.dx > _pageFlingVelocity) target = from - 1;
        _pages.animateToPage(
          target.clamp(0, widget.items.length - 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      case _Gesture.close:
        if (_dragY > _closeDragPt || v.dy > _closeVelocity) {
          _close();
        } else {
          setState(() => _dragY = 0);
        }
      default:
        break;
    }
    _gesture = _Gesture.undecided;
  }

  void _showToast(String text) {
    final rules = ref.read(rulesProvider).value;
    final sec = rules?.bigViewSavedToastSec ?? 1.5;
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(Duration(milliseconds: (sec * 1000).round()), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// 지금 장의 액자 그림을 PNG로 떠서 사진첩에 넣는다
  Future<void> _save() async {
    if (_saving) return;
    final item = widget.items[_index];
    final key = _boundaries[_index];
    setState(() => _saving = true);
    var text = '저장하지 못했어요';
    try {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      // 원본 그림(1536px)에 가까운 크기로 뜬다
      final ratio = box == null ? sharePixelRatio : (1536 / box.size.width).clamp(sharePixelRatio, 5.0);
      final png = await capturePng(key, pixelRatio: ratio);
      if (png == null || png.isEmpty) throw StateError('그림을 이미지로 만들지 못했다');
      final name = paintingFileStem(isFirstPack: item.isFirstPack, landmarkName: item.landmark.name);
      text = switch (await ref.read(paintingSaverProvider).save(png, name)) {
        SaveOutcome.saved => '저장했어요',
        SaveOutcome.denied => '사진 권한이 없어 저장하지 못했어요',
        SaveOutcome.failed => '저장하지 못했어요',
      };
    } catch (e) {
      debugPrint('그림 저장 실패: $e');
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _showToast(text);
  }

  @override
  Widget build(BuildContext context) {
    final maxZoom = ref.watch(rulesProvider).value?.bigViewMaxZoom ?? 2.0;
    final dragOpacity = (1 - _dragY / 400).clamp(0.4, 1.0);
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(builder: (context, box) {
            _viewport = box.biggest;
            return GestureDetector(
              key: const ValueKey('viewer-drag'),
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onStart,
              onScaleUpdate: (d) => _onUpdate(d, maxZoom),
              onScaleEnd: _onEnd,
              child: Transform.translate(
                offset: Offset(0, _dragY),
                child: Opacity(
                  opacity: dragOpacity,
                  // 넘기기는 위 몸짓이 controller로 한다
                  child: PageView.builder(
                    key: const ValueKey('viewer-pages'),
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.items.length,
                    onPageChanged: (i) => setState(() {
                      _index = i;
                      _scale = 1;
                      _shift = Offset.zero;
                    }),
                    itemBuilder: (context, i) => _page(i),
                  ),
                ),
              ),
            );
          }),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const ValueKey('viewer-save'),
                      tooltip: '이미지로 저장',
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.file_download_outlined, color: _iconColor, size: 24),
                    ),
                    IconButton(
                      key: const ValueKey('viewer-close'),
                      tooltip: '닫기',
                      onPressed: _close,
                      icon: const Icon(Icons.close, color: _iconColor, size: 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_toast case final text?)
            Positioned(
              left: 16,
              right: 16,
              bottom: 48 + MediaQuery.paddingOf(context).bottom,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey('viewer-toast'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Palette.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Palette.ink, width: InkLine.pill),
                    ),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Palette.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 한 장: 화면 폭에 맞춘 4:3 액자 그림. 지금 장만 확대한다
  Widget _page(int i) {
    final item = widget.items[i];
    final framed = RepaintBoundary(
      key: _boundaries[i],
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: item.isFirstPack
            ? const FramedPainting.firstPack(thickness: 12)
            : FramedPainting(landmark: item.landmark, frame: item.frame, thickness: 12, fullSize: true),
      ),
    );
    final page = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: KeyedSubtree(key: ValueKey('viewer-painting-${item.landmark.id}'), child: framed),
      ),
    );
    return Transform.translate(
      offset: i == _index ? _shift : Offset.zero,
      child: Transform.scale(
        key: ValueKey('viewer-zoom-$i'),
        scale: i == _index ? _scale : 1,
        alignment: Alignment.topLeft,
        child: page,
      ),
    );
  }
}
