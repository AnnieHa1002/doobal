import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';

/// 기기 걸음 센서. health 기록은 안드로이드에서 몇 분씩 늦게 들어와서, 걷는 중 화면의 숫자와
/// 땅 움직임만 이 센서로 바로 보여 준다 (진행·보상의 기준은 StepSource). 테스트는 FakeLiveSteps를 쓴다
abstract class LiveSteps {
  /// 부팅 이후 누적 걸음. 구독하는 동안만 센서를 읽는다. 센서가 없으면 오류가 흐른다
  Stream<int> stepCounts();

  /// 센서를 읽을 권한이 있는가
  Future<bool> hasPermission();

  /// 권한을 묻고 허용됐는지 돌려준다
  Future<bool> requestPermission();
}

/// 안드로이드 STEP_COUNTER / iOS CMPedometer (pedometer 패키지).
/// 안드로이드 ACTIVITY_RECOGNITION 런타임 권한은 MainActivity의 채널로 묻는다.
/// iOS는 따로 묻지 않고 구독할 때 시스템이 동작 권한을 묻는다 (거부하면 값이 오지 않는다).
/// 휴대폰이 아닌 곳(테스트·데스크톱)에서는 센서도 권한도 없다
class PedometerLiveSteps implements LiveSteps {
  const PedometerLiveSteps();

  static const _channel = MethodChannel('doobal/activity');

  @override
  Stream<int> stepCounts() => Platform.isAndroid || Platform.isIOS
      ? Pedometer.stepCountStream.map((c) => c.steps)
      : const Stream.empty();

  @override
  Future<bool> hasPermission() async {
    if (Platform.isIOS) return true;
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('has') ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isIOS) return true;
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('request') ?? false;
  }
}

class FakeLiveSteps implements LiveSteps {
  FakeLiveSteps({this.permitted = true, this.grantOnRequest = true});

  /// hasPermission이 돌려줄 답. 권한을 허용하면 true가 된다
  bool permitted;

  /// requestPermission이 허용할지. false면 거부로 답한다
  bool grantOnRequest;

  /// requestPermission을 부른 횟수
  int permissionRequests = 0;

  /// 구독 중인 곳의 수 (걷는 중 화면이 들어올 때 늘고 나갈 때 준다)
  int listeners = 0;

  /// stepCounts를 구독한 횟수
  int subscriptions = 0;

  late final _controller = StreamController<int>.broadcast(
    onListen: () {
      listeners++;
      subscriptions++;
    },
    onCancel: () => listeners--,
  );

  /// 센서가 누적 걸음 [total]을 준 것처럼 밀어 넣는다 (구독자가 없으면 버려진다)
  void push(int total) => _controller.add(total);

  /// 센서가 없는 기기: 구독자에게 오류를 보낸다
  void pushError() => _controller.addError(StateError('걸음 센서가 없다'));

  @override
  Stream<int> stepCounts() => _controller.stream;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) permitted = true;
    return grantOnRequest;
  }
}
