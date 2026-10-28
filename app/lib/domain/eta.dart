import 'rules.dart';
import 'time_kst.dart';

/// 도착 예정일 = 오늘 + ceil(남은 거리 ÷ 하루 평균).
/// 평균은 첫 기록일부터 어제까지(최대 etaWindowDays일), 기록 없는 날은 0km.
/// 그런 날이 없거나 평균이 0이면 기본값(7,000보 × 0.7m). 남은 거리 0이면 오늘
DateTime etaDate(
  double remainingKm,
  Map<String, double> dailyKm,
  String todayKst,
  String firstRecordDay,
  Rules rules,
) {
  final today = dayFromKey(todayKst);
  if (remainingKm <= 0) return today;

  final completed = today.difference(dayFromKey(firstRecordDay)).inDays;
  final n = completed.clamp(0, rules.etaWindowDays);
  var sum = 0.0;
  for (var i = 1; i <= n; i++) {
    sum += dailyKm[addDays(todayKst, -i)] ?? 0;
  }
  final avg = (n == 0 || sum <= 0) ? rules.defaultDailyKm : sum / n;

  // 49 ÷ 4.9 같은 나눗셈이 부동소수 오차로 10.000…1이 되어 하루 늘지 않게 아주 작은 값을 뺀다
  final days = (remainingKm / avg - 1e-9).ceil();
  return DateTime.utc(today.year, today.month, today.day + days);
}
