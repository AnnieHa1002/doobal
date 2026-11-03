import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'spirit_controller.dart';

/// 정령 캔버스 600×600, 기본 머리 위 y150, 발바닥 y440.
class SpiritCharacter extends StatefulWidget {
  const SpiritCharacter({
    super.key,
    this.speed = 0,
    this.sitting = false,
    this.boat = false,
    this.capeEnabled = false,
    this.lookX = 0,
    this.lookY = 0,
    this.onReady,
  });
  static const asset = 'assets/rive/doobal_spirit.riv';
  final double speed, lookX, lookY;
  final bool sitting, boat, capeEnabled;
  final ValueChanged<SpiritController>? onReady;
  @override
  State<SpiritCharacter> createState() => _SpiritCharacterState();
}

class _SpiritCharacterState extends State<SpiritCharacter>
    with WidgetsBindingObserver {
  rive.File? _file;
  SpiritController? _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    rive.File? file;
    SpiritController? controller;
    try {
      await rive.RiveNative.init();
      file = await rive.File.asset(
        SpiritCharacter.asset,
        riveFactory: rive.Factory.flutter,
      );
      if (file == null) throw StateError('정령 파일을 읽지 못했어요');
      if (!mounted) {
        file.dispose();
        return;
      }
      controller = SpiritController(file);
      controller.setScene(
        speed: widget.speed,
        sitting: widget.sitting,
        boat: widget.boat,
      );
      controller.setCape(widget.capeEnabled);
      controller.setLook(widget.lookX, widget.lookY);
      setState(() {
        _file = file;
        _controller = controller;
      });
      widget.onReady?.call(controller);
    } catch (error) {
      controller?.dispose();
      file?.dispose();
      debugPrint('정령 로드 실패: $error');
    }
  }

  @override
  void didUpdateWidget(SpiritCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.capeEnabled != oldWidget.capeEnabled) {
      _controller?.setCape(widget.capeEnabled);
    }
    if (widget.speed != oldWidget.speed ||
        widget.sitting != oldWidget.sitting ||
        widget.boat != oldWidget.boat) {
      _controller?.setScene(
        speed: widget.speed,
        sitting: widget.sitting,
        boat: widget.boat,
      );
    }
    if (widget.lookX != oldWidget.lookX || widget.lookY != oldWidget.lookY) {
      _controller?.setLook(widget.lookX, widget.lookY);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.release();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.expand();
    return Semantics(
      label: '두발 정령. 머리와 배를 눌러 볼 수 있어요',
      child: Listener(
        onPointerUp: (_) => controller.release(),
        onPointerCancel: (_) => controller.release(),
        child: rive.RiveWidget(controller: controller, fit: rive.Fit.contain),
      ),
    );
  }
}

/// 상자 안에 정령을 세운다 (꾸미기 미리보기·나의 정보 초상). 쉼터와 같은 잣대로
/// 머리 위 y150~발바닥 y440을 키로 보고, 키는 짧은 변의 [share], 발바닥은 위에서 [footAt] 높이다.
/// 상자 밖으로 나간 캔버스 가장자리는 잘린다
class SpiritStanding extends StatelessWidget {
  const SpiritStanding({super.key, this.share = 0.6, this.footAt = 0.88});

  final double share, footAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final scale = (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight) *
          share /
          (440 - 150);
      return Stack(
        children: [
          if (scale > 0)
            Positioned(
              left: box.maxWidth / 2 - 300 * scale,
              top: box.maxHeight * footAt - 440 * scale,
              width: 600 * scale,
              height: 600 * scale,
              child: const SpiritCharacter(),
            ),
        ],
      );
    });
  }
}
