import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/db/app_db.dart';
import '../data/notifier.dart';
import '../domain/notification_policy.dart';
import '../domain/rules.dart';
import '../domain/time_kst.dart';

/// 알림 판단을 DB(알림 기록·켜고 끄기)와 SystemNotifier에 잇는다 (M6 명세). 무엇을 보낼지는
/// domain/notification_policy.dart가 정하고, 여기서는 기록을 읽어 넣어 주고 결과대로 보내거나
/// 예약하고 기록을 적는다. 알림 실패는 동기화·앱 흐름을 막지 않는다 (로그만 남긴다).
/// 부름은 하나씩 차례로 처리한다 (하루 최대가 어긋나지 않게)
class NotificationService {
  NotificationService({
    required this.db,
    required this.rules,
    required this.catalog,
    required this.notifier,
    this.inForeground = _always,
  });

  final AppDb db;
  final Rules rules;
  final NoticeCatalog catalog;
  final SystemNotifier notifier;

  /// 앱이 앞에 있는가. 앞이면 시스템 알림 대신 화면 안 표시만 한다.
  /// 앱은 AutoSync가 lifecycle로 알려 주는 값을 넣는다 (기본은 앞)
  final bool Function() inForeground;

  Future<void> _queue = Future.value();

  Future<void> _serial(Future<void> Function() job) {
    final run = _queue.then((_) => job());
    _queue = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  // -------------------------------------------------------------------------------------------
  // 켜고 끄기

  Future<NoticeSettings> settings() async {
    final r = await (db.select(db.notificationSettings)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (r == null) return const NoticeSettings();
    return NoticeSettings(all: r.allOn, off: {
      if (!r.n1On) NoticeKind.n1,
      if (!r.n2On) NoticeKind.n2,
      if (!r.n3On) NoticeKind.n3,
      if (!r.n4On) NoticeKind.n4,
      if (!r.n5On) NoticeKind.n5,
    });
  }

  /// 전체 켜기·끄기. 꺼진 종류의 예약은 취소한다
  Future<NoticeSettings> setAll(bool on, DateTime now) => _save((s) => s.withAll(on), now);

  /// 종류 하나 켜기·끄기. 꺼진 종류의 예약은 취소한다
  Future<NoticeSettings> setKind(NoticeKind kind, bool on, DateTime now) =>
      _save((s) => s.withKind(kind, on), now);

  Future<NoticeSettings> _save(NoticeSettings Function(NoticeSettings) change, DateTime now) async {
    final saved = change(await settings());
    await db.into(db.notificationSettings).insertOnConflictUpdate(NotificationSettingsCompanion(
          id: const Value(1),
          allOn: Value(saved.all),
          n1On: Value(!saved.off.contains(NoticeKind.n1)),
          n2On: Value(!saved.off.contains(NoticeKind.n2)),
          n3On: Value(!saved.off.contains(NoticeKind.n3)),
          n4On: Value(!saved.off.contains(NoticeKind.n4)),
          n5On: Value(!saved.off.contains(NoticeKind.n5)),
        ));
    await _serial(() => _cancelPending(now.toUtc(), keep: saved.enabled));
    return saved;
  }

  // -------------------------------------------------------------------------------------------
  // 동기화 끝 (N1~N4)

  /// 한 번의 동기화가 끝났을 때 새로 생긴 일 [candidates]를 정책에 넘겨 보내거나 예약하거나
  /// 화면 안 표시만 하고, 어떻게 됐는지 기록에 적는다. 이미 기록에 있는 일은 다시 알리지 않는다
  /// (N4는 여정마다 1번)
  Future<void> afterSync(List<NoticeCandidate> candidates, DateTime now) async {
    if (candidates.isEmpty) return;
    try {
      await _serial(() => _afterSync(candidates, now.toUtc()));
    } catch (e) {
      debugPrint('알림 판정 실패: $e');
    }
  }

  Future<void> _afterSync(List<NoticeCandidate> candidates, DateTime now) async {
    final fresh = <NoticeCandidate>[];
    for (final c in candidates) {
      if (!await _logged(c.kind, c.key)) fresh.add(c);
    }
    if (fresh.isEmpty) return;

    final pendingRow = await _pendingSlot(now);
    final decision = pickNotice(
      candidates: fresh,
      now: now,
      rules: rules,
      catalog: catalog,
      installId: await _installId(),
      enabled: (await settings()).enabled,
      sentByDay: await _sentByDay(now, except: pendingRow),
      inForeground: inForeground(),
      pending: pendingRow == null ? null : PendingNotice(pendingRow.kind, _utc(pendingRow.atUtc)),
    );

    final chosen = decision.chosen;
    final message = decision.message;
    switch (decision.action) {
      case NoticeAction.nothing:
        break;
      case NoticeAction.inApp:
        await _log(chosen!.kind, chosen.key, now, NoticeStatus.inApp);
      case NoticeAction.sendNow:
        final id = await _log(chosen!.kind, chosen.key, now, NoticeStatus.sent);
        await _deliver(id,
            () => notifier.show(id, message!.kind, message.title, message.body, message.payload));
      case NoticeAction.schedule:
        if (decision.replacesPending) await _cancelRow(pendingRow!);
        final at = decision.at!;
        final id = await _log(chosen!.kind, chosen.key, at, NoticeStatus.scheduled);
        await _deliver(id, () => notifier.schedule(
            id, at, message!.kind, message.title, message.body, message.payload));
    }
    for (final c in decision.dropped) {
      await _log(c.kind, c.key, now, NoticeStatus.dropped);
    }
  }

  // -------------------------------------------------------------------------------------------
  // N5 (며칠 미접속)

  /// 앱이 백그라운드로 갈 때: N5를 지금 + inactiveHours에 예약한다. 이미 예약돼 있거나,
  /// 이미 울렸는데 아직 안 열었거나, N5가 꺼져 있으면 하지 않는다
  Future<void> onBackground(DateTime now) async {
    try {
      await _serial(() => _onBackground(now.toUtc()));
    } catch (e) {
      debugPrint('N5 예약 실패: $e');
    }
  }

  Future<void> _onBackground(DateTime now) async {
    final at = planInactive(
      now: now,
      rules: rules,
      enabled: (await settings()).isOn(NoticeKind.n5),
      state: await _inactiveState(now),
    );
    if (at == null) return;
    final message = buildNotice(
        const NoticeCandidate(NoticeKind.n5), catalog, await _installId(), now);
    final id = await _log(NoticeKind.n5, '', at, NoticeStatus.scheduled);
    await _deliver(id, () => notifier.schedule(
        id, at, message.kind, message.title, message.body, message.payload));
  }

  /// 앱을 열 때(켤 때·돌아올 때): 예약해 둔 N5를 취소하고 울린 상태를 초기화한다
  /// (울렸던 것은 울린 것으로 남기고 다음 백그라운드 때 다시 예약할 수 있게 한다)
  Future<void> onOpen(DateTime now) async {
    try {
      await _serial(() => _onOpen(now.toUtc()));
    } catch (e) {
      debugPrint('N5 취소 실패: $e');
    }
  }

  Future<void> _onOpen(DateTime now) async {
    final nowMs = now.millisecondsSinceEpoch;
    for (final r in await _scheduledRows(NoticeKind.n5)) {
      if (r.atUtc > nowMs) {
        await _cancelRow(r);
      } else {
        await _setStatus(r.id, NoticeStatus.sent);
      }
    }
  }

  Future<InactiveState> _inactiveState(DateTime now) async {
    final rows = await _scheduledRows(NoticeKind.n5);
    if (rows.isEmpty) return InactiveState.none;
    return rows.any((r) => r.atUtc > now.millisecondsSinceEpoch)
        ? InactiveState.pending
        : InactiveState.fired;
  }

  // -------------------------------------------------------------------------------------------
  // 취소

  /// 아직 안 뜬 예약을 모두 취소한다 (기기 기록을 모두 지우기 전에)
  Future<void> cancelAllPending(DateTime now) =>
      _serial(() => _cancelPending(now.toUtc(), keep: const {}));

  /// 아직 안 뜬 예약 중 [keep]에 없는 종류를 취소한다
  Future<void> _cancelPending(DateTime now, {required Set<NoticeKind> keep}) async {
    final rows = await (db.select(db.notificationLog)
          ..where((t) =>
              t.status.equalsValue(NoticeStatus.scheduled) &
              t.atUtc.isBiggerThanValue(now.millisecondsSinceEpoch)))
        .get();
    for (final r in rows) {
      if (!keep.contains(r.kind)) await _cancelRow(r);
    }
  }

  // -------------------------------------------------------------------------------------------
  // 기록

  Future<String> _installId() async =>
      (await (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull())
          ?.installId ??
      '';

  Future<int> _log(NoticeKind kind, String refKey, DateTime at, NoticeStatus status) =>
      db.into(db.notificationLog).insert(NotificationLogCompanion.insert(
            kind: kind,
            refKey: refKey,
            atUtc: at.millisecondsSinceEpoch,
            status: status,
          ));

  Future<void> _setStatus(int id, NoticeStatus status) =>
      (db.update(db.notificationLog)..where((t) => t.id.equals(id)))
          .write(NotificationLogCompanion(status: Value(status)));

  /// 알림을 실제로 내보낸다. 실패하면 기록을 못 보낸 것(dropped)으로 고친다
  Future<void> _deliver(int id, Future<void> Function() send) async {
    try {
      await send();
    } catch (e) {
      debugPrint('알림 보내기 실패: $e');
      await _setStatus(id, NoticeStatus.dropped);
    }
  }

  /// 예약을 취소하고 기록을 cancelled로
  Future<void> _cancelRow(NotificationLogRow r) async {
    await _setStatus(r.id, NoticeStatus.cancelled);
    try {
      await notifier.cancel(r.id);
    } catch (e) {
      debugPrint('알림 취소 실패: $e');
    }
  }

  /// 같은 일((종류, 키))을 이미 기록했는가
  Future<bool> _logged(NoticeKind kind, String refKey) async =>
      (await (db.select(db.notificationLog)
                ..where((t) => t.kind.equalsValue(kind) & t.refKey.equals(refKey))
                ..limit(1))
              .get())
          .isNotEmpty;

  Future<List<NotificationLogRow>> _scheduledRows(NoticeKind kind) =>
      (db.select(db.notificationLog)
            ..where((t) => t.kind.equalsValue(kind) & t.status.equalsValue(NoticeStatus.scheduled))
            ..orderBy([(t) => OrderingTerm.desc(t.id)]))
          .get();

  /// 조용한 시간에 예약해 둔 N1~N4 중 아직 안 뜬 것 하나 (우선순위가 가장 높은 것)
  Future<NotificationLogRow?> _pendingSlot(DateTime now) async {
    final rows = await (db.select(db.notificationLog)
          ..where((t) =>
              t.status.equalsValue(NoticeStatus.scheduled) &
              t.kind.equalsValue(NoticeKind.n5).not() &
              t.atUtc.isBiggerThanValue(now.millisecondsSinceEpoch)))
        .get();
    NotificationLogRow? best;
    for (final r in rows) {
      if (best == null || catalog.priorityOf(r.kind) < catalog.priorityOf(best.kind)) best = r;
    }
    return best;
  }

  /// 오늘 이후 한국 날짜별로, 나갔거나 나가기로 한 시스템 알림 수 (보냄 + 예약, 취소 뺌).
  /// 조용한 시간 예약 하나([except])는 바꿔 끼울 수 있어서 세지 않는다
  Future<Map<String, int>> _sentByDay(DateTime now, {NotificationLogRow? except}) async {
    final from = kstDayStartUtc(kstDayKey(now)).millisecondsSinceEpoch;
    final rows = await (db.select(db.notificationLog)
          ..where((t) =>
              t.atUtc.isBiggerOrEqualValue(from) &
              (t.status.equalsValue(NoticeStatus.sent) |
                  t.status.equalsValue(NoticeStatus.scheduled))))
        .get();
    final byDay = <String, int>{};
    for (final r in rows) {
      if (r.id == except?.id) continue;
      final day = kstDayKey(_utc(r.atUtc));
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    return byDay;
  }
}

bool _always() => true;

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
