import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/day_card.dart';
import 'providers.dart';
import 'report_service.dart';

/// 하루 카드·걷기 리포트 (기기 안 자료만)
final reportServiceProvider = FutureProvider<ReportService>(
  (ref) async => ReportService(ref.watch(dbProvider), await ref.watch(rulesProvider.future)),
);

/// 앱을 열 때 쉼터 위에 겹쳐 뜨는 하루 카드 (M2~M6 v0.17 U ①). 없으면 null.
/// AutoSync가 앱을 켜고·다시 앞으로 올 때 동기화한 뒤 [check]하고, 카드를 닫으면 [dismiss]가 그 끝날까지
/// 본 것으로 적는다 (닫기 전에 앱이 끝나면 다음에 열 때 다시 뜬다)
class PendingDayCard extends Notifier<DayCard?> {
  /// 이번 실행에서 닫은 카드의 끝날. 닫은 기록(DB)이 아직 안 써졌거나, 닫기 전에 시작한 확인이 늦게 끝나도
  /// 그 날까지의 카드를 다시 띄우지 않는다
  String? _closedTo;

  @override
  DayCard? build() => null;

  /// 지금 보여 줄 카드를 다시 본다 (05:00 기준, 밀린 날은 한 장)
  Future<void> check() async {
    try {
      final svc = await ref.read(reportServiceProvider.future);
      final card = await svc.dueCard(ref.read(clockProvider)());
      final closed = _closedTo;
      state = card != null && closed != null && card.range.to.compareTo(closed) <= 0 ? null : card;
    } catch (e) {
      debugPrint('하루 카드 확인 실패: $e');
    }
  }

  /// 카드를 닫았다
  Future<void> dismiss() async {
    final card = state;
    if (card == null) return;
    _closedTo = card.range.to;
    state = null;
    try {
      await (await ref.read(reportServiceProvider.future)).markShown(card.range.to);
    } catch (e) {
      debugPrint('하루 카드 닫음 기록 실패: $e');
    }
  }
}

final pendingDayCardProvider = NotifierProvider<PendingDayCard, DayCard?>(PendingDayCard.new);

/// 노트 날짜 줄에서 다시 보는 그날 하루 카드 (날짜로 다시 계산, M2~M6 v0.17 U ④)
final dayCardOfProvider = FutureProvider.autoDispose.family<DayCard, String>((ref, day) async {
  await ref.watch(snapshotProvider.future);
  return (await ref.watch(reportServiceProvider.future)).cardFor(DayRange.single(day));
});

/// 최근 [days]일 걷기 리포트 (캔버스 6-4). 아직 다 지난 날이 없으면 null
final walkReportProvider = FutureProvider.autoDispose.family<WalkReport?, int>((ref, days) async {
  await ref.watch(snapshotProvider.future);
  final svc = await ref.watch(reportServiceProvider.future);
  return svc.report(ref.read(clockProvider)(), days);
});
