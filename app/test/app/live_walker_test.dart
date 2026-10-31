import 'package:doobal/app/live_walker.dart';
import 'package:doobal/data/live_steps.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

final _t0 = DateTime.utc(2026, 11, 18, 1);

/// 권한을 묻다가 예외가 나는 센서 (동작 정보를 못 읽는 기기)
class _ThrowingLive extends FakeLiveSteps {
  _ThrowingLive() : super(permitted: false);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    throw StateError('채널이 없다');
  }
}

class _Walker {
  _Walker(this.live, {this.denied = false}) {
    walker = LiveWalker(
      steps: live,
      rules: rules,
      clock: () => now,
      denied: () => denied,
      onDenied: () {
        denied = true;
        deniedCalls++;
      },
    );
  }

  final FakeLiveSteps live;
  late final LiveWalker walker;

  /// 이번 앱 실행 중 거부당한 적이 있는가
  bool denied;
  var deniedCalls = 0;
  var now = _t0;
}

/// 앱을 뒤로 보낸다 / 다시 앞으로 가져온다
void _leave(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void _back(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void main() {
  group('권한', () {
    testWidgets('권한이 있으면 묻지 않고 센서를 읽는다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();

      expect(w.live.permissionRequests, 0);
      expect(w.live.listeners, 1);
      expect(w.walker.walk.active, isFalse);
      w.walker.dispose();
    });

    testWidgets('권한이 없고 거부된 적이 없으면 한 번 묻고, 허용되면 읽는다', (tester) async {
      final w = _Walker(FakeLiveSteps(permitted: false));
      await w.walker.start();

      expect(w.live.permissionRequests, 1);
      expect(w.live.listeners, 1);
      expect(w.deniedCalls, 0);
      w.walker.dispose();
    });

    testWidgets('거부하면 읽지 않고 거부했다고 알린다', (tester) async {
      final w = _Walker(FakeLiveSteps(permitted: false, grantOnRequest: false));
      await w.walker.start();

      expect(w.live.permissionRequests, 1);
      expect(w.live.listeners, 0);
      expect(w.deniedCalls, 1);
      expect(w.walker.walk.active, isFalse);
      w.walker.dispose();
    });

    testWidgets('이미 거부된 적이 있으면 다시 묻지 않는다', (tester) async {
      final w = _Walker(FakeLiveSteps(permitted: false), denied: true);
      await w.walker.start();

      expect(w.live.permissionRequests, 0);
      expect(w.live.listeners, 0);
      expect(w.deniedCalls, 0);
      w.walker.dispose();
    });

    testWidgets('이미 거부된 적이 있어도 그 사이 설정에서 켰다면 읽는다', (tester) async {
      final w = _Walker(FakeLiveSteps(), denied: true);
      await w.walker.start();

      expect(w.live.permissionRequests, 0);
      expect(w.live.listeners, 1);
      w.walker.dispose();
    });

    testWidgets('묻다가 예외가 나도 죽지 않고 읽지 않는다 (거부로 적지는 않는다)', (tester) async {
      final w = _Walker(_ThrowingLive());
      await w.walker.start();

      expect(w.live.permissionRequests, 1);
      expect(w.live.listeners, 0);
      expect(w.deniedCalls, 0);
      w.walker.dispose();
    });

    testWidgets('권한 답이 오기 전에 화면을 나가면 읽지 않는다', (tester) async {
      final w = _Walker(FakeLiveSteps(permitted: false));
      final started = w.walker.start();
      w.walker.dispose();
      await started;

      expect(w.live.listeners, 0);
    });
  });

  group('센서 값', () {
    testWidgets('첫 값은 기준값, 그 뒤 증가분이 걸음과 거리로 쌓인다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();

      w.live.push(8000);
      await tester.pump();
      expect(w.walker.walk.active, isTrue);
      expect(w.walker.walk.steps, 0);

      w.now = _t0.add(const Duration(seconds: 10));
      w.live.push(8030);
      await tester.pump();
      expect(w.walker.walk.steps, 30);
      expect(w.walker.walk.distanceM, closeTo(21, 1e-9));
      w.walker.dispose();
    });

    testWidgets('센서가 오류를 주면 읽기를 그만두고, 앱을 다시 켜도 다시 읽지 않는다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      w.live.push(100);
      w.live.pushError();
      await tester.pump();
      expect(w.live.listeners, 0);

      _leave(tester);
      _back(tester);
      await tester.pump();
      expect(w.live.listeners, 0);
      w.walker.dispose();
    });

    testWidgets('화면을 나가면 읽기를 멈춘다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      expect(w.live.listeners, 1);

      w.walker.dispose();
      expect(w.live.listeners, 0);
      // 나간 뒤에 앱이 다시 켜져도 읽지 않는다
      _leave(tester);
      _back(tester);
      await tester.pump();
      expect(w.live.listeners, 0);
    });
  });

  group('앱이 뒤로 갔다 오면', () {
    testWidgets('읽기를 멈췄다가 다시 켜지면 그동안 늘어난 걸음도 센다 (첫 증가에 다 들어 있다)',
        (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      w.live.push(1000);
      w.now = _t0.add(const Duration(seconds: 5));
      w.live.push(1010);
      await tester.pump();
      expect(w.walker.walk.steps, 10);

      // 5초에 숨는다
      _leave(tester);
      expect(w.live.listeners, 0);
      // 꺼져 있는 동안 센서에 걸음이 쌓였다 (읽지 않으니 들어오지 않는다)
      w.live.push(1500);
      await tester.pump();
      expect(w.walker.walk.steps, 10);

      _back(tester);
      expect(w.live.listeners, 1);
      expect(w.live.subscriptions, 2);
      // 기준값은 그대로라 아직 활성이다
      expect(w.walker.walk.active, isTrue);

      // 30분 5초에 다시 읽기 시작해서 받은 값: 숨은 5초부터 30분 5초까지 30분(1,800초)에
      // 1,510 - 10 = 1,500보 → 분당 1500 × 60 ÷ 1800 = 50 → 걷기 → 1,500 × 0.7 = 1,050m
      w.now = _t0.add(const Duration(minutes: 30, seconds: 5));
      w.live.push(2510);
      await tester.pump();
      expect(w.walker.walk.steps, 1510);
      expect(w.walker.walk.catchUps, 1);
      expect(w.walker.walk.distanceM, closeTo(1057, 1e-9)); // 7 + 1,050

      // 그 뒤는 평소처럼 센다
      w.now = _t0.add(const Duration(minutes: 30, seconds: 10));
      w.live.push(2517);
      await tester.pump();
      expect(w.walker.walk.steps, 1517);
      expect(w.walker.walk.catchUps, 1);
      w.walker.dispose();
    });

    testWidgets('숨은 뒤 옛 값이 먼저 다시 와도 숨은 시각부터 센다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      w.live.push(1000);
      w.now = _t0.add(const Duration(seconds: 5));
      w.live.push(1010);
      await tester.pump();

      // 5초에 숨는다
      _leave(tester);
      _back(tester);
      // 다시 구독하자 센서가 마지막 값을 한 번 더 준다
      w.now = _t0.add(const Duration(minutes: 10));
      w.live.push(1010);
      await tester.pump();
      expect(w.walker.walk.steps, 10);
      expect(w.walker.walk.catchUps, 0);

      // 숨은 5초부터 10분 5초까지 10분에 600보 → 분당 60 → 걷기 → 420m
      w.now = _t0.add(const Duration(minutes: 10, seconds: 5));
      w.live.push(1610);
      await tester.pump();
      expect(w.walker.walk.steps, 610);
      expect(w.walker.walk.catchUps, 1);
      expect(w.walker.walk.distanceM, closeTo(427, 1e-9)); // 7 + 420
      w.walker.dispose();
    });

    testWidgets('뒤로 가지 않고 inactive만 지나갔으면(권한 창 등) 기준을 다시 잡지 않는다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      w.live.push(1000);
      w.live.push(1010);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(w.live.subscriptions, 1);
      expect(w.walker.walk.active, isTrue);

      w.live.push(1015);
      await tester.pump();
      expect(w.walker.walk.steps, 15);
      w.walker.dispose();
    });

    testWidgets('권한이 없어서 읽지 않던 앱은 다시 켜져도 읽지 않는다', (tester) async {
      final w = _Walker(FakeLiveSteps(permitted: false, grantOnRequest: false));
      await w.walker.start();

      _leave(tester);
      _back(tester);
      await tester.pump();
      expect(w.live.listeners, 0);
      expect(w.live.permissionRequests, 1);
      w.walker.dispose();
    });
  });
}
