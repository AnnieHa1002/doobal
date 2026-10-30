/// 첫 실행 시작 흐름의 단계 (UI 명세 1장). done이면 쉼터로 간다
enum OnboardingStep { welcome, me, home, permission, done }

/// 프로필에 채워진 값으로 지금 보여 줄 단계를 정한다: 비어 있는 첫 항목
/// (만 14세 확인 → 닉네임 → 출발 동네 → 권한 단계 끝)
OnboardingStep onboardingStepOf({
  required int? ageConfirmedAt,
  required String? nickname,
  required double? homeLat,
  required int? onboardedAt,
}) {
  if (ageConfirmedAt == null) return OnboardingStep.welcome;
  if (nickname == null) return OnboardingStep.me;
  if (homeLat == null) return OnboardingStep.home;
  if (onboardedAt == null) return OnboardingStep.permission;
  return OnboardingStep.done;
}
