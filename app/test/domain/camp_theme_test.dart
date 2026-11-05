import 'package:doobal/domain/camp_theme.dart';
import 'package:doobal/domain/rest_camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('실제 camp_wide.json v3: 장면 크기와 자리 (캔버스 2-2 메모)', () {
    expect(campTheme.id, 'camp');
    expect(campTheme.approx, isTrue);
    expect(campTheme.widthPt, 585);
    expect((campTheme.refW, campTheme.refH), (390, 844));
    expect([for (final o in campTheme.objects) o.id],
        ['backpack', 'note', 'map', 'cart', 'guestbookSign']);
    expect(campTheme.object('map').label, '지도');
    expect((campTheme.object('backpack').box.x, campTheme.object('backpack').box.y), (268, 510));
    expect((campTheme.object('note').box.x, campTheme.object('note').box.y), (184, 572));
    expect((campTheme.object('map').box.x, campTheme.object('map').box.y), (318, 596));
    expect((campTheme.object('cart').box.x, campTheme.object('cart').box.y), (440, 530));
    expect((campTheme.companion.box.x, campTheme.companion.box.y), (236, 612));
    expect((campTheme.campfire.box.x, campTheme.campfire.box.y), (174, 684));
    expect(campTheme.campfire.frames, 3);
    expect(campTheme.campfire.frameSec, 0.2);
    expect((campTheme.character.x, campTheme.character.y, campTheme.character.heightPt), (20, 545, 180));
    expect(campTheme.object('guestbookSign').onlyWhenTicket, isTrue);
    expect(() => campTheme.object('tent'), throwsStateError);
  });

  test('물건은 장면 안에 있고 누름 상자는 44pt 이상', () {
    for (final o in [...campTheme.objects, campTheme.companion]) {
      expect(o.box.x, greaterThanOrEqualTo(0), reason: o.id);
      expect(o.box.x + o.box.w, lessThanOrEqualTo(campTheme.widthPt), reason: o.id);
      expect(o.box.y + o.box.h, lessThanOrEqualTo(campTheme.refH), reason: o.id);
      expect(o.box.w, greaterThanOrEqualTo(44), reason: o.id);
      expect(o.box.h, greaterThanOrEqualTo(44), reason: o.id);
      expect(o.artH, lessThanOrEqualTo(o.box.h), reason: o.id);
    }
  });

  test('수레는 처음 화면 밖, 나머지 물건과 정령은 처음 화면 안', () {
    expect(campTheme.object('cart').box.x, greaterThanOrEqualTo(campTheme.refW));
    for (final id in ['backpack', 'note', 'map', 'guestbookSign']) {
      final b = campTheme.object(id).box;
      expect(b.x + b.w, lessThanOrEqualTo(campTheme.refW), reason: id);
    }
    expect(campTheme.character.x + campTheme.character.w, lessThanOrEqualTo(campTheme.refW));
    expect(campTheme.companion.box.x + campTheme.companion.box.w, lessThanOrEqualTo(campTheme.refW));
  });

  group('누름 순서', () {
    test('hitOrder의 물건은 모두 테마에 있다', () {
      for (final id in campTheme.hitOrder) {
        if (id == campCharacterId || id == campCompanionId) continue;
        expect(campTheme.objects.any((o) => o.id == id), isTrue, reason: id);
      }
      expect(campTheme.hitOrder.last, campCharacterId);
    });

    test('Stack에 쌓는 순서는 hitOrder를 뒤집은 것이고 정령과 안 서 있는 물건은 뺀다', () {
      expect(
        campTheme.hitStack({'cart', 'map', 'backpack', 'note', 'guestbookSign', 'companion'}),
        ['companion', 'guestbookSign', 'note', 'backpack', 'map', 'cart'],
      );
      expect(campTheme.hitStack({'map', 'note'}), ['note', 'map']);
      expect(campTheme.hitStack({}), isEmpty);
    });

    test('노트와 동행이 겹치는 자리에서는 노트가 위', () {
      final note = campTheme.object('note').box;
      final companion = campTheme.companion.box;
      // 겹치는 자리가 실제로 있다
      expect(note.contains(237, 620), isTrue);
      expect(companion.contains(237, 620), isTrue);
      final stack = campTheme.hitStack({'note', 'companion'});
      expect(stack.indexOf('note'), greaterThan(stack.indexOf('companion')));
    });
  });

  group('비율 좌표', () {
    test('세로 화면은 폭 비례, 아래 기준', () {
      for (final (w, h) in [(390.0, 844.0), (375.0, 667.0), (411.0, 1005.0), (768.0, 1024.0)]) {
        final g = RestGeometry(campTheme, rules.rest, w, h);
        expect(g.k, closeTo(w / 390, 1e-9));
        expect(g.sceneWidth, closeTo(w * 1.5, 1e-9));
        // 장면 아래 끝은 화면 아래 끝
        expect(g.sy(844), closeTo(h, 1e-9));
        // 정령 발은 아래에서 (844 − 725) × k
        expect(g.sy(campTheme.character.footY), closeTo(h - 119 * w / 390, 1e-9));
        expect(g.sx(440), closeTo(440 * w / 390, 1e-9));
      }
    });

    test('기준 화면에서는 캔버스 pt 그대로', () {
      final g = RestGeometry(campTheme, rules.rest, 390, 844);
      expect(g.k, 1);
      expect(g.sx(268), 268);
      expect(g.sy(510), 510);
    });

    test('키 작은 폰은 하늘 위쪽이 잘릴 뿐 물건은 화면 안', () {
      final g = RestGeometry(campTheme, rules.rest, 375, 667);
      for (final o in campTheme.objects) {
        expect(g.sy(o.box.y), greaterThan(0), reason: o.id);
      }
      expect(g.sy(campTheme.character.y), greaterThan(0));
    });

    test('가로 화면은 장면 폭이 화면 폭과 같아 밀 곳이 없다', () {
      final g = RestGeometry(campTheme, rules.rest, 1024, 768);
      expect(g.sceneWidth, closeTo(1024, 1e-9));
      expect(g.minX(1), 0);
    });
  });
}
