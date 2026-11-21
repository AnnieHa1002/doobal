import 'dart:ui' show lerpDouble;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../domain/decor.dart';
import '../../domain/decor_place.dart';
import '../../domain/rest_camera.dart';

// 쉼터 꾸미기 상태와 끌기 (16장 11/18 ③·11/19, M2~M6 AB, config rest.decor).
// 편집 모드는 따로 없다: 물품을 길게 누르면 집히고(서랍이 열린다), 끌어서 놓으면 저장된다.
// 쉼터 옆 ‘꾸미기’ 버튼은 서랍(가진 물품 중 안 놓은 것)을 열고 닫는다. 서랍이 열린 동안이 ‘꾸미기 중’이다
// (연출 decorWiggle offInEditMode는 이때 흔들지 않는다, T19)

/// 집은 물품
class DecorHeld {
  const DecorHeld({required this.id, required this.flipped, required this.grab, this.from});

  final String id;
  final bool flipped;

  /// 손가락 자리 → 발 자리 (장면 pt). 놓인 물품을 집으면 누른 자리를 지키고, 서랍에서 꺼내면 손가락 끝이 발
  final ScenePoint grab;

  /// 집기 전 자리. 서랍에서 꺼냈으면 null
  final DecorSpot? from;

  DecorHeld flip() => DecorHeld(id: id, flipped: !flipped, grab: grab, from: from);
}

/// 쉼터 꾸미기 화면 상태: 서랍이 열렸는가, 고른 물품, 집은 물품과 그 발 자리
class DecorEdit extends ChangeNotifier {
  bool _drawerOpen = false;
  String? _selected;
  DecorHeld? _held;

  /// 집은 물품의 지금 발 자리 (손가락을 따라 자주 바뀌어서 따로 알린다)
  final foot = ValueNotifier<ScenePoint?>(null);

  /// 집은 물품이 서랍 위에 있다 (놓으면 치운다)
  final overDrawer = ValueNotifier<bool>(false);

  bool get drawerOpen => _drawerOpen;
  String? get selected => _selected;
  DecorHeld? get held => _held;

  /// 꾸미기 중: 서랍이 열렸거나 물품을 집었다
  bool get editing => _drawerOpen || _held != null;

  void openDrawer() {
    if (_drawerOpen) return;
    _drawerOpen = true;
    notifyListeners();
  }

  /// 서랍을 닫으면 고른 물품도 놓는다 (집은 동안에는 닫지 않는다)
  void closeDrawer() {
    if (!_drawerOpen || _held != null) return;
    _drawerOpen = false;
    _selected = null;
    notifyListeners();
  }

  void toggleDrawer() => _drawerOpen ? closeDrawer() : openDrawer();

  void select(String? id) {
    if (_selected == id) return;
    _selected = id;
    notifyListeners();
  }

  void _hold(DecorHeld h, ScenePoint at) {
    _held = h;
    _selected = h.id;
    foot.value = at;
    overDrawer.value = false;
    notifyListeners();
  }

  void _flipHeld() {
    final h = _held;
    if (h == null) return;
    _held = h.flip();
    notifyListeners();
  }

  void _release() {
    if (_held == null) return;
    _held = null;
    foot.value = null;
    overDrawer.value = false;
    notifyListeners();
  }

  @override
  void dispose() {
    foot.dispose();
    overDrawer.dispose();
    super.dispose();
  }
}

/// 화면이 build마다 넣어 주는 값 (화면 크기·테마가 바뀌면 같이 바뀐다)
class DecorFrame {
  const DecorFrame({
    required this.geometry,
    required this.stage,
    required this.item,
    required this.sceneBox,
    required this.drawerRect,
    required this.placedCount,
    this.liftCorrection,
  });

  final RestGeometry geometry;
  final DecorStage stage;
  final DecorItem? Function(String id) item;

  /// 장면 상자 (손가락 화면 자리 → 장면 상자 안 자리, 들어 올림 반영)
  final RenderBox? Function() sceneBox;

  /// 서랍 (화면 전체 좌표). 닫혀 있으면 null
  final Rect? Function() drawerRect;

  /// 지금 놓인 물품 수
  final int Function() placedCount;

  /// 장면을 들어 올리는 중이면 다 올린 뒤 자리와의 차이 (pt, 손가락 → 장면 자리를 다 올린 장면으로 센다:
  /// 집으면 서랍이 열려 장면이 올라가도 그대로 놓으면 제자리)
  final double Function()? liftCorrection;
}

