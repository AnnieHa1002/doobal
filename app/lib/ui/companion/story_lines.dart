import '../../app/sync_service.dart';
import '../../domain/companion_engine.dart';
import '../../domain/rules.dart';
import 'meet_flow.dart' show withName;

// 동행 이야기 진행을 부르는 글 (캔버스 3-1 걷는 중, 3-3 걷기 기록)

/// 걷는 중 펼침 카드의 동행 줄: ‘퐁이 이야기 2/4’. 이야기를 끝까지 열었으면 ‘퐁이와 함께 걷는 중’
String walkingStoryLine(MetCompanion now, Rules rules) {
  final n = walksToNextChapter(now.walksTogether, now.chapter, rules);
  return n == null
      ? '${withName(now.companion)} 함께 걷는 중'
      : '${now.companion.name} 이야기 $n/${rules.companionWalksPerChapter}';
}

/// 걷기 기록: ‘이야기 3장이 열렸어요’
String storyOpenedLine(int chapter) => '이야기 $chapter장이 열렸어요';

/// 걷기 기록: 열린 장 아래 작은 글 ‘함께 걷기 4번째’ (그 장까지 몇 번째 걷기였나)
String storyOpenedSub(Rules rules) => '함께 걷기 ${rules.companionWalksPerChapter}번째';

/// 걷기 기록: ‘이야기 3장까지 함께 걷기 3/4’
String storyProgressLine(WalkStory story, Rules rules) =>
    '이야기 ${story.next}장까지 함께 걷기 ${story.walks}/${rules.companionWalksPerChapter}';
