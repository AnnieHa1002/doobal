import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/companion.dart';
import '../../domain/companion_engine.dart';
import '../../domain/notification_policy.dart' show josa;
import '../../domain/rules.dart';
import '../common/app_text.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import 'companion_art.dart';

// 길 위 만남 (캔버스 3-4): 실루엣 → 다가가기 → 프롤로그 → 함께/혼자

/// 프롤로그 뒤 바탕
const _prologueBg = Color(0xFF2E2420);

/// 실루엣 오른쪽 여백: 폭 대비 (캔버스 3-4, 390폭에서 49pt)
const _silhouetteRightRatio = 0.125;

/// 프롤로그 대사 카드 높이(글자 크기 1배)와, 쓸 수 있는 높이 중 대사·그림이 차지할 수 있는 비율
const _lineHeight = 200.0;
const _lineMaxRatio = 0.5;
const _artMaxRatio = 0.45;

/// 만남 칸이 나온 걷는 중 화면 위에 덮는 흐름. 첫 장면·마지막 장면은 뒤의 장면이 비친다.
/// 앱이 그사이 꺼지면 동기화 쪽에 만남 대기로 남아 다음 걷는 중에 처음부터 다시 나온다
class MeetFlow extends StatefulWidget {
  const MeetFlow({
    super.key,
    required this.companion,
    required this.walkingWith,
    required this.rules,
    required this.onChoose,
  });

  final Companion companion;

  /// 실루엣 크기·자리를 장면과 맞추는 값
  final Rules rules;

  /// 지금 함께 걷는 동행 (혼자면 null). 있으면 버튼이 '퐁이와 함께 걷기'·'휴와 계속 걷기'로 바뀐다
  final Companion? walkingWith;

  /// 고르면 부른다. true = 이 동행과 함께, false = 지금까지 걷던 대로
  final ValueChanged<bool> onChoose;

  @override
  State<MeetFlow> createState() => _MeetFlowState();
}

enum _Step { silhouette, prologue, choice }

class _MeetFlowState extends State<MeetFlow> {
  var _step = _Step.silhouette;
  var _beat = 0;

  late final List<StoryBeat> _beats = storyBeats(widget.companion.chapters.first.lines);

