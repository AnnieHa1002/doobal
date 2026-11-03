import 'package:doobal/data/local_notifications.dart';
import 'package:doobal/data/notifier.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_local_notifications가 안드로이드에서 쓰는 채널
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    // 실제 앱에서는 플러그인 등록이 해 주는 일 (테스트의 기본 플랫폼은 안드로이드)
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  AndroidSystemNotifier make() => AndroidSystemNotifier(LocalNotifications());
  MethodCall only(String method) => calls.singleWhere((c) => c.method == method);
  Map<Object?, Object?> args(MethodCall c) => c.arguments as Map<Object?, Object?>;
  Map<Object?, Object?> specifics(MethodCall c) =>
      args(c)['platformSpecifics']! as Map<Object?, Object?>;

  test('show: 알림 기록 id로 두발 소식 채널에 띄우고, 누르면 쓸 payload를 단다', () async {
    await make().show(7, NoticeKind.n1, '3,000보예요', '방명록을 남길 수 있어요', 'N1:m:3000');

    final a = args(only('show'));
    expect((a['id'], a['title'], a['body'], a['payload']),
        (7, '3,000보예요', '방명록을 남길 수 있어요', 'N1:m:3000'));
    final d = specifics(only('show'));
    expect(d['channelId'], 'notices');
    expect(d['channelName'], '두발 소식');
    expect(d['channelDescription'], '도착·방명록 기회 같은 소식만, 하루 2개까지');
    expect(d['icon'], 'ic_stat_walk');
    // 걷는 중 상시 알림(조용한 low)과 달리 보통 중요도
    expect(d['importance'], 3);
  });

  test('schedule: UTC 시각 그대로, 정확한 시각 권한 없이 되는 방식으로 예약한다', () async {
    final at = DateTime.now().toUtc().add(const Duration(days: 3));
    final utc = DateTime.utc(at.year, at.month, at.day, 1); // 한국 오전 10시
    await make().schedule(9, utc, NoticeKind.n5, '보고 싶어', '쉼터에서 기다릴게', 'N5:');

    final call = only('zonedSchedule');
    final a = args(call);
    expect((a['id'], a['title'], a['body'], a['payload']), (9, '보고 싶어', '쉼터에서 기다릴게', 'N5:'));
    expect(a['timeZoneName'], 'Etc/UTC');
    expect(a['scheduledDateTime'], utc.toIso8601String().split('.')[0].replaceAll('Z', ''));
    expect(specifics(call)['scheduleMode'], 'inexactAllowWhileIdle');
    expect(specifics(call)['channelId'], 'notices');
  });

  test('cancel: 그 id의 알림을 취소한다', () async {
    await make().cancel(9);
    expect(args(only('cancel'))['id'], 9);
  });
}
