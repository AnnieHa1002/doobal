import 'dart:math' as math;

import 'moderation.dart';
import 'rules.dart';

/// 글자 수가 모자람·넘침, 아주 명백한 욕설
enum NicknameProblem { tooShort, tooLong, swear }

/// 닉네임 검사 결과. [value]는 앞뒤 공백을 자른 닉네임, 쓸 수 있으면 [problem]이 null
class NicknameCheck {
  const NicknameCheck(this.value, this.problem);

  final String value;
  final NicknameProblem? problem;

  bool get ok => problem == null;
}

/// 닉네임 검사: 앞뒤 공백을 자르고 글자 수가 config profile의 min~max인지 본다. [moderation]이 있으면
/// 아주 명백한 욕설만 막는다(11/10 Annie, [Moderation.isObviousSwear]). 그 밖의 말은 검열하지 않는다
NicknameCheck checkNickname(String input, Rules rules, {Moderation? moderation}) {
  final value = input.trim();
  final length = value.runes.length;
  return NicknameCheck(
    value,
    length < rules.nicknameMin
        ? NicknameProblem.tooShort
        : length > rules.nicknameMax
            ? NicknameProblem.tooLong
            : moderation != null && moderation.isObviousSwear(value)
                ? NicknameProblem.swear
                : null,
  );
}

/// 설치마다 하나인 임의 번호: 16바이트를 소문자 hex 32자로 (M5 명세).
/// 테스트에서 [random]을 넣을 수 있다
String newInstallId([math.Random? random]) {
  final r = random ?? math.Random.secure();
  return [for (var i = 0; i < 16; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