  void _next() {
    setState(() {
      if (_beat + 1 < _beats.length) {
        _beat++;
      } else {
        _step = _Step.choice;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.silhouette => _SilhouetteStep(
          companion: widget.companion,
          rules: widget.rules,
          onApproach: () => setState(() => _step = _Step.prologue),
        ),
      _Step.prologue => _PrologueStep(
          companion: widget.companion,
          beat: _beats[_beat],
          index: _beat,
          total: _beats.length,
          onNext: _next,
        ),
      _Step.choice => _ChoiceStep(
          companion: widget.companion,
          walkingWith: widget.walkingWith,
          onChoose: widget.onChoose,
        ),
    };
  }
}

/// 첫 장면: 길 앞쪽의 실루엣과 카드, 다가가기
class _SilhouetteStep extends StatefulWidget {
  const _SilhouetteStep({required this.companion, required this.rules, required this.onApproach});

  final Companion companion;
  final Rules rules;
  final VoidCallback onApproach;

  @override
  State<_SilhouetteStep> createState() => _SilhouetteStepState();
}

class _SilhouetteStepState extends State<_SilhouetteStep> with SingleTickerProviderStateMixin {
  late final _sway = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 움직임 줄이기를 켠 기기에서는 흔들지 않는다
    if (MediaQuery.disableAnimationsOf(context)) {
      _sway.stop();
    } else if (!_sway.isAnimating) {
      _sway.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        Positioned(
          right: screen.width * _silhouetteRightRatio,
          bottom: sceneFootFromBottom(widget.rules, screen),
          child: AnimatedBuilder(
            animation: _sway,
            builder: (context, child) =>
                Transform.translate(offset: Offset(_sway.value * 4, 0), child: child),
            child: CompanionFigure(
              key: const Key('meet-silhouette'),
              companion: widget.companion,
              height: sceneCompanionHeight(widget.rules, screen),
              silhouette: true,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MeetCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('길 위 만남', style: AppText.label),
                      const SizedBox(height: 6),
                      Text(
                        '길 앞쪽에 누군가 있어요',
                        style: context.display(21, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text('다가가 볼까요?', style: TextStyle(fontSize: 14, color: Palette.subInk)),
                    ],
                  ),
                ),
                const Spacer(),
                GameButton(
                  key: const Key('meet-approach'),
                  label: '다가가기',
                  onPressed: widget.onApproach,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 프롤로그: 그림 + 눌러서 넘기는 대사
class _PrologueStep extends StatelessWidget {
  const _PrologueStep({
    required this.companion,
    required this.beat,
    required this.index,
    required this.total,
    required this.onNext,
  });

  final Companion companion;
  final StoryBeat beat;
  final int index;
  final int total;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final who = storySpeakerName(beat.who, companion);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return ColoredBox(
      color: _prologueBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: LayoutBuilder(
            builder: (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                // 가로 화면·작은 화면에서도 대사 자리를 남긴다
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: box.maxHeight * _artMaxRatio),
                  child: Center(heightFactor: 1, child: StoryArt(companion: companion)),
                ),
                const Spacer(flex: 3),
                // 대사마다 들썩이지 않게 높이를 고정한다 (글자 크기만큼은 키운다). 그래도 길면 대사 안에서 민다
                SizedBox(
                  height: math.min(_lineHeight * textScale, box.maxHeight * _lineMaxRatio),
                  child: Semantics(
                    button: true,
                    label: '다음 대사',
                    child: GestureDetector(
                      key: const Key('meet-line'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onNext,
                      child: _MeetCard(
                        radius: 20,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (beat.direction != null) ...[
                                Text('(${beat.direction})', style: AppText.label),
                                const SizedBox(height: 8),
                              ],
                              if (who != null) ...[
                                Text(who, style: context.display(17, weight: FontWeight.w600)),
                                const SizedBox(height: 8),
                              ],
                              Text(beat.text, style: const TextStyle(fontSize: 16, height: 1.6)),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${index + 1} / $total · 눌러서 넘기기',
                                  style: AppText.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 마지막: 새 동행 카드와 고르기
class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.companion,
    required this.walkingWith,
    required this.onChoose,
  });

  final Companion companion;
  final Companion? walkingWith;
  final ValueChanged<bool> onChoose;

  @override
  Widget build(BuildContext context) {
    final now = walkingWith;
    return ColoredBox(
      color: Palette.ink.withValues(alpha: 0.4),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: _MeetCard(
                      radius: 24,
                      child: Column(
                        children: [
                          CompanionPortrait(companion: companion, size: 140),
                          const SizedBox(height: 10),
                          const Text('새 동행을 만났어요', style: AppText.label),
                          const SizedBox(height: 4),
                          Text(
                            companion.name,
                            style: context.display(25, weight: FontWeight.w600),
                          ),
                          if (speciesNames[companion.species] case final species?) ...[
                            const SizedBox(height: 4),
                            Text(species, style: AppText.label),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GameButton(
                key: const Key('meet-together'),
                label: now == null ? '함께 걷기' : '${withName(companion)} 함께 걷기',
                onPressed: () => onChoose(true),
              ),
              const SizedBox(height: 10),
              GameButton(
                key: const Key('meet-solo'),
                kind: GameButtonKind.secondary,
                label: now == null ? '혼자 걷기' : '${withName(now)} 계속 걷기',
                onPressed: () => onChoose(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetCard extends StatelessWidget {
  const _MeetCard({required this.child, this.radius = 22});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
        boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
      ),
      child: child,
    );
  }
}

/// '퐁이와'·'심 박사와' (받침에 맞는 조사)
String withName(Companion c) => '${c.name}${josa(c.name, '과/와')}';

/// 대사 앞에 붙는 말하는 이. 지문은 null
String? storySpeakerName(StorySpeaker who, Companion companion) => switch (who) {
      StorySpeaker.companion => companion.name,
      StorySpeaker.me => '나',
      StorySpeaker.narr => null,
    };
