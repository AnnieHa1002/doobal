import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('assets/data/$name').readAsStringSync()) as Map<String, dynamic>;

final _moderation = Moderation.fromJson(_json('moderation.json'));

void main() {
  group('시험 문장 (moderation_cases.json, 서버 테스트와 같은 파일)', () {
    final cases = (_json('moderation_cases.json')['cases'] as List).cast<Map<String, dynamic>>();

    test('100개를 읽는다', () => expect(cases, hasLength(100)));

    for (final c in cases) {
      test('${c['id']} ${c['expect']}: ${c['text']}', () {
        final got = _moderation.check(c['text'] as String);
        expect(got != null, c['expect'] == 'block', reason: '걸린 규칙: ${got?.id}');
        final want = c['cat'];
        if (got != null && want != null) {
          expect(want is List ? want : [want], contains(got.category), reason: got.id);
        }
      });
    }
  });

  group('허용 이름', () {
    test('명소·시군구 이름은 그 자체로 막히지 않는다', () {
      final names = [for (final l in landmarks) l.name, for (final s in sigungu) s.name];
      for (final n in names) {
        expect(_moderation.check(n, names: names), isNull, reason: n);
      }
    });

    test('허용 이름은 가리고 나머지를 본다', () {
      const name = ['이상한발산'];
      expect(_moderation.isBlocked('이상한발산에서 출발해요', names: name), isFalse);
      expect(_moderation.isBlocked('이상한발산에서 씨발', names: name), isTrue);
    });
  });

  group('글 다듬기', () {
    test('전각 글자는 반각으로, 영문은 소문자로', () {
      expect(foldForModeration('ＡＢｃ１'), 'abc1');
    });

    test('풀어 쓴 한글(맥 입력)을 모은다', () {
      expect(foldForModeration('각스'), '각스');
      expect(_moderation.isBlocked('씨발'), isTrue);
    });

    test('띄어쓰기·특수문자·늘임으로 피해도 걸린다', () {
      for (final t in ['씨 .발', '씨이이발', 'ㅅㅂ']) {
        expect(_moderation.isBlocked(t), isTrue, reason: t);
      }
    });
  });

  test('규칙은 123개, 막힌 글 안내는 한 줄', () {
    expect((_json('moderation.json')['rules'] as List), hasLength(123));
    expect(_moderation.message, '이 표현은 방명록에 남길 수 없어요');
  });

  test('모르는 규칙 자리는 FormatException', () {
    expect(
        () => ModerationRule.fromJson({'id': 'x', 'cat': 'A', 'on': 'elsewhere', 're': 'a'}),
        throwsFormatException);
  });
}
