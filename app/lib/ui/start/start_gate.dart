import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auto_sync.dart';
import '../../app/providers.dart';
import '../../domain/onboarding.dart';
import '../rest/rest_screen.dart';
import 'home_pick_screen.dart';
import 'me_screen.dart';
import 'permission_screen.dart';
import 'welcome_screen.dart';

/// 단계가 바뀔 때의 크로스페이드 (UI 명세 0장 0.25초)
const _crossfade = Duration(milliseconds: 250);

/// 앱의 첫 화면(home). 첫 실행에는 시작 흐름(환영 → 나 → 출발 동네 → 권한)을 보여 주고,
/// 끝났으면 쉼터로 간다. 각 단계 화면은 저장한 뒤 onboardingStepProvider를 다시 읽는다.
/// 동기화·도착 화면(AutoSync)은 흐름이 끝난 뒤에 시작한다. 만 14세 확인 전에는 걸음·알림 권한을
/// 묻지 않고 (권한은 마지막 단계 버튼을 눌러야 묻는다), 걸음 동기화도 권한 단계 뒤에야 돈다
class StartGate extends ConsumerWidget {
  const StartGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(onboardingStepProvider).value;
    final rules = ref.watch(rulesProvider).value;
    // 프로필과 규칙을 읽을 때까지는 종이색 빈 화면
    if (step == null || rules == null) return const Scaffold(body: SizedBox.expand());

    return AnimatedSwitcher(
      duration: _crossfade,
      child: KeyedSubtree(
        key: ValueKey(step),
        child: switch (step) {
          OnboardingStep.welcome => WelcomeScreen(rules: rules),
          OnboardingStep.me => MeScreen(rules: rules),
          OnboardingStep.home => const HomePickScreen(),
          OnboardingStep.permission => PermissionScreen(rules: rules),
          OnboardingStep.done => const AutoSync(child: RestScreen()),
        },
      ),
    );
  }
}
