import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/companion_providers.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/companion.dart';
import '../common/app_text.dart';
import '../common/ink_press.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import 'companion_art.dart';
import 'meet_flow.dart';
import 'story_sheet.dart';

/// 줄 사이 선
const _rowLine = Color(0xFFEFE6D4);

/// 안 고른 칸 선
const _tileLine = Color(0xFFD9C9AE);

/// 동행 (캔버스 7-1): 지금 함께 걷는 동행, 만난 동행, 그 동행의 열린 이야기.
/// 만나지 않은 동행은 어떤 표시도 없다 (11/5 Annie, 기준 문서 16장). 안 열린 장도 줄 자체가 없다.
/// 칸을 누르면 그 동행과 걷는다. 지금은 개발 화면에서 들어온다 (쉼터 입구는 T3)
class CompanionScreen extends ConsumerWidget {
  const CompanionScreen({super.key});

  Future<void> _walkWith(BuildContext context, WidgetRef ref, String? id) async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.walkWith(id, ref.read(clockProvider)());
    if (context.mounted) ref.invalidate(companionsViewProvider);
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Companion companion,
    StoryChapter chapter,
  ) async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.markStoryRead(companion.id, chapter.no);
    if (!context.mounted) return;
    ref.invalidate(companionsViewProvider);
    await showStorySheet(context, companion, chapter);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(companionsViewProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('동행'),
            if (view != null)
              Expanded(
                child: _Body(
                  view: view,
                  onWalkWith: (id) => _walkWith(context, ref, id),
                  onOpen: (c, ch) => _open(context, ref, c, ch),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.view, required this.onWalkWith, required this.onOpen});

  final CompanionsView view;
  final ValueChanged<String?> onWalkWith;
  final void Function(Companion, StoryChapter) onOpen;

  @override
  Widget build(BuildContext context) {
    final walking = view.metById(view.walkingWith);
    final shown = walking ?? view.metById(view.lastWith);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _NowCard(
          walking: walking?.companion,
          last: shown?.companion,
          onToggle: shown == null
              ? null
              : () => onWalkWith(walking == null ? shown.companion.id : null),
        ),
        const SizedBox(height: 12),
        _SectionLabel('만난 동행 ${view.met.length}'),
        const SizedBox(height: 6),
        if (view.met.isNotEmpty)
          _MateGrid(met: view.met, walkingWith: view.walkingWith, onPick: onWalkWith),
        if (shown != null) ...[
          const SizedBox(height: 12),
          _SectionLabel('${shown.companion.name}의 이야기'),
          const SizedBox(height: 6),
          _StoryList(met: shown, onOpen: onOpen),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text, style: AppText.label),
      );
}

/// 맨 위 카드: 초상, 지금 상태, 혼자/함께 바꾸기
class _NowCard extends StatelessWidget {
  const _NowCard({required this.walking, required this.last, required this.onToggle});

  final Companion? walking;

  /// 혼자 걷는 중일 때 다시 함께 걸을 동행 (만난 동행이 없으면 null)
  final Companion? last;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final now = walking;
    final back = last;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
        boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
      ),
      child: Row(
        children: [
          CompanionPortrait(companion: now, size: 104),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(now == null ? '혼자 걷는 중' : '지금 함께 걷는 중', style: AppText.label),
                const SizedBox(height: 6),
                Text(
                  now?.name ?? '혼자',
                  key: const Key('companion-now'),
                  style: context.display(21, weight: FontWeight.w600),
                ),
                if (back != null && onToggle != null) ...[
                  const SizedBox(height: 6),
                  InkPress(
                    key: const Key('companion-toggle'),
                    onPressed: onToggle,
                    fill: Palette.card,
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        now == null ? '${withName(back)} 함께 걷기' : '혼자 걷기',
                        textAlign: TextAlign.center,
                        style: context.display(14, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 만난 동행 칸 (3열). 만난 만큼만 있고 빈 칸은 그리지 않는다
class _MateGrid extends StatelessWidget {
  const _MateGrid({required this.met, required this.walkingWith, required this.onPick});

  final List<MetCompanion> met;
  final String? walkingWith;
  final ValueChanged<String?> onPick;

  static const _columns = 3;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < met.length; i += _columns) {
      final row = met.skip(i).take(_columns).toList();
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var c = 0; c < _columns; c++) ...[
              if (c > 0) const SizedBox(width: 8),
              Expanded(
                child: c < row.length
                    ? _MateTile(
                        met: row[c],
                        on: row[c].companion.id == walkingWith,
                        onTap: () => onPick(row[c].companion.id),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _MateTile extends StatelessWidget {
  const _MateTile({required this.met, required this.on, required this.onTap});

  final MetCompanion met;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = met.companion;
    return Semantics(
      button: true,
      selected: on,
      label: on ? '${c.name}, 함께 걷는 중' : '${c.name}, 같이 걷기',
      child: GestureDetector(
        key: Key('companion-tile-${c.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? Palette.terracotta : _tileLine,
              width: on ? InkLine.focus : 2,
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CompanionFigure(companion: c, height: 58),
                const SizedBox(height: 4),
                Text(c.name, textAlign: TextAlign.center, style: context.display(13)),
                Text(
                  met.chapter == 0 ? '프롤로그' : '이야기 ${met.chapter}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, height: 1.3, color: Palette.subInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 열린 장 목록. 프롤로그는 만나면 늘 열려 있다
class _StoryList extends StatelessWidget {
  const _StoryList({required this.met, required this.onOpen});

  final MetCompanion met;
  final void Function(Companion, StoryChapter) onOpen;

  @override
  Widget build(BuildContext context) {
    final open = [
      for (final ch in met.companion.chapters)
        if (ch.no <= met.chapter) ch,
    ];
    return Container(
      decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          for (final (i, ch) in open.indexed)
            _StoryRow(
              chapter: ch,
              companionId: met.companion.id,
              divider: i < open.length - 1,
              onTap: () => onOpen(met.companion, ch),
            ),
        ],
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.chapter,
    required this.companionId,
    required this.divider,
    required this.onTap,
  });

  final StoryChapter chapter;
  final String companionId;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${storyChapterNo(chapter)} ${chapter.title}',
      child: GestureDetector(
        key: Key('story-row-$companionId-${chapter.no}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: divider ? const Border(bottom: BorderSide(color: _rowLine)) : null,
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(storyChapterNo(chapter), style: AppText.label),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(chapter.title, style: const TextStyle(fontSize: 14))),
                if (chapter.art != null) ...[
                  const SizedBox(width: 8),
                  const Text('그림', style: AppText.label),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
