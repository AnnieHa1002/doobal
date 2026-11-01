import 'dart:math';
import 'dart:ui' as ui;

import 'doobal_item_art.dart';

import 'package:rive/rive.dart' as rive;

import '../../domain/blink.dart';

/// Rive ViewModel2.pose의 값. 이동 속도와 별개로 자세를 선택한다.
enum DoobalPose {
  standing(0),
  sitting(1),
  boat(2);

  const DoobalPose(this.value);
  final double value;
}

/// 이동·자세 상태 머신을 재생한 뒤 눈 깜빡임만 겹친다.
/// 프레임 시간으로 간격을 세어 화면이 숨겨진 동안 깜빡임이 쌓이지 않는다.
final class DoobalController extends rive.RiveWidgetController {
  DoobalController(
    super.file, {
    required this.blinkRule,
    Random? random,
    this.itemArt,
  }) : _random = random ?? Random() {
    _blink = artboard.animationNamed('blink');
    if (_blink == null) {
      dispose();
      throw StateError('캐릭터의 blink 동작이 없어요');
    }
    _plan();
  }

  final DoobalItemArt? itemArt;
  final _bones = <String, rive.Component>{};
  final _inverse = <String, rive.Mat2D>{};
  bool get supportsItems => _bones.length == 6;
  void initializeItems() {
    if (itemArt == null || _bones.isNotEmpty) return;
    if (!itemArt!.supportsSeatedArt) {
      throw StateError('앉기 전용 파츠가 빠졌어요');
    }
    advance(0);
    for (final name in [
      'head',
      'motion_root',
      'elbow_r',
      'char_body_arm_lower_r',
      'item_cloth_01_arm_upper_r',
      'char_body_torso',
    ]) {
      final component = artboard.component(name);
      if (component == null) throw StateError('소품 관절이 없어요: $name');
      final inverse = rive.Mat2D();
      if (!rive.Mat2D.invert(inverse, component.worldTransform)) {
        throw StateError('소품 관절 좌표 오류');
      }
      _bones[name] = component;
      _inverse[name] = inverse;
    }
  }

  rive.Mat2D itemTransform(String bone) => rive.Mat2D.multiply(
    rive.Mat2D(),
    _bones[bone]!.worldTransform,
    _inverse[bone]!,
  );
  void _item(rive.Renderer renderer, String key, String bone) {
    final image = itemArt?.images[key];
    if (image == null) return;
    renderer.save();
    renderer.transform(itemTransform(bone));
    if (key == 'bag_back') {
      renderer.translate(-60 * _brushSitProgress, 120 * _brushSitProgress);
    }
    if (key == 'hand') {
      if (_brushSitProgress > 0) {
        renderer.translate(300, 920);
        renderer.rotate(brushAngle);
        renderer.translate(-300, -920);
      }
      renderer.transform(rive.Mat2D.fromTranslate(650, 1800));
      renderer.scale(-1, -1);
    }
    renderer.drawImage(
      image,
      ui.BlendMode.srcOver,
      key == 'bag_strap' ? 1 - _brushSitProgress : 1,
    );
    renderer.restore();
  }

  @override
  void paint(rive.Renderer renderer, ui.Size size, double paintPixelRatio) {
    if (!supportsItems) {
      super.paint(renderer, size, paintPixelRatio);
      return;
    }
    renderer.save();
    renderer.align(
      fit,
      alignment,
      rive.AABB.fromValues(0, 0, size.width, size.height),
      artboard.bounds,
      layoutScaleFactor,
    );
    _item(renderer, 'bag_back', 'motion_root');
    final blend =
        _brushSitProgress * _brushSitProgress * (3 - 2 * _brushSitProgress);
    final art = itemArt!;
    if (blend > 0) {
      // 기존 하체만 흐리게 남기고, 상체는 한 번만 불투명하게 그린다.
      if (blend < 1) {
        art.setSeatedArt(false);
        renderer.save();
        renderer.clipRect(
          ui.Rect.fromLTRB(
            0,
            790 + itemTransform('motion_root')[5],
            1024,
            1280,
          ),
        );
        renderer.modulateOpacity(1 - blend);
        artboard.draw(renderer);
        renderer.restore();
      }
      final lower = art.images['sit_lower_v04']!;
      renderer.save();
      renderer.transform(itemTransform('motion_root'));
      renderer.drawImage(lower, ui.BlendMode.srcOver, blend);
      renderer.restore();
      art.setSeatedArt(true);
    } else {
      art.setSeatedArt(false);
    }
    renderer.restore();
    super.paint(renderer, size, paintPixelRatio);
    _item(renderer, 'bag_strap', 'motion_root');
    _item(renderer, 'hand', 'elbow_r');
    // 앞팔은 어깨끈 위에 놓인다. 원본 이미지 노드의 좌표를 그대로 사용한다.
    for (final pair in [
      ('cloth_arm_upper_r', 'item_cloth_01_arm_upper_r'),
      ('arm', 'char_body_arm_lower_r'),
    ]) {
      final image = itemArt?.images[pair.$1];
      if (image == null) continue;
      renderer.save();
      renderer.transform(_bones[pair.$2]!.worldTransform);
      renderer.translate(-image.width / 2, -image.height / 2);
      renderer.drawImage(image, ui.BlendMode.srcOver, 1);
      renderer.restore();
    }
    _item(renderer, 'hat', 'head');
    _item(renderer, 'pet', 'head');
  }

