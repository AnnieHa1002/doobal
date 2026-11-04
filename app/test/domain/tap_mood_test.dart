import 'package:doobal/domain/tap_mood.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _t0 = DateTime.utc(2026, 11, 18, 9);

/// t0에서 [ms] 밀리초 뒤
DateTime _at(int ms) => _t0.add(Duration(milliseconds: ms));

void main() {
  test('config: 3초 안에 5번이면 2초 화남', () {
    final r = rules.tapReaction;
    expect((r.angryWindowSec, r.angryTaps, r.angryHoldSec), (3, 5, 2));
  });

  test('안 눌렀으면 반응 없음', () {
    expect(tapMood([], _t0, rules), TapMood.none);
  });

  test('한 번·네 번은 행복', () {
    expect(tapMood([_at(0)], _at(0), rules), TapMood.happy);
    final four = [_at(0), _at(500), _at(1000), _at(1500)];
    expect(tapMood(four, _at(1500), rules), TapMood.happy);
  });

  test('3초 안에 다섯 번은 화남', () {
    final five = [_at(0), _at(500), _at(1000), _at(1500), _at(2000)];
    expect(tapMood(five, _at(2000), rules), TapMood.angry);
    // 여섯 번째도 화남
    expect(tapMood([...five, _at(2200)], _at(2200), rules), TapMood.angry);
  });

  test('3초를 넘긴 다섯 번은 행복', () {
    final slow = [_at(0), _at(1000), _at(2000), _at(3001), _at(3500)];
    expect(tapMood(slow, _at(3500), rules), TapMood.happy);
  });

  test('경계: 정확히 3초에 걸친 다섯 번은 화남, 1밀리초 넘으면 행복', () {
    expect(tapMood([_at(0), _at(750), _at(1500), _at(2250), _at(3000)], _at(3000), rules),
        TapMood.angry);
    expect(tapMood([_at(0), _at(750), _at(1500), _at(2250), _at(3001)], _at(3001), rules),
        TapMood.happy);
  });

  test('창이 지난 옛 누름은 세지 않는다 (느린 세 번 뒤 빠른 네 번은 행복)', () {
    final taps = [_at(0), _at(1000), _at(2000), _at(10000), _at(10100), _at(10200), _at(10300)];
    expect(tapMood(taps, _at(10300), rules), TapMood.happy);
  });
}
