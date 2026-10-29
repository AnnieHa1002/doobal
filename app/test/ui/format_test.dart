import 'package:doobal/domain/journey.dart';
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

  test('regionLabels: 칩 순서대로 수도권·강원·충청·전라·경상·제주·울릉', () {
    expect(regionLabels.keys,
        ['capital', 'gangwon', 'chungcheong', 'jeolla', 'gyeongsang', 'jeju', 'ulleung']);
    expect(regionLabels.values, ['수도권', '강원', '충청', '전라', '경상', '제주', '울릉']);
  });

  test('terrainLabels·frameLabel', () {
    expect(terrainLabels, {'mountain': '산길', 'coast': '바닷가', 'field': '들판', 'city': '도시'});
    expect([for (final f in Frame.values) frameLabel(f)], ['나무 액자', '은 액자', '금 액자']);
  });

  test('frameName: 나무·은·금', () {
    expect([for (final f in Frame.values) frameName(f)], ['나무', '은', '금']);
  });

  group('revisitLine', () {
    test('첫 방문은 줄이 없다', () {
      expect(revisitLine(1, null, Frame.gold, null), isNull);
    });

    test('액자가 오르면 `이전 → 새으로 바뀌었어요`', () {
      expect(revisitLine(2, Frame.silver, Frame.gold, 32.4), '은 → 금으로 바뀌었어요');
      expect(revisitLine(2, Frame.wood, Frame.gold, 3), '나무 → 금으로 바뀌었어요');
      expect(revisitLine(3, Frame.wood, Frame.silver, 3), '나무 → 은으로 바뀌었어요');
    });

    test('그대로면 지난번 거리를 정수로 반올림해서 붙인다', () {
      expect(revisitLine(2, Frame.silver, Frame.silver, 32.4), '액자는 그대로예요 (지난번 32km)');
      expect(revisitLine(2, Frame.gold, Frame.gold, 49.6), '액자는 그대로예요 (지난번 50km)');
      expect(revisitLine(2, Frame.wood, Frame.wood, 0.4), '액자는 그대로예요 (지난번 0km)');
    });

    test('지난번 거리를 모르면 괄호 없이', () {
      expect(revisitLine(2, Frame.wood, Frame.wood, null), '액자는 그대로예요');
    });
  });

  test('propSlotLabels: 소품 탭 순서 모자·옷·손·가방·신발·어깨 친구', () {
    expect(propSlotLabels.keys, ['hat', 'cloth', 'hand', 'bag', 'shoe', 'pet']);
    expect(propSlotLabels.values, ['모자', '옷', '손', '가방', '신발', '어깨 친구']);
  });
}