  final BlinkRule blinkRule;
  final Random _random;
  rive.Animation? _blink;
  rive.ViewModelInstanceNumber? _lookX;
  rive.ViewModelInstanceNumber? _lookY;
  rive.ViewModelInstanceNumber? _pose;
  double _brushSitProgress = 0;

  /// 자세 전환 중에도 손 소품이 즉시 꺾이지 않도록 350ms 동안 보간한다.
  double get brushAngle {
    final t = _brushSitProgress;
    return pi / 3 * t * t * (3 - 2 * t);
  }

  double _wait = 0;
  double? _secondGap;
  double _blinkTime = double.infinity;

  bool get isBlinking => _blinkTime <= (_blink?.duration ?? 0);

  /// 시선 값은 원본 캔버스 px. Rive에서 두 입력이 연결된 파일만 지원한다.
  bool get supportsLook => _lookX != null && _lookY != null;

  @override
  rive.ViewModelInstance dataBind(rive.DataBind dataBind) {
    final instance = super.dataBind(dataBind);
    _lookX = instance.number('lookX');
    _lookY = instance.number('lookY');
    _pose = instance.number('pose');
    return instance;
  }

  /// 눈동자 그룹만 ±5px 안에서 움직인다. 이전 파일에서는 동작을 바꾸지 않는다.
  bool setLook(double x, double y) {
    if (!supportsLook) return false;
    double bounded(double value) => value.isFinite ? value.clamp(-5.0, 5.0) : 0;
    _lookX!.value = bounded(x);
    _lookY!.value = bounded(y);
    scheduleRepaint();
    return true;
  }

  bool get supportsPose => _pose != null;

  /// Rive 안의 전환이 앉기·일어서기와 배 위 자세를 처리한다.
  /// 이전 파일에서는 지원하지 않는 자세를 적용하지 않는다.
  bool setPose(DoobalPose pose) {
    final input = _pose;
    if (input == null) return false;
    input.value = pose.value;
    scheduleRepaint();
    return true;
  }

  bool sit() => setPose(DoobalPose.sitting);
  bool stand() => setPose(DoobalPose.standing);

  void _plan() {
    final times = nextBlinks(blinkRule, _random);
    _wait = times.first.inMicroseconds / Duration.microsecondsPerSecond;
    _secondGap = times.length > 1
        ? (times[1] - times[0]).inMicroseconds / Duration.microsecondsPerSecond
        : null;
  }

  /// 시험 화면에서도 이동을 끊지 않고 눈만 감았다 뜨게 한다.
  void blinkNow() {
    _blinkTime = 0;
    scheduleRepaint();
  }

  @override
  bool advance(double elapsedSeconds) {
    super.advance(elapsedSeconds);
    final brushTarget = _pose?.value == DoobalPose.sitting.value ? 1.0 : 0.0;
    final step = elapsedSeconds.isFinite
        ? max(0.0, elapsedSeconds) / 0.35
        : 0.0;
    _brushSitProgress = brushTarget > _brushSitProgress
        ? min(brushTarget, _brushSitProgress + step)
        : max(brushTarget, _brushSitProgress - step);
    _wait -= elapsedSeconds;
    if (_wait <= 0) {
      blinkNow();
      final second = _secondGap;
      if (second != null) {
        _wait = second;
        _secondGap = null;
      } else {
        _plan();
      }
    }
    final blink = _blink!;
    // 완료한 뒤에도 뜬 눈을 적용해 기존 상태 머신의 눈 키와 충돌하지 않게 한다.
    blink.time = _blinkTime.clamp(0, blink.duration);
    blink.advanceAndApply(0);
    _blinkTime += elapsedSeconds;
    // 다음 무작위 깜빡임을 위해 시계를 계속 진행한다 (숨쉬기도 계속 재생).
    return active;
  }

  @override
  void dispose() {
    for (final bone in _bones.values) {
      bone.dispose();
    }
    _bones.clear();
    _blink?.dispose();
    super.dispose();
  }
}
