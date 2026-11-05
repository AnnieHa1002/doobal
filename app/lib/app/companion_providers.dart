import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'sync_service.dart';

/// 동행 화면의 값. 동행을 바꾸거나 이야기를 읽은 뒤에 invalidate 한다
final companionsViewProvider = FutureProvider.autoDispose<CompanionsView>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.companionsView();
});

/// 동행 입구의 알림 점: 안 읽은 장이 있는가. 쉼터 입구(T3)가 NoticeDot으로 읽는다
final unreadStoryProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(companionsViewProvider).value?.hasUnread ?? false,
);
