import 'rules.dart';

/// 정령을 누른 뒤의 표정: 행복 · 화남 · 반응 없음
enum TapMood { happy, angry, none }

/// 지금([now])까지 누른 시각들([tapTimes], 마지막이 방금 누른 것)로 정한 반응 (config character.tapReaction).
/// 창(angryWindowSec) 안에 angryTaps번 이상이면 화남, 한 번이라도 눌렀으면 행복, 안 눌렀으면 없음.
/// 창은 닫힌 구간이라 정확히 3초 간격의 5번도 화남이다. now보다 늦은 시각은 세지 않는다
TapMood tapMood(List<DateTime> tapTimes, DateTime now, Rules rules) {
  final r = rules.tapReaction;
  final windowMs = (r.angryWindowSec * 1000).round();
  var inWindow = 0;
  var any = false;
  for (final t in tapTimes) {
    final age = now.difference(t).inMilliseconds;
    if (age < 0) continue;
    any = true;
    if (age <= windowMs) inWindow++;
  }
  if (inWindow >= r.angryTaps) return TapMood.angry;
  return any ? TapMood.happy : TapMood.none;
}
