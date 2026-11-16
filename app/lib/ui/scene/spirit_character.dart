import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../../domain/rules.dart';
import '../../domain/screen_rules.dart';
import '../../domain/spirit_look.dart';

import 'spirit_controller.dart';

/// 정령 캔버스 600×600, 기본 머리 위 y150, 발바닥 y440.
class SpiritCharacter extends StatefulWidget {
  const SpiritCharacter({
    super.key,
    this.speed = 0,
    this.sitting = false,
    this.boat = false,
    this.lookX = 0,
    this.lookY = 0,
    this.look = SpiritLook.base,
    this.tapRules,
    this.expression = 0,
    this.pose,
    this.mirrored = false,
    this.cue,
    this.cues,
    this.onReady,
    this.riveFactory,
  });
  /// 앱용 정령 Rive v36 (16장 11/14 정령 기준, 아트보드 `Spirit` 502×600, 바탕 투명, 입력은 v33과 같다.
  /// 머리 선택 5 새싹·6 꽃은 riv에만 있고 앱은 보내지 않는다)
  static const asset = 'assets/rive/spirit_v36.riv';
  @visibleForTesting
  static rive.Factory renderer = rive.Factory.rive;
  final double speed, lookX, lookY;
  final bool sitting, boat;

  /// 고른 얼굴, 입은 소품, 몸 색
  final SpiritLook look;

  /// 주면 정령을 연타할 때 화낸다 (쉼터·꾸미기만). config character.tapReaction
  final Rules? tapRules;

  /// 늘 두는 표정 Rive expr (0 기본·1 행복·2 놀람·3 울먹임·4 졸림·5 화남, 정령 계약 4장). 밤 쉼터는 졸림
  final int expression;

  /// 화면이 정한 자세 poseChoice (config character.rive.screens·restSwap). null이면 [speed]·[sitting]이 정한다
  final int? pose;

  /// 좌우로 뒤집는다 (옆모습이 오른쪽을 봐야 하는 걷는 중, config flipSideOn). 발 디딤점을 축으로 뒤집는다
  final bool mirrored;

  /// 잠깐 보일 표정 신호 (도착·만남·새 소품 …). 다른 객체로 바뀔 때마다 한 번 울린다
  final SpiritCue? cue;

  /// 누르기 행복·연타 화남 표정 (palette 표정 호출 표). 없으면 동작만
  final SpiritCues? cues;
  final ValueChanged<SpiritController>? onReady;

  /// 이 정령만 다른 그리기로 (없으면 [SpiritCharacter.renderer]). 하루 카드 공유 이미지는 Flutter 그리기로
  /// 그려야 RepaintBoundary로 뜰 수 있다 (Rive 그리기는 화면 텍스처라 이미지에 안 담길 수 있다)
  final rive.Factory? riveFactory;
  @override
  State<SpiritCharacter> createState() => _SpiritCharacterState();
}

/// v33을 600 캔버스에 놓던 배율 (11/12 통합본이 잘라 쓰던 배율 328.16 / 560, v33 원점은 v32 판의 (44, 252))
const _v33Scale = 328.16 / 560;

/// 발 디딤점(아트보드 (244, 559), v33·v36 같음)이 600 캔버스에 놓이는 자리. v33 때 자리 그대로
const _footX = 133 + (44 + 244) * _v33Scale;
const _footY = 68 + (252 - 180 + 559) * _v33Scale;

/// 좌우 뒤집기 축: 아트보드 발 디딤점 x 244 / 502 (config bodyBox.footPoint). 가운데로 뒤집으면 발이 약 3% 밀린다
const _footAxis = Alignment(2 * 244 / 502 - 1, 0);

/// 600 캔버스에서 v36 그림 1px의 크기. v36은 그림 전체가 v33의 0.97배라(v35 표시 여유) 몸 키가
/// v33과 같게 키운다: 자세 0·여행복·소품 없음 첫 장면 실측(11/15) 몸 키 v33 488.5px ÷ v36 473.5px
const _scale = _v33Scale * 488.5 / 473.5;

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
        riveFactory: widget.riveFactory ?? SpiritCharacter.renderer,
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
      controller.setLook(widget.lookX, widget.lookY);
      controller.wear(widget.look);
      controller.tapRules = widget.tapRules;
      controller.cues = widget.cues;
      controller.setPose(widget.pose);
      controller.setBaseExpression(widget.expression);
      if (widget.cue case final c?) controller.cue(c);
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
    _controller?.cues = widget.cues;
    if (widget.pose != oldWidget.pose) _controller?.setPose(widget.pose);
    if (widget.expression != oldWidget.expression) {
      _controller?.setBaseExpression(widget.expression);
    }
    if (widget.cue case final c? when !identical(c, oldWidget.cue)) _controller?.cue(c);
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
    // v36 `Spirit` 아트보드(502×600)를 기존 600 캔버스(머리 위 y150~발 y440 잣대)에 놓는다.
    // 발 디딤점과 몸 키를 v33 자리(11/12 통합본과 픽셀까지 같게 맞춘 것)와 같게 둔다
    final view = FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 600,
        height: 600,
        child: Stack(
          children: [
            Positioned(
              left: _footX - 244 * _scale,
              top: _footY - 559 * _scale,
              width: 502 * _scale,
              height: 600 * _scale,
              child: widget.mirrored
                  ? Transform(
                      key: const ValueKey('spirit-mirrored'),
                      alignment: _footAxis,
                      transform: Matrix4.diagonal3Values(-1, 1, 1),
                      child: rive.RiveWidget(controller: controller, fit: rive.Fit.contain),
                    )
                  : rive.RiveWidget(controller: controller, fit: rive.Fit.contain),
            ),
          ],
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
    this.pose,
    this.cue,
    this.cues,
    this.tapRules,
    this.onReady,
    this.riveFactory,
  });

  final ValueChanged<SpiritController>? onReady;
  final SpiritLook look;
  final double share, footAt;

  /// [SpiritCharacter.riveFactory]와 같다
  final rive.Factory? riveFactory;

  /// 표정·자세·표정 신호와 연타 화남 규칙 (SpiritCharacter와 같다)
  final int expression;
  final int? pose;
  final SpiritCue? cue;
  final SpiritCues? cues;
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
                  pose: pose,
                  cue: cue,
                  cues: cues,
                  tapRules: tapRules,
                  onReady: onReady,
                  riveFactory: riveFactory,
                ),
              ),
          ],
        );
      },
    );
  }
}
