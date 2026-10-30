import 'dart:math' as math;

import 'rules.dart';

enum NicknameProblem { tooShort, tooLong }

/// 닉네임 검사 결과. [value]는 앞뒤 공백을 자른 닉네임, 쓸 수 있으면 [problem]이 null
class NicknameCheck {
  const NicknameCheck(this.value, this.problem);

  final String value;
  final NicknameProblem? problem;

  bool get ok => problem == null;
}

/// 닉네임 검사: 앞뒤 공백을 자르고 글자 수가 config profile의 min~max인지 본다.
/// TODO: 금칙어는 M5 금칙어 문서(config/moderation)가 나오면 여기에 붙인다
NicknameCheck checkNickname(String input, Rules rules) {
  final value = input.trim();
  final length = value.runes.length;
  return NicknameCheck(
    value,
    length < rules.nicknameMin
        ? NicknameProblem.tooShort
        : length > rules.nicknameMax
            ? NicknameProblem.tooLong
            : null,
  );
}

/// 설치마다 하나인 임의 번호: 16바이트를 소문자 hex 32자로 (M5 명세).
/// 테스트에서 [random]을 넣을 수 있다
String newInstallId([math.Random? random]) {
  final r = random ?? math.Random.secure();
  return [for (var i = 0; i < 16; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
