/// 방명록 금칙어 (assets/data/moderation.json, M5에서는 Firestore config/moderation이 대신한다).
/// 검사 순서는 data/check_moderation.py가 정답지다. 서버(TypeScript)도 같은 순서로 만든다.
/// 시험 문장은 moderation_cases.json을 앱·서버 테스트가 같이 읽는다
class Moderation {
  Moderation({
    required this.message,
    required this.allowWords,
    required this.lookalike,
    required List<ModerationRule> rules,
  })  : _raw = [for (final r in rules) if (!r.tight) r],
        _tight = [for (final r in rules) if (r.tight) r];

  /// 막혔을 때 보여 주는 한 줄. 어떤 단어인지는 알려 주지 않는다 (기준 문서 6장)
  final String message;

  /// 검사에서 빼는 낱말 (시발점·한남동처럼 오탐이 나는 것)
  final List<String> allowWords;

  /// 닮은꼴 글자 치환표
  final Map<String, String> lookalike;

  final List<ModerationRule> _raw;
  final List<ModerationRule> _tight;

  factory Moderation.fromJson(Map<String, dynamic> j) => Moderation(
        message: j['message'] as String,
        allowWords: ((j['allow'] as Map<String, dynamic>)['words'] as List).cast<String>(),
        lookalike: ((j['normalize'] as Map<String, dynamic>)['lookalike'] as Map<String, dynamic>)
            .cast<String, String>(),
        rules: [
          for (final r in j['rules'] as List) ModerationRule.fromJson(r as Map<String, dynamic>),
        ],
      );

  /// 걸린 규칙. 통과면 null. [names]는 앱이 더하는 허용 이름(명소·시군구)이다
  ModerationRule? check(String text, {List<String> names = const []}) {
    final t = _maskAllowed(foldForModeration(text), [...allowWords, ...names]);
    for (final r in _raw) {
      if (r.re.hasMatch(t)) return r;
    }
    final (tt, index) = _tighten(t);
    for (final r in _tight) {
      for (final m in r.re.allMatches(tt)) {
        if (m.end == m.start) continue;
        final start = index[m.start];
        final end = index[m.end - 1] + 1;
        // 띄어쓰기를 건너뛴 일치는 낱말 첫머리에서 시작할 때만 인정한다
        if (_space.hasMatch(t.substring(start, end)) && !_wordStart(t, start)) continue;
        return r;
      }
    }
    return null;
  }

  bool isBlocked(String text, {List<String> names = const []}) =>
      check(text, names: names) != null;

  /// 닮은꼴 치환 → 한글·자모·영문·#만 남김 → 낱자 모아쓰기 → 같은 글자 2번까지 → 늘임 모음 빼기.
  /// 돌려주는 목록은 남은 글자마다 [t]에서의 자리다
  (String, List<int>) _tighten(String t) {
    final chars = <String>[];
    final index = <int>[];
    for (var i = 0; i < t.length; i++) {
      final c = lookalike[t[i]] ?? t[i];
      if (c.isEmpty || !_keep.hasMatch(c)) continue;
      // 자음 뒤에 모음이 오면 받침 없는 글자로 모은다 (ㄱ+ㅐ → 개). 자리는 자음 것을 쓴다
      final v = _jung.indexOf(c);
      if (v >= 0 && chars.isNotEmpty) {
        final l = _cho.indexOf(chars.last);
        if (l >= 0) {
          chars.last = String.fromCharCode(_syllableBase + l * 588 + v * 28);
          continue;
        }
      }
      chars.add(c);
      index.add(i);
    }
    final out = <String>[];
    final outIndex = <int>[];
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      if (out.length >= 2 && out.last == c && out[out.length - 2] == c) continue;
      if (out.isNotEmpty && _isStretch(out.last, c)) continue;
      out.add(c);
      outIndex.add(index[i]);
    }
    return (out.join(), outIndex);
  }
}

/// 규칙 하나. [tight]면 붙여 쓴 글에, 아니면 가린 원문에 검사한다
class ModerationRule {
  ModerationRule({required this.id, required this.category, required this.tight, required this.re});

  final String id;
  final String category;
  final bool tight;
  final RegExp re;

  factory ModerationRule.fromJson(Map<String, dynamic> j) => ModerationRule(
        id: j['id'] as String,
        category: j['cat'] as String,
        tight: switch (j['on']) {
          'raw' => false,
          'tight' => true,
          final on => throw FormatException('모르는 금칙어 규칙 자리: $on (${j['id']})'),
        },
        re: RegExp(j['re'] as String, caseSensitive: j['i'] != true),
      );
}

/// 1단계: NFC(한글만)·전각 ASCII → 반각·영문 소문자. Dart에 정규화가 없어서 한글 자모만 직접 모은다
String foldForModeration(String text) {
  final out = StringBuffer();
  for (final code in _composeHangul(text)) {
    out.writeCharCode(code >= 0xFF01 && code <= 0xFF5E ? code - 0xFEE0 : code);
  }
  return out.toString().toLowerCase();
}

/// 첫가끝 자모(U+1100~)를 완성형으로 모은다 (맥·일부 입력기가 풀어 쓴 한글)
List<int> _composeHangul(String text) {
  final out = <int>[];
  for (final c in text.runes) {
    if (out.isNotEmpty) {
      final p = out.last;
      if (p >= 0x1100 && p <= 0x1112 && c >= 0x1161 && c <= 0x1175) {
        out.last = _syllableBase + (p - 0x1100) * 588 + (c - 0x1161) * 28;
        continue;
      }
      final o = p - _syllableBase;
      if (o >= 0 && o < 11172 && o % 28 == 0 && c > 0x11A7 && c <= 0x11C2) {
        out.last = p + c - 0x11A7;
        continue;
      }
    }
    out.add(c);
  }
  return out;
}

/// 2단계: 허용 낱말을 같은 길이의 #으로 가린다(긴 것부터). 자리가 그대로라 원문과 맞출 수 있다
String _maskAllowed(String t, List<String> allow) {
  final words = [for (final w in allow) if (w.isNotEmpty) w]
    ..sort((a, b) => b.length.compareTo(a.length));
  var out = t;
  for (final raw in words) {
    final w = foldForModeration(raw);
    if (w.isNotEmpty) out = out.replaceAll(w, '#' * w.length);
  }
  return out;
}

/// 씨이발 → 씨발, 새애끼 → 새끼: 앞 글자에 받침이 없고, 뒤가 ㅇ + 앞과 같은 모음이면 늘임이다
bool _isStretch(String prev, String next) {
  final p = _splitSyllable(prev);
  final s = _splitSyllable(next);
  if (p == null || s == null) return false;
  return p.$3 == 0 && s.$1 == _cho.indexOf('ㅇ') && s.$3 == 0 && s.$2 == p.$2;
}

(int, int, int)? _splitSyllable(String c) {
  final o = c.codeUnitAt(0) - _syllableBase;
  if (o < 0 || o >= 11172) return null;
  return (o ~/ 588, (o % 588) ~/ 28, o % 28);
}

bool _wordStart(String t, int i) => i == 0 || !_wordChar.hasMatch(t[i - 1]);

const _syllableBase = 0xAC00;
const _cho = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
const _jung = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
final _keep = RegExp(r'^[가-힣ㄱ-ㅣa-z#]');
final _space = RegExp(r'\s');
final _wordChar = RegExp(r'[가-힣ㄱ-ㅣa-z0-9#]');
