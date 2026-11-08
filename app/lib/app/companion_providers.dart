import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_pace.dart';
import 'providers.dart';
import 'sync_service.dart';

/// 동행 화면의 값. 동행을 바꾸거나 이야기를 읽은 뒤에 invalidate 한다
final companionsViewProvider = FutureProvider.autoDispose<CompanionsView>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.companionsView();
});

/// 동행 입구의 알림 점: 안 읽은 장이 있는가. 쉼터 불 옆 동행이 NoticeDot으로 읽는다
final unreadStoryProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(companionsViewProvider).value?.hasUnread ?? false,
);

/// 마지막으로 걷기를 마친 때와 동행이 쉼터에 늦게 오는 시간(초, lateArrivalSec)
typedef CampLateArrival = ({DateTime finishedUtc, double lateSec});

/// 걷기를 마칠 때 한 번 적는다. 화면 연출이라 저장하지 않는다 (앱을 닫으면 없어진다, M2)
class CampArrivalNotifier extends Notifier<CampLateArrival?> {
  @override
  CampLateArrival? build() => null;

  void finishWalk(DateTime finishedUtc, double lateSec) =>
      state = (finishedUtc: finishedUtc, lateSec: lateSec);
}

final campArrivalProvider =
    NotifierProvider<CampArrivalNotifier, CampLateArrival?>(CampArrivalNotifier.new);

/// 쉼터 불 옆에 동행이 와 앉았는가 (seatedAtCamp). 늦게 오는 중이면 false이고, 그때가 되면 다시 읽어 true
final companionSeatedProvider = Provider.autoDispose<bool>((ref) {
  final late = ref.watch(campArrivalProvider);
  if (late == null) return true;
  final since = ref.watch(clockProvider)().difference(late.finishedUtc).inMicroseconds /
      Duration.microsecondsPerSecond;
  if (seatedAtCamp(lateSec: late.lateSec, sinceFinishSec: since)) return true;
  final wait = Duration(
    microseconds: ((late.lateSec - since) * Duration.microsecondsPerSecond).ceil(),
  );
  final timer = Timer(wait, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return false;
});
