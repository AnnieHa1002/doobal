import 'dart:convert';

import 'rules.dart';
import 'time_kst.dart';

/// 알림 종류 (M6 명세). 우선순위 숫자는 notifications.json의 priority에서 읽는다 (낮을수록 먼저)
enum NoticeKind {
  /// 방명록 걸음 숫자
  n1,

  /// 도착
  n2,

  /// 이야기 새 장
  n3,

  /// 목적지 nearDestKm 안
  n4,

  /// 며칠 미접속
  n5;

  /// notifications.json의 id: 'N1'
  String get id => 'N${index + 1}';

  static NoticeKind? fromId(String id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }
}

/// 알림 문구 하나
class NoticeText {
  const NoticeText(this.title, this.body);

  final String title;
  final String body;
}

/// 종류 하나의 우선순위와 문구들 (종류마다 둘)
class NoticeSpec {
  const NoticeSpec(this.priority, this.texts);

  final int priority;
  final List<NoticeText> texts;
}

/// notifications.json. 종류의 id·priority·texts만 읽어서 문구 버전(v2의 `{이/가}` 토큰,
/// v3의 바뀐 본문)이 달라도 같은 코드로 읽힌다. 문구 속 토큰은 [fillNotice]가 채운다
class NoticeCatalog {
  const NoticeCatalog(this.specs);

  final Map<NoticeKind, NoticeSpec> specs;

  factory NoticeCatalog.fromJson(Map<String, dynamic> j) {
    final specs = <NoticeKind, NoticeSpec>{};
    for (final raw in j['kinds'] as List) {
      final k = raw as Map<String, dynamic>;
      final kind = NoticeKind.fromId(k['id'] as String) ??
          (throw FormatException('모르는 알림 종류: ${k['id']}'));
      final texts = [
        for (final t in k['texts'] as List)
          NoticeText((t as Map<String, dynamic>)['title'] as String, t['body'] as String),
      ];
      if (texts.isEmpty) throw FormatException('${kind.id}의 문구가 없다');
      specs[kind] = NoticeSpec(k['priority'] as int, texts);
    }
    for (final kind in NoticeKind.values) {
      if (!specs.containsKey(kind)) throw FormatException('알림 종류가 없다: ${kind.id}');
    }
    return NoticeCatalog(specs);
  }

  int priorityOf(NoticeKind kind) => specs[kind]!.priority;
}

/// 이번 동기화에서 새로 생긴 일 하나. [key]는 그 일을 가리키는 값 (N1은 기회 id, N2·N4는 여정 id).
/// 같은 (종류, key)로는 다시 알리지 않는다. [vars]는 문구에 채울 값:
/// milestone(int)·remainingKm(num)·dest·companion
class NoticeCandidate {
  const NoticeCandidate(this.kind, {this.key = '', this.vars = const {}});

  final NoticeKind kind;
  final String key;
  final Map<String, Object> vars;
}

/// 보낼 알림의 글과 눌렀을 때 쓸 값. payload는 'N1:m:3000' 꼴 (종류 id : key).
/// TODO(M6): 눌렀을 때 N1 → 방명록 쓰기, N2 → 도착 화면, N3 → 동행 화면의 그 장, N4·N5 → 쉼터
class NoticeMessage {
  const NoticeMessage(this.kind, this.key, this.title, this.body);

  final NoticeKind kind;
  final String key;
  final String title;
  final String body;

  String get payload => '${kind.id}:$key';
}

/// 알림 종류별 켜고 끄기: 전체 + 종류별. 기본은 모두 켬. 전체가 꺼져 있으면 종류별 값과 상관없이 모두 꺼진다
class NoticeSettings {
  const NoticeSettings({this.all = true, this.off = const {}});

  final bool all;

  /// 종류별로 꺼 둔 것
  final Set<NoticeKind> off;

  /// 그 종류가 실제로 켜져 있는가 (전체도 켜져 있어야 한다)
  bool isOn(NoticeKind kind) => all && !off.contains(kind);

