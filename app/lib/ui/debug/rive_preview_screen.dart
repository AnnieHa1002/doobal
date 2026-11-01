import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/blink.dart';
import '../scene/doobal_controller.dart';

import 'package:rive/rive.dart' as rive;

import 'rive_blink_preview_screen.dart';
import '../scene/doobal_item_art.dart';

/// 내보낸 캐릭터의 데이터 바인딩과 이동 동작을 확인하는 개발 화면.
class RivePreviewScreen extends StatefulWidget {
  const RivePreviewScreen({super.key, this.random});

  final Random? random;
  static const asset = 'assets/rive/doobal_custom.riv';

  @override
  State<RivePreviewScreen> createState() => _RivePreviewScreenState();
}

class _RivePreviewScreenState extends State<RivePreviewScreen>
    with SingleTickerProviderStateMixin {
  rive.File? _file;
  DoobalItemArt? _art;
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _instance;
  rive.ViewModelInstanceNumber? _speed;
  String? _error;
  double _target = 0;
  double _from = 0;
  double _lookX = 0;
  double _lookY = 0;
  DoobalPose _pose = DoobalPose.standing;
  late final AnimationController _transition =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      )..addListener(() {
        final t = Curves.easeInOut.transform(_transition.value);
        _speed?.value = _from + (_target - _from) * t;
        _controller?.scheduleRepaint();
      });

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    rive.File? file;
    DoobalController? controller;
    rive.ViewModelInstance? instance;
    final art = DoobalItemArt();
    try {
      await rive.RiveNative.init();
      await art.load();
      file = await rive.File.asset(
        RivePreviewScreen.asset,
        riveFactory: rive.Factory.flutter,
        assetLoader: art.assetLoader,
      );
      await art.decodeArm();
      if (file == null) throw StateError('캐릭터 파일을 읽지 못했어요');
      final config = jsonDecode(
        await rootBundle.loadString('assets/data/config.json'),
      ) as Map<String, dynamic>;
      if (!mounted) {
        file.dispose();
        art.dispose();
        return;
      }
      controller = DoobalController(
        file,
        blinkRule: BlinkRule.fromConfig(config),
        random: widget.random,
        itemArt: art,
      );
      instance = controller.dataBind(rive.DataBind.auto());
      controller.initializeItems();
      final speed = instance.number('speed');
      if (speed == null) throw StateError('캐릭터의 speed 항목이 없어요');
      speed.value = 0;
      if (!mounted) {
        controller.dispose();
        instance.dispose();
        file.dispose();
        art.dispose();
        return;
      }
      setState(() {
        _file = file;
        _art = art;
        _controller = controller;
        _instance = instance;
        _speed = speed;
      });
    } catch (e) {
      controller?.dispose();
      instance?.dispose();
      file?.dispose();
      art.dispose();
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _setSpeed(double value) {
    final controller = _controller;
    if (value > 0 && controller is DoobalController) {
      controller.stand();
      _pose = DoobalPose.standing;
    }
    _from = _speed?.value ?? 0;
    setState(() => _target = value);
    _transition.forward(from: 0);
  }

  void _setPose(DoobalPose pose) {
    final controller = _controller;
    if (controller is! DoobalController || !controller.setPose(pose)) return;
    setState(() => _pose = pose);
    if (pose != DoobalPose.standing) _setSpeed(0);
  }

  @override
  void dispose() {
    _transition.dispose();
    _controller?.dispose();
    _instance?.dispose();
    _file?.dispose();
    _art?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Rive 동작 시험')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center))
                  : controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : ColoredBox(
                      color: const Color(0xFFE7E1D4),
                      child: rive.RiveWidget(
                        controller: controller,
                        fit: rive.Fit.contain,
                      ),
                    ),
            ),
            Flexible(
              flex: 0,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final entry in {
                            0.0: '정지',
                            1.0: '걷기',
                            2.0: '뛰기',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _target == entry.key,
                              onSelected: controller == null
                                  ? null
                                  : (_) => _setSpeed(entry.key),
                            ),
                        ],
                      ),
                      Slider(
                        value: _target,
                        min: 0,
                        max: 2,
                        divisions: 20,
                        label: _target.toStringAsFixed(1),
                        onChanged: controller == null ? null : _setSpeed,
                      ),
                      const Text('중간 속도에서도 팔·다리와 정지 복귀를 확인해 주세요.'),
                      if (controller is DoobalController &&
                          controller.supportsPose)
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final entry in {
                              DoobalPose.standing: '서 있기',
                              DoobalPose.sitting: '앉기',
                              DoobalPose.boat: '배 위',
                            }.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: _pose == entry.key,
                                onSelected: (_) => _setPose(entry.key),
                              ),
                          ],
                        ),
                      if (controller is DoobalController &&
                          controller.supportsLook) ...[
                        const Text('좌우 시선'),
                        Slider(
                          value: _lookX,
                          min: -5,
                          max: 5,
                          onChanged: (value) {
                            setState(() => _lookX = value);
                            controller.setLook(_lookX, _lookY);
                          },
                        ),
                        const Text('위아래 시선'),
                        Slider(
                          value: _lookY,
                          min: -5,
                          max: 5,
                          onChanged: (value) {
                            setState(() => _lookY = value);
                            controller.setLook(_lookX, _lookY);
                          },
                        ),
                      ],
                      TextButton(
                        onPressed: controller is DoobalController
                            ? controller.blinkNow
                            : null,
                        child: const Text('지금 깜빡'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RiveBlinkPreviewScreen(random: widget.random),
                          ),
                        ),
                        child: const Text('기존 눈 깜빡임 시험 열기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
