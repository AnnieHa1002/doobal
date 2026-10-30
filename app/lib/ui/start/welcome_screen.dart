import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/rules.dart';
import '../../domain/sky.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../scene/sky_painter.dart';

/// 밤하늘의 달이 호 위 어디쯤 있는지 (0 = 왼쪽, 1 = 오른쪽). 글자와 겹치지 않게 오른쪽 위로
const _moonProgress = 0.7;

/// 시작 ① 환영: 밤하늘 + 앱 이름 + 한 줄 소개 + 주 버튼 하나.
/// 버튼을 누르는 것이 만 14세 확인이고 [아니요] 버튼은 없다. 확인은 이 기기에만 적는다
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, required this.rules});

  final Rules rules;

  Future<void> _confirm(WidgetRef ref) async {
    await ref.read(profileServiceProvider).confirmAge(ref.read(clockProvider)());
    ref.invalidate(onboardingStepProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 앱의 하늘 그리기를 밤 단계로 고정해 쓴다
          CustomPaint(
            painter: SkyPainter(
              sky: skyLookOf(const SkyMix(SkyPhase.night, SkyPhase.night, 0), rules),
              celestial: const Celestial(SkyBody.moon, _moonProgress),
              rules: rules,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 5),
                  const Text(
                    '두발: 여행하는 예술가',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Palette.paper,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '걸은 만큼 내 화가가 실제 명소로 여행해요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.4, color: Palette.paper),
                  ),
                  const Spacer(flex: 4),
                  GameButton(label: '만 14세 이상이에요', onPressed: () => _confirm(ref)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
