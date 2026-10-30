import 'package:doobal/domain/onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

OnboardingStep _step({int? age, String? nickname, double? lat, int? done}) => onboardingStepOf(
      ageConfirmedAt: age,
      nickname: nickname,
      homeLat: lat,
      onboardedAt: done,
    );

void main() {
  group('onboardingStepOf: 비어 있는 첫 항목이 지금 단계', () {
    test('아무것도 없으면 환영', () => expect(_step(), OnboardingStep.welcome));

    test('만 14세 확인만 있으면 나', () => expect(_step(age: 1), OnboardingStep.me));

    test('닉네임까지 있으면 출발 동네',
        () => expect(_step(age: 1, nickname: '화가'), OnboardingStep.home));

    test('출발 동네까지 있으면 권한',
        () => expect(_step(age: 1, nickname: '화가', lat: 37.5), OnboardingStep.permission));

    test('권한 단계까지 마쳤으면 끝',
        () => expect(_step(age: 1, nickname: '화가', lat: 37.5, done: 2), OnboardingStep.done));

    test('앞 항목이 비면 뒤가 차 있어도 거기서 멈춘다 (확인이 없으면 환영)', () {
      expect(_step(nickname: '화가', lat: 37.5, done: 2), OnboardingStep.welcome);
      expect(_step(age: 1, lat: 37.5, done: 2), OnboardingStep.me);
      expect(_step(age: 1, nickname: '화가', done: 2), OnboardingStep.home);
    });
  });
}
