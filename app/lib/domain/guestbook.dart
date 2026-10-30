import 'dart:math' as math;

/// 방명록 쓸 기회와 글 검사 (기준 문서 6장). 기회는 두 가지, 이월은 없다:
/// 목적지에 도착할 때 1번(다음 여정을 시작하기 전까지), 걸음 숫자를 달성할 때 1번(알림 뒤 500보 안)
enum TicketKind { arrival, milestone }

/// 도착 기회의 id. 여정마다 하나라 같은 도착으로 기회를 두 번 만들지 않는다
String arrivalTicketId(String journeyId) => 'a:$journeyId';

/// 걸음 숫자 기회의 id. 숫자마다 하나다
String milestoneTicketId(int milestone) => 'm:$milestone';

/// 걸음 숫자 기회가 '어디서' 쓴 글인지: 'steps:12345'
String milestoneScope(int milestone) => 'steps:$milestone';

const _stepsScopePrefix = 'steps:';

/// [milestoneScope]의 숫자. 걸음 숫자 scope가 아니면 null
int? milestoneOfScope(String scope) => scope.startsWith(_stepsScopePrefix)
    ? int.tryParse(scope.substring(_stepsScopePrefix.length))
    : null;

/// 총 걸음 [totalSteps]까지 달성한 걸음 숫자 전부 (오름차순 그대로).
/// 숫자와 같은 걸음이면 달성이다. [milestones]는 milestones.json의 stepMilestones
List<int> milestonesReached(int totalSteps, List<int> milestones) =>
    [for (final m in milestones) if (m <= totalSteps) m];

/// 걸음 숫자 기회의 남은 걸음: 알림이 뜬 뒤 걸은 [stepsSinceOpened]만큼 [window]에서 줄고
/// 0에서 멈춘다. 0이면 기회가 닫힌 것이다 (500보를 걸으면 닫히고, 499보까지는 열려 있다)
int stepsLeft(int window, int stepsSinceOpened) => math.max(0, window - stepsSinceOpened);

/// 글 길이. 글자(rune) 수라서 이모지 하나도 한 글자로 센다
int postLength(String text) => text.runes.length;

/// 올릴 글: 앞뒤 공백을 자른 글이 비어 있지 않고 [maxChars] 이하면 그 글, 아니면 null
String? cleanPost(String text, int maxChars) {
  final t = text.trim();
  if (t.isEmpty || postLength(t) > maxChars) return null;
  return t;
}

/// 입력 칸이 [maxChars]를 넘지 않게 자른다 (붙여 넣기용). 글자(rune) 기준
String clipPost(String text, int maxChars) =>
    postLength(text) <= maxChars ? text : String.fromCharCodes(text.runes.take(maxChars));
