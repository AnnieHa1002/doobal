import 'package:flutter/material.dart';

import '../../domain/companion.dart';
import '../common/app_text.dart';
import '../common/palette.dart';
import 'companion_art.dart';
import 'meet_flow.dart';

/// 장 이름의 앞 ('프롤로그'·'3장')
String storyChapterNo(StoryChapter c) => c.no == 0 ? '프롤로그' : '${c.no}장';

/// 이야기 읽기 시트 (캔버스 7-1). 본문은 companions.json에서 온다.
/// 표정 스프라이트는 아직 없어(T2c) 글만 보여 주고, 그림 있는 장은 위에 그림 자리를 둔다
Future<void> showStorySheet(BuildContext context, Companion companion, StoryChapter chapter) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.card,
    barrierColor: Palette.ink.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: Palette.ink, width: InkLine.panel),
    ),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: _StorySheet(companion: companion, chapter: chapter),
    ),
  );
}

class _StorySheet extends StatelessWidget {
  const _StorySheet({required this.companion, required this.chapter});

  final Companion companion;
  final StoryChapter chapter;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
        child: Column(
          key: const Key('story-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${storyChapterNo(chapter)} · ${chapter.title}',
                    style: context.display(18, weight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const Key('story-close'),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close, color: Palette.ink),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (chapter.art != null) ...[
                      StoryArt(companion: companion, radius: 16),
                      const SizedBox(height: 12),
                    ],
                    for (final line in chapter.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StoryLineText(companion: companion, line: line),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryLineText extends StatelessWidget {
  const _StoryLineText({required this.companion, required this.line});

  final Companion companion;
  final StoryLine line;

  @override
  Widget build(BuildContext context) {
    final who = storySpeakerName(line.who, companion);
    if (who == null) {
      return Text(line.text, style: const TextStyle(fontSize: 14, height: 1.55, color: Palette.subInk));
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$who ', style: context.display(14, color: Palette.subInk)),
          TextSpan(text: line.text),
        ],
      ),
      style: const TextStyle(fontSize: 15, height: 1.55, color: Palette.ink),
    );
  }
}
