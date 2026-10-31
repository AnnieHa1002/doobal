import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/live_steps.dart';
import '../domain/live_walk.dart';
import '../domain/rules.dart';

/// 앱이 숨어 있는 동안 센서 값으로 미리 낸 걸음 수와 거리(m)
typedef HiddenPreview = ({int steps, double distanceM});

/// 걷는 중 화면 하나가 쓰는 실시간 걸음. 센서 스트림을 [LiveWalk]에 먹인다.
/// 센서가 없거나 권한이 없으면 [LiveWalk.active]가 false인 채로 있어서, 화면은 health 값만 쓴다.
/// 앱이 뒤로 가도 센서 읽기는 멈추지 않는다 (안드로이드는 걷는 중 상시 알림이 앱을 살려 둔다.
/// iOS는 앱이 멈춰서 아무 값도 오지 않는다). 숨은 시각은 [LiveWalk.pause]에 적되 숨어 있는 동안의
/// 값은 [LiveWalk]에 먹이지 않고 마지막 값과 받은 시각만 기억해 둔다. 그 값으로 걸음·거리 미리보기를
/// [onHiddenSteps]에 알리고(알림 갱신용), 앱이 다시 앞으로 오면 마지막 값을 받은 시각으로 한 번 먹인다.
/// 센서 값은 부팅 이후 누적이라 그 값에 숨어 있던 동안의 걸음이 다 들어 있고, [LiveWalk]가 그걸 센다.
/// 숨어 있는 사이 앱이 종료되면 이 걸음은 놓친다 (health 기록에는 남는다)
class LiveWalker {
  LiveWalker({
    required this._steps,
    required Rules rules,
    required this._clock,
    required this._denied,
    required this._onDenied,
    this.onHiddenSteps,
  }) : walk = LiveWalk(rules);

  final LiveSteps _steps;
  final DateTime Function() _clock;

  /// 이번 앱 실행 중 권한을 거부당한 적이 있는가 / 거부당했다고 적어 두기
  final bool Function() _denied;
  final void Function() _onDenied;

  /// 앱이 숨어 있는 동안 센서 값이 올 때마다 그때의 걸음·거리 미리보기
  /// ([LiveWalk.previewSteps]·[LiveWalk.previewDistanceM])를 알린다
  final void Function(HiddenPreview preview)? onHiddenSteps;

  final LiveWalk walk;

  StreamSubscription<int>? _sub;
  AppLifecycleListener? _lifecycle;
  var _ready = false;
  var _disposed = false;

  /// 앱이 뒤로 가 있는가. 이 동안 받은 값은 [LiveWalk]에 먹이지 않고 마지막 것만 둔다
  var _hidden = false;
  int? _hiddenTotal;
  DateTime? _hiddenAt;

  /// 권한이 있어서 센서를 읽고 있는가 (권한을 못 받았거나 센서가 오류를 줬으면 false)
  bool get ready => _ready;

  /// 권한을 확인하고(없으면 거부된 적이 없을 때 한 번 묻고) 센서 읽기를 시작한다
  Future<void> start() async {
    _lifecycle = AppLifecycleListener(onHide: _hide, onResume: _resume);
    try {
      if (!await _steps.hasPermission()) {
        if (_denied()) return;
        if (!await _steps.requestPermission()) {
          _onDenied();
          return;
        }
      }
    } catch (e) {
      debugPrint('걸음 센서 권한 확인 실패: $e');
      return;
    }
    if (_disposed) return;
    _ready = true;
    _listen();
  }

  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    _unlisten();
  }

  void _listen() {
    if (_sub != null) return;
    _sub = _steps.stepCounts().listen(
          _onCount,
          onError: (Object e) {
            // 센서가 없는 기기: 읽기를 그만두고 health 값만 쓴다
            debugPrint('걸음 센서 읽기 실패: $e');
            _ready = false;
            _unlisten();
          },
          onDone: () => _sub = null,
        );
  }

  void _unlisten() {
    _sub?.cancel();
    _sub = null;
  }

  void _onCount(int total) {
    final at = _clock();
    if (!_hidden) {
      walk.onCount(total, at);
      return;
    }
    _hiddenTotal = total;
    _hiddenAt = at;
    onHiddenSteps?.call((
      steps: walk.previewSteps(total),
      distanceM: walk.previewDistanceM(total),
    ));
  }

  /// 앱이 뒤로 갔다: 숨은 시각을 적는다. 읽기는 계속한다
  void _hide() {
    _hidden = true;
    walk.pause(_clock());
  }

  /// 앱이 다시 켜졌다. 숨어 있는 동안 받은 마지막 값이 있으면 받은 시각으로 한 번 먹인다
  /// (그 값에 숨어 있던 동안의 걸음이 다 들어 있어서 숨은 시각부터 그때까지로 펴서 센다).
  /// 받은 값이 없었으면 다음에 늘어나는 값이 그 역할을 한다. 읽기가 끊겨 있었다면 다시 읽는다
  void _resume() {
    if (_disposed) return;
    _hidden = false;
    final total = _hiddenTotal;
    final at = _hiddenAt;
    _hiddenTotal = null;
    _hiddenAt = null;
    if (total != null && at != null) walk.onCount(total, at);
    if (_ready && _sub == null) _listen();
  }
}
