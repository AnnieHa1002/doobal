import 'dart:async';

import 'package:doobal/data/live_steps.dart';
import 'package:doobal/data/local_notifications.dart';
import 'package:doobal/data/walk_notice.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_local_notifications가 안드로이드에서 쓰는 채널
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

final _startedAt = DateTime.utc(2026, 11, 18, 1, 30);

/// 걸음 센서 권한 확인에서 예외가 나는 기기
class _ThrowingLive extends FakeLiveSteps {
  @override
  Future<bool> hasPermission() async => throw StateError('채널이 없다');
}

/// 권한 확인 답을 [answer]로 늦게 주는 센서
class _SlowLive extends FakeLiveSteps {
  final answer = Completer<bool>();

  @override
  Future<bool> hasPermission() => answer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 플러그인 채널로 간 부름 (테스트가 만든 플랫폼 응답으로 받는다)
  late List<MethodCall> calls;

  /// 채널이 부름에 낼 오류를 정한다. null이면 정상
  Object? Function(MethodCall call)? fail;

  setUp(() {
    // 실제 앱에서는 플러그인 등록이 해 주는 일 (테스트의 기본 플랫폼은 안드로이드)
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    fail = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      final error = fail?.call(call);
      if (error != null) throw error;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  AndroidWalkNotice make(LiveSteps live) => AndroidWalkNotice(LocalNotifications(), live);

  List<MethodCall> starts() => calls.where((c) => c.method == 'startForegroundService').toList();
  List<MethodCall> stops() => calls.where((c) => c.method == 'stopForegroundService').toList();

  Map<Object?, Object?> data(MethodCall c) =>
      (c.arguments as Map<Object?, Object?>)['notificationData'] as Map<Object?, Object?>;

  group('AndroidWalkNotice', () {
    test('start: 센서 권한이 있으면 포그라운드 서비스를 건강 유형으로 시작한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(_startedAt, 0);

      expect(starts(), hasLength(1));
      final args = starts().single.arguments as Map<Object?, Object?>;
      // 죽은 프로세스를 되살리지 않는다 (startNotSticky = 2), 건강 유형 = 256
      expect(args['startType'], 2);
      expect(args['foregroundServiceTypes'], [256]);

      final n = data(starts().single);
      expect(n['id'], 2000000001);
      expect(n['title'], '걷는 중이에요');
      expect(n['body'], '0보');

      final d = n['platformSpecifics']! as Map<Object?, Object?>;
      expect(d['channelId'], 'walking');
      expect(d['channelName'], '걷는 중');
      expect(d['channelDescription'], '걷는 동안 걸음을 보여 줘요');
      expect(d['icon'], 'ic_stat_walk');
      expect(d['importance'], 2); // low
      expect(d['priority'], -1); // low
      expect(d['playSound'], false);
      expect(d['enableVibration'], false);
      expect(d['ongoing'], true);
      expect(d['autoCancel'], false);
      expect(d['onlyAlertOnce'], true);
      // 걷기 시작 시각부터 흐르는 시간이 알림에 스스로 올라간다
      expect(d['showWhen'], true);
      expect(d['usesChronometer'], true);
      expect(d['when'], _startedAt.millisecondsSinceEpoch);
    });

    test('update: 같은 id로 서비스를 다시 시작해 문구만 새로 쓴다 (시작 시각은 그대로)', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(_startedAt, 0);
      await notice.update(1234);

      expect(starts(), hasLength(2));
      final first = data(starts().first);
      final second = data(starts().last);
      expect(second['id'], first['id']);
      expect(second['body'], '1,234보');
      final d = second['platformSpecifics']! as Map<Object?, Object?>;
      expect(d['when'], _startedAt.millisecondsSinceEpoch);
      expect((starts().last.arguments as Map<Object?, Object?>)['foregroundServiceTypes'], [256]);
    });

    test('센서 권한이 없으면 서비스를 시작하지 않고(안드로이드 14에서 앱이 멈춘다), update도 무시한다', () async {
      final notice = make(FakeLiveSteps(permitted: false));
      await notice.start(_startedAt, 0);
      await notice.update(100);

      expect(starts(), isEmpty);
    });

    test('시작하기 전의 update는 무시한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.update(100);

      expect(calls, isEmpty);
    });

    test('stop: 서비스를 멈추고, 여러 번 불러도 되고, 그 뒤 update는 무시한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(_startedAt, 0);
      await notice.stop();
      await notice.stop();
      await notice.update(50);

      expect(stops(), hasLength(2));
      expect(starts(), hasLength(1));
    });

    test('stop 뒤에 다시 start하면 새로 시작한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(_startedAt, 0);
      await notice.stop();
      await notice.start(_startedAt.add(const Duration(hours: 1)), 7);

      expect(starts(), hasLength(2));
      expect(data(starts().last)['body'], '7보');
      final d = data(starts().last)['platformSpecifics']! as Map<Object?, Object?>;
      expect(d['when'], _startedAt.add(const Duration(hours: 1)).millisecondsSinceEpoch);
    });

    test('권한 답을 기다리는 사이 stop이 불리면 뒤늦게 시작하지 않는다', () async {
      final live = _SlowLive();
      final notice = make(live);
      final started = notice.start(_startedAt, 0);
      await notice.stop();
      live.answer.complete(true);
      await started;
      await notice.update(10);

      expect(starts(), isEmpty);
    });

    test('서비스 시작이 실패해도(플랫폼 오류) 던지지 않고, 이후 update는 무시한다', () async {
      fail = (c) => c.method == 'startForegroundService'
          ? PlatformException(code: 'error', message: 'SecurityException')
          : null;
      final notice = make(FakeLiveSteps());
      await notice.start(_startedAt, 0);
      await notice.update(10);

      expect(starts(), hasLength(1));
    });

    test('갱신이 실패해도 던지지 않고, 다음 갱신은 다시 시도한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(_startedAt, 0);
      fail = (c) => PlatformException(code: 'error');
      await notice.update(10);
      fail = null;
      await notice.update(20);

      expect(starts(), hasLength(3));
      expect(data(starts().last)['body'], '20보');
    });

    test('stop이 실패해도 던지지 않는다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(_startedAt, 0);
      fail = (c) => PlatformException(code: 'error');
      await notice.stop();
    });

    test('권한 확인에서 예외가 나도 던지지 않고 시작하지 않는다', () async {
      final notice = make(_ThrowingLive());
      await notice.start(_startedAt, 0);

      expect(starts(), isEmpty);
    });
  });

  group('NoopWalkNotice·FakeWalkNotice', () {
    test('Noop은 아무것도 하지 않는다 (플러그인 채널도 부르지 않는다)', () async {
      const notice = NoopWalkNotice();
      await notice.start(_startedAt, 0);
      await notice.update(5);
      await notice.stop();

      expect(calls, isEmpty);
    });

    test('Fake는 부름을 순서대로 기록한다', () async {
      final notice = FakeWalkNotice();
      expect(notice.running, isFalse);

      await notice.start(_startedAt, 3);
      await notice.update(10);
      await notice.update(20);
      expect(notice.starts, [(_startedAt, 3)]);
      expect(notice.updates, [10, 20]);
      expect(notice.running, isTrue);

      await notice.stop();
      await notice.stop();
      expect(notice.stops, 2);
      expect(notice.running, isFalse);
    });
  });
}
