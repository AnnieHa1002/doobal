import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/map_album_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _config() =>
    jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('config map.style·map.card·album (T18)', () {
    test('지금 config: 연필 선 넷·다음 길 점선·연필 동그라미·압정 핀·종이 깃발·핀 크기 고정', () {
      final m = rules.mapAlbum.map;
      expect(m.pencil, {'regionBorders', 'offAppTrail', 'nextRoute', 'seaRoute'});
      expect(m.nextRouteDashed, isTrue);
      expect(m.jitterPt, greaterThan(0));
      expect(m.unvisitedCircle, isTrue);
      expect(m.visitedPin, isTrue);
      expect(m.destinationFlag, isTrue);
      expect(m.pinsNonScaling, isTrue);
    });

    test('지도 카드 그림 칸: MVP 1칸, 점선 빈 칸, 액자 색 + 썸네일, 누르면 크게 보기', () {
      final s = rules.mapAlbum.paintingSlot;
      expect(s.count, 1);
      expect(s.emptyDashed, isTrue);
      expect(s.filledThumbnail, isTrue);
      expect(s.tapBigView, isTrue);
    });

    test('화집: 탭은 그림·소품·물감(도장 없음), 가진 것만, 소품 바로 입기·다시 누르면 벗기·옷은 안 벗음', () {
      final a = rules.mapAlbum;
      expect(a.albumTabs, ['paintings', 'props', 'paints']);
      expect(a.ownedOnly, isTrue);
      expect(a.propsTab.tapToWear, isTrue);
      expect(a.propsTab.tapAgainRemoves, isTrue);
      expect(a.propsTab.neverRemove, {'cloth'});
      expect(a.propsTab.joyTrigger, 'joy');
      expect(a.propsTab.joySec, 1);
      expect(a.propsTab.toast, isTrue);
    });

    test('크게 보기: 센서로 가로, 닫으면 세로, ui.orientation.landscape에도 bigView', () {
      expect(rules.mapAlbum.bigView.landscape, isTrue);
      expect(rules.mapAlbum.bigView.portraitOnClose, isTrue);
      expect(rules.screen.landscapeScreens, contains('bigView'));
      // 다른 화면은 세로 (가로는 걷는 중·크게 보기뿐)
      expect(rules.screen.landscapeScreens, {'walking', 'bigView'});
    });

    test('모르는 값은 읽지 않는다', () {
      void bad(void Function(Map<String, dynamic> j) edit) {
        final j = _config();
        edit(j);
        expect(() => MapAlbumRules.fromJson(j), throwsFormatException);
      }

      Map<String, dynamic> style(Map<String, dynamic> j) =>
          (j['map'] as Map<String, dynamic>)['style'] as Map<String, dynamic>;
      Map<String, dynamic> album(Map<String, dynamic> j) => j['album'] as Map<String, dynamic>;

      bad((j) => album(j)['tabs'] = ['paintings', 'stamps']);
      bad((j) => album(j)['tabs'] = ['props', 'props']);
      bad((j) => album(j)['tabs'] = <String>[]);
      bad((j) => ((style(j)['lines'] as Map)['pencil'] as List).add('coast'));
      bad((j) => (style(j)['lines'] as Map)['nextRoute'] = 'wavy');
      bad((j) => (style(j)['lines'] as Map)['jitterPt'] = -1);
      bad((j) => style(j)['unvisited'] = 'lock');
      bad((j) => style(j)['visited'] = {'kind': 'star'});
      bad((j) => style(j)['destination'] = 'balloon');
      bad((j) => ((album(j)['bigView'] as Map)['rotate'] = 'button'));
      bad((j) => ((album(j)['propsTab'] as Map)['joy'] as Map)['sec'] = 0);
      bad((j) => (((j['map'] as Map)['card'] as Map)['paintingSlot'] as Map)['count'] = 0);
    });
  });
}
