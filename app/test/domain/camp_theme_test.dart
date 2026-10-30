import 'package:doobal/domain/camp_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('실제 camp.json: 물건 3개와 자리', () {
    expect(campTheme.id, 'camp');
    expect(campTheme.approx, isTrue);
    expect([for (final o in campTheme.objects) o.id], ['map', 'backpack', 'note']);
    expect(campTheme.object('map').label, '지도');
    expect(campTheme.object('backpack').size, 64);
    expect(campTheme.object('note').size, 56);
    expect(campTheme.character.x, 0.42);
    expect(campTheme.character.footY, 0.845);
    expect(campTheme.companion.footY, 0.80);
    expect(campTheme.signpost.x, 0.12);
    // 방명록 표지판은 이정표 옆(오른쪽), 발 높이는 이정표보다 조금 위
    expect(campTheme.guestbookSign.x, 0.27);
    expect(campTheme.guestbookSign.footY, 0.60);
    expect(campTheme.guestbookSign.x, greaterThan(campTheme.signpost.x));
  });

  test('위치는 모두 화면 비율(0~1)이고 물건은 누르기 쉬운 크기(44pt 이상)', () {
    for (final o in campTheme.objects) {
      expect(o.x, inInclusiveRange(0, 1));
      expect(o.y, inInclusiveRange(0, 1));
      expect(o.size, greaterThanOrEqualTo(44));
    }
    for (final s in [
      campTheme.character,
      campTheme.companion,
      campTheme.signpost,
      campTheme.guestbookSign,
    ]) {
      expect(s.x, inInclusiveRange(0, 1));
      expect(s.footY, inInclusiveRange(0, 1));
    }
  });

  test('approx가 없으면 false, 없는 물건 id는 StateError', () {
    final t = CampTheme.fromJson({
      'id': 'x',
      'objects': const [],
      'character': {'x': 0.5, 'footY': 0.8},
      'companion': {'x': 0.5, 'footY': 0.8},
      'signpost': {'x': 0.5, 'footY': 0.8},
    });
    expect(t.approx, isFalse);
    expect(() => t.object('map'), throwsStateError);
  });

  test('guestbookSign이 없으면 이정표에서 오른쪽으로 guestbookSignGapX만큼 떨어진 기본값', () {
    final t = CampTheme.fromJson({
      'id': 'x',
      'objects': const [],
      'character': {'x': 0.5, 'footY': 0.8},
      'companion': {'x': 0.5, 'footY': 0.8},
      'signpost': {'x': 0.3, 'footY': 0.6},
    });
    expect(t.guestbookSign.x, closeTo(0.3 + guestbookSignGapX, 1e-9));
    expect(t.guestbookSign.footY, 0.6);

    // 있으면 그 값
    final u = CampTheme.fromJson({
      'id': 'x',
      'objects': const [],
      'character': {'x': 0.5, 'footY': 0.8},
      'companion': {'x': 0.5, 'footY': 0.8},
      'signpost': {'x': 0.3, 'footY': 0.6},
      'guestbookSign': {'x': 0.7, 'footY': 0.55},
    });
    expect((u.guestbookSign.x, u.guestbookSign.footY), (0.7, 0.55));
  });
}
