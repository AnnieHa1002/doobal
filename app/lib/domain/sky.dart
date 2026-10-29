import 'rules.dart';
import 'sun.dart';
import 'time_kst.dart';

/// 하늘 5단계 (새벽·아침·낮·노을·밤)
enum SkyPhase { dawn, morning, day, sunset, night }

/// 하늘 띠 기준 시각 [0, 24). 한국 시계 시각을 일출·일몰로 구간별 선형 환산한다:
/// [0:00, 일출] → [0, 6], [일출, 일몰] → [6, 18], [일몰, 24:00] → [18, 24].
/// sun은 utc가 속한 한국 날짜의 일출·일몰이어야 한다
double skyRefHour(DateTime utc, SunTimes sun) {
  final h = _kstHours(utc);
  final sunrise = _kstHours(sun.sunrise);
  final sunset = _kstHours(sun.sunset);
  if (h < sunrise) return 6 * h / sunrise;
  if (h < sunset) return 6 + 12 * (h - sunrise) / (sunset - sunrise);
  return 18 + 6 * (h - sunset) / (24 - sunset);
}

/// 기준 시각 → 하늘 띠의 x(px). 띠는 24시간이고 양 끝이 같은 밤이라 이어 붙는다
double skyBandX(double refHour, double bandWidthPx) => refHour / 24 * bandWidthPx;

/// 기준 시각 → 5단계. 밤은 [night, 24)과 [0, dawn)
SkyPhase skyPhaseAt(double refHour, Rules rules) {
  if (refHour >= rules.skyNightHour || refHour < rules.skyDawnHour) return SkyPhase.night;
  if (refHour >= rules.skySunsetHour) return SkyPhase.sunset;
  if (refHour >= rules.skyDayHour) return SkyPhase.day;
  if (refHour >= rules.skyMorningHour) return SkyPhase.morning;
  return SkyPhase.dawn;
}

/// 한국 시계로 그날 0시부터 지난 시간(h)
double _kstHours(DateTime utc) =>
    utc.difference(kstDayStartUtc(kstDayKey(utc))).inMicroseconds /
    Duration.microsecondsPerHour;
