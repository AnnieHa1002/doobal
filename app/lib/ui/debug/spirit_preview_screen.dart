import 'package:flutter/material.dart';

import '../../domain/spirit_look.dart';
import '../scene/spirit_character.dart';
import '../scene/spirit_controller.dart';

/// 실제 앱에서 일곱 동작과 손가락 눌림을 확인하는 화면.
class SpiritPreviewScreen extends StatefulWidget {
  const SpiritPreviewScreen({super.key});
  @override
  State<SpiritPreviewScreen> createState() => _SpiritPreviewScreenState();
}

class _SpiritPreviewScreenState extends State<SpiritPreviewScreen> {
  SpiritController? _controller;
  bool _cape = true;
  var _look = SpiritLook.base;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('정령 움직임')),
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
                    capeEnabled: _cape,
                    look: _look,
                    onReady: (c) {
                      if (mounted) setState(() => _controller = c);
                    },
                  ),
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('여행 망토'),
            value: _cape,
            onChanged: (value) => setState(() => _cape = value),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('머리와 배를 꾹 눌렀다가 놓아 보세요.'),
          ),
          // Rive v25에 붙은 소품 5종 (props v4 id: hand_01·hand_02·cloth_02·cloth_05·pet_05)
          Wrap(
            spacing: 8,
            children: [
              for (final (label, look) in [
                ('소품 없음', SpiritLook.base),
                ('큰 붓', SpiritLook.base.copyWith(bag: 1)),
                ('봇짐 지팡이', SpiritLook.base.copyWith(bag: 2)),
                ('여행복', SpiritLook.base.copyWith(outfit: 1)),
                ('연두 여행 망토', SpiritLook.base.copyWith(outfit: 2)),
                ('괭이갈매기', SpiritLook.base.copyWith(companion: 1)),
              ])
                OutlinedButton(
                  onPressed: () => setState(() {
                    _look = look;
                    if (look != SpiritLook.base) _cape = false;
                  }),
                  child: Text(label),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in const {
                  SpiritMotion.idle: '기본',
                  SpiritMotion.wave: '손 흔들기',
                  SpiritMotion.walk: '옆으로 걷기',
                  SpiritMotion.sit: '앉아서 쉬기',
                  SpiritMotion.fall: '넘어지기',
                  SpiritMotion.run: '뛰기',
                  SpiritMotion.laugh: '웃기',
                  SpiritMotion.sleep: '누워서 자기',
                }.entries)
                  OutlinedButton(
                    onPressed: _controller == null
                        ? null
                        : () => _controller!.play(entry.key),
                    child: Text(entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
