import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/live_steps.dart';
import '../domain/live_walk.dart';
import '../domain/paint_trail.dart';
import '../domain/rules.dart';

/// 앱이 숨어 있는 동안 센서 값으로 미리 낸 걸음 수와 거리(m)
typedef HiddenPreview = ({int steps, double distanceM});

/// 기기 걸음 센서 스트림을 [LiveWalk]에 먹인다 (물감 길 하나의 실시간 걸음, PaintTrailController가 하나 둔다).
/// 센서가 없거나 권한이 없으면 [ready]가 false인 채로 있어서, 화면은 health 값만 쓴다.
/// 앱이 뒤로 가도 센서 읽기는 멈추지 않는다 (안드로이드는 물감 길 동안 상시 알림이 앱을 살려 둔다.
/// iOS는 앱이 멈춰서 아무 값도 오지 않는다). 숨은 시각은 [LiveWalk.pause]에 적되 숨어 있는 동안의
/// 값은 [LiveWalk]에 먹이지 않고 마지막 값과 받은 시각만 기억해 둔다. 그 값으로 걸음·거리 미리보기를
/// [onHiddenSteps]에 알리고(알림 갱신용), 앱이 다시 앞으로 오면 마지막 값을 받은 시각으로 한 번 먹인다.
/// 센서 값은 부팅 이후 누적이라 그 값에 숨어 있던 동안의 걸음이 다 들어 있고, [LiveWalk]가 그걸 센다.
/// 숨어 있는 사이 앱이 종료되면 이 걸음은 놓친다 (health 기록에는 남는다).
/// 값이 늘 때마다(숨어 있어도) [onGain]에 그 증가를 알린다 (물감 길 시작·끝 판정)
class LiveWalker {
  LiveWalker({
    required this._steps,
    required this.rules,
    required this._clock,
    required this._denied,
    required this._onDenied,
    this.onHiddenSteps,
    this.onGain,
    this.ask = true,
  }) : walk = LiveWalk(rules);

  final LiveSteps _steps;
  final Rules rules;
  final DateTime Function() _clock;

  /// 이번 앱 실행 중 권한을 거부당한 적이 있는가 / 거부당했다고 적어 두기
  final bool Function() _denied;
  final void Function() _onDenied;

  /// 앱이 숨어 있는 동안 센서 값이 올 때마다 그때의 걸음·거리 미리보기
  /// ([LiveWalk.previewSteps]·[LiveWalk.previewDistanceM])를 알린다
  final void Function(HiddenPreview preview)? onHiddenSteps;

  /// 센서 값이 늘 때마다: 그 증가([SensorGain], 앞에 있었는지·숨었다 돌아와 처음 받은 값인지)와 누적값
  final void Function(SensorGain gain, int total)? onGain;

  /// 권한이 없을 때 묻는가. false면 확인만 하고 없으면 읽지 않는다 (앱을 켤 때마다 묻지 않게)
  final bool ask;

  /// 지금 세는 걷기. [restart]로 새로 시작한다
  LiveWalk walk;

  StreamSubscription<int>? _sub;
  AppLifecycleListener? _lifecycle;
  var _ready = false;
  var _disposed = false;

  /// 센서가 오류를 줬다 (센서가 없는 기기). 다시 읽지 않는다
  var _failed = false;

  /// 앱이 뒤로 가 있는가. 이 동안 받은 값은 [LiveWalk]에 먹이지 않고 마지막 것만 둔다
  var _hidden = false;
  int? _hiddenTotal;
  DateTime? _hiddenAt;

  /// 마지막으로 받은 누적값 (증가를 [onGain]에 알릴 때의 기준)
  int? _lastRaw;

  /// 숨었다 돌아온 뒤 아직 값을 못 받았고, 숨어 있는 동안에도 값이 오지 않았다 (iOS: 앱이 멈춰 있었다).
  /// 그러면 다음 증가에는 숨어 있던 동안의 걸음이 한꺼번에 들어 있다
  var _catchUpNext = false;

  /// 권한이 있어서 센서를 읽고 있는가 (권한을 못 받았거나 센서가 오류를 줬으면 false)
  bool get ready => _ready;

  /// 지금 앱이 뒤에 있는가
  bool get hidden => _hidden;

  /// 마지막으로 받은 누적값 (아직 없으면 null)
  int? get lastTotal => _lastRaw;

  /// 권한을 확인하고(없으면 [ask]일 때만, 거부된 적이 없을 때 한 번 묻고) 센서 읽기를 시작한다
  Future<void> start() async {
    _lifecycle ??= AppLifecycleListener(onHide: _hide, onResume: _resume);
    if (_ready) return;
    try {
      if (!await _steps.hasPermission()) {
        if (!ask || _denied()) return;
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

  /// 새 걷기를 센다: [walk]를 새로 만들고, [baseline]을 주면 그 값을 [at]에 받은 기준으로 둔다
  /// (물감 길이 열릴 때 시작을 일으킨 걸음까지 세려고 그 걸음 전 누적값을 넣는다)
  void restart({int? baseline, DateTime? at}) {
    walk = LiveWalk(rules);
    if (baseline != null) walk.onCount(baseline, at ?? _clock());
    final last = _lastRaw;
    if (last != null && !_hidden) walk.onCount(last, _clock());
  }

  /// 숨어 있는 동안 받아 둔 마지막 값을 지금 [LiveWalk]에 먹인다 (숨은 채 물감 길이 끝날 때 그 걸음까지 세려고).
  /// 숨어 있지 않거나 받은 값이 없으면 아무 일도 없다
  void feedHidden() {
    final total = _hiddenTotal;
    final at = _hiddenAt;
    if (!_hidden || total == null || at == null) return;
    walk.onCount(total, at);
    _hiddenTotal = null;
    _hiddenAt = null;
    walk.pause(at);
  }

  void _listen() {
    if (_sub != null) return;
    _sub = _steps.stepCounts().listen(
          _onCount,
          onError: (Object e) {
            // 센서가 없는 기기: 읽기를 그만두고 health 값만 쓴다
            debugPrint('걸음 센서 읽기 실패: $e');
            _ready = false;
            _failed = true;
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
    final last = _lastRaw;
    _lastRaw = total;
    final gain = last != null && total > last
        ? SensorGain(at, total - last, foreground: !_hidden, catchUp: _catchUpNext && !_hidden)
        : null;
    if (last != null && total != last) _catchUpNext = false;
    if (!_hidden) {
      walk.onCount(total, at);
    } else {
      _hiddenTotal = total;
      _hiddenAt = at;
      onHiddenSteps?.call((
        steps: walk.previewSteps(total),
        distanceM: walk.previewDistanceM(total),
      ));
    }
    // 걷기에 먹인 뒤에 알린다 (받는 쪽이 지금 숫자를 읽는다)
    if (gain != null) onGain?.call(gain, total);
  }

  /// 앱이 뒤로 갔다: 숨은 시각을 적는다. 읽기는 계속한다
  void _hide() {
    _hidden = true;
    _catchUpNext = true;
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
    // 숨어 있는 동안 값을 받았으면(안드로이드) 그 걸음은 이미 [onGain]으로 알렸다
    if (total != null) _catchUpNext = false;
    if (total != null && at != null) walk.onCount(total, at);
    if (_ready && _sub == null) _listen();
    // 묻지 않는 쪽([ask] false)은 권한이 없어 못 읽던 중이면 설정에서 켜고 왔을 수 있어 다시 확인한다
    if (!_ready && !ask && !_failed) unawaited(start());
  }
}
