import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/sketch.dart';
import '../../domain/time_kst.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/framed_painting.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import 'painting_share.dart';

/// 그림 상세: 큰 액자 그림, 이름, 시도·시군구·지형, 액자 등급과 방문 기록, 맨 아래 보조 버튼 "공유".
/// 첫 그림(첫 여행 짐 꾸러미)은 방문 기록이 없어서 나무 액자의 큰 그림과 이름·받은 날짜만 보여 준다.
/// "공유"는 액자 낀 그림만 PNG로 떠서(RepaintBoundary) 공유 시트에 올린다 (UI 명세 10장)
class PaintingDetailScreen extends ConsumerStatefulWidget {
  const PaintingDetailScreen({super.key, required this.landmarkId});

  final String landmarkId;

  @override
  ConsumerState<PaintingDetailScreen> createState() => _PaintingDetailScreenState();
}

/// 공유 이미지에서 액자 둘레에 두르는 종이색 여백 (액자 모서리 바깥이 비어 보이지 않게)
const _shareMargin = 8.0;

class _PaintingDetailScreenState extends ConsumerState<PaintingDetailScreen> {
  /// 공유할 그림 영역 (RepaintBoundary)
  final _boundaryKey = GlobalKey();

  /// 공유 버튼 (iPad에서 공유 시트가 뜰 자리)
  final _buttonKey = GlobalKey();

  /// 이미지를 뜨고 시트를 여는 동안 또 누르지 않게
  var _sharing = false;

  /// 그림을 PNG로 떠서 공유 시트를 연다. 못 하면 토스트로 알린다
  Future<void> _share(OwnedPaintingView p) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      final png = await capturePng(_boundaryKey);
      if (png == null || png.isEmpty) throw StateError('그림을 이미지로 만들지 못했다');
      await ref.read(paintingSharerProvider).share(
            png: png,
            fileName: paintingShareFileName(p),
            text: paintingShareText(p),
            origin: origin,
          );
    } catch (e) {
      debugPrint('그림 공유 실패: $e');
      if (mounted) showToast(context, '그림을 공유하지 못했어요');
    }
    if (mounted) setState(() => _sharing = false);
  }

  /// 공유 버튼. 보조 버튼이라 그림 아래 맨 끝에 둔다
  Widget _shareButton(OwnedPaintingView p) => KeyedSubtree(
        key: _buttonKey,
        child: GameButton(
          label: '공유',
          kind: GameButtonKind.secondary,
          onPressed: _sharing ? null : () => _share(p),
        ),
      );

  /// 공유 이미지가 되는 영역: 종이색 여백 안의 액자 그림
  Widget _capture(Widget framed) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300 + 2 * _shareMargin),
          child: RepaintBoundary(
            key: _boundaryKey,
            child: ColoredBox(
              color: Palette.paper,
              child: Padding(
                padding: const EdgeInsets.all(_shareMargin),
                child: AspectRatio(aspectRatio: 4 / 3, child: framed),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final painting = ref
        .watch(paintingsProvider)
        .value
        ?.where((p) => p.landmark.id == widget.landmarkId)
        .firstOrNull;
    final visits = ref.watch(visitsProvider(widget.landmarkId)).value ?? const <VisitView>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CornerButton(
                  icon: Icons.arrow_back,
                  label: '뒤로',
                  size: 44,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Expanded(
              child: painting == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: painting.isFirstPack
                          ? _firstPackContent(painting)
                          : _content(painting, visits),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 첫 그림: 나무 액자의 큰 그림, `첫 그림 · 첫 여행 짐 꾸러미`, 받은 날짜
  Widget _firstPackContent(OwnedPaintingView p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _capture(const FramedPainting.firstPack(key: ValueKey('detail-first-pack'), thickness: 12)),
        const SizedBox(height: 16),
        const Text(
          '$firstPackLabel · $firstPackName',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ink),
        ),
        const SizedBox(height: 4),
        Text(
          formatMonthDay(kstDate(p.firstArrivedAt)),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Palette.subInk),
        ),
        const SizedBox(height: 24),
        _shareButton(p),
      ],
    );
  }

  Widget _content(OwnedPaintingView p, List<VisitView> visits) {
    final l = p.landmark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _capture(FramedPainting(
          key: const ValueKey('detail-painting'),
          landmark: l,
          frame: p.frame,
          thickness: 12,
        )),
        const SizedBox(height: 16),
        Text(
          l.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ink),
        ),
        const SizedBox(height: 4),
        Text(
          '${l.sido} ${l.sigungu} · ${terrainLabels[l.terrain] ?? l.terrain}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Palette.subInk),
        ),
        const SizedBox(height: 8),
        Text(
          frameLabel(p.frame),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ink, width: 2.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final v in visits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${v.visitNo}번째 방문 · ${formatKm(v.km)} · '
                    '${formatMonthDay(kstDate(v.arrivedAt))}',
                    style: const TextStyle(fontSize: 14, color: Palette.ink),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _shareButton(p),
      ],
    );
  }
}
