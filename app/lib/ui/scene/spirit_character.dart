import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../../domain/rules.dart';
import '../../domain/spirit_look.dart';

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
    this.look = SpiritLook.base,
    this.tapRules,
    this.expression = 0,
    this.onReady,
  });
  static const asset = 'assets/rive/doobal_unified.riv';
  @visibleForTesting
  static rive.Factory renderer = rive.Factory.rive;
  final double speed, lookX, lookY;
  final bool sitting, boat, capeEnabled;

  /// 고른 얼굴, 입은 소품, 몸 색
  final SpiritLook look;

  /// 주면 정령을 연타할 때 화낸다 (쉼터·꾸미기만). config character.tapReaction
  final Rules? tapRules;

  /// 고른 표정 번호 (0 기본·1 행복·2 울먹임·3 놀람·4 졸림·5 화남, 꾸미기 표정 미리보기)
  final int expression;
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
        riveFactory: SpiritCharacter.renderer,
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
      controller.wear(widget.look);
      controller.tapRules = widget.tapRules;
      controller.setExpression(widget.expression);
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
    if (widget.look != oldWidget.look) _controller?.wear(widget.look);
    _controller?.tapRules = widget.tapRules;
    if (widget.expression != oldWidget.expression) {
      _controller?.setExpression(widget.expression);
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
    // 통합 조작판은 게임 안에 노출하지 않고, 그림 영역만 기존600좌표 장면에 맞춘다.
    final view = LayoutBuilder(
      builder: (context, box) => FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 600,
          height: 600,
          child: Stack(
            children: [
              Positioned(
                left: 133,
                top: 68,
                width: 328.16,
                height: 436.57,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 560,
                    height: 745,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: 1500,
                        maxWidth: 1500,
                        minHeight: 1100,
                        maxHeight: 1100,
                        child: Transform.translate(
                          offset: const Offset(0, -180),
                          child: rive.RiveWidget(
                            controller: controller,
                            fit: rive.Fit.contain,
                          ),
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
    );
    return Semantics(
      label: '두발 정령. 머리와 배를 눌러 볼 수 있어요',
      child: LayoutBuilder(
        builder: (context, box) {
          void center() => controller.setLook(widget.lookX, widget.lookY);
          void gaze(Offset point) {
            final scale =
                (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight) /
                600;
            if (scale <= 0) return;
            final x = (point.dx - (box.maxWidth - 600 * scale) / 2) / scale;
            final y = (point.dy - (box.maxHeight - 600 * scale) / 2) / scale;
            controller.setLook((x - 300) / 140, (y - 240) / 140);
          }

          return MouseRegion(
            onHover: (e) => gaze(e.localPosition),
            onExit: (_) => center(),
            child: Listener(
              onPointerMove: (e) => gaze(e.localPosition),
              onPointerUp: (_) => center(),
              onPointerCancel: (_) => center(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final scale = box.maxWidth < box.maxHeight
                      ? box.maxWidth / 600
                      : box.maxHeight / 600;
                  if (scale <= 0) return;
                  final x =
                      (d.localPosition.dx - (box.maxWidth - 600 * scale) / 2) /
                      scale;
                  final y =
                      (d.localPosition.dy - (box.maxHeight - 600 * scale) / 2) /
                      scale;
                  if (x >= 200 && x <= 400 && y >= 135 && y <= 300) {
                    controller.press(SpiritPress.head);
                  } else if (x >= 230 && x <= 380 && y > 300 && y <= 445) {
                    controller.press(SpiritPress.belly);
                  }
                },
                onTapUp: (_) => controller.release(),
                onTapCancel: controller.release,
                child: view,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 상자 안에 정령을 세운다 (꾸미기 미리보기·나의 정보 초상). 쉼터와 같은 잣대로
/// 머리 위 y150~발바닥 y440을 키로 보고, 키는 짧은 변의 [share], 발바닥은 위에서 [footAt] 높이다.
/// 상자 밖으로 나간 캔버스 가장자리는 잘린다
class SpiritStanding extends StatelessWidget {
  const SpiritStanding({
    super.key,
    this.look = SpiritLook.base,
    this.share = 0.6,
    this.footAt = 0.88,
    this.expression = 0,
    this.tapRules,
    this.onReady,
  });

  final ValueChanged<SpiritController>? onReady;
  final SpiritLook look;
  final double share, footAt;

  /// 표정 번호와 연타 화남 규칙 (SpiritCharacter와 같다)
  final int expression;
  final Rules? tapRules;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale =
            (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight) *
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
                child: SpiritCharacter(
                  look: look,
                  expression: expression,
                  tapRules: tapRules,
                  onReady: onReady,
                ),
              ),
          ],
        );
      },
    );
  }
}
