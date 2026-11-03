import 'package:doobal/domain/display_font.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('표시 글꼴 세 가지: 개구(기본) 1.3배 · 동글 1.5배 · 고운 바탕 1.0배 (16장 11/3)', () {
    expect(DisplayFont.values.map((f) => (f.label, f.scale)),
        [('개구', 1.3), ('동글', 1.5), ('고운 바탕', 1.0)]);
    expect(DisplayFont.values.map((f) => f.family), ['Gaegu', 'Dongle', 'GowunBatang']);
  });

  test('저장한 이름으로 고른다. 없거나 모르는 이름이면 개구', () {
    expect(DisplayFont.fromName('dongle'), DisplayFont.dongle);
    expect(DisplayFont.fromName('batang'), DisplayFont.batang);
    expect(DisplayFont.fromName(null), DisplayFont.gaegu);
    expect(DisplayFont.fromName('comic'), DisplayFont.gaegu);
  });

  test('개구·동글은 줄 높이를 고운 바탕 정도로 줄인다 (배율 × 줄 높이가 1.43~1.5)', () {
    expect(DisplayFont.gaegu.scale * DisplayFont.gaegu.height!, closeTo(1.43, 0.01));
    expect(DisplayFont.dongle.scale * DisplayFont.dongle.height!, 1.5);
    expect(DisplayFont.batang.height, isNull);
  });
}
