import 'package:flutter/foundation.dart' show debugPrint;

import '../domain/notification_policy.dart' show NoticeKind;

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

/// 자리표시: 아무것도 띄우지 않고 부름만 [calls]에 쌓는다 (테스트가 읽는다).
/// M6에서 flutter_local_notifications로 바꾼다 (알림 권한·눌렀을 때 이동·예약 시각 변환도 그때)
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
