import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/time_kst.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/framed_painting.dart';
import '../common/palette.dart';

/// 그림 상세: 큰 액자 그림, 이름, 시도·시군구·지형, 액자 등급과 방문 기록.
/// 공유 버튼은 공유 패키지를 넣을 때 더한다
class PaintingDetailScreen extends ConsumerWidget {
  const PaintingDetailScreen({super.key, required this.landmarkId});

  final String landmarkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painting = ref
        .watch(paintingsProvider)
        .value
        ?.where((p) => p.landmark.id == landmarkId)
        .firstOrNull;
    final visits = ref.watch(visitsProvider(landmarkId)).value ?? const <VisitView>[];

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
                      child: _content(painting, visits),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(OwnedPaintingView p, List<VisitView> visits) {
    final l = p.landmark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: FramedPainting(
                key: const ValueKey('detail-painting'),
                landmark: l,
                frame: p.frame,
                thickness: 12,
              ),
            ),
          ),
        ),
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
      ],
    );
  }
}
