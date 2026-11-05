import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'sync_service.dart';

/// 동행 화면의 값. 동행을 바꾸거나 이야기를 읽은 뒤에 invalidate 한다
final companionsViewProvider = FutureProvider.autoDispose<CompanionsView>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.companionsView();
});