  /// 켜져 있는 종류들 (판정에 들어가는 것)
  Set<NoticeKind> get enabled => {for (final k in NoticeKind.values) if (isOn(k)) k};

  NoticeSettings withAll(bool on) => NoticeSettings(all: on, off: off);

  NoticeSettings withKind(NoticeKind kind, bool on) =>
      NoticeSettings(all: all, off: on ? ({...off}..remove(kind)) : {...off, kind});
}

// ---------------------------------------------------------------------------------------------
// 조용한 시간 (한국 시간)

/// [t]가 조용한 시간인가: 한국 시간 quietFromHour시 정각부터 quietToHour시 정각 전까지
/// (밤을 넘긴다). 시작 정각은 조용하고 끝 정각은 아니다 (22시 정각 조용, 8시 정각 아님).
/// 두 시각이 같으면 조용한 시간이 없다
bool isQuietTime(DateTime t, Rules rules) {
  final from = rules.notificationQuietFromHour;
  final to = rules.notificationQuietToHour;
  if (from == to) return false;
  final h = kstDateTime(t).hour;
  return from < to ? (h >= from && h < to) : (h >= from || h < to);
}

/// [t] 뒤 처음 오는 한국 시간 quietToHour시 정각 (조용한 시간이 끝나는 때).
/// 조용한 시간 안의 시각이면 그 시간의 끝이다
DateTime quietEnd(DateTime t, Rules rules) {
  final today = kstDayKey(t);
  final day = kstDateTime(t).hour < rules.notificationQuietToHour ? today : addDays(today, 1);
  return kstDayStartUtc(day).add(Duration(hours: rules.notificationQuietToHour));
}

// ---------------------------------------------------------------------------------------------
// 보낼지 말지 (N1~N4)

/// 판정 결과
enum NoticeAction {
  /// 아무것도 안 한다 (꺼졌거나, 하루 최대에 막혔거나, 이미 예약된 게 더 높다)
  nothing,

  /// 앱이 켜져 있어서 시스템 알림은 안 보내고 화면 안 표시만 한다
  inApp,

  /// 지금 시스템 알림을 보낸다
  sendNow,

  /// 조용한 시간이라 [NoticeDecision.at](그 시간이 끝나는 08:00)에 하나만 예약한다
  schedule,
}

/// 조용한 시간에 예약해 둔 알림 하나 (N1~N4)
class PendingNotice {
  const PendingNotice(this.kind, this.at);

  final NoticeKind kind;

  /// 뜨기로 한 시각 (UTC)
  final DateTime at;
}

class NoticeDecision {
  const NoticeDecision(
    this.action, {
    this.chosen,
    this.message,
    this.at,
    this.replacesPending = false,
    this.dropped = const [],
  });

  final NoticeAction action;

  /// 고른 후보와 그 글. [action]이 nothing이면 null
  final NoticeCandidate? chosen;
  final NoticeMessage? message;

  /// schedule일 때 뜨는 시각 (UTC)
  final DateTime? at;

  /// schedule이 이미 예약된 것을 바꿔 끼우는 것이면 true (부른 쪽이 앞 예약을 취소한다)
  final bool replacesPending;

  /// 고르지 못한 후보 (꺼진 종류·우선순위에서 밀린 것·막혀서 보내지 않은 것 전부)
  final List<NoticeCandidate> dropped;
}

