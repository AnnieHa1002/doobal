const _kstOffset = Duration(hours: 9);

/// 한국 시간 날짜 'yyyy-MM-dd'. 기기 시간대와 상관없다
String kstDayKey(DateTime utc) => _format(utc.toUtc().add(_kstOffset));

/// 'yyyy-MM-dd' → 그 날짜의 UTC 0시 (날짜 계산용, 시각은 의미 없음)
DateTime dayFromKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

/// 그 한국 날짜가 시작하는 시각(UTC)
DateTime kstDayStartUtc(String key) => dayFromKey(key).subtract(_kstOffset);

String addDays(String key, int days) {
  final d = dayFromKey(key);
  return _format(DateTime.utc(d.year, d.month, d.day + days));
}

String _format(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String _two(int n) => n.toString().padLeft(2, '0');