/// 물품 끌기: 집기 → 끌기(땅 띠 안, 화면 끝이면 장면이 밀림) → 놓기(저장 · 못 놓는 자리면 튕겨 원래 자리로 ·
/// 서랍 위면 치우기)
class DecorDragger {
  DecorDragger({
    required this.edit,
    required this.camera,
    required TickerProvider vsync,
    required this.onPlace,
    required this.onRemove,
    required this.onFlip,
    this.onScrolled,
  })  : _bounce = AnimationController(vsync: vsync, duration: bounceDuration),
        _edgeTicker = null,
        _vsync = vsync {
    _bounce.addListener(_onBounce);
  }

  /// 튕겨 돌아가는 시간 (글 없음, ‘살짝’)
  static const bounceDuration = Duration(milliseconds: 220);

  final DecorEdit edit;
  final ValueNotifier<RestCamera> camera;
  final TickerProvider _vsync;

  /// 놓기 (발 자리·뒤집기). 저장은 부르는 쪽이 한다
  final Future<void> Function(String id, ScenePoint foot, bool flipped) onPlace;

  /// 서랍으로 치우기
  final Future<void> Function(String id) onRemove;

  /// 놓인 물품 뒤집기
  final Future<void> Function(String id) onFlip;

  /// 끄는 동안 장면을 밀었다 (놓은 뒤 끝으로 붙이게)
  final VoidCallback? onScrolled;

  DecorFrame? frame;

  final AnimationController _bounce;
  ScenePoint? _bounceFrom;
  ScenePoint? _bounceTo;
  Ticker? _edgeTicker;
  Duration _lastTick = Duration.zero;
  Offset? _finger;
  bool _scrolled = false;

  bool get holding => edit.held != null;

