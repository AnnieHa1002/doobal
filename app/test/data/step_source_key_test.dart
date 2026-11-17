import 'package:doobal/data/step_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // health 패키지: iOS는 sourceId = HealthKit 출처 번들 id, 안드로이드는 sourceId 빈 값 + sourceName = Health Connect
  // dataOrigin 패키지 이름 (11/17 폰: 271개 모두 빈 sourceId). allowedSources는 이 키로 거른다
  test('출처 키: sourceId가 있으면 그것(iOS), 비면 sourceName(안드로이드 dataOrigin)', () {
    expect(stepSourceKey('com.apple.health.ABCD', 'iPhone'), 'com.apple.health.ABCD');
    expect(stepSourceKey('', 'com.sec.android.app.shealth'), 'com.sec.android.app.shealth');
    expect(stepSourceKey('', ''), '');
  });
}
