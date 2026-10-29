import 'package:doobal/ui/common/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatInt: 천 단위 쉼표', () {
    expect(formatInt(0), '0');
    expect(formatInt(999), '999');
    expect(formatInt(1000), '1,000');
    expect(formatInt(12345), '12,345');
    expect(formatInt(1234567), '1,234,567');
    expect(formatInt(-1234), '-1,234');
  });

  test('formatKm: 기본 소수 1자리, 자리 수 지정', () {
    expect(formatKm(12.34), '12.3 km');
    expect(formatKm(0), '0.0 km');
    expect(formatKm(1.05, digits: 2), '1.05 km');
  });

  test('formatDuration: m:ss, 1시간 이상은 h:mm:ss, 음수는 0', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(minutes: 15)), '15:00');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatDuration(const Duration(seconds: -4)), '0:00');
  });

  test('formatMonthDay', () {
    expect(formatMonthDay(DateTime.utc(2026, 11, 8)), '11월 8일');
  });
}
