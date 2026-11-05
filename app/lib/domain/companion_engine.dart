import 'companion.dart';
import 'road_event.dart' show eventSeed;
import 'rules.dart';

// 동행 규칙 (M4): 어느 칸에서 누구를 만나는가, 누구와 걸었나, 이야기가 몇 장 열렸나.
// 화면·DB 없는 순수 계산이다

const _msPerMin = 60000;

/// [metCount]명을 만난 뒤 다음 칸에서 반드시 만나야 하는가.
/// 아무도 못 만났으면 늘 그렇고(첫 실제 여정의 첫 칸), 그다음은 설치 후 [guaranteeDays]째 날부터
bool meetingDue({
  required int metCount,
  required int installAgeDays,
  required List<int> guaranteeDays,
}) {
  if (metCount == 0) return true;
  final i = metCount - 1;
  return i < guaranteeDays.length && installAgeDays >= guaranteeDays[i];
}

/// 이 칸에서 만날 동행. 안 만나면 null.
/// 시드 hash(설치 번호, 여정, k)로 정해서 같은 칸은 늘 같은 결과다.
/// 지형이 맞는 동행이 있으면 그 칸의 확률이 오르고, 만날 때도 그 동행이 먼저다
Companion? pickMeeting({
  required List<Companion> companions,
  required Set<String> metIds,
  required String terrain,
  required int installAgeDays,
  required String installId,
  required String journeyId,
  required int k,
  required Rules rules,
}) {
  final unmet = [
    for (final c in companions)
      if (!metIds.contains(c.id)) c,
  ];
  if (unmet.isEmpty) return null;
  final matching = [
    for (final c in unmet)
      if (c.terrain == terrain) c,
  ];
  final key = '$installId|$journeyId|$k';
  final due = meetingDue(
    metCount: companions.length - unmet.length,
    installAgeDays: installAgeDays,
    guaranteeDays: rules.companionGuaranteeDays,
  );
  if (!due) {
    final chance =
        matching.isNotEmpty ? rules.companionMeetChanceMatch : rules.companionMeetChanceOther;
    if (_roll('$key|meet') >= chance) return null;
  }
  final pool = matching.isNotEmpty ? matching : unmet;
  return pool[eventSeed('$key|who') % pool.length];
}

/// 시드로 정한 0 이상 1 미만의 값
double _roll(String key) => eventSeed(key) / 0x100000000;

/// [CompanionStints] 한 줄: [startUtc](ms)부터 다음 줄 앞까지 [companionId]와 걷는다 (null은 혼자)
class CompanionStint {
  const CompanionStint(this.startUtc, this.companionId);

  final int startUtc;
  final String? companionId;
}

/// [atUtc](ms)에 함께 걷던 동행 (없거나 혼자면 null). [stints]는 시작 시각 순서.
/// 걷기 1번의 시작은 분 단위로 내려가므로 분으로 맞춰 본다: 고른 뒤 그 분 안에 걷기 시작해도 함께 걸은 것이다
String? companionAt(List<CompanionStint> stints, int atUtc) {
  final minute = atUtc ~/ _msPerMin;
  String? out;
  for (final s in stints) {
    if (s.startUtc ~/ _msPerMin > minute) break;
    out = s.companionId;
  }
  return out;
}

/// 동행마다 함께 인정된 걷기 1번 수. [countedStarts]는 인정된 걷기 1번의 시작 시각(ms).
/// 그 시각에 함께 걷던 동행에게만 센다 (혼자 걷기는 어디에도 안 쌓인다).
/// 저장된 기록에서 늘 처음부터 세므로 같은 기록이면 같은 값이다
Map<String, int> walksTogether(List<int> countedStarts, List<CompanionStint> stints) {
  final sorted = [...stints]..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  final out = <String, int>{};
  for (final start in countedStarts) {
    final id = companionAt(sorted, start);
    if (id != null) out[id] = (out[id] ?? 0) + 1;
  }
  return out;
}

/// 함께 걷기 [walks]번으로 열리는 장 (0 = 프롤로그뿐, 끝은 rules.companionChapters)
int openedChapter(int walks, Rules rules) {
  final n = walks ~/ rules.companionWalksPerChapter;
  return n > rules.companionChapters ? rules.companionChapters : n;
}

/// 다음 장까지 함께 걷기 진행 n (`n/walksPerChapter`). 마지막 장까지 열렸으면 null
int? walksToNextChapter(int walks, int chapter, Rules rules) =>
    chapter >= rules.companionChapters ? null : walks % rules.companionWalksPerChapter;

