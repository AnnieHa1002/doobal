import 'dart:async';

import 'package:doobal/data/live_steps.dart';
import 'package:doobal/data/local_notifications.dart';
import 'package:doobal/data/walk_notice.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_local_notifications가 안드로이드에서 쓰는 채널
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

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
  List<MethodCall> shows() => calls.where((c) => c.method == 'show').toList();

  Map<Object?, Object?> data(MethodCall c) =>
      (c.arguments as Map<Object?, Object?>)['notificationData'] as Map<Object?, Object?>;

  test('알림 제목: 뛰면 두발 · 달리는 중, 아니면 두발 · 걷는 중', () {
    expect(noticeTitle(isRunning: true), '두발 · 달리는 중');
    expect(noticeTitle(isRunning: false), '두발 · 걷는 중');
  });

  group('AndroidWalkNotice', () {
    test('start: 센서 권한이 있으면 포그라운드 서비스를 건강 유형으로 시작한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);

      expect(starts(), hasLength(1));
      final args = starts().single.arguments as Map<Object?, Object?>;
      // 죽은 프로세스를 되살리지 않는다 (startNotSticky = 2), 건강 유형 = 256
      expect(args['startType'], 2);
      expect(args['foregroundServiceTypes'], [256]);

      final n = data(starts().single);
      expect(n['id'], 2000000001);
      expect(n['title'], '두발 · 걷는 중');
      expect(n['body'], '0보 · 0.0km');

      final d = n['platformSpecifics']! as Map<Object?, Object?>;
      expect(d['channelId'], 'walking');
      expect(d['channelName'], '걷는 중');
      expect(d['channelDescription'], '걷는 동안 걸음을 보여 줘요');
      expect(d['icon'], 'ic_stat_doobal');
      expect(d['importance'], 2); // low
      expect(d['priority'], -1); // low
      expect(d['playSound'], false);
      expect(d['enableVibration'], false);
      expect(d['ongoing'], true);
      expect(d['autoCancel'], false);
      expect(d['onlyAlertOnce'], true);
      // 걸린 시간은 알림에 보이지 않는다 (시각도 크로노미터도 없다)
      expect(d['showWhen'], false);
      expect(d['usesChronometer'], false);
      expect(d['when'], isNull);
    });

    test('update: 서비스를 다시 시작하지 않고 같은 id의 알림을 다시 쓴다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);
      await notice.update(1234, 1200);

      // 앱이 뒤에 있을 때 서비스 시작은 막힐 수 있어서 갱신은 show로만 한다
      expect(starts(), hasLength(1));
      expect(shows(), hasLength(1));
      final args = shows().single.arguments as Map<Object?, Object?>;
      expect(args['id'], data(starts().single)['id']);
      expect(args['title'], '두발 · 걷는 중');
      expect(args['body'], '1,234보 · 1.2km');
      final d = args['platformSpecifics']! as Map<Object?, Object?>;
      expect(d['channelId'], 'walking');
      expect(d['ongoing'], true);
      expect(d['playSound'], false);
      expect(d['enableVibration'], false);
      expect(d['showWhen'], false);
      expect(d['usesChronometer'], false);
    });

    test('본문: 걸음은 천 단위 쉼표, 거리는 km 0.1 단위 (km 앞에 띄어쓰기 없음)', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);
      // (걸음, 거리 m) → 본문
      const cases = [
        (7, 4.0, '7보 · 0.0km'),
        (100, 60.0, '100보 · 0.1km'),
        (1234, 1234.0, '1,234보 · 1.2km'),
        (17890, 12345.0, '17,890보 · 12.3km'),
        (1234567, 100000.0, '1,234,567보 · 100.0km'),
      ];
      for (final (steps, m, _) in cases) {
        await notice.update(steps, m);
      }
      expect(shows(), hasLength(cases.length));
      for (final (i, c) in cases.indexed) {
        expect((shows()[i].arguments as Map<Object?, Object?>)['body'], c.$3);
      }
    });

    test('noticeBody: 걸음·거리 (본격 걷기 끝 글은 없다, 16장 11/13)', () {
      expect(noticeBody(7, 4), '7보 · 0.0km');
      expect(noticeBody(1234, 1234), '1,234보 · 1.2km');
    });

    test('noticeKm: 미터를 km 0.1 단위 글로', () {
      expect(noticeKm(0), '0.0');
      expect(noticeKm(40), '0.0');
      expect(noticeKm(60), '0.1');
      expect(noticeKm(1234), '1.2');
      expect(noticeKm(12345), '12.3');
    });

    test('센서 권한이 없으면 서비스를 시작하지 않고(안드로이드 14에서 앱이 멈춘다), update도 무시한다', () async {
      final notice = make(FakeLiveSteps(permitted: false));
      await notice.start(0, 0);
      await notice.update(100, 70);

      expect(starts(), isEmpty);
    });

    test('시작하기 전의 update는 무시한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.update(100, 70);

      expect(calls, isEmpty);
    });

    test('stop: 서비스를 멈추고, 여러 번 불러도 되고, 그 뒤 update는 무시한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);
      await notice.stop();
      await notice.stop();
      await notice.update(50, 35);

      expect(stops(), hasLength(2));
      expect(starts(), hasLength(1));
      expect(shows(), isEmpty);
      // 서비스를 멈춘 뒤 같은 id의 알림도 지운다
      final cancels = calls.where((c) => c.method == 'cancel').toList();
      expect(cancels, hasLength(2));
      expect((cancels.first.arguments as Map<Object?, Object?>)['id'], 2000000001);
    });

    test('stop 뒤에 다시 start하면 새로 시작한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);
      await notice.stop();
      await notice.start(7, 500);

      expect(starts(), hasLength(2));
      expect(data(starts().last)['body'], '7보 · 0.5km');
    });

    test('권한 답을 기다리는 사이 stop이 불리면 뒤늦게 시작하지 않는다', () async {
      final live = _SlowLive();
      final notice = make(live);
      final started = notice.start(0, 0);
      await notice.stop();
      live.answer.complete(true);
      await started;
      await notice.update(10, 7);

      expect(starts(), isEmpty);
    });

    test('서비스 시작이 실패해도(플랫폼 오류) 던지지 않고, 이후 update는 무시한다', () async {
      fail = (c) => c.method == 'startForegroundService'
          ? PlatformException(code: 'error', message: 'SecurityException')
          : null;
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);
      await notice.update(10, 7);

      expect(starts(), hasLength(1));
    });

    test('갱신이 실패해도 던지지 않고, 다음 갱신은 다시 시도한다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);
      fail = (c) => PlatformException(code: 'error');
      await notice.update(10, 7);
      fail = null;
      await notice.update(20, 14);

      expect(starts(), hasLength(1));
      expect(shows(), hasLength(2));
      expect((shows().last.arguments as Map<Object?, Object?>)['body'], '20보 · 0.0km');
    });

    test('stop이 실패해도 던지지 않는다', () async {
      final notice = make(FakeLiveSteps());
      await notice.start(0, 0);
      fail = (c) => PlatformException(code: 'error');
      await notice.stop();
    });

    test('권한 확인에서 예외가 나도 던지지 않고 시작하지 않는다', () async {
      final notice = make(_ThrowingLive());
      await notice.start(0, 0);

      expect(starts(), isEmpty);
    });
  });

  group('NoopWalkNotice·FakeWalkNotice', () {
    test('Noop은 아무것도 하지 않는다 (플러그인 채널도 부르지 않는다)', () async {
      const notice = NoopWalkNotice();
      await notice.start(0, 0);
      await notice.update(5, 3.5);
      await notice.stop();

      expect(calls, isEmpty);
    });

    test('Fake는 부름을 순서대로 기록한다', () async {
      final notice = FakeWalkNotice();
      expect(notice.running, isFalse);

      await notice.start(3, 2.1);
      await notice.update(10, 7);
      await notice.update(20, 14);
      expect(notice.starts, [(3, 2.1)]);
      expect(notice.updates, [(10, 7.0), (20, 14.0)]);
      expect(notice.running, isTrue);

      await notice.stop();
      await notice.stop();
      expect(notice.stops, 2);
      expect(notice.running, isFalse);
    });
  });
}