/// 한 번의 동기화에서 생긴 [candidates] 중 보낼 것 하나를 고른다 (M6 명세):
/// - 꺼진 종류는 뺀다. 남은 것 중 우선순위가 가장 높은 1개만 쓰고 나머지는 버린다
///   (우선순위 숫자가 같으면 앞에 온 것)
/// - 앱이 켜져 있으면 화면 안 표시만 한다 (하루 개수에도 안 센다)
/// - 한국 시간으로 하루 최대 dailyMax개 ([sentByDay]: 한국 날짜 → 그날 나갔거나 나가기로 한 시스템
///   알림 수. 아래 [pending]은 뺀다). 이미 찼으면 안 보낸다
/// - 조용한 시간에 생기면 끝나는 시각에 1개만 예약한다. 이미 예약된 [pending]보다 우선순위가
///   높으면 바꿔 끼우고, 같거나 낮으면 그대로 둔다. 하루 최대는 알림이 뜨는 날로 센다
///
/// [now]는 UTC, 글은 [installId]·종류·한국 날짜 시드로 2개 중 하나 ([buildNotice])
NoticeDecision pickNotice({
  required List<NoticeCandidate> candidates,
  required DateTime now,
  required Rules rules,
  required NoticeCatalog catalog,
  required String installId,
  required Set<NoticeKind> enabled,
  required Map<String, int> sentByDay,
  required bool inForeground,
  PendingNotice? pending,
}) {
  NoticeCandidate? best;
  for (final c in candidates) {
    if (!enabled.contains(c.kind)) continue;
    if (best == null || catalog.priorityOf(c.kind) < catalog.priorityOf(best.kind)) best = c;
  }
  if (best == null) return NoticeDecision(NoticeAction.nothing, dropped: candidates);
  final chosen = best;
  final others = [for (final c in candidates) if (!identical(c, chosen)) c];

  NoticeDecision skip() => NoticeDecision(NoticeAction.nothing, dropped: candidates);
  NoticeMessage message() => buildNotice(chosen, catalog, installId, now);

  if (inForeground) {
    return NoticeDecision(NoticeAction.inApp,
        chosen: chosen, message: message(), dropped: others);
  }

  final quiet = isQuietTime(now, rules);
  final at = quiet ? quietEnd(now, rules) : null;
  // 조용한 시간이 아니면 남아 있는 예약은 따지지 않는다
  final held = quiet ? pending : null;
  if (held != null && catalog.priorityOf(held.kind) <= catalog.priorityOf(chosen.kind)) {
    return skip();
  }
  if ((sentByDay[kstDayKey(at ?? now)] ?? 0) >= rules.notificationDailyMax) return skip();

  return NoticeDecision(
    quiet ? NoticeAction.schedule : NoticeAction.sendNow,
    chosen: chosen,
    message: message(),
    at: at,
    replacesPending: held != null,
    dropped: others,
  );
}

/// 이번 동기화에서 목적지 [nearKm] 안으로 들어왔는가: 전에는 남은 거리가 [nearKm]보다 컸고
/// 지금은 [nearKm] 이하. 여정마다 1번만 알리는 건 부른 쪽이 로그로 거른다
bool enteredNearDest({
  required double remainingBefore,
  required double remainingAfter,
  required double nearKm,
}) =>
    remainingBefore > nearKm && remainingAfter <= nearKm;

// ---------------------------------------------------------------------------------------------
// N5 (며칠 미접속)

/// 앱을 닫은 뒤 N5가 어떤 상태인가
enum InactiveState {
  /// 예약이 없다
  none,

  /// 예약돼 있고 아직 안 울렸다
  pending,

  /// 이미 울렸는데 앱을 아직 안 열었다 (다시 열 때까지 예약하지 않는다)
  fired,
}

/// 앱이 백그라운드로 갈 때 N5를 예약할 시각 (UTC). 예약하지 않으면 null:
/// 꺼져 있거나, 이미 예약돼 있거나(그대로 둔다), 이미 울렸는데 아직 안 열었을 때.
/// 지금 + inactiveHours가 조용한 시간이면 그 시간이 끝날 때로 미룬다 (밤에는 안 울린다)
DateTime? planInactive({
  required DateTime now,
  required Rules rules,
  required bool enabled,
  required InactiveState state,
}) {
  if (!enabled || state != InactiveState.none) return null;
  final at = now.toUtc().add(Duration(hours: rules.notificationInactiveHours));
  return isQuietTime(at, rules) ? quietEnd(at, rules) : at;
}

// ---------------------------------------------------------------------------------------------
// 문구

