import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/prop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// JSON 문자열을 거쳐 돌려 읽는다 (DB에는 문자열로 들어간다)
Look _roundTrip(Look look) =>
    Look.fromJson(jsonDecode(jsonEncode(look.toJson())) as Map<String, dynamic>);

void main() {
  group('Look', () {
    test('기본값은 기본 얼굴(점·시바·쑥스러움·ω), 크림 몸, 칸마다 기본 소품', () {
      final l = Look.initial;
      expect([l.eyes, l.brows, l.nose, l.mouth], ['e1', 'b1', 'n7', 'm7']);
      expect(l.body, const SwatchBodyColor(1));
      expect(l.slots, defaultSlots);
    });

    test('기본 얼굴은 palette.json defaultFace와 같다', () {
      final d = (jsonDecode(File('assets/data/palette.json').readAsStringSync())
          as Map<String, dynamic>)['customParts']['defaultFace'] as Map<String, dynamic>;
      expect({
        'eyes': defaultEyes,
        'brows': defaultBrows,
        'nose': defaultNose,
        'mouth': defaultMouth,
      }, d);
    });

    test('기본 소품은 props.json에서 unlock.kind가 default인 것, 처음 끼는 소품은 그중에서', () {
      expect(initialPropIds, {
        for (final p in props)
          if (p.kind == PropUnlockKind.initial) p.id,
      });
      for (final id in defaultSlots.values.nonNulls) {
        expect(initialPropIds, contains(id));
      }
      // 소품 칸 이름은 props.json의 slot과 같다
      expect(props.map((p) => p.slot).toSet(), lookSlots.toSet());
      expect(defaultSlots.keys.toSet(), lookSlots.toSet());
    });

    test('JSON 왕복: 기본 모습의 모양', () {
      expect(Look.initial.toJson(), {
        'eyes': 'e1',
        'brows': 'b1',
        'nose': 'n7',
        'mouth': 'm7',
        'body': {'kind': 'swatch', 'i': 1},
        'clothColor': 1,
        'slots': {
          'hat': 'hat_01',
          'face': null,
          'cloth': 'cloth_02',
          'shoe': 'shoe_01',
          'hand': null,
          'bag': 'hand_01',
          'pet': 'pet_01',
          'float': null,
          'effect': null,
        },
      });
      expect(_roundTrip(Look.initial), Look.initial);
    });

    test('JSON 왕복: 모든 칸을 바꾼 모습 (비운 칸은 null로 남는다)', () {
      const look = Look(
        eyes: 'e3',
        brows: 'none',
        nose: 'n4',
        mouth: 'm5',
        body: CustomBodyColor('#A1B2C3'),
        slots: {
          'hat': 'hat_01',
          'hand': null,
          'pet': 'pet_03',
          'bag': 'bag_01',
          'shoe': 'shoe_02',
          'cloth': 'cloth_03',
        },
      );
      final json = look.toJson();
      expect(json['body'], {'kind': 'custom', 'hex': '#A1B2C3'});
      expect((json['slots'] as Map)['hand'], isNull);
      expect((json['slots'] as Map).containsKey('hand'), isTrue);
      final back = _roundTrip(look);
      expect(back.slots['hand'], isNull);
      // 칸을 빠뜨린 slots도 읽을 때 기본 소품으로 채워지므로 같은 모습으로 돌아온다
      expect(back, _roundTrip(back));
      expect(back.eyes, 'e3');
      expect(back.body, look.body);
    });

    test('같은 값이면 같고, 칸 하나만 달라도 다르다', () {
      expect(const SwatchBodyColor(1), const SwatchBodyColor(1));
      expect(const SwatchBodyColor(1) == const SwatchBodyColor(2), isFalse);
      expect(const CustomBodyColor('#000000') == const SwatchBodyColor(1), isFalse);
      final a = Look.initial.withSlot('hat', 'hat_02');
      expect(a, Look.initial.withSlot('hat', 'hat_02'));
      expect(a.hashCode, Look.initial.withSlot('hat', 'hat_02').hashCode);
      expect(a == Look.initial, isFalse);
      expect(Look.initial == Look.initial.copyWith(nose: 'n4'), isFalse);
      expect(Look.initial == Look.initial.copyWith(body: const SwatchBodyColor(2)), isFalse);
      expect(Look.initial == Look.initial.withSlot('hat', 'hat_02'), isFalse);
    });

    test('copyWith는 준 것만 바꾸고 소품 칸을 그대로 가져간다', () {
      final base = Look.initial.withSlot('hat', 'hat_02');
      final a = base.copyWith(eyes: 'e2', body: const SwatchBodyColor(5));
      expect((a.eyes, a.brows, a.nose, a.mouth), ('e2', 'b1', 'n7', 'm7'));
      expect(a.body, const SwatchBodyColor(5));
      expect(a.slots, base.slots);
    });

    test('withSlot: 그 칸만 바꾸고, 비우기는 옷만 막는다', () {
      final a = Look.initial.withSlot('hat', 'hat_02');
      expect(a.slots['hat'], 'hat_02');
      expect(a.slots['bag'], 'hand_01');
      // 원래 모습은 그대로 (기본 슬롯 상수도 안 바뀐다)
      expect(Look.initial.slots['hat'], 'hat_01');
      expect(defaultSlots['hat'], 'hat_01');
      expect(a.withSlot('hat', null).slots['hat'], isNull);
      expect(() => a.withSlot('cloth', null), throwsArgumentError);
      expect(() => a.withSlot('wing', 'wing_01'), throwsArgumentError);
      expect(a.eyes, Look.initial.eyes);
      expect(a.body, Look.initial.body);
    });
  });

  group('Look 읽기', () {
    Map<String, dynamic> face(String key, Object? v) => {'mouth': 'm7', key: v};

    test('빠진 키는 기본값, 일부만 있어도 빠진 키만 기본값', () {
      expect(Look.fromJson(<String, dynamic>{}), Look.initial);
      final look = Look.fromJson({
        'eyes': 'e3',
        'mouth': 'flat',
        'slots': {'hat': 'hat_02'},
      });
      expect((look.eyes, look.mouth, look.nose, look.brows), ('e3', 'm7', 'n7', 'b1'));
      expect(look.slots['hat'], 'hat_02');
      // slots 안에서 빠진 칸은 그 칸의 기본 소품
      expect(look.slots['bag'], 'hand_01');
      expect(look.slots['cloth'], 'cloth_02');
      expect(look.body, defaultBody);
      expect(look.clothColor, defaultClothColor);
    });

    test('옛 얼굴 id (계약 v0.5): PSD 이름은 같은 번호로 옮기고, v24 id는 기본 얼굴로', () {
      final psd = Look.fromJson({'eyes': 'soft', 'brows': 'angry', 'nose': 'arch', 'mouth': 'grin'});
      expect((psd.eyes, psd.brows, psd.nose, psd.mouth), ('e2', 'b3', 'n3', 'm5'));
      final v24 = Look.fromJson({'eyes': 'cat', 'brows': 'shiba', 'nose': 'heart', 'mouth': 'smirk'});
      expect((v24.eyes, v24.brows, v24.nose), ('e1', 'b1', 'n7'));
      expect(Look.initial.copyWith(eyes: 'bean').eyes, 'e1');
    });

    test('옷 색 번호: 왕복하고, 칸을 바꿔도 남고, 1보다 작거나 정수가 아니면 FormatException', () {
      final look = Look.initial.copyWith(clothColor: 3);
      expect(_roundTrip(look).clothColor, 3);
      expect(look.withSlot('hat', 'hat_02').clothColor, 3);
      expect(look.copyWith(eyes: 'cat').clothColor, 3);
      expect(look == Look.initial, isFalse);
      expect(() => Look.fromJson({'clothColor': 0}), throwsFormatException);
      expect(() => Look.fromJson({'clothColor': '2'}), throwsFormatException);
    });

    test('11/10 전 모습(옷 색 키 없음)의 앞치마는 여행복으로 읽고, 새 모습의 앞치마(300km 보상)는 그대로', () {
      expect(
        Look.fromJson({
          'slots': {'cloth': 'cloth_01', 'hat': 'hat_02'},
        }).slots,
        {...defaultSlots, 'hat': 'hat_02'},
      );
      expect(Look.fromJson({'clothColor': 2, 'slots': {'cloth': 'cloth_01'}}).slots['cloth'], 'cloth_01');
      expect(Look.fromJson({'slots': {'cloth': 'cloth_05'}}).slots['cloth'], 'cloth_05');
      expect(Look.fromJson({'hair': 1, 'slots': {'cloth': 'cloth_01'}}).slots['cloth'], 'cloth_02');
      // 한 번 다시 적으면 옷 색 키가 생겨서, 그 뒤에 입은 앞치마는 앞치마로 남는다
      final worn = Look.fromJson({'slots': {'cloth': 'cloth_01'}}).withSlot('cloth', 'cloth_01');
      expect(_roundTrip(worn).slots['cloth'], 'cloth_01');
    });

    test('slots 안의 null은 비운 칸, 빠진 칸은 기본 소품 (옷은 비울 수 없다)', () {
      Look read(Map<String, dynamic> slots) => Look.fromJson({'slots': slots});
      expect(read({'hat': null}).slots['hat'], isNull);
      expect(read(<String, dynamic>{}).slots, defaultSlots);
      expect(() => read({'cloth': null}), throwsFormatException);
    });

    test('모르는 칸 이름은 무시한다', () {
      final look = Look.fromJson({
        'slots': {'wing': 'wing_01'},
      });
      expect(look.slots, defaultSlots);
      expect((look.toJson()['slots'] as Map).keys, lookSlots);
    });

    test('옛 사람형 JSON(hair 키가 있다)은 예외 없이 기본 얼굴·크림으로 읽고 slots는 살린다', () {
      final look = Look.fromJson({
        'hair': 4,
        'hairColor': {'kind': 'gradient', 'root': '#000000', 'tip': '#FFFFFF'},
        'skin': {'kind': 'custom', 'hex': '#C08060'},
        'eyes': 3,
        'nose': 2,
        'brows': 3,
        'mouth': 4,
        'ears': 2,
        'slots': {
          'hat': 'hat_02',
          'hand': null,
          'bag': 'bag_01',
          'wing': 'wing_01',
          'shoe': 5,
        },
      });
      expect([look.eyes, look.brows, look.nose, look.mouth], ['e1', 'b1', 'n7', 'm7']);
      expect(look.body, const SwatchBodyColor(1));
      expect(look.slots['hat'], 'hat_02');
      expect(look.slots['hand'], isNull);
      expect(look.slots['bag'], 'bag_01');
      // 모르는 칸은 무시, 읽을 수 없는 칸(숫자)은 그 칸의 기본 소품
      expect(look.slots.containsKey('wing'), isFalse);
      expect(look.slots['shoe'], 'shoe_01');
      expect(look.slots['cloth'], 'cloth_02');
      // 다시 적으면 새 모양이 되어 그대로 읽힌다
      expect(look.toJson().keys, ['eyes', 'brows', 'nose', 'mouth', 'body', 'clothColor', 'slots']);
      expect(_roundTrip(look), look);
    });

    test('옛 JSON은 어디가 깨져 있어도 멈추지 않는다 (hair만, 옷이 null, eyes 숫자, slots가 맵이 아님)', () {
      expect(Look.fromJson({'hair': 1}), Look.initial);
      expect(Look.fromJson({'hair': 1, 'slots': 'x'}), Look.initial);
      expect(Look.fromJson({'hair': 1, 'slots': {'cloth': null}}), Look.initial);
      expect(Look.fromJson({'eyes': 3}), Look.initial);
      expect(Look.fromJson({'eyes': 3, 'slots': {'hat': ''}}), Look.initial);
    });

    test('새 형식에서 틀린 값은 FormatException: 모르는 파츠 id, 숫자 id, 틀린 색', () {
      expect(() => Look.fromJson(face('eyes', 'laser')), throwsFormatException);
      expect(() => Look.fromJson(face('brows', 'dot')), throwsFormatException);
      expect(() => Look.fromJson(face('nose', 5)), throwsFormatException);
      expect(() => Look.fromJson(face('mouth', 'dot')), throwsFormatException);
      expect(() => Look.fromJson(face('body', {'kind': 'gradient'})), throwsFormatException);
      expect(() => Look.fromJson(face('body', {'kind': 'custom', 'hex': 'C08060'})),
          throwsFormatException);
      expect(() => Look.fromJson(face('body', {'kind': 'swatch', 'i': '1'})),
          throwsFormatException);
      expect(() => Look.fromJson(face('body', 'swatch')), throwsFormatException);
      expect(() => Look.fromJson(face('slots', ['hat_01'])), throwsFormatException);
      expect(() => Look.fromJson(face('slots', {'hat': 5})), throwsFormatException);
      expect(() => Look.fromJson(face('slots', {'hat': ''})), throwsFormatException);
    });

    test('BodyColor: 견본·직접 고른 색을 왕복하고, 틀린 모양은 FormatException', () {
      expect(const SwatchBodyColor(7).toJson(), {'kind': 'swatch', 'i': 7});
      expect(const CustomBodyColor('#A1B2C3').toJson(), {'kind': 'custom', 'hex': '#A1B2C3'});
      expect(BodyColor.fromJson({'kind': 'swatch', 'i': 7}), const SwatchBodyColor(7));
      expect(BodyColor.fromJson({'kind': 'custom', 'hex': '#a1b2c3'}),
          const CustomBodyColor('#a1b2c3'));
      expect(() => BodyColor.fromJson({'kind': 'custom', 'hex': '#A1B2C'}), throwsFormatException);
      expect(() => BodyColor.fromJson({'kind': 'custom'}), throwsFormatException);
      expect(() => BodyColor.fromJson({'kind': 'swatch'}), throwsFormatException);
    });
  });
}
