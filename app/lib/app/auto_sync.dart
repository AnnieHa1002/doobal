import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// MaterialApp에 달아 두면 어느 화면에서도 토스트를 띄울 수 있다
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 이 거리(km) 이상 늘었을 때만 "그동안 n km 걸었어요"를 보여 준다
const _toastMinKm = 0.1;

/// 앱을 켤 때와 백그라운드에서 돌아올 때 한 번씩 동기화하고 상태를 새로 읽는다.
/// 권한이 없는 등 실패는 조용히 넘어간다
class AutoSync extends ConsumerStatefulWidget {
  const AutoSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends ConsumerState<AutoSync> {
  late final AppLifecycleListener _lifecycle;
  var _running = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _sync);
    _sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    // 겹쳐 돌지 않게 한다 (시작과 resumed가 연달아 올 수 있다)
    if (_running) return;
    _running = true;
    try {
      final svc = await ref.read(syncServiceProvider.future);
      final report = await svc.sync(ref.read(clockProvider)());
      if (!mounted) return;
      ref.invalidate(snapshotProvider);
      if (report.advancedKm >= _toastMinKm) {
        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text('그동안 ${report.advancedKm.toStringAsFixed(1)}km 걸었어요'),
        ));
      }
    } catch (e) {
      debugPrint('자동 동기화 실패: $e');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