/// 동행 그림에서 숨길 층. 완결 소품을 건넨 뒤(마지막 장이 열린 뒤)에만 있다 (심 박사 안경)
String? hiddenLayerOf(Companion companion, int chapter, Rules rules) =>
    chapter >= rules.companionChapters ? companion.hideLayerOnFinale : null;

/// 이야기 한 장을 가리키는 값 (알림 N3·걷기 기록 ‘읽기’)
class StoryRef {
  const StoryRef(this.companionId, this.no);

  final String companionId;
  final int no;
}

/// N3 알림의 key: 'bright:3'. 같은 동행의 같은 장은 다시 알리지 않는다
String storyNoticeKey(String companionId, int no) => '$companionId:$no';

/// [storyNoticeKey]를 되돌린다. 모양이 다르면 null
StoryRef? parseStoryNoticeKey(String key) {
  final colon = key.lastIndexOf(':');
  if (colon <= 0) return null;
  final no = int.tryParse(key.substring(colon + 1));
  return no == null ? null : StoryRef(key.substring(0, colon), no);
}

/// 걷기 한 번이 그 동행의 이야기에 어떻게 닿았나 (걷기 기록)
class WalkStory {
  const WalkStory({required this.companionId, this.opened, this.next, this.walks = 0});

  final String companionId;

  /// 이 걷기로 열린 장. 없으면 null
  final int? opened;

  /// 다음 장 번호. 마지막 장까지 열렸으면 null
  final int? next;

  /// 다음 장까지 걸은 수 ([next]가 null이면 0)
  final int walks;
}

/// 걷기 한 번의 이야기 값. [thisWalk]는 이 걷기의 인정된 구간 시작(ms), [countedStarts]는 인정된 구간 전부.
/// 동행은 이 걷기의 인정된 구간을 시작할 때 함께 걷던 동행이다. 인정된 구간이 없거나 그때 혼자였으면
/// 걷기를 시작한 [startUtc] 때의 동행으로 지금까지의 진행만 보여 준다. 혼자였으면 null.
/// [beforeUtc] 앞의 기록만 세므로 지난 걷기를 다시 볼 때는 그때의 값이다
WalkStory? walkStoryOf({
  required List<int> countedStarts,
  required List<int> thisWalk,
  required List<CompanionStint> stints,
  required int startUtc,
  required int beforeUtc,
  required Rules rules,
}) {
  final sorted = [...stints]..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  String? id;
  for (final s in thisWalk) {
    id = companionAt(sorted, s) ?? id;
  }
  id ??= companionAt(sorted, startUtc);
  if (id == null) return null;
  final after = countedStarts.where((s) => s < beforeUtc && companionAt(sorted, s) == id).length;
  final added = thisWalk.where((s) => s < beforeUtc && companionAt(sorted, s) == id).length;
  final chapter = openedChapter(after, rules);
  final open = chapter > openedChapter(after - added, rules);
  final last = chapter >= rules.companionChapters;
  return WalkStory(
    companionId: id,
    opened: open ? chapter : null,
    next: last ? null : chapter + 1,
    walks: last ? 0 : after % rules.companionWalksPerChapter,
  );
}

/// 이야기를 한 번에 보는 단위: 말 한 줄과 그 앞의 지문
class StoryBeat {
  const StoryBeat({required this.who, required this.text, this.direction});

  /// 말하는 이. 지문만 남은 끝줄은 [StorySpeaker.narr]
  final StorySpeaker who;
  final String text;

  /// 이 줄 앞의 지문 (없으면 null)
  final String? direction;
}

/// 지문은 다음 말 줄에 붙인다 (캔버스 3-4 길 위 만남). 말이 안 따라오는 끝 지문은 그대로 한 단위다.
/// 지문이 이어지면 한 줄로 합친다
List<StoryBeat> storyBeats(List<StoryLine> lines) {
  final out = <StoryBeat>[];
  String? pending;
  for (final l in lines) {
    if (l.who == StorySpeaker.narr) {
      pending = pending == null ? l.text : '$pending ${l.text}';
      continue;
    }
    out.add(StoryBeat(who: l.who, text: l.text, direction: pending));
    pending = null;
  }
  if (pending != null) out.add(StoryBeat(who: StorySpeaker.narr, text: pending));
  return out;
}
