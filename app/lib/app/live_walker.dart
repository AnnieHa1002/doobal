import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/live_steps.dart';
import '../domain/live_walk.dart';
import '../domain/rules.dart';

/// 걷는 중 화면 하나가 쓰는 실시간 걸음. 센서 스트림을 [LiveWalk]에 먹인다.
/// 센서가 없거나 권한이 없으면 [LiveWalk.active]가 false인 채로 있어서, 화면은 health 값만 쓴다.
/// 앱이 뒤로 가면 센서 읽기를 멈추고, 다시 앞으로 오면 새 기준값을 잡아서
/// 꺼져 있던 동안 쌓인 센서 걸음을 화면 이동에 넣지 않는다
class LiveWalker {
  LiveWalker({
    required this._steps,
    required Rules rules,
    required this._clock,
    required this._denied,
    required this._onDenied,
  }) : walk = LiveWalk(rules);

  final LiveSteps _steps;
  final DateTime Function() _clock;

  /// 이번 앱 실행 중 권한을 거부당한 적이 있는가 / 거부당했다고 적어 두기
  final bool Function() _denied;
  final void Function() _onDenied;

  final LiveWalk walk;

  StreamSubscription<int>? _sub;
  AppLifecycleListener? _lifecycle;
  var _ready = false;
  var _disposed = false;

  /// 권한을 확인하고(없으면 거부된 적이 없을 때 한 번 묻고) 센서 읽기를 시작한다
  Future<void> start() async {
    _lifecycle = AppLifecycleListener(onHide: _unlisten, onResume: _resume);
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
          (total) => walk.onCount(total, _clock()),
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

  /// 앱이 다시 켜졌다. 읽기를 멈췄었다면 새 기준값부터 다시 센다
  void _resume() {
    if (!_ready || _disposed || _sub != null) return;
    walk.rebase();
    _listen();
  }
}
