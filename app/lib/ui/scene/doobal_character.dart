import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/blink.dart';
import 'doobal_controller.dart';
import 'doobal_item_art.dart';

export 'doobal_controller.dart' show DoobalPose;

import 'package:rive/rive.dart' as rive;

/// 쉼터와 이동 장면에서 공유하는 캐릭터. speed: 0 숨쉬기, 1 걷기, 2 뛰기.
class DoobalCharacter extends StatefulWidget {
  const DoobalCharacter({
    super.key,
    required this.speed,
    this.pose = DoobalPose.standing,
    this.lookX = 0,
    this.lookY = 0,
  });
  final double speed;
  final DoobalPose pose;

  /// 원본 캔버스에서의 눈동자 이동량(px), 컨트롤러에서 ±5로 제한한다.
  final double lookX;
  final double lookY;
  static const asset = 'assets/rive/doobal_custom.riv';

  @override
  State<DoobalCharacter> createState() => _DoobalCharacterState();
}

class _DoobalCharacterState extends State<DoobalCharacter>
    with SingleTickerProviderStateMixin {
  rive.File? _file;
  DoobalItemArt? _art;
  DoobalController? _controller;
  rive.ViewModelInstance? _instance;
  rive.ViewModelInstanceNumber? _speed;
  double _target = 0;
  double _from = 0;
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
        DoobalCharacter.asset,
        riveFactory: rive.Factory.flutter,
        assetLoader: art.assetLoader,
      );
      await art.decodeArm();
      if (!mounted) {
        art.dispose();
        file?.dispose();
        return;
      }
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
        itemArt: art,
      );
      instance = controller.dataBind(rive.DataBind.auto());
      final speed = instance.number('speed');
      if (speed == null) throw StateError('캐릭터의 speed 항목이 없어요');
      speed.value = widget.pose == DoobalPose.standing ? widget.speed : 0;
      controller.initializeItems();
      controller.setPose(widget.pose);
      controller.setLook(widget.lookX, widget.lookY);
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
      debugPrint('두발 캐릭터 로드 실패: $e');
    }
  }

  @override
  void didUpdateWidget(DoobalCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pose != oldWidget.pose) _controller?.setPose(widget.pose);
    if (widget.speed != oldWidget.speed || widget.pose != oldWidget.pose) {
      _setSpeed(widget.pose == DoobalPose.standing ? widget.speed : 0);
    }
    if (widget.lookX != oldWidget.lookX || widget.lookY != oldWidget.lookY) {
      _controller?.setLook(widget.lookX, widget.lookY);
    }
  }

  void _setSpeed(double value) {
    _from = _speed?.value ?? 0;
    _target = value;
    _transition.forward(from: 0);
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
    return IgnorePointer(
      child: controller == null
          ? const SizedBox.expand()
          : rive.RiveWidget(controller: controller, fit: rive.Fit.contain),
    );
  }
}