/// [candidate]의 글: 종류의 문구 2개 중 시드 hash(installId, 종류, 한국 날짜)로 하나를 고르고
/// 변수를 채운다. 같은 설치·종류·날짜는 늘 같은 글이다
NoticeMessage buildNotice(
  NoticeCandidate candidate,
  NoticeCatalog catalog,
  String installId,
  DateTime now,
) {
  final texts = catalog.specs[candidate.kind]!.texts;
  final seed = _mix32(_fnv1a32(utf8.encode('$installId:${candidate.kind.id}:${kstDayKey(now)}')));
  final text = texts[seed % texts.length];
  return NoticeMessage(
    candidate.kind,
    candidate.key,
    fillNotice(text.title, candidate.vars),
    fillNotice(text.body, candidate.vars),
  );
}

/// FNV-1a 32비트 해시 (sketch.dart와 같다)
int _fnv1a32(List<int> bytes) {
  var h = 0x811C9DC5;
  for (final b in bytes) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// 해시의 비트를 섞는다 (murmur3의 마무리). FNV-1a 그대로는 마지막 글자(날짜의 끝 숫자)가 아래 비트에만
/// 약하게 남아서, 날짜가 바뀌어도 같은 문구가 나오거나 홀짝으로만 바뀐다
int _mix32(int h) {
  h ^= h >> 16;
  h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
  h ^= h >> 13;
  h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
  return h ^ (h >> 16);
}

final _token = RegExp(r'\{([^{}]+)\}');

/// 문구의 `{변수}`와 조사 토큰(`{이/가}` 따위)을 채운다.
/// milestone은 천 단위 쉼표, remainingKm은 소수 1자리, dest·companion은 그대로.
/// 조사는 바로 앞 글자의 받침으로 고른다. 채울 값이 없는 변수나 모르는 토큰은 FormatException
String fillNotice(String template, Map<String, Object> vars) {
  final out = StringBuffer();
  var last = 0;
  for (final m in _token.allMatches(template)) {
    out.write(template.substring(last, m.start));
    last = m.end;
    final name = m[1]!;
    if (name.contains('/')) {
      out.write(josa(out.toString(), name) ?? (throw FormatException('모르는 조사: {$name}')));
    } else {
      final value = vars[name] ?? (throw FormatException('채울 값이 없다: {$name}'));
      out.write(switch (name) {
        'milestone' => _withCommas(value as int),
        'remainingKm' => (value as num).toStringAsFixed(1),
        _ => value.toString(),
      });
    }
  }
  out.write(template.substring(last));
  return out.toString();
}

String _withCommas(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// [before] 끝 글자에 받침이 있는가. 한글이 아니면(숫자·영문·기호) 받침 없는 것으로 본다
/// (읽는 소리까지는 따지지 않는다)
bool hasBatchim(String before) => _jongseong(before) > 0;

/// 끝 글자의 종성 번호 (0이면 받침 없음·한글 아님, ㄹ은 8)
int _jongseong(String before) {
  if (before.isEmpty) return 0;
  final c = before.runes.last;
  if (c < 0xAC00 || c > 0xD7A3) return 0;
  return (c - 0xAC00) % 28;
}

/// 받침 있을 때 / 없을 때 (조사 토큰은 어느 쪽을 먼저 써도 된다: `{이/가}`·`{가/이}`)
const _josaPairs = {'이': '가', '을': '를', '은': '는', '과': '와', '으로': '로'};

/// 조사 토큰 [token]('이/가'·'을/를'·'은/는'·'과/와'·'으로/로')에서 [before] 끝 글자 받침에 맞는
/// 쪽. '으로/로'는 ㄹ 받침이면 '로'. 모르는 토큰이면 null
String? josa(String before, String token) {
  final parts = token.split('/');
  if (parts.length != 2) return null;
  String? withBatchim;
  String? without;
  if (_josaPairs[parts[0]] == parts[1]) {
    (withBatchim, without) = (parts[0], parts[1]);
  } else if (_josaPairs[parts[1]] == parts[0]) {
    (withBatchim, without) = (parts[1], parts[0]);
  } else {
    return null;
  }
  final j = _jongseong(before);
  if (withBatchim == '으로' && j == 8) return without;
  return j > 0 ? withBatchim : without;
}
