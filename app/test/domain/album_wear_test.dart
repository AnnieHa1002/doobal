import 'package:doobal/domain/album_wear.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/map_album_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final r = rules.mapAlbum.propsTab;
  const look = Look.initial;

  group('화집 소품 바로 입기 (16장 11/19, album.propsTab)', () {
    test('안 입은 소품을 누르면 그 칸에 입는다 (같은 칸은 바뀜, 다른 칸은 그대로)', () {
      final out = tapToWear(look, 'hat', 'hat_02', r)!;
      expect(out.change, WearChange.worn);
      expect(out.look.slots['hat'], 'hat_02');
      for (final s in lookSlots.where((s) => s != 'hat')) {
        expect(out.look.slots[s], look.slots[s], reason: s);
      }
      // 빈 칸(얼굴 소품)에도 입는다
      expect(tapToWear(look, 'face', 'face_01', r)!.look.slots['face'], 'face_01');
    });

    test('입은 것을 다시 누르면 벗는다', () {
      final out = tapToWear(look, 'hat', 'hat_01', r)!;
      expect(out.change, WearChange.removed);
      expect(out.look.slots['hat'], isNull);
      expect(tapToWear(look, 'pet', 'pet_01', r)!.look.slots['pet'], isNull);
    });

    test('옷은 다시 눌러도 벗지 않는다 (옷 없는 정령 없음)', () {
      expect(tapToWear(look, 'cloth', 'cloth_02', r), isNull);
      // 다른 옷은 갈아입는다
      expect(tapToWear(look, 'cloth', 'cloth_01', r)!.look.slots['cloth'], 'cloth_01');
    });

    test('다시 눌러 벗기·바로 입기를 끄면', () {
      const noRemove = PropsTabRules(
        tapToWear: true,
        tapAgainRemoves: false,
        neverRemove: {'cloth'},
        joyTrigger: 'joy',
        joySec: 1,
        toast: true,
      );
      expect(tapToWear(look, 'hat', 'hat_01', noRemove), isNull);
      expect(tapToWear(look, 'hat', 'hat_02', noRemove)!.look.slots['hat'], 'hat_02');
      const off = PropsTabRules(
        tapToWear: false,
        tapAgainRemoves: true,
        neverRemove: {'cloth'},
        joyTrigger: 'joy',
        joySec: 1,
        toast: true,
      );
      expect(tapToWear(look, 'hat', 'hat_02', off), isNull);
    });

    test('토스트 한 줄 (캔버스 6-1): 썼어요·입었어요·신었어요·멨어요·와/과 함께해요·벗었어요', () {
      expect(wearToast('베레모', 'hat', WearChange.worn), '베레모 썼어요');
      expect(wearToast('여행복', 'cloth', WearChange.worn), '여행복 입었어요');
      expect(wearToast('갈색 신발', 'shoe', WearChange.worn), '갈색 신발 신었어요');
      expect(wearToast('큰 붓', 'bag', WearChange.worn), '큰 붓 멨어요');
      expect(wearToast('종이새', 'pet', WearChange.worn), '종이새와 함께해요');
      expect(wearToast('갈매기', 'pet', WearChange.worn), '갈매기와 함께해요');
      expect(wearToast('고양이 풍선', 'float', WearChange.worn), '고양이 풍선과 함께해요');
      expect(wearToast('베레모', 'hat', WearChange.removed), '베레모 벗었어요');
    });
  });
}
