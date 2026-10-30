import 'dart:math';

import 'package:doobal/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// nextInt가 늘 같은 값을 돌려주는 가짜 (max를 넘지 않게 자른다)
class _Fixed implements Random {
  _Fixed(this.value);

  final int value;

  @override
  int nextInt(int max) => value % max;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  group('config에서 읽는 값', () {
    test('닉네임 길이 2~10자 (config profile)', () {
      expect(rules.nicknameMin, 2);
      expect(rules.nicknameMax, 10);
    });

    test('알림은 하루 2개까지 (config notifications, 시작 화면 알림 권한 설명에도 쓴다)', () {
      expect(rules.notificationDailyMax, 2);
    });
  });

  group('checkNickname (2~10자, 앞뒤 공백은 자른다)', () {
    NicknameCheck check(String s) => checkNickname(s, rules);

    test('1자는 짧다', () {
      final c = check('가');
      expect((c.ok, c.problem), (false, NicknameProblem.tooShort));
    });

    test('2자는 된다', () {
      final c = check('가나');
      expect((c.ok, c.problem, c.value), (true, null, '가나'));
    });

    test('10자는 된다', () {
      final c = check('가나다라마바사아자차');
      expect((c.ok, c.value.runes.length), (true, 10));
    });

    test('11자는 길다', () {
      final c = check('가나다라마바사아자차카');
      expect((c.ok, c.problem), (false, NicknameProblem.tooLong));
    });

    test('빈 문자열과 공백뿐인 것은 짧다 (값은 빈 문자열)', () {
      for (final s in ['', ' ', '      ', '\t \n']) {
        final c = check(s);
        expect((c.ok, c.problem, c.value), (false, NicknameProblem.tooShort, ''), reason: '"$s"');
      }
    });

    test('앞뒤 공백을 자르고 센다: 공백 두 개 + 1자는 짧고, 공백 + 2자 + 공백은 된다', () {
      expect(check('  가  ').problem, NicknameProblem.tooShort);
      final c = check(' 가나 ');
      expect((c.ok, c.value), (true, '가나'));
    });

    test('10자에 앞뒤 공백이 붙어도 자른 길이로 본다', () {
      expect(check('  가나다라마바사아자차  ').ok, isTrue);
    });

    test('가운데 공백은 글자로 센다', () {
      expect(check('가 나').value, '가 나');
      expect(check('가 나').ok, isTrue);
    });

    test('영문·숫자도 글자 수로 센다', () {
      expect(check('ab').ok, isTrue);
      expect(check('a').ok, isFalse);
      expect(check('abcde12345').ok, isTrue);
      expect(check('abcde123456').problem, NicknameProblem.tooLong);
    });
  });

  group('newInstallId', () {
    final hex32 = RegExp(r'^[0-9a-f]{32}$');

    test('소문자 hex 32자 (16바이트)', () {
      for (var i = 0; i < 20; i++) {
        expect(newInstallId(), matches(hex32));
      }
    });

    test('매번 다르다', () {
      expect({for (var i = 0; i < 50; i++) newInstallId()}, hasLength(50));
    });

    test('Random을 넣으면 그 값으로 만든다 (같은 씨앗이면 같은 번호)', () {
      expect(newInstallId(Random(42)), newInstallId(Random(42)));
      expect(newInstallId(Random(42)) == newInstallId(Random(43)), isFalse);
      expect(newInstallId(_Fixed(0)), '00' * 16);
      expect(newInstallId(_Fixed(255)), 'ff' * 16);
      expect(newInstallId(_Fixed(10)), '0a' * 16);
    });
  });
}
