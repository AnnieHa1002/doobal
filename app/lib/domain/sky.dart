import 'color.dart';
import 'rules.dart';
import 'sun.dart';
import 'time_kst.dart';

/// 하늘 5단계 (새벽·아침·낮·노을·밤)
enum SkyPhase { dawn, morning, day, sunset, night }

/// 하루 안의 하늘 기준점. [minute]은 그 한국 날짜 0시부터 지난 분
class SkyKey {
  const SkyKey(this.minute, this.phase);

  final double minute;
  final SkyPhase phase;
}

/// 그날의 기준점 7개, 시간 순: 밤 끝(밤) · 새벽 · 아침 · 낮 시작(낮) · 낮 끝(낮) · 노을 · 밤 시작(밤).
/// 일출·일몰에서 config scene.sky의 분 간격만큼 떨어진 시각이다.
/// 순서가 뒤집히면 StateError (한국에서는 일어나지 않는다)
List<SkyKey> skyKeys(SunTimes sun, Rules rules) {
  final sr = _kstMinutes(sun.sunrise);
  final ss = _kstMinutes(sun.sunset);
  final keys = [
    SkyKey(sr + rules.skyNightEndMin, SkyPhase.night),
    SkyKey(sr + rules.skyDawnMin, SkyPhase.dawn),
    SkyKey(sr + rules.skyMorningMin, SkyPhase.morning),
    SkyKey(sr + rules.skyDayStartMin, SkyPhase.day),
    SkyKey(ss + rules.skyDayEndMin, SkyPhase.day),
    SkyKey(ss + rules.skySunsetMin, SkyPhase.sunset),
    SkyKey(ss + rules.skyNightStartMin, SkyPhase.night),
  ];
  for (var i = 1; i < keys.length; i++) {
    if (keys[i].minute <= keys[i - 1].minute) {
      throw StateError('하늘 기준점 순서가 맞지 않는다: ${keys[i - 1].minute} → ${keys[i].minute}');
    }
  }
  return keys;
}

/// 지금 하늘 = [from]에서 [to]로 [t](0~1)만큼 간 상태. 머무는 구간은 from == to, t = 0
class SkyMix {
  const SkyMix(this.from, this.to, this.t);

  final SkyPhase from;
  final SkyPhase to;
  final double t;

  /// 더 가까운 쪽 단계 (딱 중간은 to)
  SkyPhase get dominant => t < 0.5 ? from : to;

  @override
  bool operator ==(Object other) =>
      other is SkyMix && other.from == from && other.to == to && other.t == t;

  @override
  int get hashCode => Object.hash(from, to, t);

  @override
  String toString() => 'SkyMix($from → $to, $t)';
}

/// 지금 시각의 하늘 섞임. 첫 기준점 전과 마지막 기준점 뒤는 밤, 두 낮 기준점 사이는 낮에 머문다.
/// 기준점 사이는 선형. sun은 utc가 속한 한국 날짜의 일출·일몰이어야 한다
SkyMix skyMixAt(DateTime utc, SunTimes sun, Rules rules) {
  final keys = skyKeys(sun, rules);
  final m = _kstMinutes(utc);
  if (m < keys.first.minute) return const SkyMix(SkyPhase.night, SkyPhase.night, 0);
  for (var i = 0; i + 1 < keys.length; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (m >= b.minute) continue;
    if (a.phase == b.phase) return SkyMix(a.phase, a.phase, 0);
    return SkyMix(a.phase, b.phase, (m - a.minute) / (b.minute - a.minute));
  }
  return SkyMix(keys.last.phase, keys.last.phase, 0);
}

/// 그릴 하늘: 세로 그라디언트 세 색(위·가운데·지평선), 빛무리 색·세기, 별 불투명도.
/// 색은 불투명 ARGB
class SkyLook {
  const SkyLook({
    required this.top,
    required this.mid,
    required this.horizon,
    required this.glow,
    required this.glowStrength,
    required this.stars,
  });

  final int top;
  final int mid;
  final int horizon;
  final int glow;
  final double glowStrength;
  final double stars;

  @override
  bool operator ==(Object other) =>
      other is SkyLook &&
      other.top == top &&
      other.mid == mid &&
      other.horizon == horizon &&
      other.glow == glow &&
      other.glowStrength == glowStrength &&
      other.stars == stars;

  @override
  int get hashCode => Object.hash(top, mid, horizon, glow, glowStrength, stars);
}

/// 섞임 → 하늘. 색은 채널별 반올림, 세기·별은 선형
SkyLook skyLookOf(SkyMix mix, Rules rules) {
  final a = rules.skyKeys[mix.from.name]!;
  final b = rules.skyKeys[mix.to.name]!;
  return SkyLook(
    top: lerpArgb(a.top, b.top, mix.t),
    mid: lerpArgb(a.mid, b.mid, mix.t),
    horizon: lerpArgb(a.horizon, b.horizon, mix.t),
    glow: lerpArgb(a.glow, b.glow, mix.t),
    glowStrength: _lerp(a.glowStrength, b.glowStrength, mix.t),
    stars: _lerp(rules.skyStars[mix.from.name] ?? 0, rules.skyStars[mix.to.name] ?? 0, mix.t),
  );
}

enum SkyBody { sun, moon, none }

/// 호 위의 해·달. progress 0 = 왼쪽(뜸), 1 = 오른쪽(짐)
class Celestial {
  const Celestial(this.body, this.progress);

  final SkyBody body;
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is Celestial && other.body == body && other.progress == progress;

  @override
  int get hashCode => Object.hash(body, progress);

  @override
  String toString() => 'Celestial($body, $progress)';
}

/// 지금 하늘에 있는 해·달. 해는 일출~일몰, 달은 밤 시작~(다음 날) 밤 끝에 같은 호를 지난다.
/// 자정 뒤쪽도 같은 날의 일출·일몰로 재서 실제와 2분 안쪽으로 어긋난다 (근사).
/// 해도 달도 없는 사이는 빛무리만 남는다: 해 진 뒤~달 뜨기 전은 해 진 자리(1),
/// 달 진 뒤~해 뜨기 전은 해 뜰 자리(0).
/// sun은 utc가 속한 한국 날짜의 일출·일몰이어야 한다
Celestial celestialAt(DateTime utc, SunTimes sun, Rules rules) {
  final m = _kstMinutes(utc);
  final sr = _kstMinutes(sun.sunrise);
  final ss = _kstMinutes(sun.sunset);
  if (m >= sr && m < ss) return Celestial(SkyBody.sun, (m - sr) / (ss - sr));

  final nightStart = ss + rules.skyNightStartMin;
  final nightEnd = sr + rules.skyNightEndMin;
  final moonSpan = nightEnd + _dayMinutes - nightStart;
  if (m >= nightStart) return Celestial(SkyBody.moon, (m - nightStart) / moonSpan);
  if (m < nightEnd) return Celestial(SkyBody.moon, (m + _dayMinutes - nightStart) / moonSpan);
  return Celestial(SkyBody.none, m >= ss ? 1 : 0);
}

const _dayMinutes = 1440.0;

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// 그 시각이 속한 한국 날짜 0시부터 지난 분
double _kstMinutes(DateTime utc) =>
    utc.difference(kstDayStartUtc(kstDayKey(utc))).inMicroseconds /
    Duration.microsecondsPerMinute;
