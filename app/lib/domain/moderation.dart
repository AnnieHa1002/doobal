import 'package:korean_profanity_filter/korean_profanity_filter.dart';

/// 방명록 쓰는 중에 보여 주는 안내. 어떤 단어인지는 알려 주지 않는다 (기준 문서 6장)
const blockedMessage = '이 표현은 방명록에 남길 수 없어요';

/// 혐오·성적 표현 시작 목록 (기획/방명록_금칙어.md v02: 혐오 22개·성적 16개).
/// TODO: 원문이 리포에 아직 없어서 비워 둔다. 파일이 들어오면 여기에 넣는다.
/// M5에서는 Firestore config/moderation에서 받은 목록이 이것을 대신한다 (extraBlockedWordsProvider)
const starterWords = <String>[];

final _notWord = RegExp(r'[^\p{L}\p{N}]', unicode: true);

/// 검사용으로 다듬은 글: 소문자로 바꾸고 글자·숫자가 아닌 것(공백·특수문자)을 모두 뺀다
String normalizeForModeration(String text) => text.toLowerCase().replaceAll(_notWord, '');

/// 방명록에 남길 수 없는 글인가. 앱과 서버가 같은 규칙으로 두 번 검사한다 (이 함수는 앱 쪽).
/// - 욕설: korean_profanity_filter(MIT) 정규식. 글을 그대로 검사한다 (공백을 지워 붙이면
///   "5시 발걸음"처럼 다른 낱말이 이어져 멀쩡한 글이 걸린다)
/// - [extraWords]: 혐오·성적 표현 목록. 공백·특수문자를 뺀 글에 부분 일치로 본다
/// - [allowedNames]: 이 이름이 글에 그대로 들어 있으면 그 부분은 검사에서 뺀다 (명소 이름 오탐 방지).
///   긴 이름부터 뺀다
bool isBlocked(
  String text, {
  List<String> extraWords = const [],
  List<String> allowedNames = const [],
}) {
  final checked = _withoutAllowed(text, allowedNames);
  if (checked.containsBadWords) return true;
  if (extraWords.isEmpty) return false;
  final flat = normalizeForModeration(checked);
  for (final word in extraWords) {
    final w = normalizeForModeration(word);
    // 빈 낱말은 모든 글에 들어 있는 것으로 나온다
    if (w.isNotEmpty && flat.contains(w)) return true;
  }
  return false;
}

/// [text]에서 허용 이름을 공백으로 바꾼다 (공백이라 앞뒤 글자가 붙어 새 낱말이 되지 않는다)
String _withoutAllowed(String text, List<String> allowedNames) {
  if (allowedNames.isEmpty) return text;
  final names = allowedNames.where((n) => n.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  var result = text;
  for (final name in names) {
    result = result.replaceAll(name, ' ');
  }
  return result;
}
