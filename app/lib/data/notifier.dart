import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_policy.dart' show NoticeKind;
import 'local_notifications.dart';

/// 시스템 알림을 띄우는 곳. 무엇을 언제 보낼지는 정하지 않는다 (그건 notification_policy).
/// 이름이 SystemNotifier인 건 riverpod의 Notifier와 겹치지 않으려고다.
/// [id]는 알림 기록(NotificationLog)의 id라서 예약한 것을 [cancel]로 취소할 수 있다.
/// [payload]는 눌렀을 때 어디로 갈지 ('N1:m:3000' 꼴, NoticeMessage.payload). 테스트는 가짜를 쓴다
abstract class SystemNotifier {
  /// 지금 띄운다
  Future<void> show(int id, NoticeKind kind, String title, String body, String payload);

  /// [at](UTC)에 뜨도록 예약한다
  Future<void> schedule(
    int id,
    DateTime at,
    NoticeKind kind,
    String title,
    String body,
    String payload,
  );

  /// 예약을 취소한다. 없는 id면 아무 일도 없다
  Future<void> cancel(int id);
}

enum NotifierOp { show, schedule, cancel }

/// [PlaceholderNotifier]가 받은 부름 하나
class NotifierCall {
  const NotifierCall(this.op, this.id, {this.kind, this.at, this.title, this.body, this.payload});

  final NotifierOp op;
  final int id;
  final NoticeKind? kind;
  final DateTime? at;
  final String? title;
  final String? body;
  final String? payload;
}

/// 안드로이드: flutter_local_notifications로 띄우고 예약한다 (UI 명세 13장 알림 5종).
/// 채널은 하나(`두발 소식`), 작은 아이콘은 걷는 중 상시 알림과 같은 발자국이다.
/// 예약은 정확한 시각 권한(SCHEDULE_EXACT_ALARM) 없이 되는 inexactAllowWhileIdle이라 몇 분 늦을 수 있다
/// (N5 오전 10시·조용한 시간 뒤 08시 같은 예약이라 괜찮다). 휴대폰을 껐다 켜도 예약은 남는다
/// (AndroidManifest의 ScheduledNotificationBootReceiver). 알림 권한이 꺼져 있으면 안드로이드가 띄우지 않는다
class AndroidSystemNotifier implements SystemNotifier {
  AndroidSystemNotifier(this._notifications);

  final LocalNotifications _notifications;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'notices',
      '두발 소식',
      channelDescription: '도착·방명록 기회 같은 소식만, 하루 2개까지',
      icon: walkNoticeIcon,
    ),
  );

  @override
  Future<void> show(int id, NoticeKind kind, String title, String body, String payload) async {
    final plugin = await _notifications.ready();
    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  @override
  Future<void> schedule(
    int id,
    DateTime at,
    NoticeKind kind,
    String title,
    String body,
    String payload,
  ) async {
    final plugin = await _notifications.ready();
    // 시간대 자료 없이 쓸 수 있는 UTC로 넘긴다 (예약 시각은 늘 UTC로 정해 온다)
    await plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    final plugin = await _notifications.ready();
    await plugin.cancel(id: id);
  }
}

/// 자리표시: 아무것도 띄우지 않고 부름만 [calls]에 쌓는다 (테스트·iOS·데스크톱).
/// iOS는 안드로이드 다음에 붙인다 (11/1 Annie: 안드로이드 먼저)
class PlaceholderNotifier implements SystemNotifier {
  /// 받은 부름, 받은 순서대로
  final calls = <NotifierCall>[];

  @override
  Future<void> show(int id, NoticeKind kind, String title, String body, String payload) async {
    debugPrint('알림 보냄(자리표시): ${kind.id} $title');
    calls.add(NotifierCall(NotifierOp.show, id,
        kind: kind, title: title, body: body, payload: payload));
  }

  @override
  Future<void> schedule(
    int id,
    DateTime at,
    NoticeKind kind,
    String title,
    String body,
    String payload,
  ) async {
    debugPrint('알림 예약(자리표시): ${kind.id} $title $at');
    calls.add(NotifierCall(NotifierOp.schedule, id,
        kind: kind, at: at, title: title, body: body, payload: payload));
  }

  @override
  Future<void> cancel(int id) async {
    debugPrint('알림 취소(자리표시): $id');
    calls.add(NotifierCall(NotifierOp.cancel, id));
  }
}
