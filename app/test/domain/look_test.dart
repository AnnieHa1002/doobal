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
    test('기본값은 기본 얼굴(점·시바·쑥스러움·ω), 크림 몸, 칸마다 기본 소품, 소품 색 없음', () {
      final l = Look.initial;
      expect([l.eyes, l.brows, l.nose, l.mouth], ['dot', 'shiba', 'shy', 'omega']);
      expect(l.body, const SwatchBodyColor(1));
      expect(l.slots, defaultSlots);
      expect(l.tints, isEmpty);
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
        'eyes': 'dot',
        'brows': 'shiba',
        'nose': 'shy',
        'mouth': 'omega',
        'body': {'kind': 'swatch', 'i': 1},
        'slots': {
          'hat': 'hat_01',
          'face': null,
          'cloth': 'cloth_01',
          'shoe': 'shoe_01',
          'hand': null,
          'bag': 'hand_01',
          'pet': 'pet_01',
          'float': null,
          'effect': null,
        },
        'tints': <String, dynamic>{},
      });
      expect(_roundTrip(Look.initial), Look.initial);
    });

    test('JSON 왕복: 모든 칸을 바꾼 모습 (비운 칸은 null로 남는다)', () {
      const look = Look(
        eyes: 'cat',
        brows: 'none',
        nose: 'heart',
        mouth: 'smirk',
        body: CustomBodyColor('#A1B2C3'),
        slots: {
          'hat': 'hat_01',
          'hand': null,
          'pet': 'pet_03',
          'bag': 'bag_01',
          'shoe': 'shoe_02',
          'cloth': 'cloth_03',
        },
        tints: {'hat_01': SwatchBodyColor(7), 'hat_02': CustomBodyColor('#102030')},
      );
      final json = look.toJson();
      expect(json['body'], {'kind': 'custom', 'hex': '#A1B2C3'});
      expect(json['tints'], {
        'hat_01': {'kind': 'swatch', 'i': 7},
        'hat_02': {'kind': 'custom', 'hex': '#102030'},
      });
      expect((json['slots'] as Map)['hand'], isNull);
      expect((json['slots'] as Map).containsKey('hand'), isTrue);
      final back = _roundTrip(look);
      expect(back.slots['hand'], isNull);
      // 칸을 빠뜨린 slots도 읽을 때 기본 소품으로 채워지므로 같은 모습으로 돌아온다
      expect(back, _roundTrip(back));
      expect(back.eyes, 'cat');
      expect(back.tints, look.tints);
      expect(back.body, look.body);
    });

    test('같은 값이면 같고, 칸 하나만 달라도 다르다', () {
      expect(const SwatchBodyColor(1), const SwatchBodyColor(1));
      expect(const SwatchBodyColor(1) == const SwatchBodyColor(2), isFalse);
      expect(const CustomBodyColor('#000000') == const SwatchBodyColor(1), isFalse);
      final a = Look.initial.withTint('hat_01', const SwatchBodyColor(3));
      expect(a, Look.initial.withTint('hat_01', const SwatchBodyColor(3)));
      expect(a.hashCode, Look.initial.withTint('hat_01', const SwatchBodyColor(3)).hashCode);
      expect(a == Look.initial, isFalse);
      expect(a == a.withTint('hat_01', const SwatchBodyColor(4)), isFalse);
      expect(Look.initial == Look.initial.copyWith(nose: 'heart'), isFalse);
      expect(Look.initial == Look.initial.copyWith(body: const SwatchBodyColor(2)), isFalse);
      expect(Look.initial == Look.initial.withSlot('hat', 'hat_02'), isFalse);
    });

    test('copyWith는 준 것만 바꾸고 소품 칸·소품 색을 그대로 가져간다', () {
      final base = Look.initial.withSlot('hat', 'hat_02').withTint('hat_01', defaultBody);
      final a = base.copyWith(eyes: 'bean', body: const SwatchBodyColor(5));
      expect((a.eyes, a.brows, a.nose, a.mouth), ('bean', 'shiba', 'shy', 'omega'));
      expect(a.body, const SwatchBodyColor(5));
      expect(a.slots, base.slots);
      expect(a.tints, base.tints);
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

    test('withTint: 소품 색을 정하고, null이면 기본 색으로 되돌린다', () {
      final a = Look.initial.withTint('hat_01', const CustomBodyColor('#102030'));
      expect(a.tints, {'hat_01': const CustomBodyColor('#102030')});
      final b = a.withTint('hat_01', const SwatchBodyColor(2));
      expect(b.tints, {'hat_01': const SwatchBodyColor(2)});
      expect(b.withTint('hat_01', null).tints, isEmpty);
      expect(_roundTrip(b).tints, b.tints);
      expect(Look.initial.tints, isEmpty);
    });
  });

  group('Look 읽기', () {
    Map<String, dynamic> face(String key, Object? v) => {'mouth': 'omega', key: v};

    test('빠진 키는 기본값, 일부만 있어도 빠진 키만 기본값', () {
      expect(Look.fromJson(<String, dynamic>{}), Look.initial);
      final look = Look.fromJson({
        'eyes': 'cat',
        'mouth': 'flat',
        'slots': {'hat': 'hat_02'},
      });
      expect((look.eyes, look.mouth, look.nose, look.brows), ('cat', 'flat', 'shy', 'shiba'));
      expect(look.slots['hat'], 'hat_02');
      // slots 안에서 빠진 칸은 그 칸의 기본 소품
      expect(look.slots['bag'], 'hand_01');
      expect(look.slots['cloth'], 'cloth_01');
      expect(look.body, defaultBody);
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
      expect([look.eyes, look.brows, look.nose, look.mouth], ['dot', 'shiba', 'shy', 'omega']);
      expect(look.body, const SwatchBodyColor(1));
      expect(look.tints, isEmpty);
      expect(look.slots['hat'], 'hat_02');
      expect(look.slots['hand'], isNull);
      expect(look.slots['bag'], 'bag_01');
      // 모르는 칸은 무시, 읽을 수 없는 칸(숫자)은 그 칸의 기본 소품
      expect(look.slots.containsKey('wing'), isFalse);
      expect(look.slots['shoe'], 'shoe_01');
      expect(look.slots['cloth'], 'cloth_01');
      // 다시 적으면 새 모양이 되어 그대로 읽힌다
      expect(look.toJson().keys, ['eyes', 'brows', 'nose', 'mouth', 'body', 'slots', 'tints']);
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
      expect(() => Look.fromJson(face('tints', ['x'])), throwsFormatException);
      expect(() => Look.fromJson(face('tints', {'hat_01': 'red'})), throwsFormatException);
      expect(() => Look.fromJson(face('tints', {'hat_01': {'kind': 'rainbow'}})),
          throwsFormatException);
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
