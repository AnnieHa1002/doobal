import 'package:doobal/app/providers.dart';
import 'package:doobal/data/local_notifications.dart';
import 'package:doobal/data/notification_permission.dart';
import 'package:doobal/data/walk_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_local_notifications가 안드로이드·iOS에서 쓰는 채널
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

class _FakePermission implements NotificationPermission {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool?> isGranted() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 채널로 간 부름과, 부름 이름별로 줄 답 (없으면 null)
  late List<MethodCall> calls;
  late Map<String, Object?> answers;

  setUp(() {
    calls = [];
    answers = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      final answer = answers[call.method];
      if (answer is Exception) throw answer;
      return answer;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('휴대폰이 아닌 곳 (테스트·데스크톱)', () {
    test('묻지 않고 거부로 답하고, 상태는 모른다고 답한다', () async {
      final permission = LocalNotificationPermission(LocalNotifications());

      expect(await permission.requestPermission(), isFalse);
      expect(await permission.isGranted(), isNull);
      expect(calls, isEmpty);
    });
  });

  group('안드로이드', () {
    setUp(AndroidFlutterLocalNotificationsPlugin.registerWith);

    LocalNotificationPermission make() =>
        LocalNotificationPermission(LocalNotifications(), isAndroid: true);

    test('권한을 요청하고 플러그인이 준 답(허용)을 돌려준다', () async {
      answers['requestNotificationsPermission'] = true;
      expect(await make().requestPermission(), isTrue);
      expect(calls.map((c) => c.method), ['requestNotificationsPermission']);
    });

    test('거부하면 false, 답이 없으면(null) 거부로 본다', () async {
      answers['requestNotificationsPermission'] = false;
      expect(await make().requestPermission(), isFalse);

      answers['requestNotificationsPermission'] = null;
      expect(await make().requestPermission(), isFalse);
    });

    test('요청 중 오류(이미 묻는 중 등)가 나면 거부로 답하고 던지지 않는다', () async {
      answers['requestNotificationsPermission'] =
          PlatformException(code: 'permissionRequestInProgress');
      expect(await make().requestPermission(), isFalse);
    });

    test('지금 허용돼 있는지는 알림이 켜져 있는가(areNotificationsEnabled)로 안다', () async {
      answers['areNotificationsEnabled'] = true;
      expect(await make().isGranted(), isTrue);
      answers['areNotificationsEnabled'] = false;
      expect(await make().isGranted(), isFalse);
      // 묻는 창을 띄우지는 않는다
      expect(calls.map((c) => c.method).toSet(), {'areNotificationsEnabled'});
    });

    test('상태 확인 중 오류가 나면 모른다(null)고 답한다', () async {
      answers['areNotificationsEnabled'] = PlatformException(code: 'error');
      expect(await make().isGranted(), isNull);
    });
  });

  group('iOS', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });

    LocalNotificationPermission make() =>
        LocalNotificationPermission(LocalNotifications(), isIOS: true);

    test('알림·배지·소리 권한을 한 번에 요청한다', () async {
      answers['requestPermissions'] = true;
      expect(await make().requestPermission(), isTrue);

      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(calls.single.method, 'requestPermissions');
      expect(args['alert'], true);
      expect(args['badge'], true);
      expect(args['sound'], true);
      expect(args['provisional'], false);
    });

    test('거부하면 false', () async {
      answers['requestPermissions'] = false;
      expect(await make().requestPermission(), isFalse);
    });

    test('지금 허용돼 있는지는 checkPermissions의 isEnabled로 안다', () async {
      answers['checkPermissions'] = <String, bool>{'isEnabled': true};
      expect(await make().isGranted(), isTrue);
      answers['checkPermissions'] = <String, bool>{'isEnabled': false};
      expect(await make().isGranted(), isFalse);
    });

    test('확인 결과를 못 받으면 모른다(null)고 답한다', () async {
      answers['checkPermissions'] = null;
      expect(await make().isGranted(), isNull);
    });
  });

  group('provider', () {
    test('기본값은 실제 알림 권한 / 휴대폰이 아닌 곳에서 걷는 중 알림은 아무것도 하지 않는다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(notificationPermissionProvider), isA<LocalNotificationPermission>());
      expect(container.read(walkNoticeProvider), isA<NoopWalkNotice>());
    });

    test('테스트는 가짜로 바꿔 끼운다', () {
      final notice = FakeWalkNotice();
      final container = ProviderContainer(overrides: [
        notificationPermissionProvider.overrideWithValue(_FakePermission()),
        walkNoticeProvider.overrideWithValue(notice),
      ]);
      addTearDown(container.dispose);

      expect(container.read(notificationPermissionProvider), isA<_FakePermission>());
      expect(container.read(walkNoticeProvider), same(notice));
    });
  });
}
