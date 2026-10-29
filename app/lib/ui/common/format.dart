/// 1234567 → '1,234,567'
String formatInt(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// 12.34 → '12.3 km'
String formatKm(double km, {int digits = 1}) => '${km.toStringAsFixed(digits)} km';

/// 65초 → '1:05', 1시간 이상은 '1:02:03'. 음수는 0으로
String formatDuration(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = total % 3600 ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h == 0) return '$m:$ss';
  return '$h:${m.toString().padLeft(2, '0')}:$ss';
}

/// 날짜만 쓴다: '11월 24일'
String formatMonthDay(DateTime d) => '${d.month}월 ${d.day}일';
