import 'package:flutter/material.dart';

import '../../domain/screen_rules.dart';
import '../../domain/spirit_look.dart';
import '../scene/spirit_character.dart';
import '../scene/spirit_controller.dart';

/// 개발 화면: 앱이 쓰는 정령 Rive(옷 최종 v11)의 자세 7·반응·표정 6·뒤집기와 몇 가지 소품을 폰에서 바로 본다.
/// 번호는 정령 계약 2·4장 (poseChoice·expr·트리거). 머리·배는 손가락으로 눌러 볼 수 있다
class SpiritPreviewScreen extends StatefulWidget {
  const SpiritPreviewScreen({super.key});
  @override
  State<SpiritPreviewScreen> createState() => _SpiritPreviewScreenState();
}

/// poseChoice 0~6 (정령 계약 2장)
const _poses = ['둥둥 정면', '둥둥 옆', '앉기 정면', '앉기 옆', '잠들기', '둥둥 뒤', '옆 이동'];

/// expr 0~5 (정령 계약 2장)
const _expressions = ['기본', '행복', '놀람', '울먹임', '졸림', '화남'];

/// 소품 몇 가지 (unified_wardrobe.dart 칸 번호)
const _looks = <(String, SpiritLook)>[
  ('소품 없음', SpiritLook.base),
  ('여행복', SpiritLook(choices: {'cloth': 4})),
  ('큰 붓', SpiritLook(choices: {'cloth': 4, 'bag': 1})),
  ('봇짐 지팡이', SpiritLook(choices: {'cloth': 4, 'bag': 5})),
  ('연두 망토', SpiritLook(choices: {'cloth': 1})),
  ('괭이갈매기', SpiritLook(choices: {'cloth': 4, 'pet': 5})),
  ('별빛 망토', SpiritLook(choices: {'cloth': 2, 'float': 6})),
  ('앞치마', SpiritLook(choices: {'cloth': 3, 'float': 6})),
  ('금빛 코트', SpiritLook(choices: {'cloth': 5, 'float': 6})),
  ('파랑새', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 6})),
  ('카나리아', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 7})),
  ('잠자리', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 8})),
  ('도깨비불', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 9})),
  ('꼬마 인삼', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 10})),
  ('두더지', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 11})),
  ('고슴도치', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 12})),
  ('너구리', SpiritLook(choices: {'cloth': 1, 'float': 6, 'pet': 13})),
];

class _SpiritPreviewScreenState extends State<SpiritPreviewScreen> {
  SpiritController? _controller;
  var _look = SpiritLook.base;
  var _pose = 0;
  var _expression = 0;
  var _mirrored = false;

  /// 반응 트리거 (표정은 잠깐 뒤 [_expression]으로 돌아감)
  void _react(String trigger, int expr) =>
      _controller?.cue(SpiritCue(expr, holdSec: 2, trigger: trigger));

  void _press(SpiritPress region) {
    _controller?.press(region);
    _controller?.release();
  }

  Widget _chips<T>(List<(String, T)> items, T selected, ValueChanged<T> onPick) => Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final (label, value) in items)
            ChoiceChip(label: Text(label), selected: value == selected, onSelected: (_) => onPick(value)),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('정령 움직임 (v11)')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ColoredBox(
                      color: const Color(0xfff4eddf),
                      child: SpiritCharacter(
                        look: _look,
                        pose: _pose,
                        expression: _expression,
                        mirrored: _mirrored,
                        onReady: (c) {
                          if (mounted) setState(() => _controller = c);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text('머리와 배를 눌러 보세요.', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    _chips([for (var i = 0; i < _poses.length; i++) ('$i ${_poses[i]}', i)], _pose,
                        (v) => setState(() => _pose = v)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final (label, onTap) in <(String, VoidCallback)>[
                          ('인사', () => _react('greet', _expression)),
                          ('기쁨', () => _react('joy', 1)),
                          ('화남', () => _react('angry', 5)),
                          ('머리 눌림', () => _press(SpiritPress.head)),
                          ('배 눌림', () => _press(SpiritPress.belly)),
                        ])
                          OutlinedButton(onPressed: _controller == null ? null : onTap, child: Text(label)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _chips([for (var i = 0; i < _expressions.length; i++) ('$i ${_expressions[i]}', i)],
                        _expression, (v) => setState(() => _expression = v)),
                    const SizedBox(height: 8),
                    _chips(_looks, _look, (v) => setState(() => _look = v)),
                    SwitchListTile(
                      title: const Text('좌우 뒤집기 (걷는 중)'),
                      value: _mirrored,
                      onChanged: (v) => setState(() => _mirrored = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
