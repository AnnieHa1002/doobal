import 'package:doobal/domain/camp_theme.dart';
import 'package:doobal/domain/rest_camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 옛 꼴(v3)의 테마: 동행 자리·hitOrder·방명록 표지판이 있다. 빠진 v5와 둘 다 읽는지 본다
CampTheme _v3({bool withHitOrder = true}) {
  Map<String, dynamic> obj(String id, double x, double y, {bool ticket = false}) => {
        'id': id,
        'label': id,
        'x': x,
        'y': y,
        'w': 60,
        'h': 70,
        'artW': 60,
        'artH': 56,
        'labelTop': 56,
        if (ticket) 'onlyWhenTicket': true,
      };
  return CampTheme.fromJson({
    'id': 'camp',
    'scene': {'widthPt': 585, 'refScreenPt': [390, 844]},
    'objects': [obj('note', 184, 572), obj('cart', 440, 530), obj('guestbookSign', 2, 470, ticket: true)],
    'companion': {...obj('x', 200, 590)}..remove('id'),
    'character': {'x': 20, 'y': 545, 'w': 140, 'heightPt': 180},
    'campfire': {'x': 174, 'y': 684, 'w': 80, 'h': 80, 'frames': 3, 'frameSec': 0.2},
    'firstSign': {'x': 0, 'y': 0, 'w': 50, 'h': 20, 'label': '첫날'},
    if (withHitOrder) 'hitOrder': ['cart', 'note', 'guestbookSign', 'companion', 'character'],
  });
}

void main() {
  test('실제 camp_wide.json v5: 장면 크기와 자리, 땅 위 물건은 수레만 (16장 11/18)', () {
    expect(campTheme.id, 'camp');
    expect(campTheme.approx, isTrue);
    expect(campTheme.widthPt, 585);
    expect((campTheme.refW, campTheme.refH), (390, 844));
    expect([for (final o in campTheme.objects) o.id], ['cart']);
    expect((campTheme.object('cart').box.x, campTheme.object('cart').box.y), (440, 530));
    expect(campTheme.object('cart').artSourceFile, 'obj_rest_cart_v01_clean.png');
    // v5 수레에는 이름표 자리가 없어 그림 바로 아래
    expect(campTheme.object('cart').labelTop, campTheme.object('cart').artH);
    // 동행 자리·누름 순서는 파일에서 빠졌다: 동행은 그리지 않고, 순서는 물건 → 동행 → 정령
    expect(campTheme.companion, isNull);
    expect(campTheme.hitOrder, ['cart', campCompanionId, campCharacterId]);
    expect((campTheme.campfire.box.x, campTheme.campfire.box.y), (174, 684));
    expect(campTheme.campfire.frames, 3);
    expect(campTheme.campfire.frameSec, 0.2);
    expect((campTheme.character.x, campTheme.character.y, campTheme.character.heightPt), (20, 545, 180));
    expect(() => campTheme.object('tent'), throwsStateError);
    for (final id in ['tent', 'map', 'backpack', 'note', campGuestbookSignId, campCompanionId]) {
      expect(campTheme.objectOrNull(id), isNull, reason: id);
    }
  });

  test('물건은 장면 안에 있고 누름 상자는 44pt 이상', () {
    for (final o in campTheme.objects) {
      expect(o.box.x, greaterThanOrEqualTo(0), reason: o.id);
      expect(o.box.x + o.box.w, lessThanOrEqualTo(campTheme.widthPt), reason: o.id);
      expect(o.box.y + o.box.h, lessThanOrEqualTo(campTheme.refH), reason: o.id);
      expect(o.box.w, greaterThanOrEqualTo(44), reason: o.id);
      expect(o.box.h, greaterThanOrEqualTo(44), reason: o.id);
      expect(o.artH, lessThanOrEqualTo(o.box.h), reason: o.id);
    }
  });

  test('수레는 처음 화면 밖, 정령은 처음 화면 안', () {
    expect(campTheme.object('cart').box.x, greaterThanOrEqualTo(campTheme.refW));
    expect(campTheme.character.x + campTheme.character.w, lessThanOrEqualTo(campTheme.refW));
  });

  group('누름 순서', () {
    test('v5: 테마에 자리가 없는 물건(방명록 표지판·동행)은 서 있어도 빠진다', () {
      expect(campTheme.hitStack({'cart', 'map', 'guestbookSign', 'companion'}), ['cart']);
      expect(campTheme.hitStack({}), isEmpty);
    });

    test('옛 꼴(v3): 동행 자리와 hitOrder를 읽고, Stack은 hitOrder를 뒤집어 정령·안 서 있는 물건을 뺀다', () {
      final v3 = _v3();
      expect(v3.companion?.id, campCompanionId);
      expect(v3.objectOrNull(campCompanionId), same(v3.companion));
      expect(v3.object(campGuestbookSignId).onlyWhenTicket, isTrue);
      expect(
        v3.hitStack({'cart', 'note', 'guestbookSign', 'companion'}),
        ['companion', 'guestbookSign', 'note', 'cart'],
      );
      expect(v3.hitStack({'note'}), ['note']);
    });

    test('hitOrder가 없으면 물건 순서가 위, 동행·정령이 아래', () {
      final v3 = _v3(withHitOrder: false);
      expect(v3.hitOrder, ['note', 'cart', 'guestbookSign', campCompanionId, campCharacterId]);
      expect(v3.hitStack({'note', 'companion'}), ['companion', 'note']);
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