  /// 손가락 화면 자리 → 장면 pt
  ScenePoint? _toScene(Offset global) {
    final f = frame;
    final box = f?.sceneBox();
    if (f == null || box == null || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    final p = f.geometry.fromScreen(camera.value, local.dx, local.dy + (f.liftCorrection?.call() ?? 0));
    return ScenePoint(p.x, p.y);
  }

  /// [id]를 집는다. [from]은 놓여 있던 자리 (서랍에서 꺼내면 null). 서랍이 닫혀 있으면 연다
  void pick(String id, {DecorSpot? from, required Offset global}) {
    final f = frame;
    if (f == null || holding || _bounce.isAnimating) return;
    final item = f.item(id);
    if (item == null || !f.stage.canPlace(item)) return;
    // 서랍에서 꺼낼 때 이미 최대로 놓였으면 집히지 않는다
    if (from == null && f.placedCount() >= f.stage.rules.maxPlaced) return;
    // 서랍을 먼저 연다 (장면이 올라갈 자리로 손가락을 센다)
    edit.openDrawer();
    final finger = _toScene(global);
    if (finger == null) return;
    final grab = from == null
        ? const ScenePoint(0, 0)
        : ScenePoint(from.foot.x - finger.x, from.foot.y - finger.y);
    _finger = global;
    _scrolled = false;
    edit._hold(DecorHeld(id: id, flipped: from?.flipped ?? false, grab: grab, from: from),
        from?.foot ?? f.stage.clampToBand(finger));
    _update();
    _startEdge();
  }

  void move(Offset global) {
    if (!holding || _bounce.isAnimating) return;
    _finger = global;
    _update();
  }

  /// 뒤집기 버튼: 집은 동안(다른 손가락)이면 집은 물품을, 아니면 고른 물품을 좌우로 뒤집는다 (놓인 것은 바로 저장)
  Future<void> flip() async {
    if (holding) {
      edit._flipHeld();
      return;
    }
    final id = edit.selected;
    if (id != null) await onFlip(id);
  }

  /// 손을 뗐다
  Future<void> drop() async {
    _stopEdge();
    final h = edit.held;
    final f = frame;
    final at = edit.foot.value;
    if (h == null || f == null || at == null || _bounce.isAnimating) return;
    final item = f.item(h.id);
    if (edit.overDrawer.value) {
      edit._release();
      if (h.from != null) await onRemove(h.id);
      _settled();
      return;
    }
    final full = h.from == null && f.placedCount() >= f.stage.rules.maxPlaced;
    if (item == null || full || f.stage.blockedAt(item, at) != null) {
      _bounceBack(h, at);
      return;
    }
    edit._release();
    edit.select(h.id);
    await onPlace(h.id, at, h.flipped);
    _settled();
  }

  /// 몸짓이 끊겼다 (다른 몸짓에 졌다): 원래 자리로
  void cancel() {
    _stopEdge();
    final h = edit.held;
    final at = edit.foot.value;
    if (h == null || at == null || _bounce.isAnimating) return;
    _bounceBack(h, at);
  }

  /// 서랍 칸을 누르면 지금 보이는 장면 가운데(막혔으면 옆)에 놓는다 (캔버스 2-2)
  Future<bool> placeAtCenter(String id) async {
    final f = frame;
    if (f == null || holding) return false;
    final item = f.item(id);
    if (item == null || f.placedCount() >= f.stage.rules.maxPlaced) return false;
    final c = f.geometry.fromScreen(camera.value, f.geometry.width / 2, f.geometry.height / 2);
    final band = f.stage.band;
    final spot = f.stage.freeSpotNear(item, ScenePoint(c.x, (band.footYMin + band.footYMax) / 2));
    if (spot == null) return false;
    edit.select(id);
    await onPlace(id, spot, false);
    return true;
  }

  void _update() {
    final f = frame;
    final h = edit.held;
    final finger = _finger;
    if (f == null || h == null || finger == null) return;
    final p = _toScene(finger);
    if (p == null) return;
    final want = ScenePoint(p.x + h.grab.x, p.y + h.grab.y);
    // 서랍 위인지는 손가락이 아니라 물품 발이 화면에서 놓일 자리로 본다: 땅 띠 아래쪽 물품을 집으면 서랍이 손가락
    // 밑에 열리지만, 물품을 서랍 쪽으로 끌어 내려야 치운다
    final g = _footOnScreen(want);
    final over = g != null && (f.drawerRect()?.contains(g) ?? false);
    edit.overDrawer.value = over;
    // 서랍 위에서는 손가락을 그대로 따라가고, 아니면 땅 띠 안으로
    edit.foot.value = over ? want : f.stage.clampToBand(want);
  }

  /// 장면 자리 [p]가 다 올린 장면에서 화면 어디인가 (전체 좌표)
  Offset? _footOnScreen(ScenePoint p) {
    final f = frame;
    final box = f?.sceneBox();
    if (f == null || box == null || !box.hasSize) return null;
    final local = f.geometry.toScreen(camera.value, p.x, p.y);
    return box.localToGlobal(Offset(local.x, local.y)) - Offset(0, f.liftCorrection?.call() ?? 0);
  }

  void _bounceBack(DecorHeld h, ScenePoint at) {
    final back = h.from?.foot;
    if (back == null) {
      // 서랍에서 꺼낸 것은 서랍으로 (놓지 않음)
      edit._release();
      _settled();
      return;
    }
    _bounceFrom = at;
    _bounceTo = back;
    _bounce.forward(from: 0).whenCompleteOrCancel(() {
      edit._release();
      _settled();
    });
  }

  void _onBounce() {
    final a = _bounceFrom, b = _bounceTo;
    if (a == null || b == null) return;
    final t = Curves.easeOut.transform(_bounce.value);
    edit.foot.value = ScenePoint(lerpDouble(a.x, b.x, t)!, lerpDouble(a.y, b.y, t)!);
  }

  void _settled() {
    if (_scrolled) onScrolled?.call();
    _scrolled = false;
  }

  void _startEdge() {
    _lastTick = Duration.zero;
    _edgeTicker ??= _vsync.createTicker(_onEdgeTick);
    if (!_edgeTicker!.isActive) _edgeTicker!.start();
  }

  void _stopEdge() {
    if (_edgeTicker?.isActive ?? false) _edgeTicker!.stop();
  }

  void _onEdgeTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final f = frame;
    final finger = _finger;
    final box = f?.sceneBox();
    if (f == null || finger == null || box == null || !holding || dt <= 0) return;
    final local = box.globalToLocal(finger);
    final v = f.stage.edgeScrollSpeed(local.dx, f.geometry.width);
    if (v == 0) return;
    final c = camera.value;
    final next = f.geometry.clamp(RestCamera(x: c.x + v * dt, zoom: c.zoom));
    if (next == c) return;
    camera.value = next;
    _scrolled = true;
    _update();
  }

  void dispose() {
    _edgeTicker?.dispose();
    _bounce.dispose();
  }
}
