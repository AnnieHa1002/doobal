import 'package:doobal/app/live_walker.dart';
import 'package:doobal/data/live_steps.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/gait.dart';
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
      onHiddenSteps: hiddenSteps.add,
    );
  }

  final FakeLiveSteps live;
  late final LiveWalker walker;

  /// 이번 앱 실행 중 거부당한 적이 있는가
  bool denied;
  var deniedCalls = 0;
  var now = _t0;

  /// 앱이 숨어 있는 동안 알린 걸음·거리 미리보기, 받은 순서대로
  final hiddenSteps = <HiddenPreview>[];

  /// 알린 미리보기의 걸음 / 거리(m)
  List<int> get hiddenStepCounts => [for (final p in hiddenSteps) p.steps];
  List<double> get hiddenDistances => [for (final p in hiddenSteps) p.distanceM];

  /// [sec]초 뒤(처음부터 잰 시각)로 시계를 옮기고 센서가 누적 걸음 [total]을 준다
  Future<void> sensorAt(WidgetTester tester, int sec, int total) async {
    now = _t0.add(Duration(seconds: sec));
    live.push(total);
    await tester.pump();
  }
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
      expect(w.walker.ready, isTrue);
      expect(w.walker.walk.active, isFalse);
      w.walker.dispose();
    });

    testWidgets('권한이 없고 거부된 적이 없으면 한 번 묻고, 허용되면 읽는다', (tester) async {
      final w = _Walker(FakeLiveSteps(permitted: false));
      expect(w.walker.ready, isFalse);
      await w.walker.start();

      expect(w.live.permissionRequests, 1);
      expect(w.live.listeners, 1);
      expect(w.walker.ready, isTrue);
      expect(w.deniedCalls, 0);
      w.walker.dispose();
    });

    testWidgets('거부하면 읽지 않고 거부했다고 알린다', (tester) async {
      final w = _Walker(FakeLiveSteps(permitted: false, grantOnRequest: false));
      await w.walker.start();

      expect(w.live.permissionRequests, 1);
      expect(w.live.listeners, 0);
      expect(w.walker.ready, isFalse);
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
      expect(w.walker.ready, isFalse);

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

  group('앱이 뒤로 가 있는 동안', () {
    testWidgets('센서 구독을 끊지 않는다 (뒤로 갔다 와도 구독은 한 번)', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      expect(w.live.listeners, 1);

      _leave(tester);
      expect(w.live.listeners, 1);
      _back(tester);
      await tester.pump();
      expect(w.live.listeners, 1);
      expect(w.live.subscriptions, 1);
      w.walker.dispose();
    });

    testWidgets('숨어 있는 동안 받은 값은 LiveWalk에 먹이지 않고, 걸음 미리보기만 알린다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      await w.sensorAt(tester, 0, 1000);
      await w.sensorAt(tester, 5, 1010);
      expect(w.walker.walk.steps, 10);
      // 앞에 있는 동안은 미리보기를 알리지 않는다
      expect(w.hiddenSteps, isEmpty);

      _leave(tester); // 5초에 숨는다
      await w.sensorAt(tester, 65, 1100);
      await w.sensorAt(tester, 125, 1250);

      // 미리보기 = 센 걸음 10 + (받은 값 - 기준 1,010) = 100, 250
      expect(w.hiddenStepCounts, [100, 250]);
      // 거리는 센 거리 7m + 늘어난 걸음 × 걷기 보폭 0.7m = 70m, 175m
      expect(w.hiddenDistances, [closeTo(70, 1e-9), closeTo(175, 1e-9)]);
      // LiveWalk는 그대로다: 걸음·거리·따라잡기·분 버킷 모두 숨기 전과 같다
      expect(w.walker.walk.steps, 10);
      expect(w.walker.walk.distanceM, closeTo(7, 1e-9));
      expect(w.walker.walk.catchUps, 0);
      expect(w.walker.walk.minutes.map((m) => m.steps), [10]);
      w.walker.dispose();
    });

    testWidgets('다시 앞으로 오면 마지막 값을 받은 시각으로 한 번 먹여서 그 시각까지 따라잡는다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      await w.sensorAt(tester, 0, 1000);
      await w.sensorAt(tester, 5, 1010);
      _leave(tester); // 5초에 숨는다
      await w.sensorAt(tester, 65, 1100);
      await w.sensorAt(tester, 125, 1250);

      // 10분(600초)에 앞으로 온다. 먹이는 값은 125초에 받은 1,250
      w.now = _t0.add(const Duration(seconds: 600));
      _back(tester);
      expect(w.walker.walk.steps, 250); // 10 + (1,250 - 1,010)
      expect(w.walker.walk.catchUps, 1);
      // 숨은 5초~125초 120초에 240보: 분당 240 × 60 ÷ 120 = 120 → 걷기 → 240 × 0.7 = 168m
      expect(w.walker.walk.gait, Gait.walk);
      expect(w.walker.walk.distanceM, closeTo(175, 1e-9)); // 7 + 168
      // 240보를 5~125초와 겹친 시간 비율로: 0분(5~60초, 55초) 110, 1분(60초) 120, 2분(120~125초, 5초) 10.
      // 0분에는 숨기 전에 센 10보가 같은 걷기라 합쳐진다
      final m0 = epochMinute(_t0);
      expect(
        [for (final m in w.walker.walk.minutes) (m.minute - m0, m.steps, m.gait)],
        [(0, 120, Gait.walk), (1, 120, Gait.walk), (2, 10, Gait.walk)],
      );
      // 앞으로 온 뒤에는 미리보기를 알리지 않고 평소처럼 센다 (600초 뒤 5초)
      w.hiddenSteps.clear();
      await w.sensorAt(tester, 605, 1260);
      expect(w.walker.walk.steps, 260);
      expect(w.walker.walk.catchUps, 1);
      expect(w.hiddenSteps, isEmpty);
      w.walker.dispose();
    });

    testWidgets('값이 한 번도 오지 않았으면 앞으로 온 뒤 처음 늘어난 값이 따라잡는다 (iOS처럼 멈춰 있던 경우)',
        (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      await w.sensorAt(tester, 0, 1000);
      await w.sensorAt(tester, 5, 1010);
      expect(w.walker.walk.steps, 10);

      _leave(tester); // 5초에 숨는다
      w.now = _t0.add(const Duration(minutes: 30, seconds: 5));
      _back(tester);
      expect(w.walker.walk.catchUps, 0);
      expect(w.hiddenSteps, isEmpty);
      // 구독은 그대로
      expect(w.live.subscriptions, 1);

      // 30분 5초에 받은 값: 숨은 5초부터 30분 5초까지 1,800초에
      // 1,510 - 10 = 1,500보 → 분당 1500 × 60 ÷ 1800 = 50 → 걷기 → 1,500 × 0.7 = 1,050m
      await w.sensorAt(tester, 30 * 60 + 5, 2510);
      expect(w.walker.walk.steps, 1510);
      expect(w.walker.walk.catchUps, 1);
      expect(w.walker.walk.distanceM, closeTo(1057, 1e-9)); // 7 + 1,050

      // 그 뒤는 평소처럼 센다
      await w.sensorAt(tester, 30 * 60 + 10, 2517);
      expect(w.walker.walk.steps, 1517);
      expect(w.walker.walk.catchUps, 1);
      w.walker.dispose();
    });

    testWidgets('숨어 있는 동안 기준과 같은 값만 왔으면 앞으로 온 뒤에도 숨은 시각부터 센다',
        (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      await w.sensorAt(tester, 0, 1000);
      await w.sensorAt(tester, 5, 1010);

      _leave(tester); // 5초에 숨는다
      await w.sensorAt(tester, 60, 1010);
      expect(w.hiddenStepCounts, [10]);

      w.now = _t0.add(const Duration(minutes: 10));
      _back(tester);
      expect(w.walker.walk.steps, 10);
      expect(w.walker.walk.catchUps, 0);

      // 숨은 5초부터 10분 5초까지 10분에 600보 → 분당 60 → 걷기 → 420m
      await w.sensorAt(tester, 10 * 60 + 5, 1610);
      expect(w.walker.walk.steps, 610);
      expect(w.walker.walk.catchUps, 1);
      expect(w.walker.walk.distanceM, closeTo(427, 1e-9)); // 7 + 420
      w.walker.dispose();
    });

    testWidgets('기준을 잡기 전에 숨어도 첫 값은 기준이 된다 (미리보기는 0, 앞으로 오면 기준만 잡는다)',
        (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();

      _leave(tester);
      await w.sensorAt(tester, 30, 5000);
      expect(w.hiddenStepCounts, [0]);
      expect(w.hiddenDistances, [0.0]);
      expect(w.walker.walk.active, isFalse);

      _back(tester);
      expect(w.walker.walk.active, isTrue);
      expect(w.walker.walk.steps, 0);
      expect(w.walker.walk.catchUps, 0);

      await w.sensorAt(tester, 40, 5025);
      expect(w.walker.walk.steps, 25);
      w.walker.dispose();
    });

    testWidgets('재부팅으로 값이 작아지면 미리보기는 더하지 않는다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      await w.sensorAt(tester, 0, 50000);
      await w.sensorAt(tester, 5, 50020);

      _leave(tester);
      await w.sensorAt(tester, 60, 30);
      expect(w.hiddenStepCounts, [20]);
      // 거리도 더하지 않는다 (센 20보 × 0.7m = 14m)
      expect(w.hiddenDistances, [closeTo(14, 1e-9)]);
      w.walker.dispose();
    });

    testWidgets('뒤로 가지 않고 inactive만 지나갔으면(권한 창 등) 숨은 것이 아니다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      await w.sensorAt(tester, 0, 1000);
      await w.sensorAt(tester, 1, 1010);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await w.sensorAt(tester, 2, 1015);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(w.live.subscriptions, 1);
      expect(w.walker.walk.active, isTrue);
      // 먹이는 값 그대로 센다
      expect(w.walker.walk.steps, 15);
      expect(w.hiddenSteps, isEmpty);

      await w.sensorAt(tester, 3, 1020);
      expect(w.walker.walk.steps, 20);
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

    testWidgets('화면을 나간 뒤 앱이 뒤로 갔다 와도 아무 일도 없다', (tester) async {
      final w = _Walker(FakeLiveSteps());
      await w.walker.start();
      await w.sensorAt(tester, 0, 1000);
      w.walker.dispose();

      _leave(tester);
      await w.sensorAt(tester, 30, 1500);
      _back(tester);
      await tester.pump();
      expect(w.live.listeners, 0);
      expect(w.hiddenSteps, isEmpty);
      expect(w.walker.walk.steps, 0);
    });
  });
}
